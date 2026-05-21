import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import items_calculator/game_data.{type Faction}
import sets_calculator/sets_game_data.{
  type SetId, items_needed, items_per_set, pool_size, set_ids_for_color,
  set_ids_for_entity, set_ids_for_faction,
}
import sets_calculator/sets_inventory.{type Inventory, count_owned, get_slots}
import sets_calculator/sets_model.{
  type Model, GoalAnySetOnEntity, GoalAnySetOnFaction, GoalDuplicates,
  GoalFirstSetOfColor, GoalSpecificSet,
}

/// Расчет кривой вероятности для заданной цели
pub fn calculate_for_goal(model: Model) -> List(#(Int, Float)) {
  let max_n = model.max_attempts
  let pool = pool_size()

  case model.goal_type {
    GoalSpecificSet -> {
      // Конкретный сет: нужно собрать items_needed из 4 целевых из пула pool_size
      let initial_owned = count_owned(model.owned_slots)
      let entity_type = model.selected_entity_type
      let needed = items_needed(entity_type)
      let target = items_per_set()
      calculate_single_set_curve(pool, target, needed, initial_owned, max_n)
    }

    GoalAnySetOnEntity -> {
      // Любой из 2 сетов на сущность - учитываем оба сета из инвентаря
      case model.selected_entity {
        Some(name) -> {
          let set_ids =
            set_ids_for_entity(
              name,
              model.selected_entity_type,
              model.selected_color,
            )
          calculate_any_of_sets_curve_with_inventory(
            pool,
            set_ids,
            model.inventory,
            max_n,
          )
        }
        None -> generate_zeros(max_n)
      }
    }

    GoalAnySetOnFaction -> {
      // Любой сет на фракцию - учитываем все сеты фракции из инвентаря
      case model.selected_faction {
        Some(faction) -> {
          let set_ids = set_ids_for_faction(faction, model.selected_color)
          calculate_any_of_sets_curve_with_inventory(
            pool,
            set_ids,
            model.inventory,
            max_n,
          )
        }
        None -> generate_zeros(max_n)
      }
    }

    GoalFirstSetOfColor -> {
      // Любой сет редкости - учитываем все сеты редкости из инвентаря
      let set_ids = set_ids_for_color(model.selected_color)
      calculate_any_of_sets_curve_with_inventory(
        pool,
        set_ids,
        model.inventory,
        max_n,
      )
    }

    GoalDuplicates -> {
      // Дубликаты обрабатываются отдельно в recalculate
      generate_zeros(max_n)
    }
  }
}

/// Расчет вероятности собрать один конкретный сет
/// Используем динамическое программирование
fn calculate_single_set_curve(
  pool: Int,
  target: Int,
  needed: Int,
  initial_owned: Int,
  max_n: Int,
) -> List(#(Int, Float)) {
  // dp[j] = вероятность иметь ровно j уникальных целевых вещей
  // Начинаем с initial_owned вещей
  let p = int.to_float(pool)
  let t = int.to_float(target)

  // Начальное распределение: точно initial_owned вещей
  let initial_dp =
    list.range(0, target)
    |> list.map(fn(j) {
      case j == initial_owned {
        True -> 1.0
        False -> 0.0
      }
    })

  // Строим кривую
  build_curve(initial_dp, p, t, needed, max_n, 0, [
    #(0, prob_at_least(initial_dp, needed)),
  ])
}

fn build_curve(
  dp: List(Float),
  pool: Float,
  target: Float,
  needed: Int,
  max_n: Int,
  current_n: Int,
  acc: List(#(Int, Float)),
) -> List(#(Int, Float)) {
  case current_n >= max_n {
    True -> list.reverse(acc)
    False -> {
      let new_dp = step_dp(dp, pool, target)
      let prob = prob_at_least(new_dp, needed)
      let new_n = current_n + 1
      build_curve(new_dp, pool, target, needed, max_n, new_n, [
        #(new_n, prob),
        ..acc
      ])
    }
  }
}

/// Один шаг ДП: переход от dp[i] к dp[i+1]
fn step_dp(dp: List(Float), pool: Float, target: Float) -> List(Float) {
  list.index_map(dp, fn(prob_j, j) {
    let jf = int.to_float(j)
    // Вероятность остаться на j: попасть не в новую целевую
    let stay_prob = 1.0 -. { target -. jf } /. pool
    let stay = prob_j *. stay_prob

    // Вероятность перейти из j-1 в j: попасть в новую целевую
    let come_from = case j > 0 {
      True -> {
        let prev_prob = list_get(dp, j - 1)
        let prev_jf = int.to_float(j - 1)
        let trans_prob = { target -. prev_jf } /. pool
        prev_prob *. trans_prob
      }
      False -> 0.0
    }

    stay +. come_from
  })
}

/// Получить элемент списка по индексу
fn list_get(lst: List(Float), idx: Int) -> Float {
  lst
  |> list.drop(idx)
  |> list.first
  |> result.unwrap(0.0)
}

/// Вероятность иметь >= needed вещей
fn prob_at_least(dp: List(Float), needed: Int) -> Float {
  dp
  |> list.index_map(fn(p, i) { #(i, p) })
  |> list.filter(fn(pair) { pair.0 >= needed })
  |> list.map(fn(pair) { pair.1 })
  |> list.fold(0.0, fn(acc, p) { acc +. p })
}

/// Расчет вероятности собрать хотя бы один НОВЫЙ сет из списка,
/// где каждый сет имеет своё количество вещей из инвентаря.
/// Уже собранные сеты исключаются из расчёта.
pub fn calculate_any_of_sets_curve_with_inventory(
  pool: Int,
  set_ids: List(SetId),
  inventory: Inventory,
  max_n: Int,
) -> List(#(Int, Float)) {
  // Фильтруем сеты: оставляем только те, которые ещё не собраны
  let incomplete_set_ids =
    list.filter(set_ids, fn(set_id) {
      let owned_slots = get_slots(inventory, set_id)
      let initial_owned = count_owned(owned_slots)
      let needed = items_needed(set_id.entity_type)
      initial_owned < needed
      // Сет ещё не собран
    })

  // Если все сеты уже собраны - возвращаем нулевую кривую
  case list.is_empty(incomplete_set_ids) {
    True -> generate_zeros(max_n)
    False -> {
      // Для каждого незавершённого сета вычисляем его кривую
      let curves =
        list.map(incomplete_set_ids, fn(set_id) {
          let owned_slots = get_slots(inventory, set_id)
          let initial_owned = count_owned(owned_slots)
          let needed = items_needed(set_id.entity_type)
          calculate_single_set_curve(pool, 4, needed, initial_owned, max_n)
        })

      // Комбинируем кривые: P(any) = 1 - П(1 - P_i)
      combine_curves(curves, max_n)
    }
  }
}

/// Комбинирование кривых по формуле P(any) = 1 - П(1 - P_i)
fn combine_curves(
  curves: List(List(#(Int, Float))),
  max_n: Int,
) -> List(#(Int, Float)) {
  list.range(0, max_n)
  |> list.map(fn(n) {
    let p_not_any =
      list.fold(curves, 1.0, fn(acc, curve) {
        let p_single = get_prob_at_n(curve, n)
        acc *. { 1.0 -. p_single }
      })
    #(n, 1.0 -. p_not_any)
  })
}

/// Получить вероятность для точки n из кривой
fn get_prob_at_n(curve: List(#(Int, Float)), n: Int) -> Float {
  curve
  |> list.find(fn(point) { point.0 == n })
  |> result.map(fn(point) { point.1 })
  |> result.unwrap(0.0)
}

/// Генерация нулевой кривой
fn generate_zeros(max_n: Int) -> List(#(Int, Float)) {
  list.range(0, max_n)
  |> list.map(fn(n) { #(n, 0.0) })
}

/// Расчет кривой вероятности для дубликатов
/// min_duplicates - минимум раз, сколько вещь должна выпасть (K)
/// min_items - минимум вещей с таким количеством дубликатов (N)
/// max_attempts - максимум попыток
pub fn calculate_duplicates_curve(
  min_duplicates: Int,
  min_items: Int,
  max_attempts: Int,
) -> List(#(Int, Float)) {
  let pool = pool_size()
  // 288
  let p_item = 1.0 /. int.to_float(pool)
  // 1/288

  list.range(0, max_attempts)
  |> list.map(fn(m) {
    // Вероятность что одна вещь выпала ≥K раз
    let p_single = prob_at_least_k_hits(m, min_duplicates, p_item)
    // Вероятность что ≥N вещей выпали ≥K раз
    let p_total = binomial_at_least(min_items, pool, p_single)
    #(m, p_total)
  })
}

/// Вероятность ≥k попаданий за n попыток с вероятностью p
/// Использует приближение Пуассона для численной стабильности
fn prob_at_least_k_hits(n: Int, k: Int, p: Float) -> Float {
  case k <= 0 {
    True -> 1.0
    False ->
      case k > n {
        True -> 0.0
        False -> {
          // λ = n * p
          let lambda = int.to_float(n) *. p
          // P(X ≥ k) = 1 - P(X < k) = 1 - CDF(k-1)
          1.0 -. poisson_cdf(k - 1, lambda)
        }
      }
  }
}

/// CDF Пуассона: P(X ≤ k) = Σ_{i=0}^{k} (λ^i * e^(-λ)) / i!
/// Использует рекуррентную формулу P(i) = P(i-1) * λ / i для стабильности
fn poisson_cdf(k: Int, lambda: Float) -> Float {
  case lambda <=. 0.0 {
    True -> 1.0
    // При λ=0, P(X=0) = 1
    False ->
      case k < 0 {
        True -> 0.0
        False -> {
          // e^(-λ)
          let e_neg_lambda = float.exponential(0.0 -. lambda)

          // Начинаем с P(0) = e^(-λ), накапливаем сумму
          list.range(0, k)
          |> list.fold(#(e_neg_lambda, e_neg_lambda), fn(acc, i) {
            let #(p_i, sum) = acc
            case i {
              0 -> #(p_i, sum)
              _ -> {
                // P(i) = P(i-1) * λ / i
                let new_p = p_i *. lambda /. int.to_float(i)
                #(new_p, sum +. new_p)
              }
            }
          })
          |> fn(result) { result.1 }
        }
      }
  }
}

/// Биномиальная вероятность >= n успехов из total с вероятностью prob
/// Использует приближение Пуассона для численной стабильности
fn binomial_at_least(n: Int, total: Int, prob: Float) -> Float {
  case prob <=. 0.0 {
    True ->
      case n <= 0 {
        True -> 1.0
        False -> 0.0
      }
    False ->
      case prob >=. 1.0 {
        True -> 1.0
        False -> {
          // λ = total * prob
          let lambda = int.to_float(total) *. prob
          // P(X ≥ n) = 1 - P(X < n) = 1 - CDF(n-1)
          1.0 -. poisson_cdf(n - 1, lambda)
        }
      }
  }
}

// ============================================
// Бутстрап (Monte Carlo) верификация
// ============================================

@external(javascript, "../sets_ffi.mjs", "bootstrapPoint")
fn bootstrap_point(
  attempts: Int,
  pool_size: Int,
  min_duplicates: Int,
  min_items: Int,
  num_simulations: Int,
) -> Float

/// Расчёт кривой вероятности дубликатов методом бутстрапа
/// num_simulations - количество симуляций (рекомендуется 10000)
pub fn calculate_duplicates_bootstrap(
  min_duplicates: Int,
  min_items: Int,
  max_attempts: Int,
  num_simulations: Int,
) -> List(#(Int, Float)) {
  let pool = pool_size()

  list.range(0, max_attempts)
  |> list.map(fn(m) {
    let prob =
      bootstrap_point(m, pool, min_duplicates, min_items, num_simulations)
    #(m, prob)
  })
}

// ============================================
// Функции с учётом инвентаря (Poisson-Binomial свёртка)
// ============================================

/// Группировать счётчики: {начальный_счётчик → количество_вещей}
fn group_counts(counts: List(Int)) -> List(#(Int, Int)) {
  counts
  |> list.fold(dict.new(), fn(acc, count) {
    let current = dict.get(acc, count) |> result.unwrap(0)
    dict.insert(acc, count, current + 1)
  })
  |> dict.to_list
}

/// Возведение Float в целую степень
fn float_pow(base: Float, exp: Int) -> Float {
  case exp {
    0 -> 1.0
    1 -> base
    _ if exp < 0 -> 1.0 /. float_pow(base, 0 - exp)
    _ -> base *. float_pow(base, exp - 1)
  }
}

/// Построить биномиальное распределение B(n, p) как список вероятностей
/// Возвращает [P(X=0), P(X=1), ..., P(X=n)]
fn binomial_pmf(n: Int, p: Float) -> List(Float) {
  case n {
    0 -> [1.0]
    _ -> {
      // Обработка краевых случаев
      case p >=. 1.0 {
        True -> {
          // p = 1.0: все n успешны, P(X=n) = 1.0
          list.range(0, n)
          |> list.map(fn(k) {
            case k == n {
              True -> 1.0
              False -> 0.0
            }
          })
        }
        False ->
          case p <=. 0.0 {
            True -> {
              // p = 0.0: все n неуспешны, P(X=0) = 1.0
              list.range(0, n)
              |> list.map(fn(k) {
                case k == 0 {
                  True -> 1.0
                  False -> 0.0
                }
              })
            }
            False -> {
              // Обычный случай: 0 < p < 1
              let q = 1.0 -. p
              // Используем рекуррентную формулу: P(k+1) = P(k) * (n-k)/(k+1) * p/q
              // P(0) = q^n
              let p0 = float_pow(q, n)
              list.range(0, n)
              |> list.fold(#([], p0), fn(acc, k) {
                let #(probs, prev_prob) = acc
                case k {
                  0 -> #([p0], p0)
                  _ -> {
                    // P(k) = P(k-1) * (n-k+1)/k * p/q
                    let ratio =
                      int.to_float(n - k + 1) /. int.to_float(k) *. p /. q
                    let pk = prev_prob *. ratio
                    #(list.append(probs, [pk]), pk)
                  }
                }
              })
              |> fn(result) { result.0 }
            }
          }
      }
    }
  }
}

/// Свёртка двух распределений
/// conv[k] = Σ_i a[i] * b[k-i]
fn convolve(dist_a: List(Float), dist_b: List(Float)) -> List(Float) {
  let len_a = list.length(dist_a)
  let len_b = list.length(dist_b)
  let result_len = len_a + len_b - 1

  list.range(0, result_len - 1)
  |> list.map(fn(k) {
    list.range(0, k)
    |> list.fold(0.0, fn(sum, i) {
      let j = k - i
      case i < len_a && j < len_b {
        True -> {
          let a_i = list_get_float(dist_a, i)
          let b_j = list_get_float(dist_b, j)
          sum +. a_i *. b_j
        }
        False -> sum
      }
    })
  })
}

fn list_get_float(lst: List(Float), idx: Int) -> Float {
  lst |> list.drop(idx) |> list.first |> result.unwrap(0.0)
}

/// Свёртка списка распределений
fn convolve_all(distributions: List(List(Float))) -> List(Float) {
  case distributions {
    [] -> [1.0]
    [first, ..rest] -> {
      list.fold(rest, first, convolve)
    }
  }
}

/// P(S >= n) из распределения
fn prob_at_least_from_dist(dist: List(Float), n: Int) -> Float {
  dist
  |> list.index_map(fn(p, i) { #(i, p) })
  |> list.filter(fn(pair) { pair.0 >= n })
  |> list.map(fn(pair) { pair.1 })
  |> list.fold(0.0, fn(acc, p) { acc +. p })
}

/// Аналитика с учётом инвентаря (полная свёртка)
pub fn calculate_duplicates_curve_with_inventory(
  min_duplicates: Int,
  min_items: Int,
  max_attempts: Int,
  initial_counts: List(Int),
) -> List(#(Int, Float)) {
  let pool = pool_size()
  let p_item = 1.0 /. int.to_float(pool)

  // Группируем вещи по начальному счётчику
  let groups = group_counts(initial_counts)

  list.range(0, max_attempts)
  |> list.map(fn(m) {
    let prob =
      calculate_point_with_convolution(
        m,
        min_duplicates,
        min_items,
        groups,
        p_item,
      )
    #(m, prob)
  })
}

fn calculate_point_with_convolution(
  attempts: Int,
  min_duplicates: Int,
  min_items: Int,
  groups: List(#(Int, Int)),
  p_item: Float,
) -> Float {
  // Для каждой группы строим биномиальное распределение
  let distributions =
    list.map(groups, fn(group) {
      let #(initial_count, num_items) = group
      let needed = int.max(0, min_duplicates - initial_count)
      let p_success = prob_at_least_k_hits(attempts, needed, p_item)
      binomial_pmf(num_items, p_success)
    })

  // Свёртка всех распределений
  let total_dist = convolve_all(distributions)

  // P(S >= min_items)
  prob_at_least_from_dist(total_dist, min_items)
}

// ============================================
// Бутстрап с инвентарём
// ============================================

@external(javascript, "../sets_ffi.mjs", "bootstrapPointWithInitial")
fn bootstrap_point_with_initial_ffi(
  attempts: Int,
  pool_size: Int,
  min_duplicates: Int,
  min_items: Int,
  num_simulations: Int,
  initial_counts: List(Int),
) -> Float

/// Расчёт кривой вероятности дубликатов методом бутстрапа с учётом инвентаря
pub fn calculate_duplicates_bootstrap_with_inventory(
  min_duplicates: Int,
  min_items: Int,
  max_attempts: Int,
  num_simulations: Int,
  initial_counts: List(Int),
) -> List(#(Int, Float)) {
  let pool = pool_size()

  list.range(0, max_attempts)
  |> list.map(fn(m) {
    let prob =
      bootstrap_point_with_initial_ffi(
        m,
        pool,
        min_duplicates,
        min_items,
        num_simulations,
        initial_counts,
      )
    #(m, prob)
  })
}

// ============================================
// Публичные функции для панели целей
// ============================================

/// Расчёт кривой для конкретного сета
pub fn calculate_specific_set_curve(
  needed: Int,
  owned_count: Int,
  max_attempts: Int,
) -> List(#(Int, Float)) {
  let pool = pool_size()
  let target = items_per_set()
  calculate_single_set_curve(pool, target, needed, owned_count, max_attempts)
}

/// Расчёт кривой для любого сета фракции
pub fn calculate_any_faction_set_curve(
  faction: Faction,
  color: game_data.ItemColor,
  max_attempts: Int,
  inventory: Inventory,
) -> List(#(Int, Float)) {
  let pool = pool_size()
  let set_ids = set_ids_for_faction(faction, color)
  calculate_any_of_sets_curve_with_inventory(
    pool,
    set_ids,
    inventory,
    max_attempts,
  )
}
