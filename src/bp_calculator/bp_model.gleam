import bp_calculator/battle_pass
import bp_calculator/bp_storage as storage
import gleam/int
import gleam/option.{None, Some}

/// Режим калькулятора
pub type Mode {
  /// По дневным очкам → достижимый уровень
  CalculateLevel
  /// По целевому уровню → необходимые дневные очки
  CalculateDailyPoints
}

/// Состояние приложения
pub type Model {
  Model(
    mode: Mode,
    current_level: Int,
    current_progress: Int,
    daily_points: Int,
    days_remaining: Int,
    weekly_rewards_remaining: Int,
    target_level: Int,
    // Строковые значения для input полей
    current_level_str: String,
    current_progress_str: String,
    daily_points_str: String,
    days_remaining_str: String,
    weekly_rewards_str: String,
    target_level_str: String,
  )
}

/// Сообщения для обновления состояния
pub type Msg {
  SetMode(Mode)
  SetCurrentLevel(String)
  SetCurrentProgress(String)
  SetDailyPoints(String)
  SetDaysRemaining(String)
  SetWeeklyRewards(String)
  SetTargetLevel(String)
}

/// Начальное состояние с загрузкой из localStorage
pub fn init() -> Model {
  case storage.load() {
    Some(saved) -> {
      let mode = case saved.mode {
        "daily" -> CalculateDailyPoints
        _ -> CalculateLevel
      }
      Model(
        mode: mode,
        current_level: saved.current_level,
        current_progress: saved.current_progress,
        daily_points: saved.daily_points,
        days_remaining: saved.days_remaining,
        weekly_rewards_remaining: saved.weekly_rewards_remaining,
        target_level: saved.target_level,
        current_level_str: int.to_string(saved.current_level),
        current_progress_str: int.to_string(saved.current_progress),
        daily_points_str: int.to_string(saved.daily_points),
        days_remaining_str: int.to_string(saved.days_remaining),
        weekly_rewards_str: int.to_string(saved.weekly_rewards_remaining),
        target_level_str: int.to_string(saved.target_level),
      )
    }
    None -> default_model()
  }
}

fn default_model() -> Model {
  Model(
    mode: CalculateLevel,
    current_level: 1,
    current_progress: 0,
    daily_points: 100,
    days_remaining: 30,
    weekly_rewards_remaining: 4,
    target_level: battle_pass.max_level,
    current_level_str: "1",
    current_progress_str: "0",
    daily_points_str: "100",
    days_remaining_str: "30",
    weekly_rewards_str: "4",
    target_level_str: "60",
  )
}
