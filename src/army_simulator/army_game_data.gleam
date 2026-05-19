import gleam/list
import items_calculator/game_data.{type Faction, type Unit, Light, Dark}
import sets_calculator/sets_game_data

/// Константы
pub const pool_size_per_color: Int = 288

pub const items_per_set: Int = 4

pub const units_per_faction: Int = 15

pub const heroes_per_faction: Int = 3

pub const slots_per_unit: Int = 3

pub const slots_per_hero: Int = 4

/// Тип сущности в армии
pub type EntityType {
  UnitEntity
  HeroEntity
}

/// Сущность армии
pub type ArmyEntity {
  ArmyEntity(
    name: String,
    entity_type: EntityType,
    slots_needed: Int,
  )
}

/// Юниты фракции Свет
pub fn light_units() -> List(String) {
  game_data.units_by_faction(Light)
  |> list.map(fn(u: Unit) { u.name })
}

/// Юниты фракции Тьма
pub fn dark_units() -> List(String) {
  game_data.units_by_faction(Dark)
  |> list.map(fn(u: Unit) { u.name })
}

/// Герои фракции
pub fn heroes_by_faction(faction: Faction) -> List(String) {
  sets_game_data.heroes_by_faction(faction)
  |> list.map(fn(h: sets_game_data.Hero) { h.name })
}

/// Все сущности армии для фракции
pub fn army_entities(faction: Faction) -> List(ArmyEntity) {
  let units = case faction {
    Light -> light_units()
    Dark -> dark_units()
  }

  let heroes = heroes_by_faction(faction)

  let unit_entities =
    list.map(units, fn(name) {
      ArmyEntity(name: name, entity_type: UnitEntity, slots_needed: slots_per_unit)
    })

  let hero_entities =
    list.map(heroes, fn(name) {
      ArmyEntity(name: name, entity_type: HeroEntity, slots_needed: slots_per_hero)
    })

  list.append(unit_entities, hero_entities)
}

/// Общее количество слотов в армии
pub fn total_army_slots() -> Int {
  units_per_faction * slots_per_unit + heroes_per_faction * slots_per_hero
}

/// Количество сущностей в армии
pub fn army_size() -> Int {
  units_per_faction + heroes_per_faction
}

/// Индекс сущности в пуле (для расчёта позиции предметов)
pub fn entity_pool_index(entity_name: String, faction: Faction) -> Int {
  let entities = army_entities(faction)
  case list.index_map(entities, fn(e, i) { #(e.name, i) })
       |> list.find(fn(pair) { pair.0 == entity_name }) {
    Ok(#(_, idx)) -> idx
    Error(_) -> 0
  }
}

/// Получить имена всех сущностей для JS (для worker)
pub fn entity_names_for_faction(faction: Faction) -> List(String) {
  army_entities(faction)
  |> list.map(fn(e) { e.name })
}

/// Получить типы сущностей для JS (unit/hero)
pub fn entity_types_for_faction(faction: Faction) -> List(String) {
  army_entities(faction)
  |> list.map(fn(e) {
    case e.entity_type {
      UnitEntity -> "unit"
      HeroEntity -> "hero"
    }
  })
}
