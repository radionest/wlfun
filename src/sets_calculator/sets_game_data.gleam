import gleam/list
import gleam/option.{type Option, None, Some}
import items_calculator/game_data.{
  type Faction, type ItemColor, type Unit, Blue, Dark, Green, Light, Purple,
}

/// Тип сущности: обычный юнит или герой
pub type EntityType {
  RegularUnit
  HeroEntity
}

/// Герой с именем и фракцией
pub type Hero {
  Hero(name: String, faction: Faction)
}

/// Все герои игры
pub fn all_heroes() -> List(Hero) {
  [
    // Свет
    Hero("Палыч", Light),
    Hero("Берин", Light),
    Hero("Цесса", Light),
    // Тьма
    Hero("Грокк", Dark),
    Hero("Жаба", Dark),
    Hero("Жрун", Dark),
  ]
}

/// Герои по фракции
pub fn heroes_by_faction(faction: Faction) -> List(Hero) {
  list.filter(all_heroes(), fn(h: Hero) { h.faction == faction })
}

/// Найти героя по имени
pub fn find_hero(name: String) -> Result(Hero, Nil) {
  list.find(all_heroes(), fn(h: Hero) { h.name == name })
}

/// Идентификатор сета
pub type SetId {
  SetId(
    entity_name: String,
    entity_type: EntityType,
    color: ItemColor,
    set_number: Int,
  )
}

/// Количество юнитов в игре
pub fn units_count() -> Int {
  30
}

/// Количество героев в игре
pub fn heroes_count() -> Int {
  6
}

/// Количество сетов на одну редкость
pub fn sets_per_color() -> Int {
  // (30 юнитов + 6 героев) * 2 сета = 72 сета
  { units_count() + heroes_count() } * 2
}

/// Размер пула вещей одной редкости
pub fn pool_size() -> Int {
  // (30 юнитов + 6 героев) * 2 сета * 4 вещи = 288
  { units_count() + heroes_count() } * 2 * 4
}

/// Количество вещей в сете
pub fn items_per_set() -> Int {
  4
}

/// Сколько вещей нужно для сбора сета
pub fn items_needed(entity_type: EntityType) -> Int {
  case entity_type {
    RegularUnit -> 3
    HeroEntity -> 4
  }
}

/// Количество юнитов по фракции
pub fn units_count_by_faction(faction: Faction) -> Int {
  list.length(game_data.units_by_faction(faction))
}

/// Количество героев по фракции
pub fn heroes_count_by_faction(_faction: Faction) -> Int {
  3
}

/// Количество сущностей (юниты + герои) по фракции
pub fn entities_count_by_faction(faction: Faction) -> Int {
  units_count_by_faction(faction) + heroes_count_by_faction(faction)
}

/// Размер пула вещей по фракции (одной редкости)
pub fn pool_size_by_faction(faction: Faction) -> Int {
  entities_count_by_faction(faction) * 2 * 4
}

/// Преобразование типа сущности в строку
pub fn entity_type_to_string(et: EntityType) -> String {
  case et {
    RegularUnit -> "unit"
    HeroEntity -> "hero"
  }
}

/// Преобразование строки в тип сущности
pub fn string_to_entity_type(s: String) -> EntityType {
  case s {
    "hero" -> HeroEntity
    _ -> RegularUnit
  }
}

/// Проверить принадлежность сущности к фракции
pub fn entity_belongs_to_faction(name: String, faction: Faction) -> Bool {
  // Сначала проверяем среди юнитов
  case game_data.find_unit(name) {
    Ok(unit) -> unit.faction == faction
    Error(_) -> {
      // Проверяем среди героев
      case find_hero(name) {
        Ok(hero) -> hero.faction == faction
        Error(_) -> False
      }
    }
  }
}

/// Получить все имена сущностей (юниты + герои) по фракции
pub fn all_entity_names_by_faction(faction: Faction) -> List(String) {
  let units =
    game_data.units_by_faction(faction)
    |> list.map(fn(u) { u.name })
  let heroes =
    heroes_by_faction(faction)
    |> list.map(fn(h: Hero) { h.name })
  list.append(units, heroes)
}

/// Получить все имена сущностей (юниты + герои)
pub fn all_entity_names() -> List(String) {
  let units =
    game_data.all_units()
    |> list.map(fn(u) { u.name })
  let heroes =
    all_heroes()
    |> list.map(fn(h: Hero) { h.name })
  list.append(units, heroes)
}

/// Определить тип сущности по имени
pub fn detect_entity_type(name: String) -> EntityType {
  case find_hero(name) {
    Ok(_) -> HeroEntity
    Error(_) -> RegularUnit
  }
}

/// Получить SetId для обоих сетов сущности
pub fn set_ids_for_entity(
  entity_name: String,
  entity_type: EntityType,
  color: ItemColor,
) -> List(SetId) {
  [
    SetId(entity_name, entity_type, color, 1),
    SetId(entity_name, entity_type, color, 2),
  ]
}

/// Получить все SetId для фракции и редкости
pub fn set_ids_for_faction(faction: Faction, color: ItemColor) -> List(SetId) {
  all_entity_names_by_faction(faction)
  |> list.flat_map(fn(name) {
    let entity_type = detect_entity_type(name)
    [
      SetId(name, entity_type, color, 1),
      SetId(name, entity_type, color, 2),
    ]
  })
}

/// Получить все SetId для редкости
pub fn set_ids_for_color(color: ItemColor) -> List(SetId) {
  all_entity_names()
  |> list.flat_map(fn(name) {
    let entity_type = detect_entity_type(name)
    [
      SetId(name, entity_type, color, 1),
      SetId(name, entity_type, color, 2),
    ]
  })
}

/// Генерация всех SetId для всех сущностей, редкостей и сетов
pub fn generate_all_set_ids() -> List(SetId) {
  let colors = [Blue, Green, Purple]
  let set_numbers = [1, 2]

  // Все юниты
  let units = game_data.all_units()
  let unit_sets =
    list.flat_map(units, fn(unit: Unit) {
      list.flat_map(colors, fn(color) {
        list.map(set_numbers, fn(num) {
          SetId(unit.name, RegularUnit, color, num)
        })
      })
    })

  // Все герои
  let heroes = all_heroes()
  let hero_sets =
    list.flat_map(heroes, fn(hero: Hero) {
      list.flat_map(colors, fn(color) {
        list.map(set_numbers, fn(num) {
          SetId(hero.name, HeroEntity, color, num)
        })
      })
    })

  list.append(unit_sets, hero_sets)
}

/// Фильтрация списка SetId по фракции и редкости
pub fn filter_sets(
  sets: List(SetId),
  faction_filter: Option(Faction),
  color_filter: Option(ItemColor),
) -> List(SetId) {
  sets
  |> list.filter(fn(set_id) {
    let SetId(name, _, color, _) = set_id
    let faction_match = case faction_filter {
      None -> True
      Some(faction) -> entity_belongs_to_faction(name, faction)
    }
    let color_match = case color_filter {
      None -> True
      Some(c) -> color == c
    }
    faction_match && color_match
  })
}
