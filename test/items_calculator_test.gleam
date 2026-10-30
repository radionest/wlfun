import gleam/list
import gleeunit/should
import items_calculator/calculator_logic.{
  type LevelCost, apply_talent_discount, calculate_level_cost, calculate_range,
}
import items_calculator/game_data.{
  Blue, Dark, Green, LevelMultipliers, Light, Purple, Tier1, Tier2, Tier3, Tier4,
  Tier5, Unit, all_units, color_multiplier, find_unit, level_multipliers,
  string_to_color, string_to_faction, talent_discount, talent_discount_percent,
  tier_base, units_by_faction,
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

pub fn level_multipliers_level_6_test() {
  level_multipliers(6)
  |> should.equal(LevelMultipliers(10.0, 18.0))
}

pub fn level_multipliers_level_7_test() {
  level_multipliers(7)
  |> should.equal(LevelMultipliers(20.0, 40.0))
}

pub fn level_multipliers_level_9_test() {
  level_multipliers(9)
  |> should.equal(LevelMultipliers(140.0, 280.0))
}

pub fn level_multipliers_level_10_test() {
  level_multipliers(10)
  |> should.equal(LevelMultipliers(375.0, 750.0))
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
// Тесты talent_discount
// ============================================================================

pub fn talent_discount_level_0_test() {
  talent_discount(0)
  |> should.equal(0.0)
}

pub fn talent_discount_level_1_test() {
  talent_discount(1)
  |> should.equal(0.02)
}

pub fn talent_discount_level_2_test() {
  talent_discount(2)
  |> should.equal(0.04)
}

pub fn talent_discount_level_3_test() {
  talent_discount(3)
  |> should.equal(0.06)
}

pub fn talent_discount_out_of_range_test() {
  talent_discount(4)
  |> should.equal(0.0)
  talent_discount(-1)
  |> should.equal(0.0)
}

pub fn talent_discount_percent_levels_test() {
  talent_discount_percent(0)
  |> should.equal(0)
  talent_discount_percent(1)
  |> should.equal(2)
  talent_discount_percent(2)
  |> should.equal(4)
  talent_discount_percent(3)
  |> should.equal(6)
  talent_discount_percent(4)
  |> should.equal(0)
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
  // dust = round(600 / 20 * 0.5 * 1.0) = 15
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_level_cost(unit, Blue, 2)
  result.level |> should.equal(2)
  result.gold |> should.equal(300)
  result.dust |> should.equal(15)
}

pub fn calculate_level_cost_tier3_green_level5_test() {
  // base = 1500, color = 1.0, gold_mult = 6.0, dust_mult = 9.6
  // gold = round(1500 * 1.0 * 6.0) = 9000
  // dust = round(1500 / 20 * 1.0 * 9.6) = 720
  let unit = Unit("Test", Tier3, Light)
  let result = calculate_level_cost(unit, Green, 5)
  result.level |> should.equal(5)
  result.gold |> should.equal(9000)
  result.dust |> should.equal(720)
}

pub fn calculate_level_cost_tier2_purple_level9_test() {
  // Measured in game: 154350 gold / 15750 dust for a T2 epic item.
  // The player talent discounts gold only: 157500 * 0.98 = 154350.
  // Dust is undiscounted: base / 20 * color * dust_mult.
  // base = 750, color = 1.5, gold_mult = 140.0, dust_mult = 280.0
  // gold = round(750 * 1.5 * 140.0) = 157500
  // dust = round(750 / 20 * 1.5 * 280.0) = 15750
  let unit = Unit("Test", Tier2, Light)
  let result = calculate_level_cost(unit, Purple, 9)
  result.level |> should.equal(9)
  result.gold |> should.equal(157_500)
  result.dust |> should.equal(15_750)
}

pub fn calculate_level_cost_tier5_purple_level10_test() {
  // base = 6000, color = 1.5, gold_mult = 375.0, dust_mult = 750.0
  // gold = round(6000 * 1.5 * 375.0) = 3375000
  // dust = round(6000 / 20 * 1.5 * 750.0) = 337500
  let unit = Unit("Test", Tier5, Light)
  let result = calculate_level_cost(unit, Purple, 10)
  result.level |> should.equal(10)
  result.gold |> should.equal(3_375_000)
  result.dust |> should.equal(337_500)
}

pub fn calculate_level_cost_tier1_green_level7_test() {
  // Measured in game: 11520 gold / 1200 dust for a T1 rare item
  // (Рабочий/Громила screenshots). Player talent is 4%: gold shows
  // 12000 * 0.96 = 11520; dust has no talent discount.
  // base = 600, color = 1.0, gold_mult = 20.0, dust_mult = 40.0
  // gold = 600 * 1.0 * 20.0 = 12000
  // dust = round(600 / 20 * 1.0 * 40.0) = 1200
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_level_cost(unit, Green, 7)
  result.level |> should.equal(7)
  result.gold |> should.equal(12_000)
  result.dust |> should.equal(1200)
}

pub fn calculate_level_cost_tier4_purple_level6_test() {
  // Measured in game: 43200 gold / 4050 dust for a T4 epic item
  // (Каравелла hull screenshot). 4% talent on gold only.
  // base = 3000, color = 1.5, gold_mult = 10.0, dust_mult = 18.0
  // gold = 3000 * 1.5 * 10.0 = 45000
  // dust = round(3000 / 20 * 1.5 * 18.0) = 4050
  let unit = Unit("Test", Tier4, Light)
  let result = calculate_level_cost(unit, Purple, 6)
  result.level |> should.equal(6)
  result.gold |> should.equal(45_000)
  result.dust |> should.equal(4050)
}

pub fn calculate_level_cost_fractional_dust_rounds_test() {
  // Делитель 20 всё же даёт дробную пыль: результат проходит через
  // float.round (половины — от нуля).
  // base = 750, color = 0.5, gold_mult = 10.0, dust_mult = 18.0
  // gold = round(750 * 0.5 * 10.0) = 3750
  // dust = round(750 / 20 * 0.5 * 18.0) = round(337.5) = 338
  let unit = Unit("Test", Tier2, Light)
  let result = calculate_level_cost(unit, Blue, 6)
  result.level |> should.equal(6)
  result.gold |> should.equal(3750)
  result.dust |> should.equal(338)
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
  // Уровень 2: gold = 600*1.0*1.0 = 600, dust = round(600/20*1.0*1.0) = 30
  // Уровень 3: gold = 600*1.0*2.0 = 1200, dust = round(600/20*1.0*2.4) = 72
  let unit = Unit("Test", Tier1, Light)
  let result = calculate_range(unit, Green, 1, 3)
  result.total_gold |> should.equal(600 + 1200)
  result.total_dust |> should.equal(30 + 72)
}

// ============================================================================
// Тесты apply_talent_discount
// ============================================================================

pub fn apply_talent_discount_gold_only_test() {
  // T1 green 1->3: базовые шаги к2 = 600g/30d, к3 = 1200g/72d.
  // Уровень таланта 2 (4%): золото ×0.96 -> 576/1152, пыль без изменений.
  let unit = Unit("Test", Tier1, Light)
  let base = calculate_range(unit, Green, 1, 3)
  let result = apply_talent_discount(base, 2)

  result.levels
  |> list.map(fn(lc: LevelCost) { lc.gold })
  |> should.equal([576, 1152])
  result.levels
  |> list.map(fn(lc: LevelCost) { lc.dust })
  |> should.equal([30, 72])
  result.total_gold |> should.equal(576 + 1152)
  result.total_dust |> should.equal(30 + 72)
}

pub fn apply_talent_discount_level_0_identity_test() {
  let unit = Unit("Test", Tier1, Light)
  let base = calculate_range(unit, Green, 1, 3)
  apply_talent_discount(base, 0)
  |> should.equal(base)
}
