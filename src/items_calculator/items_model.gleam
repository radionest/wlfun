import gleam/option.{type Option, None, Some}
import items_calculator/calculator_logic.{type CalculationResult}
import items_calculator/game_data.{
  type Faction, type ItemColor, type Unit, Green, Light,
}
import items_calculator/items_storage as storage

/// Модель состояния приложения
pub type Model {
  Model(
    selected_faction: Faction,
    selected_unit: Option(Unit),
    selected_color: ItemColor,
    current_level: Int,
    target_level: Int,
    result: Option(CalculationResult),
  )
}

/// Начальное состояние с загрузкой из localStorage
pub fn init() -> Model {
  case storage.load() {
    Some(saved) -> {
      let faction = game_data.string_to_faction(saved.faction)
      let color = game_data.string_to_color(saved.color)
      let unit = case saved.unit_name {
        Some(name) ->
          case game_data.find_unit(name) {
            Ok(u) -> Some(u)
            Error(_) -> None
          }
        None -> None
      }
      // Вычисляем результат если есть юнит
      let result = case unit {
        Some(u) if saved.target_level > saved.current_level ->
          Some(calculator_logic.calculate_range(
            u,
            color,
            saved.current_level,
            saved.target_level,
          ))
        _ -> None
      }
      Model(
        selected_faction: faction,
        selected_unit: unit,
        selected_color: color,
        current_level: saved.current_level,
        target_level: saved.target_level,
        result: result,
      )
    }
    None ->
      Model(
        selected_faction: Light,
        selected_unit: None,
        selected_color: Green,
        current_level: 1,
        target_level: 2,
        result: None,
      )
  }
}

/// Сообщения (события пользователя)
pub type Msg {
  UserSelectedFaction(String)
  UserSelectedUnit(String)
  UserSelectedColor(String)
  UserChangedCurrentLevel(String)
  UserChangedTargetLevel(String)
}
