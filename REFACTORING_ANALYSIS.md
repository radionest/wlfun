# Анализ кода калькуляторов на соответствие DRY, KISS, YAGNI

## Обзор проекта

**Структура**: 3 калькулятора на Gleam + Lustre (Elm-like архитектура)
- `bp_calculator/` - Battle Pass калькулятор (5 файлов)
- `items_calculator/` - Items Grade калькулятор (6 файлов)
- `sets_calculator/` - Sets Probability калькулятор (10 файлов, самый сложный)

---

## Выявленные нарушения принципов

### DRY (Don't Repeat Yourself)

#### 1. Дублирование Storage слоя (КРИТИЧНО)
**Файлы:**
- `src/bp_calculator/bp_storage.gleam` (97 строк)
- `src/items_calculator/items_storage.gleam` (100 строк)
- `src/sets_calculator/sets_storage.gleam` (140 строк)

**Проблема**: Идентичный паттерн в функциях `load()` и `save()`:
```gleam
pub fn load() -> Option(SavedSettings) {
  case plinth_storage.local() {
    Error(_) -> None
    Ok(raw_storage) -> {
      let storage = varasto.new(raw_storage, decoder(), encoder)
      case varasto.get(storage, key) { ... }
    }
  }
}
```

#### 2. Конвертеры типов повторяются (ВЫСОКИЙ)
**Места:**
- `items_storage.gleam:86-99` — `faction_to_string()`, `color_to_string()`
- `sets_view.gleam:507-520` — `color_name()`, `faction_name()`
- `sets_game_data.gleam:106-121` — `entity_type_to_string()`, `string_to_entity_type()`

#### 3. Логика "active" кнопок (СРЕДНИЙ)
**Во всех view файлах** одинаковый паттерн:
```gleam
let light_class = case model.selected_faction {
  Light -> "faction-btn light active"
  Dark -> "faction-btn light"
}
```
- `bp_view.gleam:23-46`
- `items_view.gleam:38-61`
- `sets_view.gleam:68-99, 136-168, 171-194, 238-255`

#### 4. Int parsing с валидацией (НИЗКИЙ)
Разные подходы в разных файлах:
- `bp_update.gleam:69-74` — вспомогательная функция `parse_int_or()`
- `items_update.gleam:28-42` — inline парсинг
- `sets_update.gleam:149-155` — третий вариант

#### 5. Форматирование чисел (НИЗКИЙ)
- `items_view.gleam:203-220` — `format_number()`, `format_with_separators()`
- `sets_view.gleam:565-610` — `format_percent()`, `float_round()`, `pow10()`, `float_to_int()`

---

### KISS (Keep It Simple, Stupid)

#### 1. Гигантская функция update() (КРИТИЧНО)
**Файл:** `sets_update.gleam:36-370`
- **335 строк** в одной функции
- **55+ веток** case выражения
- Сложно читать, тестировать, поддерживать

#### 2. Огромный view файл (ВЫСОКИЙ)
**Файл:** `sets_view.gleam` — **847 строк**
- Смешаны разные секции UI
- Можно разбить на логические модули

#### 3. save() с 7 параметрами (СРЕДНИЙ)
**Файл:** `bp_storage.gleam:70-77`
```gleam
pub fn save(
  mode: String,
  current_level: Int,
  current_progress: Int,
  daily_points: Int,
  days_remaining: Int,
  weekly_rewards_remaining: Int,
  target_level: Int,
) -> Nil
```
Структура `SavedSettings` уже существует, но не используется.

#### 4. Глубокая вложенность в decode (СРЕДНИЙ)
**Файл:** `sets_uri.gleam:59-108`
- 4 уровня вложенных case
- Можно использовать Result pipeline

#### 5. Синхронизация slots/counts вручную (НИЗКИЙ)
**Файл:** `sets_inventory.gleam:161-193`
- Инвариант должен поддерживаться автоматически
- Риск рассинхронизации при ошибке программиста

---

### YAGNI (You Aren't Gonna Need It)

#### 1. Собственные утилиты вместо стандартных (НИЗКИЙ)
**Файл:** `sets_inventory.gleam:50-68`
- `int_max()` — есть `int.max()` в стандартной библиотеке
- `bool_to_int()` — можно заменить на `case`

#### 2. Дублирование float_to_int() (НИЗКИЙ)
Определена в двух местах:
- `items_view.gleam`
- `sets_view.gleam`

---

## Предложения по рефакторингу

### Высокий приоритет

#### 1. Создать `src/shared/storage.gleam`
Общий модуль для работы с localStorage:
```gleam
pub fn load_settings(key: String, decoder, encoder) -> Option(a)
pub fn save_settings(key: String, settings: a, decoder, encoder) -> Nil
```

#### 2. Разбить `sets_update.gleam` на подмодули
- `sets_update_goal.gleam` — SetGoalType, SelectFaction, SelectEntity, etc.
- `sets_update_inventory.gleam` — InventoryToggleSlot, InventorySetCount, etc.
- `sets_update_worker.gleam` — WorkerReady, ComputationResult, WorkerError

#### 3. Разбить `sets_view.gleam` на подмодули
- `sets_view_form.gleam` — форма ввода параметров
- `sets_view_results.gleam` — график и результаты
- `sets_view_inventory.gleam` — секция инвентаря

### Средний приоритет

#### 4. Создать `src/shared/converters.gleam`
```gleam
pub fn faction_to_string(f: Faction) -> String
pub fn string_to_faction(s: String) -> Faction
pub fn color_to_string(c: ItemColor) -> String
pub fn color_name(c: ItemColor) -> String  // локализованное
pub fn faction_name(f: Faction) -> String  // локализованное
```

#### 5. Создать `src/shared/view_helpers.gleam`
```gleam
pub fn active_class(is_active: Bool, base: String) -> String
pub fn button_group(buttons: List(ButtonConfig)) -> Element(Msg)
pub fn form_group(label: String, content: Element(Msg)) -> Element(Msg)
```

#### 6. Рефакторинг `bp_storage.save()`
```gleam
// Было: save(mode, level, progress, points, days, weekly, target)
// Стало:
pub fn save(settings: SavedSettings) -> Nil
```

### Низкий приоритет

#### 7. Создать `src/shared/format.gleam`
```gleam
pub fn format_number(n: Int) -> String  // с разделителями
pub fn format_percent(p: Float) -> String
pub fn float_round(f: Float, decimals: Int) -> String
```

#### 8. Использовать Result pipeline в `sets_uri.gleam`
```gleam
// Было: вложенные case на 4 уровня
// Стало:
use data <- result.try(parse_version(encoded))
use bytes <- result.try(bit_array.base64_url_decode(data))
use data_str <- result.try(bit_array.to_string(bytes))
use entries <- result.try(decode_sparse_entries(data_str))
Ok(restore_inventory_all(entries))
```

#### 9. Удалить `int_max()` и `bool_to_int()`
Использовать стандартные функции из `gleam/int`.

---

## Сводка по критичности

| # | Проблема | Принцип | Критичность | Файлы |
|---|----------|---------|-------------|-------|
| 1 | Дублирование storage | DRY | КРИТИЧНО | 3 файла *_storage.gleam |
| 2 | Гигантский update() | KISS | КРИТИЧНО | sets_update.gleam (335 строк) |
| 3 | Огромный view | KISS | ВЫСОКИЙ | sets_view.gleam (847 строк) |
| 4 | Дублирование конвертеров | DRY | ВЫСОКИЙ | 4 файла |
| 5 | save() с 7 параметрами | KISS | СРЕДНИЙ | bp_storage.gleam |
| 6 | Глубокая вложенность | KISS | СРЕДНИЙ | sets_uri.gleam |
| 7 | Active button логика | DRY | СРЕДНИЙ | все *_view.gleam |
| 8 | Дублирование форматтеров | DRY | НИЗКИЙ | items_view, sets_view |
| 9 | Собственные утилиты | YAGNI | НИЗКИЙ | sets_inventory.gleam |

---

## Ожидаемый результат рефакторинга

1. **Уменьшение дублирования** — ~300 строк удалённого повторяющегося кода
2. **Улучшение читаемости** — разбиение больших файлов на логические модули
3. **Упрощение поддержки** — изменения в одном месте вместо трёх
4. **Снижение risk of bugs** — единая точка истины для конвертеров и storage
