# План: Учёт инвентаря в расчёте дубликатов

## Проблема

Текущие алгоритмы (аналитика и бутстрап) не учитывают начальные счётчики инвентаря.
Все 288 вещей считаются с 0 дубликатов, хотя у некоторых уже могут быть дубликаты.

## Цель

Учесть начальное состояние инвентаря: если у вещи уже 2 дубликата и нужно K=3,
то достаточно 1 попадания, а не 3.

## Структура данных

```text
pool_size = (30 юнитов + 6 героев) × 2 сета × 4 слота = 288 вещей

Инвентарь хранит для каждого SetId:
- OwnedCounts { slot1: Int, slot2: Int, slot3: Int, slot4: Int }

Для расчёта нужен плоский список из 288 счётчиков.
```

## Зависимости

Добавить в `gleam.toml`:
```toml
[dependencies]
glearray = ">= 1.0.0 and < 2.0.0"
```

`glearray` — массив для Gleam, который компилируется в нативный JavaScript Array.
Это позволяет передавать данные в FFI без сериализации.

---

## Изменяемые файлы

### 1. `src/sets_calculator/sets_inventory.gleam`

Добавить функцию получения всех счётчиков как Array:

```gleam
import gleam/list
import glearray.{type Array}
import items_calculator/game_data.{type ItemColor}

/// Получить массив всех 288 счётчиков из инвентаря для указанной редкости
pub fn get_all_counts_array(inventory: Inventory, color: ItemColor) -> Array(Int) {
  let all_names = sets_game_data.all_entity_names()

  let counts_list = list.flat_map(all_names, fn(name) {
    let entity_type = sets_game_data.detect_entity_type(name)
    // 2 сета × 4 слота = 8 счётчиков на сущность
    list.flat_map([1, 2], fn(set_num) {
      let set_id = SetId(name, entity_type, color, set_num)
      let counts = get_counts(inventory, set_id)
      [counts.slot1, counts.slot2, counts.slot3, counts.slot4]
    })
  })

  glearray.from_list(counts_list)
}
```

---

### 2. `src/sets_ffi.mjs`

Добавить функции с начальными счётчиками:

```javascript
// Запуск симуляции с начальными счётчиками
export function runDuplicateSimulationWithInitial(
  attempts,
  poolSize,
  minDuplicates,
  initialCounts  // Array<number> длиной poolSize
) {
  // Копируем начальные счётчики
  const counts = [...initialCounts];
  for (let i = 0; i < attempts; i++) {
    const item = Math.floor(Math.random() * poolSize);
    counts[item]++;
  }
  let itemsWithDuplicates = 0;
  for (let i = 0; i < poolSize; i++) {
    if (counts[i] >= minDuplicates) {
      itemsWithDuplicates++;
    }
  }
  return itemsWithDuplicates;
}

// Бутстрап с начальными счётчиками (принимает glearray напрямую как JS Array)
export function bootstrapPointWithInitial(
  attempts,
  poolSize,
  minDuplicates,
  minItems,
  numSimulations,
  initialCounts  // glearray компилируется в нативный JS Array
) {
  let successes = 0;
  for (let sim = 0; sim < numSimulations; sim++) {
    const itemsWithDups = runDuplicateSimulationWithInitial(
      attempts, poolSize, minDuplicates, initialCounts
    );
    if (itemsWithDups >= minItems) {
      successes++;
    }
  }
  return successes / numSimulations;
}
```

---

### 3. `src/sets_calculator/sets_probability.gleam`

#### 3.1 Группировка счётчиков

```gleam
import gleam/dict.{type Dict}

/// Группировать счётчики: {начальный_счётчик → количество_вещей}
fn group_counts(counts: List(Int)) -> List(#(Int, Int)) {
  counts
  |> list.fold(dict.new(), fn(acc, count) {
    let current = dict.get(acc, count) |> result.unwrap(0)
    dict.insert(acc, count, current + 1)
  })
  |> dict.to_list
}
```

#### 3.2 Биномиальное PMF

```gleam
/// Построить биномиальное распределение B(n, p) как список вероятностей
/// Возвращает [P(X=0), P(X=1), ..., P(X=n)]
fn binomial_pmf(n: Int, p: Float) -> List(Float) {
  case n {
    0 -> [1.0]
    _ -> {
      let q = 1.0 -. p
      // Используем рекуррентную формулу: P(k+1) = P(k) * (n-k)/(k+1) * p/q
      list.range(0, n)
      |> list.fold(#([], 1.0), fn(acc, k) {
        let #(probs, prev_prob) = acc
        case k {
          0 -> {
            // P(0) = q^n
            let p0 = float_pow(q, n)
            #([p0], p0)
          }
          _ -> {
            // P(k) = P(k-1) * (n-k+1)/k * p/q
            let ratio = int.to_float(n - k + 1) /. int.to_float(k) *. p /. q
            let pk = prev_prob *. ratio
            #(list.append(probs, [pk]), pk)
          }
        }
      })
      |> fn(result) { result.0 }
    }
  }
}

fn float_pow(base: Float, exp: Int) -> Float {
  case exp {
    0 -> 1.0
    1 -> base
    _ -> base *. float_pow(base, exp - 1)
  }
}
```

#### 3.3 Свёртка распределений

```gleam
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
```

#### 3.4 Основная функция аналитики

```gleam
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
    let prob = calculate_point_with_convolution(
      m, min_duplicates, min_items, groups, p_item
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
  let distributions = list.map(groups, fn(group) {
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

fn prob_at_least_from_dist(dist: List(Float), n: Int) -> Float {
  dist
  |> list.index_map(fn(p, i) { #(i, p) })
  |> list.filter(fn(pair) { pair.0 >= n })
  |> list.map(fn(pair) { pair.1 })
  |> list.fold(0.0, fn(acc, p) { acc +. p })
}
```

#### 3.5 Бутстрап с инвентарём

```gleam
import glearray.{type Array}

@external(javascript, "../sets_ffi.mjs", "bootstrapPointWithInitial")
fn bootstrap_point_with_initial_ffi(
  attempts: Int,
  pool_size: Int,
  min_duplicates: Int,
  min_items: Int,
  num_simulations: Int,
  initial_counts: Array(Int),  // glearray → JS Array напрямую
) -> Float

pub fn calculate_duplicates_bootstrap_with_inventory(
  min_duplicates: Int,
  min_items: Int,
  max_attempts: Int,
  num_simulations: Int,
  initial_counts: Array(Int),
) -> List(#(Int, Float)) {
  let pool = pool_size()

  list.range(0, max_attempts)
  |> list.map(fn(m) {
    let prob = bootstrap_point_with_initial_ffi(
      m, pool, min_duplicates, min_items, num_simulations, initial_counts
    )
    #(m, prob)
  })
}
```

---

### 4. `src/sets_calculator/sets_update.gleam`

Обновить `recalculate` и `RunBootstrap`:

```gleam
fn recalculate(model: Model) -> Model {
  case model.goal_type {
    GoalDuplicates -> {
      // Получаем начальные счётчики из инвентаря как Array
      let initial_counts = sets_inventory.get_all_counts_array(
        model.inventory,
        model.selected_color,
      )

      // Для аналитики конвертируем в List (нужен для group_counts)
      let counts_list = glearray.to_list(initial_counts)

      // Аналитический расчёт с инвентарём
      let curve = sets_probability.calculate_duplicates_curve_with_inventory(
        model.min_duplicates_per_item,
        model.min_items_with_duplicates,
        model.max_attempts,
        counts_list,
      )

      // Бутстрап только если включено автообновление (передаём Array напрямую)
      let bootstrap = case model.bootstrap_auto_update {
        True -> Some(sets_probability.calculate_duplicates_bootstrap_with_inventory(
          model.min_duplicates_per_item,
          model.min_items_with_duplicates,
          model.max_attempts,
          10_000,
          initial_counts,  // Array для FFI
        ))
        False -> model.bootstrap_curve
      }

      Model(..model, probability_curve: Some(curve), bootstrap_curve: bootstrap)
    }
    _ -> {
      let curve = sets_probability.calculate_for_goal(model)
      Model(..model, probability_curve: Some(curve), bootstrap_curve: None)
    }
  }
}
```

---

## Алгоритм свёртки (Poisson-Binomial)

### Шаг 1: Группировка вещей

```
initial_counts: [0, 0, 2, 0, 1, 3, 0, ...] (288 элементов)
→ groups: [(0, 250), (1, 20), (2, 15), (3, 3)]
   (начальный_счётчик, количество_вещей)
```

### Шаг 2: Вероятности для каждой группы

Для группы с начальным счётчиком `c`:
```
needed = max(0, K - c)
p_c = P(Poisson(λ) ≥ needed), где λ = attempts / 288
```

Пример при K=3:
- Группа c=0: нужно ≥3 попадания → p_0 = P(X ≥ 3)
- Группа c=2: нужно ≥1 попадание → p_2 = P(X ≥ 1) — выше!
- Группа c=3: нужно ≥0 попаданий → p_3 = 1.0

### Шаг 3: Построение распределений

Для каждой группы (c, n_c, p_c):
```
X_c ~ Binomial(n_c, p_c)
dist_c = [P(X_c=0), P(X_c=1), ..., P(X_c=n_c)]
```

### Шаг 4: Свёртка

```
S = X_1 + X_2 + ... + X_G  (сумма по всем группам)
dist_S = dist_1 * dist_2 * ... * dist_G  (свёртка)
```

### Шаг 5: Результат

```
P(S ≥ N) = Σ_{k=N}^{288} dist_S[k]
```

---

## Сложность

- Группировка: O(288)
- Биномиальное PMF для группы: O(n_c)
- Свёртка двух распределений: O(len_a × len_b)
- Всего на одну точку: O(G × 288²) где G ≤ 10 групп
- На 100 точек: ~8M операций — приемлемо

---

## Порядок реализации

1. Добавить зависимость `glearray` в `gleam.toml`
2. `sets_inventory.gleam`: добавить `get_all_counts_array`
3. `sets_ffi.mjs`: добавить `bootstrapPointWithInitial`
4. `sets_probability.gleam`:
   - `group_counts`
   - `binomial_pmf`
   - `convolve`, `convolve_all`
   - `calculate_duplicates_curve_with_inventory`
   - `calculate_duplicates_bootstrap_with_inventory`
5. `sets_update.gleam`: обновить вызовы с `initial_counts`
