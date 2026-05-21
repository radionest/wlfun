import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import items_calculator/calculator_logic.{type CalculationResult, type LevelCost}
import items_calculator/game_data.{
  type ItemColor, type Unit, Blue, Dark, Green, Light, Purple,
}
import items_calculator/items_model.{
  type Model, type Msg, UserChangedCurrentLevel, UserChangedTargetLevel,
  UserSelectedColor, UserSelectedFaction, UserSelectedUnit,
}
import lustre/attribute.{class, selected, value}
import lustre/element.{type Element, text}
import lustre/element/html.{
  button, div, h1, h2, label, option, select, span, table, tbody, td, th, thead,
  tr,
}
import lustre/event.{on_change, on_click}

pub fn view(model: Model) -> Element(Msg) {
  div([class("items-calculator")], [
    h1([], [text("Калькулятор улучшения предметов")]),
    div([class("disclaimer")], [
      text(
        "Это неофициальный калькулятор. Он может содержать ошибки и неточности, особенно на 9 и 10 уровнях, так как пока что нет точных данных об их стоимости. Реальная стоимость апгрейда для этих уровней может отличаться в несколько раз как в большую так и в меньшую стороны. Если вы прокачали вещь до 8 или 9 уровней, поспамьте скринами в группу ВЛ в телеге.",
      ),
    ]),
    div([class("form-section")], [
      view_faction_select(model),
      view_unit_select(model),
      view_color_select(model),
      view_level_selects(model),
    ]),
    view_results(model),
  ])
}

/// Получить тему на основе фракции (для внешнего использования)
pub fn get_theme_class(model: Model) -> String {
  case model.selected_faction {
    Light -> "theme-light"
    Dark -> "theme-dark"
  }
}

/// Переключатель фракций
fn view_faction_select(model: Model) -> Element(Msg) {
  let light_class = case model.selected_faction {
    Light -> "faction-btn light active"
    Dark -> "faction-btn light"
  }
  let dark_class = case model.selected_faction {
    Light -> "faction-btn dark"
    Dark -> "faction-btn dark active"
  }

  div([class("form-group faction-select")], [
    label([], [text("Фракция:")]),
    div([class("faction-buttons")], [
      button([class(light_class), on_click(UserSelectedFaction("light"))], [
        text("Свет"),
      ]),
      button([class(dark_class), on_click(UserSelectedFaction("dark"))], [
        text("Тьма"),
      ]),
    ]),
  ])
}

/// Селект юнита
fn view_unit_select(model: Model) -> Element(Msg) {
  let units = game_data.units_by_faction(model.selected_faction)

  div([class("form-group")], [
    label([], [text("Юнит:")]),
    select(
      [on_change(UserSelectedUnit)],
      [option([value("")], "-- Выберите юнита --")]
        |> list.append(
          list.map(units, fn(u: Unit) {
            let is_selected = case model.selected_unit {
              Some(sel) -> sel.name == u.name
              None -> False
            }
            option(
              [value(u.name), selected(is_selected), class("unit-option")],
              u.name,
            )
          }),
        ),
    ),
  ])
}

/// Селект цвета/редкости
fn view_color_select(model: Model) -> Element(Msg) {
  div([class("form-group")], [
    label([], [text("Редкость предмета:")]),
    select([on_change(UserSelectedColor), class("color-select")], [
      option(
        [
          value("blue"),
          selected(model.selected_color == Blue),
          class("color-blue"),
        ],
        "Синий",
      ),
      option(
        [
          value("green"),
          selected(model.selected_color == Green),
          class("color-green"),
        ],
        "Зелёный",
      ),
      option(
        [
          value("purple"),
          selected(model.selected_color == Purple),
          class("color-purple"),
        ],
        "Фиолетовый",
      ),
    ]),
  ])
}

/// Селекты уровней
fn view_level_selects(model: Model) -> Element(Msg) {
  div([class("form-group level-selects")], [
    div([class("level-select")], [
      label([], [text("Текущий уровень:")]),
      select(
        [on_change(UserChangedCurrentLevel)],
        list.map(list.range(1, 9), fn(lvl) {
          option(
            [value(int.to_string(lvl)), selected(model.current_level == lvl)],
            int.to_string(lvl),
          )
        }),
      ),
    ]),
    span([class("arrow")], [text(" -> ")]),
    div([class("level-select")], [
      label([], [text("Целевой уровень:")]),
      select(
        [on_change(UserChangedTargetLevel)],
        list.map(list.range(2, 10), fn(lvl) {
          option(
            [value(int.to_string(lvl)), selected(model.target_level == lvl)],
            int.to_string(lvl),
          )
        }),
      ),
    ]),
  ])
}

/// Таблица результатов
fn view_results(model: Model) -> Element(Msg) {
  case model.result {
    None ->
      div([class("results-placeholder")], [
        text("Выберите юнита и уровни для расчёта"),
      ])
    Some(result) -> {
      div([class("results-section")], [
        h2([], [text("Стоимость улучшения")]),
        view_results_table(result),
        view_totals(result, model.selected_color),
        view_high_level_disclaimer(model),
      ])
    }
  }
}

fn view_results_table(result: CalculationResult) -> Element(Msg) {
  table([class("results-table")], [
    thead([], [
      tr([], [
        th([], [text("Уровень")]),
        th([], [text("Золото")]),
        th([], [text("Пыль")]),
      ]),
    ]),
    tbody(
      [],
      list.map(result.levels, fn(lc: LevelCost) {
        tr([], [
          td([], [text(int.to_string(lc.level))]),
          td([class("gold-cell")], [text(format_number(lc.gold))]),
          td([class("dust-cell")], [text(format_number(lc.dust))]),
        ])
      }),
    ),
  ])
}

fn view_totals(result: CalculationResult, _color: ItemColor) -> Element(Msg) {
  div([class("totals")], [
    div([class("total-item")], [
      span([class("total-label")], [text("Итого золото:")]),
      span([class("total-value gold")], [text(format_number(result.total_gold))]),
    ]),
    div([class("total-item")], [
      span([class("total-label")], [text("Итого пыль:")]),
      span([class("total-value dust")], [text(format_number(result.total_dust))]),
    ]),
  ])
}

fn view_high_level_disclaimer(model: Model) -> Element(Msg) {
  case model.target_level >= 9 {
    True ->
      div([class("disclaimer high-level-warning")], [
        text(
          "⚠️ Внимание: расчёт для 9 и 10 уровней может содержать значительную погрешность (в несколько раз в любую сторону), так как точные значения стоимости апгрейда на эти уровни пока не известны.",
        ),
      ])
    False -> text("")
  }
}

/// Форматирование числа с разделителями тысяч
pub fn format_number(n: Int) -> String {
  let str = int.to_string(n)
  format_with_separators(str, "")
}

fn format_with_separators(remaining: String, acc: String) -> String {
  let len = string.length(remaining)
  case len {
    0 -> acc
    1 | 2 | 3 -> remaining <> acc
    _ -> {
      let split_at = len - 3
      let left = string.slice(remaining, 0, split_at)
      let right = string.slice(remaining, split_at, 3)
      format_with_separators(left, " " <> right <> acc)
    }
  }
}
