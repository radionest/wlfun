/// Модуль для кодирования/декодирования инвентаря в URI
/// Формат: #inv=v2.BASE64_DATA (все 3 редкости)
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string
import items_calculator/game_data.{Blue, Green, Purple}
import plinth/browser/window
import sets_calculator/sets_game_data.{SetId}
import sets_calculator/sets_inventory.{type Inventory}

/// Версия формата URI
const uri_version = "v2"

/// Префикс в hash
const hash_prefix = "inv="

/// FFI для установки hash
@external(javascript, "../sets_uri_ffi.mjs", "setHash")
fn set_hash(hash: String) -> Nil

/// Кодирование всего инвентаря (все 3 редкости) в строку для URI
pub fn encode_inventory(inventory: Inventory) -> String {
  // Получаем плоские списки для всех редкостей (288 * 3 = 864 значения)
  let blue_counts = sets_inventory.get_all_counts_list(inventory, Blue)
  let green_counts = sets_inventory.get_all_counts_list(inventory, Green)
  let purple_counts = sets_inventory.get_all_counts_list(inventory, Purple)

  // Объединяем все counts с offset для каждого цвета
  // Blue: 0-287, Green: 288-575, Purple: 576-863
  let all_entries =
    list.flatten([
      counts_to_sparse(blue_counts, 0),
      counts_to_sparse(green_counts, 288),
      counts_to_sparse(purple_counts, 576),
    ])

  // Формируем строку "idx:cnt,idx:cnt,..."
  let data_str =
    all_entries
    |> list.map(fn(e: #(Int, Int)) {
      int.to_string(e.0) <> ":" <> int.to_string(e.1)
    })
    |> string.join(",")

  // Base64 URL-safe encode
  let encoded =
    bit_array.base64_url_encode(bit_array.from_string(data_str), False)

  // Формат: v2.DATA
  uri_version <> "." <> encoded
}

/// Преобразование списка counts в sparse entries с offset
fn counts_to_sparse(counts: List(Int), offset: Int) -> List(#(Int, Int)) {
  counts
  |> list.index_map(fn(count, idx) { #(offset + idx, count) })
  |> list.filter(fn(entry) { entry.1 > 0 })
}

/// Декодирование инвентаря из строки URI (v2 формат)
pub fn decode_inventory(encoded: String) -> Result(Inventory, String) {
  case string.split(encoded, ".") {
    // v2 формат: v2.DATA (все редкости)
    ["v2", data] -> {
      case bit_array.base64_url_decode(data) {
        Ok(bytes) -> {
          case bit_array.to_string(bytes) {
            Ok(data_str) -> {
              case decode_sparse_entries(data_str) {
                Ok(entries) -> {
                  let inventory = restore_inventory_all(entries)
                  Ok(inventory)
                }
                Error(e) -> Error("Invalid data: " <> e)
              }
            }
            Error(_) -> Error("Invalid UTF-8 data")
          }
        }
        Error(_) -> Error("Base64 decode error")
      }
    }
    _ -> Error("Invalid URI format (expected v2)")
  }
}

/// Генерация полного URL для share
pub fn generate_share_url(inventory: Inventory) -> String {
  let encoded = encode_inventory(inventory)
  let base_url = window.location()

  // Убираем существующий hash если есть
  let base = case string.split(base_url, "#") {
    [url, ..] -> url
    [] -> base_url
  }

  base <> "#" <> hash_prefix <> encoded
}

/// Установить hash в URL
pub fn set_url_hash(inventory: Inventory) -> Nil {
  let encoded = encode_inventory(inventory)
  set_hash(hash_prefix <> encoded)
}

/// Парсинг hash из URL при загрузке
pub fn parse_url_hash() -> Result(Inventory, Nil) {
  case window.get_hash() {
    Ok(hash) -> {
      // Проверяем формат #inv=... или inv=...
      let hash_clean = case string.starts_with(hash, "#") {
        True -> string.drop_start(hash, 1)
        False -> hash
      }

      case string.starts_with(hash_clean, hash_prefix) {
        True -> {
          let encoded =
            string.drop_start(hash_clean, string.length(hash_prefix))
          case decode_inventory(encoded) {
            Ok(inventory) -> Ok(inventory)
            Error(_) -> Error(Nil)
          }
        }
        False -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

// === Вспомогательные функции ===

/// Декодирование sparse entries из строки "idx:cnt,idx:cnt,..."
fn decode_sparse_entries(data_str: String) -> Result(List(#(Int, Int)), String) {
  case data_str {
    "" -> Ok([])
    _ -> {
      let parts = string.split(data_str, ",")
      parts
      |> list.try_map(fn(part) {
        case string.split(part, ":") {
          [idx_str, cnt_str] -> {
            case int.parse(idx_str), int.parse(cnt_str) {
              Ok(idx), Ok(cnt) -> Ok(#(idx, cnt))
              _, _ -> Error("Invalid entry: " <> part)
            }
          }
          _ -> Error("Invalid entry format: " <> part)
        }
      })
    }
  }
}

/// Восстановление Inventory из sparse entries (v2 формат — все редкости)
/// Индексы: Blue: 0-287, Green: 288-575, Purple: 576-863
fn restore_inventory_all(entries: List(#(Int, Int))) -> Inventory {
  let all_names = sets_game_data.all_entity_names()

  // Начинаем с пустого инвентаря
  let empty_inv = sets_inventory.empty()

  // Применяем каждую entry
  list.fold(entries, empty_inv, fn(inv, entry) {
    let #(global_idx, count) = entry

    // Определяем цвет по диапазону индексов
    let #(color, local_idx) = case global_idx {
      idx if idx < 288 -> #(Blue, idx)
      idx if idx < 576 -> #(Green, idx - 288)
      idx -> #(Purple, idx - 576)
    }

    // Вычисляем SetId из локального индекса
    // local_idx = entity_idx * 8 + (set_num - 1) * 4 + slot_idx
    let entity_idx = local_idx / 8
    let remainder = local_idx % 8
    let set_num = remainder / 4 + 1
    let slot_idx = remainder % 4 + 1
    // slots 1-4

    // Получаем имя по индексу через drop + first
    case list.drop(all_names, entity_idx) |> list.first {
      Ok(name) -> {
        let entity_type = sets_game_data.detect_entity_type(name)
        let set_id = SetId(name, entity_type, color, set_num)
        sets_inventory.set_slot_count(inv, set_id, slot_idx, count)
      }
      Error(_) -> inv
    }
  })
}
