import bp_calculator/battle_pass.{
  calculate_reachable_level, calculate_total_available_points, get_level_cost,
  level_costs, max_level, points_needed, required_daily_points,
  total_points_to_level, weekly_reward,
}
import gleam/list
import gleeunit/should

// ============================================================================
// Тесты level_costs
// ============================================================================

pub fn level_costs_length_test() {
  level_costs()
  |> list.length
  |> should.equal(59)
}

pub fn level_costs_first_three_test() {
  level_costs()
  |> list.take(3)
  |> should.equal([100, 100, 100])
}

pub fn level_costs_last_test() {
  level_costs()
  |> list.last
  |> should.equal(Ok(2000))
}

// ============================================================================
// Тесты get_level_cost
// ============================================================================

pub fn get_level_cost_level_1_test() {
  get_level_cost(1)
  |> should.equal(100)
}

pub fn get_level_cost_level_59_test() {
  get_level_cost(59)
  |> should.equal(2000)
}

pub fn get_level_cost_level_60_returns_0_test() {
  get_level_cost(60)
  |> should.equal(0)
}

pub fn get_level_cost_level_0_returns_0_test() {
  get_level_cost(0)
  |> should.equal(0)
}

pub fn get_level_cost_negative_returns_0_test() {
  get_level_cost(-5)
  |> should.equal(0)
}

// ============================================================================
// Тесты total_points_to_level
// ============================================================================

pub fn total_points_to_level_1_test() {
  total_points_to_level(1)
  |> should.equal(0)
}

pub fn total_points_to_level_2_test() {
  total_points_to_level(2)
  |> should.equal(100)
}

pub fn total_points_to_level_4_test() {
  // Уровни 1-3: 100 * 3 = 300
  total_points_to_level(4)
  |> should.equal(300)
}

pub fn total_points_to_level_exceeds_max_test() {
  // Уровень 100 должен вернуть то же что и max_level
  total_points_to_level(100)
  |> should.equal(total_points_to_level(max_level))
}

// ============================================================================
// Тесты points_needed
// ============================================================================

pub fn points_needed_same_level_test() {
  points_needed(5, 0, 5)
  |> should.equal(0)
}

pub fn points_needed_next_level_test() {
  // От уровня 1 до уровня 2 нужно 100 очков
  points_needed(1, 0, 2)
  |> should.equal(100)
}

pub fn points_needed_with_progress_test() {
  // От уровня 1 с прогрессом 50 до уровня 2 нужно 50 очков
  points_needed(1, 50, 2)
  |> should.equal(50)
}

pub fn points_needed_lower_target_returns_0_test() {
  // Если цель ниже текущего уровня, нужно 0 очков
  points_needed(10, 0, 5)
  |> should.equal(0)
}

// ============================================================================
// Тесты calculate_reachable_level
// ============================================================================

pub fn calculate_reachable_level_no_points_test() {
  let result = calculate_reachable_level(1, 0, 0)
  result.level |> should.equal(1)
  result.progress |> should.equal(0)
}

pub fn calculate_reachable_level_exact_levelup_test() {
  // 100 очков = ровно переход с 1 на 2
  let result = calculate_reachable_level(1, 0, 100)
  result.level |> should.equal(2)
  result.progress |> should.equal(0)
}

pub fn calculate_reachable_level_partial_progress_test() {
  // 150 очков = переход на 2 + 50 прогресса
  let result = calculate_reachable_level(1, 0, 150)
  result.level |> should.equal(2)
  result.progress |> should.equal(50)
}

pub fn calculate_reachable_level_with_initial_progress_test() {
  // Уровень 1 с 50 прогресса + 100 очков = уровень 2 с 50 прогресса
  let result = calculate_reachable_level(1, 50, 100)
  result.level |> should.equal(2)
  result.progress |> should.equal(50)
}

pub fn calculate_reachable_level_multiple_levels_test() {
  // 300 очков с уровня 1 = уровень 4 (100+100+100)
  let result = calculate_reachable_level(1, 0, 300)
  result.level |> should.equal(4)
  result.progress |> should.equal(0)
}

pub fn calculate_reachable_level_max_level_cap_test() {
  // Огромное количество очков не должно превышать max_level
  let result = calculate_reachable_level(1, 0, 1_000_000)
  result.level |> should.equal(max_level)
}

pub fn calculate_reachable_level_returns_level_cost_test() {
  let result = calculate_reachable_level(1, 0, 50)
  result.level |> should.equal(1)
  result.level_cost |> should.equal(100)
}

// ============================================================================
// Тесты required_daily_points
// ============================================================================

pub fn required_daily_points_zero_days_error_test() {
  required_daily_points(1, 0, 10, 0, 0)
  |> should.be_error
}

pub fn required_daily_points_negative_days_error_test() {
  required_daily_points(1, 0, 10, -5, 0)
  |> should.be_error
}

pub fn required_daily_points_already_at_target_test() {
  // Уже на цели = 0 очков нужно
  required_daily_points(10, 0, 10, 30, 0)
  |> should.equal(Ok(0))
}

pub fn required_daily_points_above_target_test() {
  // Выше цели = 0 очков нужно
  required_daily_points(15, 0, 10, 30, 0)
  |> should.equal(Ok(0))
}

pub fn required_daily_points_weekly_covers_all_test() {
  // Недельные награды покрывают всё
  // От уровня 1 до 2 нужно 100 очков
  // 1 неделя = 850 очков, которые покрывают нужные 100
  required_daily_points(1, 0, 2, 30, 1)
  |> should.equal(Ok(0))
}

pub fn required_daily_points_normal_calculation_test() {
  // От уровня 1 до 2 нужно 100 очков
  // 10 дней, 0 недельных = 10 очков в день
  let result = required_daily_points(1, 0, 2, 10, 0)
  result |> should.be_ok
  let assert Ok(daily) = result
  daily |> should.equal(10)
}

pub fn required_daily_points_rounds_up_test() {
  // От уровня 1 до 2 нужно 100 очков
  // 3 дня, 0 недельных = ceil(100/3) = 34 очка в день
  let result = required_daily_points(1, 0, 2, 3, 0)
  result |> should.be_ok
  let assert Ok(daily) = result
  daily |> should.equal(34)
}

// ============================================================================
// Тесты calculate_total_available_points
// ============================================================================

pub fn calculate_total_available_points_basic_test() {
  // 100 очков в день * 10 дней = 1000
  calculate_total_available_points(100, 10, 0)
  |> should.equal(1000)
}

pub fn calculate_total_available_points_with_weekly_test() {
  // 100 * 10 + 2 * 850 = 1000 + 1700 = 2700
  calculate_total_available_points(100, 10, 2)
  |> should.equal(2700)
}

pub fn calculate_total_available_points_no_daily_test() {
  // 0 * 30 + 4 * 850 = 3400
  calculate_total_available_points(0, 30, 4)
  |> should.equal(3400)
}

pub fn calculate_total_available_points_zero_all_test() {
  calculate_total_available_points(0, 0, 0)
  |> should.equal(0)
}

// ============================================================================
// Тесты констант
// ============================================================================

pub fn max_level_is_60_test() {
  max_level |> should.equal(60)
}

pub fn weekly_reward_is_850_test() {
  weekly_reward |> should.equal(850)
}
