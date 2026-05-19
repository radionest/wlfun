import gleam/dynamic/decode
import gleam/json
import plinth/javascript/storage as plinth_storage
import sets_calculator/sets_inventory.{
  type Inventory, type OwnedSlots, type OwnedCounts,
  OwnedSlots, OwnedCounts, from_counts_list, from_slots_list, counts_to_list,
}
import varasto

const counts_storage_key = "wl_sets_counts"

// Старый ключ для миграции
const legacy_slots_key = "wl_sets_inventory"

/// Декодер для OwnedCounts
fn owned_counts_decoder() -> decode.Decoder(OwnedCounts) {
  use c1 <- decode.field("c1", decode.int)
  use c2 <- decode.field("c2", decode.int)
  use c3 <- decode.field("c3", decode.int)
  use c4 <- decode.field("c4", decode.int)
  decode.success(OwnedCounts(slot1: c1, slot2: c2, slot3: c3, slot4: c4))
}

/// Декодер для одной записи counts
fn count_entry_decoder() -> decode.Decoder(#(String, OwnedCounts)) {
  use key <- decode.field("k", decode.string)
  use counts <- decode.field("v", owned_counts_decoder())
  decode.success(#(key, counts))
}

/// Декодер для списка записей counts
fn count_entries_decoder() -> decode.Decoder(List(#(String, OwnedCounts))) {
  decode.list(count_entry_decoder())
}

/// Энкодер для OwnedCounts
fn owned_counts_encoder(counts: OwnedCounts) -> json.Json {
  let OwnedCounts(c1, c2, c3, c4) = counts
  json.object([
    #("c1", json.int(c1)),
    #("c2", json.int(c2)),
    #("c3", json.int(c3)),
    #("c4", json.int(c4)),
  ])
}

/// Энкодер для одной записи counts
fn count_entry_encoder(entry: #(String, OwnedCounts)) -> json.Json {
  let #(key, counts) = entry
  json.object([#("k", json.string(key)), #("v", owned_counts_encoder(counts))])
}

/// Энкодер для списка записей counts
fn count_entries_encoder(entries: List(#(String, OwnedCounts))) -> json.Json {
  json.array(entries, count_entry_encoder)
}

// ========== Legacy slots (для миграции) ==========

/// Декодер для OwnedSlots (legacy)
fn owned_slots_decoder() -> decode.Decoder(OwnedSlots) {
  use s1 <- decode.field("s1", decode.bool)
  use s2 <- decode.field("s2", decode.bool)
  use s3 <- decode.field("s3", decode.bool)
  use s4 <- decode.field("s4", decode.bool)
  decode.success(OwnedSlots(slot1: s1, slot2: s2, slot3: s3, slot4: s4))
}

/// Декодер для одной записи slots (legacy)
fn slot_entry_decoder() -> decode.Decoder(#(String, OwnedSlots)) {
  use key <- decode.field("k", decode.string)
  use slots <- decode.field("v", owned_slots_decoder())
  decode.success(#(key, slots))
}

/// Декодер для списка записей slots (legacy)
fn slot_entries_decoder() -> decode.Decoder(List(#(String, OwnedSlots))) {
  decode.list(slot_entry_decoder())
}

/// Загрузить инвентарь из localStorage
/// Поддерживает миграцию: если есть старый формат slots без counts, конвертирует
pub fn load() -> Inventory {
  case plinth_storage.local() {
    Error(_) -> sets_inventory.empty()
    Ok(raw_storage) -> {
      // Пробуем загрузить counts (новый формат)
      let counts_storage = varasto.new(raw_storage, count_entries_decoder(), count_entries_encoder)
      case varasto.get(counts_storage, counts_storage_key) {
        Ok(count_entries) -> from_counts_list(count_entries)
        Error(_) -> {
          // Пробуем загрузить legacy slots и мигрировать
          let slots_storage = varasto.new(raw_storage, slot_entries_decoder(), fn(_) { json.null() })
          case varasto.get(slots_storage, legacy_slots_key) {
            Ok(slot_entries) -> {
              // Миграция: конвертируем slots в counts
              let inventory = from_slots_list(slot_entries)
              // Сохраняем в новом формате
              save(inventory)
              // Удаляем старый ключ
              let _ = plinth_storage.remove_item(raw_storage, legacy_slots_key)
              inventory
            }
            Error(_) -> sets_inventory.empty()
          }
        }
      }
    }
  }
}

/// Сохранить инвентарь в localStorage
pub fn save(inventory: Inventory) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let counts_storage = varasto.new(raw_storage, count_entries_decoder(), count_entries_encoder)
      let count_entries = counts_to_list(inventory)
      let _ = varasto.set(counts_storage, counts_storage_key, count_entries)
      Nil
    }
  }
}
