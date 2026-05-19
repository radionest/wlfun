# План E2E тестирования перед рефакторингом

## Инструменты для Gleam/Lustre

**Lustre v5.2+** включает встроенные модули для тестирования без браузера:

### 1. `lustre/dev/query` — поиск элементов в представлении

```gleam
import lustre/dev/query

// Селекторы
query.tag("div")           // по тегу
query.class("my-class")    // по классу
query.test_id("my-id")     // по test-id атрибуту
query.and(sel1, sel2)      // комбинирование

// Поиск
query.find(in: view, matching: selector)  // -> Result(Element, Nil)
query.find_all(in: view, matching: selector)  // -> List(Element)

// Assertions (Lustre v5.2+)
query.matches(element, selector)  // -> Bool
query.has(element, selector)      // -> Bool
```

### 2. `lustre/dev/simulate` — симуляция приложения

```gleam
import lustre/dev/simulate

// Создание и запуск
simulate.application(init, update, view)
|> simulate.start(Nil)

// Взаимодействие
|> simulate.message(MyMsg)           // отправить сообщение
|> simulate.submit(on: form_sel, fields: [...])  // отправить форму

// Получение состояния
simulate.view(app)   // -> Element
simulate.model(app)  // -> Model
```

### 3. `birdie` — snapshot тестирование

```gleam
import birdie

pub fn my_test() {
  "результат вычисления"
  |> birdie.snap(title: "название теста")
}
```

- Сохраняет ожидаемый результат в `birdie_snapshots/`
- При следующем запуске сравнивает
- CLI: `gleam run -m birdie` для интерактивного review

---

## Необходимые изменения в gleam.toml

```toml
[dependencies]
lustre = ">= 5.2.0 and < 6.0.0"  # Обновить с 5.0.0

[dev-dependencies]
gleeunit = ">= 1.9.0 and < 2.0.0"
lustre_dev_tools = ">= 2.3.2 and < 3.0.0"
birdie = ">= 1.5.3 and < 2.0.0"  # Добавить
```

---

## Какие тесты написать

### BP Calculator

| Функция | Файл | Тип теста |
|---------|------|-----------|
| `calculate_reachable_level()` | `battle_pass.gleam:50-80` | Unit |
| `required_daily_points()` | `battle_pass.gleam:83-120` | Unit |
| `calculate_total_available_points()` | `battle_pass.gleam:123-140` | Unit |
| `level_costs()` | `battle_pass.gleam:15-45` | Snapshot |
| `bp_view.view()` | `bp_view.gleam` | Snapshot |

### Items Calculator

| Функция | Файл | Тип теста |
|---------|------|-----------|
| `calculate_upgrade_cost()` | `calculator_logic.gleam:20-51` | Unit |
| `gold_multiplier()` / `dust_multiplier()` | `calculator_logic.gleam:5-18` | Unit |
| `items_view.view()` | `items_view.gleam` | Snapshot |

### Sets Calculator

| Функция | Файл | Тип теста |
|---------|------|-----------|
| `calculate_for_goal()` (5 типов целей) | `sets_probability.gleam` | Unit + Snapshot |
| `toggle_slot()` | `sets_inventory.gleam:161-176` | Unit |
| `set_slot_count()` | `sets_inventory.gleam:179-193` | Unit |
| `get_all_counts_list()` | `sets_inventory.gleam` | Unit |
| `encode_inventory()` | `sets_uri.gleam:20-55` | Unit |
| `decode_inventory()` | `sets_uri.gleam:59-108` | Unit |
| Encode → Decode round-trip | `sets_uri.gleam` | Round-trip |
| `sets_view.view()` | `sets_view.gleam` | Snapshot |

---

## Примеры тестов

### Unit тест для battle_pass.gleam

```gleam
// test/bp_calculator_test.gleam
import gleeunit/should
import bp_calculator/battle_pass

pub fn calculate_reachable_level_from_1_test() {
  // При 1000 очках, начиная с уровня 1, прогресс 0
  battle_pass.calculate_reachable_level(1, 0, 1000)
  |> should.equal(5)
}

pub fn calculate_reachable_level_from_30_test() {
  // При 5000 очках, начиная с уровня 30, прогресс 50
  battle_pass.calculate_reachable_level(30, 50, 5000)
  |> should.equal(42)
}

pub fn required_daily_points_zero_days_test() {
  // 0 дней — ошибка
  battle_pass.required_daily_points(1, 0, 30, 0, 0)
  |> should.be_error
}

pub fn required_daily_points_normal_test() {
  // Нужно достичь уровень 30, текущий 1, 30 дней
  let result = battle_pass.required_daily_points(1, 0, 30, 0, 30)
  result |> should.be_ok
  // Проверяем что результат разумный (между 100 и 500)
  let assert Ok(points) = result
  { points >= 100 && points <= 500 } |> should.be_true
}
```

### Snapshot тест для view

```gleam
// test/bp_view_test.gleam
import birdie
import lustre/element
import bp_calculator/bp_model
import bp_calculator/bp_view

pub fn bp_view_calculate_level_mode_test() {
  let model = bp_model.init()
  let view = bp_view.view(model)

  view
  |> element.to_readable_string
  |> birdie.snap("BP Calculator - Calculate Level Mode")
}

pub fn bp_view_daily_points_mode_test() {
  let model = bp_model.Model(
    ..bp_model.init(),
    mode: bp_model.CalculateDailyPoints,
  )
  let view = bp_view.view(model)

  view
  |> element.to_readable_string
  |> birdie.snap("BP Calculator - Daily Points Mode")
}
```

### Unit тест для sets_inventory

```gleam
// test/sets_inventory_test.gleam
import gleeunit/should
import sets_calculator/sets_inventory.{
  empty, toggle_slot, set_slot_count, get_slots, get_counts,
  OwnedSlots, OwnedCounts,
}
import sets_calculator/sets_game_data.{SetId, RegularUnit, Blue}

pub fn toggle_slot_test() {
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv = empty()
    |> toggle_slot(set_id, 1)
    |> toggle_slot(set_id, 3)

  let slots = get_slots(inv, set_id)
  slots.slot1 |> should.be_true
  slots.slot2 |> should.be_false
  slots.slot3 |> should.be_true
  slots.slot4 |> should.be_false

  // Counts должны синхронизироваться
  let counts = get_counts(inv, set_id)
  counts.slot1 |> should.equal(1)
  counts.slot3 |> should.equal(1)
}

pub fn set_slot_count_test() {
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv = empty()
    |> set_slot_count(set_id, 2, 5)

  let counts = get_counts(inv, set_id)
  counts.slot2 |> should.equal(5)

  // Slots должны синхронизироваться
  let slots = get_slots(inv, set_id)
  slots.slot2 |> should.be_true
}
```

### Round-trip тест для URI

```gleam
// test/sets_uri_test.gleam
import gleeunit/should
import sets_calculator/sets_uri
import sets_calculator/sets_inventory

pub fn encode_decode_roundtrip_test() {
  // Создаём инвентарь с данными
  let original = sets_inventory.empty()
    |> sets_inventory.toggle_slot(set_id1, 1)
    |> sets_inventory.toggle_slot(set_id1, 2)
    |> sets_inventory.set_slot_count(set_id2, 3, 5)

  // Кодируем
  let encoded = sets_uri.encode_inventory(original)

  // Декодируем
  let decoded = sets_uri.decode_inventory(encoded)
  decoded |> should.be_ok

  // Сравниваем
  let assert Ok(result) = decoded
  sets_inventory.to_list(result)
  |> should.equal(sets_inventory.to_list(original))
}

pub fn decode_v1_format_test() {
  // Тест обратной совместимости с v1 форматом
  let v1_encoded = "v1.ABC123..."
  sets_uri.decode_inventory(v1_encoded)
  |> should.be_ok
}
```

### Simulation тест

```gleam
// test/sets_simulation_test.gleam
import gleeunit/should
import lustre/dev/simulate
import lustre/dev/query
import sets_calculator/sets_model.{SetGoalType, GoalDuplicates}
import sets_calculator/sets_update
import sets_calculator/sets_view

pub fn sets_goal_change_to_duplicates_test() {
  let app = simulate.application(
    sets_model.init,
    sets_update.update,
    sets_view.view,
  )
  |> simulate.start(Nil)
  |> simulate.message(SetGoalType("duplicates"))

  let view = simulate.view(app)
  let selector = query.class("duplicate-params")

  // Должны появиться поля для дубликатов
  query.find(in: view, matching: selector)
  |> should.be_ok
}

pub fn sets_select_faction_clears_entity_test() {
  let app = simulate.application(
    sets_model.init,
    sets_update.update,
    sets_view.view,
  )
  |> simulate.start(Nil)
  |> simulate.message(sets_model.SelectFaction("light"))
  |> simulate.message(sets_model.SelectEntity("Мечник"))
  |> simulate.message(sets_model.SelectFaction("dark"))  // Смена фракции

  let model = simulate.model(app)
  // Entity должен сброситься
  model.selected_entity |> should.be_none
}
```

---

## Структура тестов

```
test/
├── bp_calculator_test.gleam      # Unit тесты BP бизнес-логики
├── bp_view_test.gleam            # Snapshot тесты BP view
├── items_calculator_test.gleam   # Unit тесты Items бизнес-логики
├── items_view_test.gleam         # Snapshot тесты Items view
├── sets_probability_test.gleam   # Unit тесты расчёта вероятностей
├── sets_inventory_test.gleam     # Unit тесты операций с инвентарём
├── sets_uri_test.gleam           # Round-trip тесты encode/decode
├── sets_view_test.gleam          # Snapshot тесты Sets view
└── sets_simulation_test.gleam    # Simulation тесты взаимодействий
```

---

## Запуск тестов

```bash
# Установка зависимостей
gleam deps download

# Запуск всех тестов
gleam test

# Интерактивный review snapshot'ов
gleam run -m birdie

# Только конкретный файл (если поддерживается)
gleam test -- --filter bp_calculator
```

---

## Порядок действий

1. **Обновить gleam.toml** — добавить birdie, обновить lustre
2. **gleam deps download** — скачать зависимости
3. **Написать unit тесты** для бизнес-логики (без view)
4. **Запустить gleam test** — убедиться что логика работает
5. **Написать snapshot тесты** для view
6. **gleam run -m birdie** — принять начальные snapshot'ы
7. **Запустить gleam test** — все тесты должны проходить
8. **Готово к рефакторингу** — теперь можно безопасно менять код

---

## Источники

- [Lustre v5.2 Announcement](https://hexdocs.pm/lustre/announcements/2025-05-18.html)
- [Birdie - Snapshot testing in Gleam](https://github.com/giacomocavalieri/birdie)
- [Birdie Documentation](https://hexdocs.pm/birdie/)
- [UI Testing With Lustre and Gleam - Code BEAM](https://codebeameurope.com/talks/ui-testing-with-lustre-and-gleam/)
