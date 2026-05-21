import bp_calculator/battle_pass
import bp_calculator/bp_model.{
  type Model, type Msg, CalculateDailyPoints, CalculateLevel, Model,
}
import bp_calculator/bp_storage as storage
import gleam/int

pub fn update(model: Model, msg: Msg) -> Model {
  let new_model = case msg {
    bp_model.SetMode(mode) -> Model(..model, mode: mode)

    bp_model.SetCurrentLevel(str) -> {
      let level =
        parse_int_or(str, model.current_level, 1, battle_pass.max_level)
      let max_progress = battle_pass.get_level_cost(level)
      let progress = int.min(model.current_progress, max_progress)
      Model(
        ..model,
        current_level: level,
        current_level_str: str,
        current_progress: progress,
      )
    }

    bp_model.SetCurrentProgress(str) -> {
      let max_progress = battle_pass.get_level_cost(model.current_level)
      let progress = parse_int_or(str, model.current_progress, 0, max_progress)
      Model(..model, current_progress: progress, current_progress_str: str)
    }

    bp_model.SetDailyPoints(str) -> {
      let points = parse_int_or(str, model.daily_points, 0, 10_000)
      Model(..model, daily_points: points, daily_points_str: str)
    }

    bp_model.SetDaysRemaining(str) -> {
      let days = parse_int_or(str, model.days_remaining, 1, 365)
      Model(..model, days_remaining: days, days_remaining_str: str)
    }

    bp_model.SetWeeklyRewards(str) -> {
      let rewards = parse_int_or(str, model.weekly_rewards_remaining, 0, 52)
      Model(..model, weekly_rewards_remaining: rewards, weekly_rewards_str: str)
    }

    bp_model.SetTargetLevel(str) -> {
      let level =
        parse_int_or(
          str,
          model.target_level,
          model.current_level,
          battle_pass.max_level,
        )
      Model(..model, target_level: level, target_level_str: str)
    }
  }

  // Сохраняем в localStorage
  let mode_str = case new_model.mode {
    CalculateLevel -> "level"
    CalculateDailyPoints -> "daily"
  }
  storage.save(
    mode_str,
    new_model.current_level,
    new_model.current_progress,
    new_model.daily_points,
    new_model.days_remaining,
    new_model.weekly_rewards_remaining,
    new_model.target_level,
  )

  new_model
}

/// Парсинг строки в Int с ограничениями и значением по умолчанию
fn parse_int_or(str: String, default: Int, min: Int, max: Int) -> Int {
  case int.parse(str) {
    Ok(n) -> int.clamp(n, min, max)
    Error(_) -> default
  }
}
