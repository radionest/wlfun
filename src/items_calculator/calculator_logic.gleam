import gleam/float
import gleam/int
import gleam/list
import items_calculator/game_data.{type ItemColor, type Unit, LevelMultipliers}

/// Результат расчёта для одного уровня
pub type LevelCost {
  LevelCost(level: Int, gold: Int, dust: Int)
}

/// Полный результат расчёта
pub type CalculationResult {
  CalculationResult(levels: List(LevelCost), total_gold: Int, total_dust: Int)
}

/// Расчёт стоимости для одного уровня
pub fn calculate_level_cost(
  unit: Unit,
  color: ItemColor,
  target_level: Int,
) -> LevelCost {
  let base = game_data.tier_base(unit.tier)
  let color_mult = game_data.color_multiplier(color)
  let LevelMultipliers(gold_mult, dust_mult) =
    game_data.level_multipliers(target_level)

  let gold = float.round(int.to_float(base) *. color_mult *. gold_mult)
  let dust =
    float.round(int.to_float(base) /. 19.6 *. color_mult *. dust_mult)

  LevelCost(level: target_level, gold: gold, dust: dust)
}

/// Расчёт общей стоимости для диапазона уровней
pub fn calculate_range(
  unit: Unit,
  color: ItemColor,
  from_level: Int,
  to_level: Int,
) -> CalculationResult {
  // Генерируем список уровней от (from_level + 1) до to_level включительно
  let levels =
    list.range(from_level + 1, to_level)
    |> list.map(fn(lvl) { calculate_level_cost(unit, color, lvl) })

  let total_gold = list.fold(levels, 0, fn(acc, lc) { acc + lc.gold })
  let total_dust = list.fold(levels, 0, fn(acc, lc) { acc + lc.dust })

  CalculationResult(levels: levels, total_gold: total_gold, total_dust: total_dust)
}
