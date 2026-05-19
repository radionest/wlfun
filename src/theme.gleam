import gleam/dynamic/decode
import gleam/json
import plinth/javascript/storage as plinth_storage
import varasto

/// Тема приложения
pub type Theme {
  Light
  Dark
}

const storage_key = "wl_calculators_theme"

/// Тема в строку
pub fn theme_to_string(theme: Theme) -> String {
  case theme {
    Light -> "light"
    Dark -> "dark"
  }
}

/// Строка в тему
pub fn string_to_theme(s: String) -> Theme {
  case s {
    "dark" -> Dark
    _ -> Light
  }
}

/// CSS класс темы
pub fn theme_class(theme: Theme) -> String {
  case theme {
    Light -> "theme-light"
    Dark -> "theme-dark"
  }
}

/// Декодер для темы
fn theme_decoder() -> decode.Decoder(String) {
  decode.string
}

/// Энкодер для темы
fn theme_encoder(theme: String) -> json.Json {
  json.string(theme)
}

/// Загрузить тему из localStorage
pub fn load() -> Theme {
  case plinth_storage.local() {
    Error(_) -> Light
    Ok(raw_storage) -> {
      let storage = varasto.new(raw_storage, theme_decoder(), theme_encoder)
      case varasto.get(storage, storage_key) {
        Ok(theme_str) -> string_to_theme(theme_str)
        Error(_) -> Light
      }
    }
  }
}

/// Сохранить тему в localStorage
pub fn save(theme: Theme) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let storage = varasto.new(raw_storage, theme_decoder(), theme_encoder)
      let _ = varasto.set(storage, storage_key, theme_to_string(theme))
      Nil
    }
  }
}
