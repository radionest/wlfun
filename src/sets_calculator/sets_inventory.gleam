import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/string
import items_calculator/game_data.{type ItemColor, Blue, Green, Light, Purple}
import sets_calculator/sets_game_data.{
  type EntityType, type SetId, HeroEntity, RegularUnit, SetId,
}

/// Имеющиеся слоты вещей в сете
pub type OwnedSlots {
  OwnedSlots(slot1: Bool, slot2: Bool, slot3: Bool, slot4: Bool)
}

/// Счётчики дубликатов для слотов (сколько раз выпала вещь)
pub type OwnedCounts {
  OwnedCounts(slot1: Int, slot2: Int, slot3: Int, slot4: Int)
}

/// Начальные пустые слоты
pub fn empty_slots() -> OwnedSlots {
  OwnedSlots(slot1: False, slot2: False, slot3: False, slot4: False)
}

/// Начальные пустые счётчики
pub fn empty_counts() -> OwnedCounts {
  OwnedCounts(slot1: 0, slot2: 0, slot3: 0, slot4: 0)
}

/// Конвертация counts -> slots (count >= 1 означает owned)
pub fn counts_to_slots(counts: OwnedCounts) -> OwnedSlots {
  OwnedSlots(
    slot1: counts.slot1 >= 1,
    slot2: counts.slot2 >= 1,
    slot3: counts.slot3 >= 1,
    slot4: counts.slot4 >= 1,
  )
}

/// Синхронизация slots -> counts (сохраняя существующие значения)
pub fn sync_slots_to_counts(
  slots: OwnedSlots,
  counts: OwnedCounts,
) -> OwnedCounts {
  OwnedCounts(
    slot1: case slots.slot1 {
      True -> int_max(1, counts.slot1)
      False -> 0
    },
    slot2: case slots.slot2 {
      True -> int_max(1, counts.slot2)
      False -> 0
    },
    slot3: case slots.slot3 {
      True -> int_max(1, counts.slot3)
      False -> 0
    },
    slot4: case slots.slot4 {
      True -> int_max(1, counts.slot4)
      False -> 0
    },
  )
}

fn int_max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}

/// Подсчет заполненных слотов
pub fn count_owned(slots: OwnedSlots) -> Int {
  let OwnedSlots(s1, s2, s3, s4) = slots
  bool_to_int(s1) + bool_to_int(s2) + bool_to_int(s3) + bool_to_int(s4)
}

fn bool_to_int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

/// Глобальный инвентарь - хранит OwnedCounts по строковому ключу SetId
/// OwnedSlots вычисляются из counts на лету (count >= 1 означает owned)
pub type Inventory {
  Inventory(counts: Dict(String, OwnedCounts))
}

/// Пустой инвентарь
pub fn empty() -> Inventory {
  Inventory(counts: dict.new())
}

/// Преобразование SetId в строковый ключ для Dict
pub fn set_id_to_key(set_id: SetId) -> String {
  let SetId(entity_name, entity_type, color, set_number) = set_id
  entity_name
  <> "|"
  <> entity_type_to_str(entity_type)
  <> "|"
  <> color_to_str(color)
  <> "|"
  <> int.to_string(set_number)
}

/// Обратное преобразование из строкового ключа
pub fn key_to_set_id(key: String) -> Result(SetId, Nil) {
  case string.split(key, "|") {
    [name, type_str, color_str, num_str] -> {
      case int.parse(num_str) {
        Ok(num) ->
          Ok(SetId(
            entity_name: name,
            entity_type: str_to_entity_type(type_str),
            color: str_to_color(color_str),
            set_number: num,
          ))
        Error(_) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

/// Получить слоты для сета (вычисляются из counts)
pub fn get_slots(inventory: Inventory, set_id: SetId) -> OwnedSlots {
  counts_to_slots(get_counts(inventory, set_id))
}

/// Установить слоты для сета (конвертирует в counts)
pub fn set_slots(
  inventory: Inventory,
  set_id: SetId,
  slots: OwnedSlots,
) -> Inventory {
  let current_counts = get_counts(inventory, set_id)
  let new_counts = sync_slots_to_counts(slots, current_counts)
  set_counts(inventory, set_id, new_counts)
}

/// Получить счётчики для сета
pub fn get_counts(inventory: Inventory, set_id: SetId) -> OwnedCounts {
  let key = set_id_to_key(set_id)
  case dict.get(inventory.counts, key) {
    Ok(counts) -> counts
    Error(_) -> empty_counts()
  }
}

/// Установить счётчики для сета
pub fn set_counts(
  inventory: Inventory,
  set_id: SetId,
  counts: OwnedCounts,
) -> Inventory {
  let key = set_id_to_key(set_id)
  // Если все счётчики нулевые - удаляем запись
  case counts == empty_counts() {
    True -> Inventory(counts: dict.delete(inventory.counts, key))
    False -> Inventory(counts: dict.insert(inventory.counts, key, counts))
  }
}

/// Переключить конкретный слот
pub fn toggle_slot(inventory: Inventory, set_id: SetId, slot: Int) -> Inventory {
  let current = get_counts(inventory, set_id)
  let OwnedCounts(c1, c2, c3, c4) = current
  // Переключаем: если count > 0 -> 0, иначе -> 1
  let new_counts = case slot {
    1 -> OwnedCounts(slot1: toggle_count(c1), slot2: c2, slot3: c3, slot4: c4)
    2 -> OwnedCounts(slot1: c1, slot2: toggle_count(c2), slot3: c3, slot4: c4)
    3 -> OwnedCounts(slot1: c1, slot2: c2, slot3: toggle_count(c3), slot4: c4)
    4 -> OwnedCounts(slot1: c1, slot2: c2, slot3: c3, slot4: toggle_count(c4))
    _ -> current
  }
  set_counts(inventory, set_id, new_counts)
}

fn toggle_count(count: Int) -> Int {
  case count > 0 {
    True -> 0
    False -> 1
  }
}

/// Установить счётчик для конкретного слота
pub fn set_slot_count(
  inventory: Inventory,
  set_id: SetId,
  slot: Int,
  count: Int,
) -> Inventory {
  let current = get_counts(inventory, set_id)
  let OwnedCounts(c1, c2, c3, c4) = current
  let new_counts = case slot {
    1 -> OwnedCounts(slot1: count, slot2: c2, slot3: c3, slot4: c4)
    2 -> OwnedCounts(slot1: c1, slot2: count, slot3: c3, slot4: c4)
    3 -> OwnedCounts(slot1: c1, slot2: c2, slot3: count, slot4: c4)
    4 -> OwnedCounts(slot1: c1, slot2: c2, slot3: c3, slot4: count)
    _ -> current
  }
  set_counts(inventory, set_id, new_counts)
}

/// Преобразовать counts Dict в список пар для сериализации
pub fn counts_to_list(inventory: Inventory) -> List(#(String, OwnedCounts)) {
  dict.to_list(inventory.counts)
}

/// Создать инвентарь из списка counts
pub fn from_counts_list(
  count_entries: List(#(String, OwnedCounts)),
) -> Inventory {
  Inventory(counts: dict.from_list(count_entries))
}

/// Создать инвентарь из slots (миграция: slots -> counts с count=1)
pub fn from_slots_list(entries: List(#(String, OwnedSlots))) -> Inventory {
  let count_entries =
    list.map(entries, fn(entry) {
      let #(key, slots) = entry
      let counts =
        OwnedCounts(
          slot1: bool_to_int(slots.slot1),
          slot2: bool_to_int(slots.slot2),
          slot3: bool_to_int(slots.slot3),
          slot4: bool_to_int(slots.slot4),
        )
      #(key, counts)
    })
  Inventory(counts: dict.from_list(count_entries))
}

// Вспомогательные функции для конвертации

fn entity_type_to_str(et: EntityType) -> String {
  case et {
    RegularUnit -> "u"
    HeroEntity -> "h"
  }
}

fn str_to_entity_type(s: String) -> EntityType {
  case s {
    "h" -> HeroEntity
    _ -> RegularUnit
  }
}

fn color_to_str(color: ItemColor) -> String {
  case color {
    Blue -> "b"
    Green -> "g"
    Purple -> "p"
  }
}

fn str_to_color(s: String) -> ItemColor {
  case s {
    "g" -> Green
    "p" -> Purple
    _ -> Blue
  }
}

/// Получить список всех 288 счётчиков из инвентаря для указанной редкости
pub fn get_all_counts_list(inventory: Inventory, color: ItemColor) -> List(Int) {
  let all_names = sets_game_data.all_entity_names()

  list.flat_map(all_names, fn(name) {
    let entity_type = sets_game_data.detect_entity_type(name)
    // 2 сета × 4 слота = 8 счётчиков на сущность
    list.flat_map([1, 2], fn(set_num) {
      let set_id = SetId(name, entity_type, color, set_num)
      let counts = get_counts(inventory, set_id)
      [counts.slot1, counts.slot2, counts.slot3, counts.slot4]
    })
  })
}

/// Заполнить все слоты для списка сетов (устанавливает count=1 если было 0)
pub fn fill_all_slots(inv: Inventory, set_ids: List(SetId)) -> Inventory {
  list.fold(set_ids, inv, fn(acc, set_id) {
    let counts = get_counts(acc, set_id)
    let filled =
      OwnedCounts(
        slot1: int_max(1, counts.slot1),
        slot2: int_max(1, counts.slot2),
        slot3: int_max(1, counts.slot3),
        slot4: int_max(1, counts.slot4),
      )
    set_counts(acc, set_id, filled)
  })
}

/// Очистить все слоты для списка сетов
pub fn clear_all_slots(inv: Inventory, set_ids: List(SetId)) -> Inventory {
  list.fold(set_ids, inv, fn(acc, set_id) {
    set_counts(acc, set_id, empty_counts())
  })
}

/// Сбросить счётчики для списка сетов
pub fn reset_all_counts(inv: Inventory, set_ids: List(SetId)) -> Inventory {
  list.fold(set_ids, inv, fn(acc, set_id) {
    set_counts(acc, set_id, empty_counts())
  })
}

/// Подсчитать количество заполненных слотов из counts
pub fn count_owned_from_counts(counts: OwnedCounts) -> Int {
  let OwnedCounts(c1, c2, c3, c4) = counts
  bool_to_int(c1 >= 1)
  + bool_to_int(c2 >= 1)
  + bool_to_int(c3 >= 1)
  + bool_to_int(c4 >= 1)
}

/// Подсчитать общее количество вещей в инвентаре
pub fn count_total_items(inventory: Inventory) -> Int {
  dict.fold(inventory.counts, 0, fn(acc, _key, counts) {
    acc + count_owned_from_counts(counts)
  })
}

/// Статистика инвентаря
pub type InventoryStats {
  InventoryStats(
    total: Int,
    blue: Int,
    green: Int,
    purple: Int,
    light: Int,
    dark: Int,
  )
}

/// Подсчитать полную статистику инвентаря
pub fn get_stats(inventory: Inventory) -> InventoryStats {
  dict.fold(
    inventory.counts,
    InventoryStats(0, 0, 0, 0, 0, 0),
    fn(acc, key, counts) {
      let item_count = count_owned_from_counts(counts)
      case key_to_set_id(key) {
        Ok(set_id) -> {
          let SetId(name, _entity_type, color, _set_num) = set_id
          let is_light = sets_game_data.entity_belongs_to_faction(name, Light)
          InventoryStats(
            total: acc.total + item_count,
            blue: acc.blue
              + case color {
              Blue -> item_count
              _ -> 0
            },
            green: acc.green
              + case color {
              Green -> item_count
              _ -> 0
            },
            purple: acc.purple
              + case color {
              Purple -> item_count
              _ -> 0
            },
            light: acc.light
              + case is_light {
              True -> item_count
              False -> 0
            },
            dark: acc.dark
              + case is_light {
              True -> 0
              False -> item_count
            },
          )
        }
        Error(_) -> acc
      }
    },
  )
}
