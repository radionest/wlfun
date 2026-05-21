import gleam/list
import gleeunit/should
import items_calculator/calculator_logic.{
  type LevelCost, calculate_level_cost, calculate_range,
}
import items_calculator/game_data.{
  Blue, Dark, Green, LevelMultipliers, Light, Purple, Tier1, Tier2, Tier3, Tier4,
  Tier5, Unit, all_units, color_multiplier, find_unit, level_multipliers,
  string_to_color, string_to_faction, tier_base, units_by_faction,
}

// ============================================================================
// Тесты color_multiplier
// ============================================================================

pub fn color_multiplier_blue_test() {
  color_multiplier(Blue)
  |> should.equal(0.5)
}

pub fn color_multiplier_green_test() {
  color_multiplier(Green)
  |> should.equal(1.0)
}

pub fn color_multiplier_purple_test() {
  color_multiplier(Purple)
  |> should.equal(1.5)
}

// ============================================================================
// Тесты tier_base
// ============================================================================

pub fn tier_base_tier1_test() {
  tier_base(Tier1)
  |> should.equal(600)
}

pub fn tier_base_tier2_test() {
  tier_base(Tier2)
  |> should.equal(750)
}

pub fn tier_base_tier3_test() {
  tier_base(Tier3)
  |> should.equal(1500)
}

pub fn tier_base_tier4_test() {
  tier_base(Tier4)
  |> should.equal(3000)
}

pub fn tier_base_tier5_test() {
  tier_base(Tier5)
  |> should.equal(6000)
}

// ============================================================================
// Тесты level_multipliers
// ============================================================================

pub fn level_multipliers_level_2_test() {
  level_multipliers(2)
  |> should.equal(LevelMultipliers(1.0, 1.0))
}

pub fn level_multipliers_level_5_test() {
  level_multipliers(5)
  |> should.equal(LevelMultipliers(6.0, 9.6))
}

pub fn level_multipliers_level_10_test() {
  level_multipliers(10)
  |> should.equal(LevelMultipliers(375.0, 494.0))
}

pub fn level_multipliers_invalid_level_test() {
  level_multipliers(1)
  |> should.equal(LevelMultipliers(0.0, 0.0))
}

pub fn level_multipliers_level_11_invalid_test() {
  level_multipliers(11)
  |> should.equal(LevelMultipliers(0.0, 0.0))
}

// ============================================================================
// Тесты string_to_color
// ============================================================================

pub fn string_to_color_blue_test() {
  string_to_color("blue")
  |> should.equal(Blue)
}

pub fn string_to_color_purple_test() {
  string_to_color("purple")
  |> should.equal(Purple)
}

pub fn string_to_color_default_green_test() {
  string_to_color("unknown")
  |> should.equal(Green)
}

// ============================================================================
// Тесты string_to_faction
// ============================================================================

pub fn string_to_faction_dark_test() {
  string_to_faction("dark")
  |> should.equal(Dark)
}

pub fn string_to_faction_default_light_test() {
  string_to_faction("unknown")
  |> should.equal(Light)
}

// ============================================================================
// Тесты all_units
// ============================================================================

pub fn all_units_count_test() {
  all_units()
  |> list.length
  |> should.equal(30)
}

// ============================================================================
// Тесты units_by_faction
// ============================================================================

pub fn units_by_faction_light_count_test() {
  units_by_faction(Light)
  |> list.length
  |> should.equal(15)
}

pub fn units_by_faction_dark_count_test() {
  units_by_faction(Dark)
  |> list.length
  |> should.equal(15)
}

// ============================================================================
// Тесты find_unit
// ============================================================================

pub fn find_unit_exists_test() {
  find_unit("Мечник")
  |> should.be_ok
}

pub fn find_unit_not_exists_test() {
  find_unit("НесуществующийЮнит")
  |> should.be_error
}

pub fn find_unit_correct_data_test() {
  let assert Ok(unit) = find_unit("Мечник")
  unit.tier |> should.equal(Tier1)
  unit.faction |> should.equal(Light)
}

// ============================================================================
// Тесты calculate_level_cost
// ============================================================================

pub fn calculate_level_cost_tier1_blue_level2_test() {
  // base = 600, color = 0.5, gold_mult = 1.0, dust_mult = 1.0
  // gold = round(600 * 0.5 * 1.0) = 300
  // dust = round(600 / 19.6 * 0.5 * 1.0) = round(15.306) = 15
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_level_cost(unit, Blue, 2)
  result.level |> should.equal(2)
  result.gold |> should.equal(300)
  result.dust |> should.equal(15)
}

pub fn calculate_level_cost_tier3_green_level5_test() {
  // base = 1500, color = 1.0, gold_mult = 6.0, dust_mult = 9.6
  // gold = round(1500 * 1.0 * 6.0) = 9000
  // dust = round(1500 / 19.6 * 1.0 * 9.6) = round(734.69) = 735
  let unit = Unit("Test", Tier3, Light)
  let result = calculate_level_cost(unit, Green, 5)
  result.level |> should.equal(5)
  result.gold |> should.equal(9000)
  result.dust |> should.equal(735)
}

pub fn calculate_level_cost_tier5_purple_level10_test() {
  // base = 6000, color = 1.5, gold_mult = 375.0, dust_mult = 494.0
  // gold = round(6000 * 1.5 * 375.0) = 3375000
  // dust = round(6000 / 19.6 * 1.5 * 494.0) = round(226836.73) = 226837
  let unit = Unit("Test", Tier5, Light)
  let result = calculate_level_cost(unit, Purple, 10)
  result.level |> should.equal(10)
  result.gold |> should.equal(3_375_000)
  result.dust |> should.equal(226_837)
}

// ============================================================================
// Тесты calculate_range
// ============================================================================

pub fn calculate_range_single_level_test() {
  // От уровня 1 до 2 = только уровень 2
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_range(unit, Blue, 1, 2)
  result.levels |> list.length |> should.equal(1)
}

pub fn calculate_range_multiple_levels_test() {
  // От уровня 1 до 4 = уровни 2, 3, 4
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_range(unit, Blue, 1, 4)
  result.levels |> list.length |> should.equal(3)
}

pub fn calculate_range_totals_sum_test() {
  // Проверяем что суммы совпадают с суммой отдельных уровней
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_range(unit, Green, 1, 3)

  let manual_gold =
    list.fold(result.levels, 0, fn(acc, lc: LevelCost) { acc + lc.gold })
  let manual_dust =
    list.fold(result.levels, 0, fn(acc, lc: LevelCost) { acc + lc.dust })

  result.total_gold |> should.equal(manual_gold)
  result.total_dust |> should.equal(manual_dust)
}

pub fn calculate_range_specific_values_test() {
  // Tier1 Green от 1 до 3 (уровни 2 и 3)
  // Уровень 2: gold = 600*1.0*1.0 = 600, dust = round(600/19.6*1.0*1.0) = 31
  // Уровень 3: gold = 600*1.0*2.0 = 1200, dust = round(600/19.6*1.0*2.4) = 73
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_range(unit, Green, 1, 3)
  result.total_gold |> should.equal(600 + 1200)
  result.total_dust |> should.equal(31 + 73)
}
