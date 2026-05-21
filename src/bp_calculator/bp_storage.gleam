import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import plinth/javascript/storage as plinth_storage
import varasto

const storage_key = "wl_bp_calculator_settings"

/// Сохраняемые настройки BP калькулятора
pub type SavedSettings {
  SavedSettings(
    mode: String,
    current_level: Int,
    current_progress: Int,
    daily_points: Int,
    days_remaining: Int,
    weekly_rewards_remaining: Int,
    target_level: Int,
  )
}

/// Декодер для настроек
fn settings_decoder() -> decode.Decoder(SavedSettings) {
  use mode <- decode.field("mode", decode.string)
  use current_level <- decode.field("current_level", decode.int)
  use current_progress <- decode.field("current_progress", decode.int)
  use daily_points <- decode.field("daily_points", decode.int)
  use days_remaining <- decode.field("days_remaining", decode.int)
  use weekly_rewards <- decode.field("weekly_rewards", decode.int)
  use target_level <- decode.field("target_level", decode.int)
  decode.success(SavedSettings(
    mode,
    current_level,
    current_progress,
    daily_points,
    days_remaining,
    weekly_rewards,
    target_level,
  ))
}

/// Энкодер для настроек
fn settings_encoder(settings: SavedSettings) -> json.Json {
  json.object([
    #("mode", json.string(settings.mode)),
    #("current_level", json.int(settings.current_level)),
    #("current_progress", json.int(settings.current_progress)),
    #("daily_points", json.int(settings.daily_points)),
    #("days_remaining", json.int(settings.days_remaining)),
    #("weekly_rewards", json.int(settings.weekly_rewards_remaining)),
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
  mode: String,
  current_level: Int,
  current_progress: Int,
  daily_points: Int,
  days_remaining: Int,
  weekly_rewards_remaining: Int,
  target_level: Int,
) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, settings_decoder(), settings_encoder)
      let settings =
        SavedSettings(
          mode: mode,
          current_level: current_level,
          current_progress: current_progress,
          daily_points: daily_points,
          days_remaining: days_remaining,
          weekly_rewards_remaining: weekly_rewards_remaining,
          target_level: target_level,
        )
      let _ = varasto.set(storage, storage_key, settings)
      Nil
    }
  }
}
