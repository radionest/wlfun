import gleam/list

/// Цвета/редкости предметов
pub type ItemColor {
  Blue
  Green
  Purple
}

pub fn color_to_string(color: ItemColor) -> String {
  case color {
    Blue -> "Синий"
    Green -> "Зелёный"
    Purple -> "Фиолетовый"
  }
}

pub fn color_multiplier(color: ItemColor) -> Float {
  case color {
    Blue -> 0.5
    Green -> 1.0
    Purple -> 1.5
  }
}

pub fn string_to_color(s: String) -> ItemColor {
  case s {
    "blue" -> Blue
    "purple" -> Purple
    _ -> Green
  }
}

/// Фракции юнитов
pub type Faction {
  Light
  Dark
}

pub fn faction_to_string(faction: Faction) -> String {
  case faction {
    Light -> "Свет"
    Dark -> "Тьма"
  }
}

pub fn string_to_faction(s: String) -> Faction {
  case s {
    "dark" -> Dark
    _ -> Light
  }
}

/// Тиры юнитов с базовой стоимостью
pub type UnitTier {
  Tier1
  Tier2
  Tier3
  Tier4
  Tier5
}

pub fn tier_base(tier: UnitTier) -> Int {
  case tier {
    Tier1 -> 600
    Tier2 -> 750
    Tier3 -> 1500
    Tier4 -> 3000
    Tier5 -> 6000
  }
}

pub fn tier_to_string(tier: UnitTier) -> String {
  case tier {
    Tier1 -> "Tier 1 (600)"
    Tier2 -> "Tier 2 (750)"
    Tier3 -> "Tier 3 (1500)"
    Tier4 -> "Tier 4 (3000)"
    Tier5 -> "Tier 5 (6000)"
  }
}

/// Юнит с именем, тиром и фракцией
pub type Unit {
  Unit(name: String, tier: UnitTier, faction: Faction)
}

/// Все юниты игры
pub fn all_units() -> List(Unit) {
  [
    // Tier 1 - Свет
    Unit("Рабочий", Tier1, Light),
    Unit("Гном", Tier1, Light),
    Unit("Мечник", Tier1, Light),
    // Tier 1 - Тьма
    Unit("Раб", Tier1, Dark),
    Unit("Скелук", Tier1, Dark),
    Unit("Громила", Tier1, Dark),
    // Tier 2 - Свет
    Unit("Шлюп", Tier2, Light),
    Unit("Вертолет", Tier2, Light),
    Unit("Арча", Tier2, Light),
    // Tier 2 - Тьма
    Unit("Шхуна", Tier2, Dark),
    Unit("Нафт", Tier2, Dark),
    Unit("Камик", Tier2, Dark),
    // Tier 3 - Свет
    Unit("Гвард", Tier3, Light),
    Unit("Конь", Tier3, Light),
    Unit("Лиса", Tier3, Light),
    // Tier 3 - Тьма
    Unit("Топор", Tier3, Dark),
    Unit("Варг", Tier3, Dark),
    Unit("Бур", Tier3, Dark),
    // Tier 4 - Свет
    Unit("Байк", Tier4, Light),
    Unit("Маг", Tier4, Light),
    Unit("Каравелла", Tier4, Light),
    Unit("Стреломет", Tier4, Light),
    Unit("Хилка", Tier4, Light),
    // Tier 4 - Тьма
    Unit("Яд", Tier4, Dark),
    Unit("Зомби", Tier4, Dark),
    Unit("Галеон", Tier4, Dark),
    Unit("Катапа", Tier4, Dark),
    Unit("Некр", Tier4, Dark),
    // Tier 5 - Свет
    Unit("Снайп", Tier5, Light),
    // Tier 5 - Тьма
    Unit("Ракетчик", Tier5, Dark),
  ]
}

/// Фильтрация юнитов по фракции
pub fn units_by_faction(faction: Faction) -> List(Unit) {
  list.filter(all_units(), fn(u) { u.faction == faction })
}

/// Группировка юнитов по тирам для UI
pub fn units_by_tier() -> List(#(UnitTier, List(Unit))) {
  let units = all_units()
  [
    #(Tier1, list.filter(units, fn(u) { u.tier == Tier1 })),
    #(Tier2, list.filter(units, fn(u) { u.tier == Tier2 })),
    #(Tier3, list.filter(units, fn(u) { u.tier == Tier3 })),
    #(Tier4, list.filter(units, fn(u) { u.tier == Tier4 })),
    #(Tier5, list.filter(units, fn(u) { u.tier == Tier5 })),
  ]
}

/// Найти юнита по имени
pub fn find_unit(name: String) -> Result(Unit, Nil) {
  list.find(all_units(), fn(u) { u.name == name })
}

/// Множители уровней
pub type LevelMultipliers {
  LevelMultipliers(gold: Float, dust: Float)
}

pub fn level_multipliers(level: Int) -> LevelMultipliers {
  case level {
    2 -> LevelMultipliers(1.0, 1.0)
    3 -> LevelMultipliers(2.0, 2.4)
    4 -> LevelMultipliers(4.0, 5.6)
    5 -> LevelMultipliers(6.0, 9.6)
    6 -> LevelMultipliers(10.0, 18.0)
    7 -> LevelMultipliers(20.0, 40.0)
    8 -> LevelMultipliers(50.0, 100.0)
    9 -> LevelMultipliers(140.0, 220.0)
    10 -> LevelMultipliers(375.0, 494.0)
    _ -> LevelMultipliers(0.0, 0.0)
  }
}
