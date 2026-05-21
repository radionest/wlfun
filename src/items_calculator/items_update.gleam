import gleam/int
import gleam/option.{None, Some}
import items_calculator/calculator_logic
import items_calculator/game_data
import items_calculator/items_model.{
  type Model, type Msg, Model, UserChangedCurrentLevel, UserChangedTargetLevel,
  UserSelectedColor, UserSelectedFaction, UserSelectedUnit,
}
import items_calculator/items_storage as storage

pub fn update(model: Model, msg: Msg) -> Model {
  let new_model = case msg {
    UserSelectedFaction(faction_str) -> {
      let faction = game_data.string_to_faction(faction_str)
      Model(..model, selected_faction: faction, selected_unit: None)
    }

    UserSelectedUnit(name) -> {
      let unit = game_data.find_unit(name)
      case unit {
        Ok(u) -> Model(..model, selected_unit: Some(u))
        Error(_) -> Model(..model, selected_unit: None)
      }
    }

    UserSelectedColor(color_str) -> {
      let color = game_data.string_to_color(color_str)
      Model(..model, selected_color: color)
    }

    UserChangedCurrentLevel(level_str) -> {
      case int.parse(level_str) {
        Ok(level) if level >= 1 && level <= 9 ->
          Model(..model, current_level: level)
        _ -> model
      }
    }

    UserChangedTargetLevel(level_str) -> {
      case int.parse(level_str) {
        Ok(level) if level >= 2 && level <= 10 ->
          Model(..model, target_level: level)
        _ -> model
      }
    }
  }

  // Автоматический пересчёт при валидных данных
  let final_model = recalculate(new_model)

  // Сохраняем в localStorage
  let unit_name = case final_model.selected_unit {
    Some(u) -> Some(u.name)
    None -> None
  }
  storage.save(
    final_model.selected_faction,
    unit_name,
    final_model.selected_color,
    final_model.current_level,
    final_model.target_level,
  )

  final_model
}

fn recalculate(model: Model) -> Model {
  case model.selected_unit {
    Some(unit) if model.target_level > model.current_level -> {
      let result =
        calculator_logic.calculate_range(
          unit,
          model.selected_color,
          model.current_level,
          model.target_level,
        )
      Model(..model, result: Some(result))
    }
    _ -> Model(..model, result: None)
  }
}
