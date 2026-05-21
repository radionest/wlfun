import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import items_calculator/game_data.{
  type Faction, type ItemColor, Blue, Dark, Green, Light, Purple,
}
import plinth/javascript/storage as plinth_storage
import varasto

const storage_key = "wl_calculator_settings"

/// Сохраняемые настройки
pub type SavedSettings {
  SavedSettings(
    faction: String,
    unit_name: Option(String),
    color: String,
    current_level: Int,
    target_level: Int,
  )
}

/// Декодер для настроек
fn settings_decoder() -> decode.Decoder(SavedSettings) {
  use faction <- decode.field("faction", decode.string)
  use unit_name <- decode.field("unit_name", decode.optional(decode.string))
  use color <- decode.field("color", decode.string)
  use current_level <- decode.field("current_level", decode.int)
  use target_level <- decode.field("target_level", decode.int)
  decode.success(SavedSettings(
    faction,
    unit_name,
    color,
    current_level,
    target_level,
  ))
}

/// Энкодер для настроек
fn settings_encoder(settings: SavedSettings) -> json.Json {
  let unit_json = case settings.unit_name {
    Some(name) -> json.string(name)
    None -> json.null()
  }

  json.object([
    #("faction", json.string(settings.faction)),
    #("unit_name", unit_json),
    #("color", json.string(settings.color)),
    #("current_level", json.int(settings.current_level)),
    #("target_level", json.int(settings.target_level)),
  ])
}

/// Загрузить настройки из localStorage
pub fn load() -> Option(SavedSettings) {
  case plinth_storage.local() {
    Error(_) -> None
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, settings_decoder(), settings_encoder)
      case varasto.get(storage, storage_key) {
        Ok(settings) -> Some(settings)
        Error(_) -> None
      }
    }
  }
}

/// Сохранить настройки в localStorage
pub fn save(
  faction: Faction,
  unit_name: Option(String),
  color: ItemColor,
  current_level: Int,
  target_level: Int,
) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, settings_decoder(), settings_encoder)
      let settings =
        SavedSettings(
          faction: faction_to_string(faction),
          unit_name: unit_name,
          color: color_to_string(color),
          current_level: current_level,
          target_level: target_level,
        )
      let _ = varasto.set(storage, storage_key, settings)
      Nil
    }
  }
}

fn faction_to_string(faction: Faction) -> String {
  case faction {
    Light -> "light"
    Dark -> "dark"
  }
}

fn color_to_string(color: ItemColor) -> String {
  case color {
    Blue -> "blue"
    Green -> "green"
    Purple -> "purple"
  }
}
