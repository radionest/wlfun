import gleam/int
import gleam/list

/// Максимальный уровень Battle Pass
pub const max_level = 60

/// Награда за неделю (в очках)
pub const weekly_reward = 850

/// Стоимость перехода с уровня N на уровень N+1
/// Индекс 0 = стоимость перехода с уровня 1 на уровень 2
pub fn level_costs() -> List(Int) {
  [
    // Уровни 1-3: 100
    100, 100, 100,
    // Уровни 4-11: 125
    125, 125, 125, 125, 125, 125, 125, 125,
    // Уровни 12-17: 150
    150, 150, 150, 150, 150, 150,
    // Уровни 18-22: 200
    200, 200, 200, 200, 200,
    // Уровни 23-26: 300
    300, 300, 300, 300,
    // Уровни 27-31: 350
    350, 350, 350, 350, 350,
    // Уровни 32-36: 400
    400, 400, 400, 400, 400,
    // Уровни 37-39: 500
    500, 500, 500,
    // Уровни 40-42: 600
    600, 600, 600,
    // Уровни 43-44: 700
    700, 700,
    // Уровни 45-46: 800
    800, 800,
    // Уровни 47-48: 900
    900, 900,
    // Уровни 49-50: 1000
    1000, 1000,
    // Уровни 51-52: 1100
    1100, 1100,
    // Уровень 53: 1200
    1200,
    // Уровень 54: 1300
    1300,
    // Уровень 55: 1400
    1400,
    // Уровень 56: 1500
    1500,
    // Уровень 57: 1600
    1600,
    // Уровень 58: 1800
    1800,
    // Уровень 59: 2000
    2000,
  ]
}

/// Получить стоимость перехода на следующий уровень
pub fn get_level_cost(level: Int) -> Int {
  case level {
    l if l < 1 -> 0
    l if l >= max_level -> 0
    _ -> {
      level_costs()
      |> list.drop(level - 1)
      |> list.first
      |> fn(result) {
        case result {
          Ok(cost) -> cost
          Error(_) -> 0
        }
      }
    }
  }
}

/// Общее количество очков для достижения уровня target с уровня 1
pub fn total_points_to_level(target_level: Int) -> Int {
  case target_level {
    l if l <= 1 -> 0
    l if l > max_level -> total_points_to_level(max_level)
    _ -> {
      level_costs()
      |> list.take(target_level - 1)
      |> int.sum
    }
  }
}

/// Сколько очков нужно от текущего уровня/прогресса до целевого уровня
pub fn points_needed(
  current_level: Int,
  current_progress: Int,
  target_level: Int,
) -> Int {
  let current_total = total_points_to_level(current_level) + current_progress
  let target_total = total_points_to_level(target_level)
  int.max(0, target_total - current_total)
}

/// Результат расчёта достижимого уровня
pub type LevelResult {
  LevelResult(level: Int, progress: Int, level_cost: Int)
}

/// Рассчитать какой уровень достигнет игрок с заданным количеством очков
pub fn calculate_reachable_level(
  current_level: Int,
  current_progress: Int,
  total_points: Int,
) -> LevelResult {
  calculate_level_recursive(current_level, current_progress + total_points)
}

fn calculate_level_recursive(level: Int, remaining_points: Int) -> LevelResult {
  case level >= max_level {
    True -> LevelResult(level: max_level, progress: remaining_points, level_cost: 0)
    False -> {
      let cost = get_level_cost(level)
      case remaining_points >= cost {
        True -> calculate_level_recursive(level + 1, remaining_points - cost)
        False -> LevelResult(level: level, progress: remaining_points, level_cost: cost)
      }
    }
  }
}

/// Рассчитать необходимые дневные очки для достижения целевого уровня
pub fn required_daily_points(
  current_level: Int,
  current_progress: Int,
  target_level: Int,
  days: Int,
  weekly_rewards: Int,
) -> Result(Int, String) {
  case days <= 0 {
    True -> Error("Количество дней должно быть больше 0")
    False -> {
      let needed = points_needed(current_level, current_progress, target_level)
      let weekly_bonus = weekly_rewards * weekly_reward
      let points_from_daily = needed - weekly_bonus

      case points_from_daily <= 0 {
        True -> Ok(0)
        False -> {
          // Округление вверх: (a + b - 1) / b
          let daily = { points_from_daily + days - 1 } / days
          Ok(daily)
        }
      }
    }
  }
}

/// Рассчитать общее количество доступных очков
pub fn calculate_total_available_points(
  daily_points: Int,
  days: Int,
  weekly_rewards: Int,
) -> Int {
  daily_points * days + weekly_rewards * weekly_reward
}
