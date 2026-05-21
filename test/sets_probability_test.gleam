import gleam/float
import gleam/list
import gleeunit/should
import sets_calculator/sets_probability.{
  calculate_duplicates_curve, calculate_duplicates_curve_with_inventory,
}

// ============================================================================
// Тесты calculate_duplicates_curve
// ============================================================================

pub fn calculate_duplicates_curve_length_test() {
  // Проверяем что возвращается правильное количество точек
  let curve = calculate_duplicates_curve(2, 1, 100)
  list.length(curve) |> should.equal(101)
}

pub fn calculate_duplicates_curve_starts_at_zero_test() {
  // При 0 попытках вероятность = 0 (если min_duplicates > 0)
  let curve = calculate_duplicates_curve(2, 1, 50)
  let assert Ok(first) = list.first(curve)
  first.0 |> should.equal(0)
  // Вероятность при 0 попытках должна быть 0
  { first.1 <=. 0.001 } |> should.be_true
}

pub fn calculate_duplicates_curve_monotonically_increasing_test() {
  // Вероятность должна монотонно возрастать
  let curve = calculate_duplicates_curve(2, 1, 100)
  let probs = list.map(curve, fn(point) { point.1 })
  is_monotonically_increasing(probs) |> should.be_true
}

pub fn calculate_duplicates_curve_approaches_one_test() {
  // При большом количестве попыток вероятность должна приближаться к 1
  let curve = calculate_duplicates_curve(2, 1, 1000)
  let assert Ok(last) = list.last(curve)
  // Должно быть близко к 1 (>0.9)
  { last.1 >. 0.9 } |> should.be_true
}

pub fn calculate_duplicates_curve_higher_k_slower_test() {
  // С большим min_duplicates вероятность растет медленнее
  let curve_k2 = calculate_duplicates_curve(2, 1, 500)
  let curve_k3 = calculate_duplicates_curve(3, 1, 500)

  let assert Ok(mid_k2) = list.drop(curve_k2, 250) |> list.first
  let assert Ok(mid_k3) = list.drop(curve_k3, 250) |> list.first

  // При одинаковом количестве попыток, k=2 должен иметь большую вероятность
  { mid_k2.1 >. mid_k3.1 } |> should.be_true
}

pub fn calculate_duplicates_curve_more_items_slower_test() {
  // С большим min_items вероятность растет медленнее
  let curve_n1 = calculate_duplicates_curve(2, 1, 500)
  let curve_n5 = calculate_duplicates_curve(2, 5, 500)

  // Используем точку 20, где кривые ещё не достигли насыщения
  // При 20 попытках: n=1 ≈ 0.45, n=5 ≈ 0.0004
  let assert Ok(point_n1) = list.drop(curve_n1, 20) |> list.first
  let assert Ok(point_n5) = list.drop(curve_n5, 20) |> list.first

  // При одинаковом количестве попыток, n=1 должен иметь большую вероятность
  { point_n1.1 >. point_n5.1 } |> should.be_true
}

// ============================================================================
// Тесты calculate_duplicates_curve_with_inventory
// ============================================================================

pub fn curve_with_inventory_empty_same_as_without_test() {
  // Пустой инвентарь должен давать тот же результат
  let pool_size = 288
  let empty_counts = list.repeat(0, pool_size)

  let curve_without = calculate_duplicates_curve(2, 1, 100)
  let curve_with =
    calculate_duplicates_curve_with_inventory(2, 1, 100, empty_counts)

  // Сравниваем первые несколько точек
  let assert Ok(p1_without) = list.drop(curve_without, 50) |> list.first
  let assert Ok(p1_with) = list.drop(curve_with, 50) |> list.first

  // Должны быть примерно равны (допуск на численные ошибки)
  let diff = float.absolute_value(p1_without.1 -. p1_with.1)
  { diff <. 0.01 } |> should.be_true
}

pub fn curve_with_inventory_faster_with_existing_test() {
  // С уже имеющимися вещами вероятность должна расти быстрее
  let pool_size = 288
  let empty_counts = list.repeat(0, pool_size)

  // Инвентарь где первая вещь уже выпала 1 раз
  let with_one =
    list.index_map(empty_counts, fn(_, i) {
      case i {
        0 -> 1
        _ -> 0
      }
    })

  let curve_empty =
    calculate_duplicates_curve_with_inventory(2, 1, 300, empty_counts)
  let curve_with_one =
    calculate_duplicates_curve_with_inventory(2, 1, 300, with_one)

  // С существующей вещью вероятность должна быть выше (или равна)
  let assert Ok(p_empty) = list.drop(curve_empty, 100) |> list.first
  let assert Ok(p_with) = list.drop(curve_with_one, 100) |> list.first

  { p_with.1 >=. p_empty.1 } |> should.be_true
}

pub fn curve_with_inventory_length_test() {
  let pool_size = 288
  let counts = list.repeat(0, pool_size)
  let curve = calculate_duplicates_curve_with_inventory(2, 1, 50, counts)
  list.length(curve) |> should.equal(51)
}

// ============================================================================
// Вспомогательные функции
// ============================================================================

fn is_monotonically_increasing(values: List(Float)) -> Bool {
  case values {
    [] -> True
    [_] -> True
    [a, b, ..rest] -> {
      case a <=. b {
        True -> is_monotonically_increasing([b, ..rest])
        False -> False
      }
    }
  }
}
