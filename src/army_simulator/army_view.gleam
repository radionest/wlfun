import army_simulator/army_model.{
  type AggregatedResult, type ColorCurveResult, type ComparisonResult,
  type DropSystem, type EquipmentCurveResult, type EquipmentMilestone,
  type FinalStats, type Model, type Msg, type Profile, type SavedSimulation,
  type SystemResult, ChartMode, CloseInventorySettingsMenu,
  CloseInventoryStatsMenu, CloseProfileSaveDialog, CloseSaveDialog,
  CloseSettingsMenu, CopyShareLink, DeleteProfile, DeleteSimulation,
  EquipmentCurveMode, HideShareNotification, InventoryClearAll, InventoryFillAll,
  InventorySetFilterColor, InventorySetFilterFaction, InventoryToggleSlot,
  LoadProfile, NoDuplicates, OpenProfileSaveDialog, OpenSaveDialog,
  RunSimulation, SaveCurrentProfile, SaveCurrentSimulation, SelectFaction,
  SetBaseSimulation, SetBluePerMonth, SetChartDropSystem, SetGreenPerMonth,
  SetMonths, SetNumSimulations, SetProfileName, SetPurplePerMonth,
  SetSimulationName, SetViewMode, TableMode, ToggleComparisonPanel,
  ToggleInventoryPanel, ToggleInventorySettingsMenu, ToggleInventoryStatsMenu,
  TogglePercentiles, ToggleProfilesPanel, ToggleSettingsMenu,
  ToggleSimulationVisibility, WithDuplicates, max_profiles,
  max_saved_simulations,
}
import army_simulator/army_storage
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import items_calculator/game_data.{
  type Faction, type ItemColor, Blue, Dark, Green, Light, Purple,
}
import lustre/attribute.{
  checked, class, disabled, name, placeholder, selected, type_, value,
}
import lustre/element.{type Element, text}
import lustre/element/html.{
  button, div, h1, h2, h3, input, label, option, p, select, span, table, tbody,
  td, th, thead, tr,
}
import lustre/element/svg
import lustre/event.{on_check, on_click, on_input}
import sets_calculator/sets_game_data.{type SetId, SetId}
import sets_calculator/sets_inventory
import shared/inventory_view

pub fn view(model: Model) -> Element(Msg) {
  let wrapper_class = case
    model.inventory_panel_open,
    model.comparison_panel_open,
    model.profiles_panel_open
  {
    True, _, _ -> "army-simulator-wrapper inventory-open"
    _, True, _ -> "army-simulator-wrapper comparison-open"
    _, _, True -> "army-simulator-wrapper profiles-open"
    _, _, _ -> "army-simulator-wrapper"
  }

  div([class(wrapper_class)], [
    // Основной контент
    div([class("army-simulator")], [
      h1([class("calculator-title")], [text("Симуляция прокачки аккаунта")]),
      div([class("army-content")], [
        view_params_section(model),
        view_run_button(model),
        view_save_section(model),
        // Показываем ошибку если есть
        case model.error_message {
          Some(err) -> div([class("error-message")], [text(err)])
          None -> element.none()
        },
        case model.comparison_result {
          Some(result) -> view_results(model, result)
          None ->
            case model.is_computing {
              True -> view_progress(model.progress)
              False -> view_placeholder()
            }
        },
      ]),
    ]),
    // Вкладка "Мой инвентарь" справа
    view_inventory_tab(model),
    // Выдвижная панель инвентаря
    view_inventory_side_panel(model),
    // Панель сравнения симуляций
    view_comparison_panel(model),
    // Панель профилей слева
    view_profiles_panel(model),
    // Диалог сохранения симуляции
    view_save_dialog(model),
    // Диалог сохранения профиля
    view_profile_save_dialog(model),
  ])
}

fn view_params_section(model: Model) -> Element(Msg) {
  div([class("params-section")], [
    // Overlay для закрытия меню настроек
    case model.settings_menu_open {
      True -> div([class("settings-overlay"), on_click(CloseSettingsMenu)], [])
      False -> text("")
    },
    h2([class("section-title")], [text("Параметры симуляции")]),
    div([class("params-grid")], [
      view_faction_select(model),
      view_items_inputs(model),
      view_simulation_params(model),
    ]),
  ])
}

fn view_faction_select(model: Model) -> Element(Msg) {
  div([class("param-group")], [
    label([class("param-label")], [text("Фракция")]),
    select([class("param-select"), on_input(SelectFaction)], [
      option(
        [value("light"), selected(model.selected_faction == Light)],
        "Свет",
      ),
      option([value("dark"), selected(model.selected_faction == Dark)], "Тьма"),
    ]),
  ])
}

fn view_items_inputs(model: Model) -> Element(Msg) {
  div([class("items-inputs")], [
    div([class("param-group")], [
      label([class("param-label blue-label")], [text("Синие / месяц")]),
      input([
        class("param-input"),
        type_("number"),
        value(int.to_string(model.params.blue_per_month)),
        placeholder("20"),
        on_input(SetBluePerMonth),
      ]),
    ]),
    div([class("param-group")], [
      label([class("param-label green-label")], [text("Зелёные / месяц")]),
      input([
        class("param-input"),
        type_("number"),
        value(int.to_string(model.params.green_per_month)),
        placeholder("10"),
        on_input(SetGreenPerMonth),
      ]),
    ]),
    div([class("param-group")], [
      label([class("param-label purple-label")], [text("Фиолетовые / месяц")]),
      input([
        class("param-input"),
        type_("number"),
        value(int.to_string(model.params.purple_per_month)),
        placeholder("5"),
        on_input(SetPurplePerMonth),
      ]),
    ]),
  ])
}

fn view_simulation_params(model: Model) -> Element(Msg) {
  div([class("simulation-params")], [
    div([class("param-group")], [
      label([class("param-label")], [text("Период (месяцев)")]),
      input([
        class("param-input"),
        type_("number"),
        value(int.to_string(model.params.months)),
        placeholder("24"),
        on_input(SetMonths),
      ]),
    ]),
    // Кнопка шестеренки с меню расширенных настроек
    view_settings_button(model),
  ])
}

/// Кнопка настроек симуляции с выпадающим меню
fn view_settings_button(model: Model) -> Element(Msg) {
  div([class("simulation-settings-wrapper")], [
    button([class("simulation-settings-btn"), on_click(ToggleSettingsMenu)], [
      text("⚙"),
    ]),
    case model.settings_menu_open {
      True -> view_settings_menu(model)
      False -> text("")
    },
  ])
}

/// Выпадающее меню настроек симуляции
fn view_settings_menu(model: Model) -> Element(Msg) {
  div([class("chart-settings-menu")], [
    div([class("settings-menu-item")], [
      label([class("settings-label")], [text("Количество симуляций")]),
      input([
        class("settings-input"),
        type_("number"),
        value(int.to_string(model.params.num_simulations)),
        placeholder("1000"),
        on_input(SetNumSimulations),
      ]),
    ]),
  ])
}

fn view_run_button(model: Model) -> Element(Msg) {
  div([class("run-section")], [
    button(
      [
        class("btn btn-primary run-button"),
        on_click(RunSimulation),
        disabled(model.is_computing),
      ],
      [
        text(case model.is_computing {
          True -> "Вычисление..."
          False -> "Запустить симуляцию"
        }),
      ],
    ),
  ])
}

fn view_progress(progress: Float) -> Element(Msg) {
  let percent = float.round(progress *. 100.0) |> int.to_string
  div([class("progress-section")], [
    div([class("progress-bar-container")], [
      div(
        [
          class("progress-bar-fill"),
          attribute.attribute("style", "width: " <> percent <> "%"),
        ],
        [],
      ),
    ]),
    p([class("progress-text")], [text("Прогресс: " <> percent <> "%")]),
  ])
}

fn view_placeholder() -> Element(Msg) {
  div([class("placeholder-section")], [
    p([class("placeholder-text")], [
      text(
        "Настройте параметры и запустите симуляцию для сравнения двух систем выпадения предметов",
      ),
    ]),
  ])
}

fn view_results(model: Model, result: ComparisonResult) -> Element(Msg) {
  div([class("results-section")], [
    view_mode_tabs(model),
    case model.view_mode {
      ChartMode -> view_comparison_chart(result)
      TableMode -> view_comparison_table(result)
      EquipmentCurveMode -> view_equipment_curve(model)
    },
  ])
}

fn view_mode_tabs(model: Model) -> Element(Msg) {
  div([class("mode-tabs")], [
    button(
      [
        class(case model.view_mode {
          ChartMode -> "mode-tab active"
          _ -> "mode-tab"
        }),
        on_click(SetViewMode(ChartMode)),
      ],
      [text("График")],
    ),
    button(
      [
        class(case model.view_mode {
          TableMode -> "mode-tab active"
          _ -> "mode-tab"
        }),
        on_click(SetViewMode(TableMode)),
      ],
      [text("Таблица")],
    ),
    button(
      [
        class(case model.view_mode {
          EquipmentCurveMode -> "mode-tab active"
          _ -> "mode-tab"
        }),
        on_click(SetViewMode(EquipmentCurveMode)),
      ],
      [text("Кривая экипировки")],
    ),
  ])
}

fn view_comparison_chart(result: ComparisonResult) -> Element(Msg) {
  let system_a: SystemResult = result.system_a
  let system_b: SystemResult = result.system_b
  div([class("chart-container")], [
    render_svg_chart(system_a.progress_curve, system_b.progress_curve),
  ])
}

fn render_svg_chart(
  curve_a: List(AggregatedResult),
  curve_b: List(AggregatedResult),
) -> Element(Msg) {
  let width = 1100
  let height = 520
  let padding = 60
  let chart_width = width - padding * 2
  let chart_height = height - padding * 2 - 70
  // 70px для легенды внизу

  let max_month = case list.last(curve_a) {
    Ok(r) -> r.month
    Error(_) -> 24
  }

  // Ось Y: 0-18 юнитов
  let max_y = 18.0

  let x_scale = fn(month: Int) -> Int {
    padding + month * chart_width / max_month
  }

  let y_scale = fn(val: Float) -> Int {
    padding
    + chart_height
    - float.round(val /. max_y *. int.to_float(chart_height))
  }

  // 6 путей для линий
  let path_a_blue =
    build_path_for_field(curve_a, x_scale, y_scale, fn(r) { r.mean_blue_sets })
  let path_a_green =
    build_path_for_field(curve_a, x_scale, y_scale, fn(r) { r.mean_green_sets })
  let path_a_purple =
    build_path_for_field(curve_a, x_scale, y_scale, fn(r) { r.mean_purple_sets })
  let path_b_blue =
    build_path_for_field(curve_b, x_scale, y_scale, fn(r) { r.mean_blue_sets })
  let path_b_green =
    build_path_for_field(curve_b, x_scale, y_scale, fn(r) { r.mean_green_sets })
  let path_b_purple =
    build_path_for_field(curve_b, x_scale, y_scale, fn(r) { r.mean_purple_sets })

  svg.svg(
    [
      attribute.attribute(
        "viewBox",
        "0 0 " <> int.to_string(width) <> " " <> int.to_string(height),
      ),
      class("comparison-chart"),
    ],
    [
      render_grid_units(padding, chart_width, chart_height),
      render_axes_units(padding, chart_width, chart_height, max_month),
      // Система A - сплошные линии
      svg.path([
        attribute.attribute("d", path_a_blue),
        attribute.attribute("stroke", "#3b82f6"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", path_a_green),
        attribute.attribute("stroke", "#22c55e"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", path_a_purple),
        attribute.attribute("stroke", "#a855f7"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("fill", "none"),
      ]),
      // Система B - пунктирные линии
      svg.path([
        attribute.attribute("d", path_b_blue),
        attribute.attribute("stroke", "#3b82f6"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-dasharray", "8,4"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", path_b_green),
        attribute.attribute("stroke", "#22c55e"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-dasharray", "8,4"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", path_b_purple),
        attribute.attribute("stroke", "#a855f7"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-dasharray", "8,4"),
        attribute.attribute("fill", "none"),
      ]),
      render_legend_6_lines(width, padding, chart_height),
    ],
  )
}

fn build_path_for_field(
  curve: List(AggregatedResult),
  x_scale: fn(Int) -> Int,
  y_scale: fn(Float) -> Int,
  get_value: fn(AggregatedResult) -> Float,
) -> String {
  curve
  |> list.index_map(fn(r, i) {
    let x = x_scale(r.month)
    let y = y_scale(get_value(r))
    case i {
      0 -> "M " <> int.to_string(x) <> " " <> int.to_string(y)
      _ -> " L " <> int.to_string(x) <> " " <> int.to_string(y)
    }
  })
  |> list.fold("", fn(acc, s) { acc <> s })
}

fn render_grid_units(
  padding: Int,
  chart_width: Int,
  chart_height: Int,
) -> Element(Msg) {
  // 6 горизонтальных линий: 0, 3, 6, 9, 12, 15, 18
  let h_lines =
    [0, 3, 6, 9, 12, 15, 18]
    |> list.map(fn(val) {
      let y = padding + chart_height - val * chart_height / 18
      svg.line([
        attribute.attribute("x1", int.to_string(padding)),
        attribute.attribute("y1", int.to_string(y)),
        attribute.attribute("x2", int.to_string(padding + chart_width)),
        attribute.attribute("y2", int.to_string(y)),
        attribute.attribute("stroke", "#e5e7eb"),
        attribute.attribute("stroke-dasharray", "4"),
      ])
    })

  svg.g([class("grid")], h_lines)
}

fn render_axes_units(
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_month: Int,
) -> Element(Msg) {
  // Y-ось: 0, 3, 6, 9, 12, 15, 18 юнитов
  let y_labels =
    [0, 3, 6, 9, 12, 15, 18]
    |> list.map(fn(val) {
      let y = padding + chart_height - val * chart_height / 18
      svg.text(
        [
          attribute.attribute("x", int.to_string(padding - 10)),
          attribute.attribute("y", int.to_string(y + 4)),
          attribute.attribute("text-anchor", "end"),
          class("axis-label"),
        ],
        int.to_string(val),
      )
    })

  // X-ось: месяцы
  let x_labels =
    [0, 6, 12, 18, 24]
    |> list.filter(fn(m) { m <= max_month })
    |> list.map(fn(m) {
      let x = padding + m * chart_width / max_month
      svg.text(
        [
          attribute.attribute("x", int.to_string(x)),
          attribute.attribute("y", int.to_string(padding + chart_height + 20)),
          attribute.attribute("text-anchor", "middle"),
          class("axis-label"),
        ],
        int.to_string(m) <> " мес",
      )
    })

  svg.g([class("axes")], list.append(y_labels, x_labels))
}

fn render_legend_6_lines(
  width: Int,
  padding: Int,
  chart_height: Int,
) -> Element(Msg) {
  // Легенда внизу по центру, в 2 строки
  let base_y = padding + chart_height + 25
  let center_x = width / 2
  let item_width = 120
  // ширина одного элемента легенды
  let row_height = 22

  svg.g([class("legend")], [
    // Первая строка: "С дубликатами" + 3 цвета
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x - item_width * 2)),
        attribute.attribute("y", int.to_string(base_y)),
        class("legend-header"),
      ],
      "С дубликатами:",
    ),
    // Синие - сплошная
    svg.line([
      attribute.attribute("x1", int.to_string(center_x - item_width)),
      attribute.attribute("y1", int.to_string(base_y - 4)),
      attribute.attribute("x2", int.to_string(center_x - item_width + 25)),
      attribute.attribute("y2", int.to_string(base_y - 4)),
      attribute.attribute("stroke", "#3b82f6"),
      attribute.attribute("stroke-width", "3"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x - item_width + 30)),
        attribute.attribute("y", int.to_string(base_y)),
        class("legend-text"),
      ],
      "Синие",
    ),
    // Зелёные - сплошная
    svg.line([
      attribute.attribute("x1", int.to_string(center_x)),
      attribute.attribute("y1", int.to_string(base_y - 4)),
      attribute.attribute("x2", int.to_string(center_x + 25)),
      attribute.attribute("y2", int.to_string(base_y - 4)),
      attribute.attribute("stroke", "#22c55e"),
      attribute.attribute("stroke-width", "3"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x + 30)),
        attribute.attribute("y", int.to_string(base_y)),
        class("legend-text"),
      ],
      "Зелёные",
    ),
    // Фиолетовые - сплошная
    svg.line([
      attribute.attribute("x1", int.to_string(center_x + item_width)),
      attribute.attribute("y1", int.to_string(base_y - 4)),
      attribute.attribute("x2", int.to_string(center_x + item_width + 25)),
      attribute.attribute("y2", int.to_string(base_y - 4)),
      attribute.attribute("stroke", "#a855f7"),
      attribute.attribute("stroke-width", "3"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x + item_width + 30)),
        attribute.attribute("y", int.to_string(base_y)),
        class("legend-text"),
      ],
      "Фиолетовые",
    ),
    // Вторая строка: "Без дубликатов" + 3 цвета (пунктир)
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x - item_width * 2)),
        attribute.attribute("y", int.to_string(base_y + row_height)),
        class("legend-header"),
      ],
      "Без дубликатов:",
    ),
    // Синие - пунктир
    svg.line([
      attribute.attribute("x1", int.to_string(center_x - item_width)),
      attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
      attribute.attribute("x2", int.to_string(center_x - item_width + 25)),
      attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
      attribute.attribute("stroke", "#3b82f6"),
      attribute.attribute("stroke-width", "3"),
      attribute.attribute("stroke-dasharray", "8,4"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x - item_width + 30)),
        attribute.attribute("y", int.to_string(base_y + row_height)),
        class("legend-text"),
      ],
      "Синие",
    ),
    // Зелёные - пунктир
    svg.line([
      attribute.attribute("x1", int.to_string(center_x)),
      attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
      attribute.attribute("x2", int.to_string(center_x + 25)),
      attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
      attribute.attribute("stroke", "#22c55e"),
      attribute.attribute("stroke-width", "3"),
      attribute.attribute("stroke-dasharray", "8,4"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x + 30)),
        attribute.attribute("y", int.to_string(base_y + row_height)),
        class("legend-text"),
      ],
      "Зелёные",
    ),
    // Фиолетовые - пунктир
    svg.line([
      attribute.attribute("x1", int.to_string(center_x + item_width)),
      attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
      attribute.attribute("x2", int.to_string(center_x + item_width + 25)),
      attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
      attribute.attribute("stroke", "#a855f7"),
      attribute.attribute("stroke-width", "3"),
      attribute.attribute("stroke-dasharray", "8,4"),
    ]),
    svg.text(
      [
        attribute.attribute("x", int.to_string(center_x + item_width + 30)),
        attribute.attribute("y", int.to_string(base_y + row_height)),
        class("legend-text"),
      ],
      "Фиолетовые",
    ),
  ])
}

fn view_comparison_table(result: ComparisonResult) -> Element(Msg) {
  let stats_a: FinalStats = result.system_a.final_stats
  let stats_b: FinalStats = result.system_b.final_stats

  table([class("comparison-table")], [
    thead([], [
      tr([], [
        th([], [text("Метрика")]),
        th([class("system-a-header")], [text("С дубликатами")]),
        th([class("system-b-header")], [text("Без дубликатов")]),
        th([], [text("Разница")]),
      ]),
    ]),
    tbody([], [
      view_stats_row(
        "Ср. синих сетов",
        stats_a.avg_blue_sets,
        stats_b.avg_blue_sets,
      ),
      view_stats_row(
        "Ср. зелёных сетов",
        stats_a.avg_green_sets,
        stats_b.avg_green_sets,
      ),
      view_stats_row(
        "Ср. фиолетовых сетов",
        stats_a.avg_purple_sets,
        stats_b.avg_purple_sets,
      ),
      view_stats_row(
        "Ср. всего предметов",
        stats_a.avg_total_items,
        stats_b.avg_total_items,
      ),
    ]),
  ])
}

fn view_stats_row(
  label_text: String,
  val_a: Float,
  val_b: Float,
) -> Element(Msg) {
  let diff = val_b -. val_a
  let diff_class = case diff >. 0.0 {
    True -> "positive"
    False ->
      case diff <. 0.0 {
        True -> "negative"
        False -> "neutral"
      }
  }

  tr([], [
    td([], [text(label_text)]),
    td([], [text(format_float(val_a, 1))]),
    td([], [text(format_float(val_b, 1))]),
    td([class(diff_class)], [text(format_diff(diff))]),
  ])
}

// ============================================================================
// Кривая экипировки
// ============================================================================

fn view_equipment_curve(model: Model) -> Element(Msg) {
  case model.equipment_curve_result {
    None ->
      div([class("placeholder-section")], [
        p([class("placeholder-text")], [
          text("Данные кривой экипировки недоступны"),
        ]),
      ])
    Some(eq) ->
      div([class("equipment-curve-section")], [
        // Чекбокс перцентилей
        div([class("percentile-toggle")], [
          label([], [
            input([
              type_("checkbox"),
              checked(model.show_percentiles),
              on_check(fn(_) { TogglePercentiles }),
            ]),
            text(" Показать перцентили (p90, p95)"),
          ]),
        ]),
        // SVG chart
        render_equipment_curve_chart(eq, model.show_percentiles),
      ])
  }
}

fn render_equipment_curve_chart(
  eq: EquipmentCurveResult,
  show_percentiles: Bool,
) -> Element(Msg) {
  let width = 1100
  let height = 600
  let padding = 60
  let chart_width = width - padding * 2
  let chart_height = height - padding * 2 - 90
  // 90px для легенды

  // Находим максимальное значение Y (сундуков) по обеим системам
  let max_chests = find_max_chests(eq, show_percentiles)
  // Округляем вверх до красивого числа
  let max_y = round_up_nice(max_chests)

  // Use the average of initial equipped across colors as starting X
  let initial_equipped =
    {
      eq.initial_equipped.blue_sets
      + eq.initial_equipped.green_sets
      + eq.initial_equipped.purple_sets
    }
    / 3

  let x_scale = fn(units: Int) -> Int { padding + units * chart_width / 18 }

  let y_scale = fn(val: Float) -> Int {
    case max_y >. 0.0 {
      True ->
        padding
        + chart_height
        - float.round(val /. max_y *. int.to_float(chart_height))
      False -> padding + chart_height
    }
  }

  let color = "#6366f1"
  // indigo

  // Build paths for 2 systems
  let sys_a_mean =
    build_eq_path(
      eq.system_a.milestones,
      initial_equipped,
      x_scale,
      y_scale,
      fn(m: EquipmentMilestone) { m.mean },
    )
  let sys_b_mean =
    build_eq_path(
      eq.system_b.milestones,
      initial_equipped,
      x_scale,
      y_scale,
      fn(m: EquipmentMilestone) { m.mean },
    )

  let mean_paths = [
    // System A (solid) - mean
    svg.path([
      attribute.attribute("d", sys_a_mean),
      attribute.attribute("stroke", color),
      attribute.attribute("stroke-width", "3"),
      attribute.attribute("fill", "none"),
    ]),
    // System B (dashed) - mean
    svg.path([
      attribute.attribute("d", sys_b_mean),
      attribute.attribute("stroke", color),
      attribute.attribute("stroke-width", "3"),
      attribute.attribute("stroke-dasharray", "8,4"),
      attribute.attribute("fill", "none"),
    ]),
  ]

  let percentile_paths = case show_percentiles {
    False -> []
    True -> {
      let sys_a_p90 =
        build_eq_path(
          eq.system_a.milestones,
          initial_equipped,
          x_scale,
          y_scale,
          fn(m: EquipmentMilestone) { m.p90 },
        )
      let sys_b_p90 =
        build_eq_path(
          eq.system_b.milestones,
          initial_equipped,
          x_scale,
          y_scale,
          fn(m: EquipmentMilestone) { m.p90 },
        )
      let sys_a_p95 =
        build_eq_path(
          eq.system_a.milestones,
          initial_equipped,
          x_scale,
          y_scale,
          fn(m: EquipmentMilestone) { m.p95 },
        )
      let sys_b_p95 =
        build_eq_path(
          eq.system_b.milestones,
          initial_equipped,
          x_scale,
          y_scale,
          fn(m: EquipmentMilestone) { m.p95 },
        )
      [
        // System A p90
        svg.path([
          attribute.attribute("d", sys_a_p90),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1.5"),
          attribute.attribute("opacity", "0.6"),
          attribute.attribute("fill", "none"),
        ]),
        // System B p90
        svg.path([
          attribute.attribute("d", sys_b_p90),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1.5"),
          attribute.attribute("stroke-dasharray", "8,4"),
          attribute.attribute("opacity", "0.6"),
          attribute.attribute("fill", "none"),
        ]),
        // System A p95
        svg.path([
          attribute.attribute("d", sys_a_p95),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1"),
          attribute.attribute("opacity", "0.4"),
          attribute.attribute("fill", "none"),
        ]),
        // System B p95
        svg.path([
          attribute.attribute("d", sys_b_p95),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1"),
          attribute.attribute("stroke-dasharray", "8,4"),
          attribute.attribute("opacity", "0.4"),
          attribute.attribute("fill", "none"),
        ]),
      ]
    }
  }

  svg.svg(
    [
      attribute.attribute(
        "viewBox",
        "0 0 " <> int.to_string(width) <> " " <> int.to_string(height),
      ),
      class("equipment-curve-chart"),
    ],
    list.flatten([
      [render_eq_grid(padding, chart_width, chart_height, max_y)],
      [render_eq_axes(padding, chart_width, chart_height, max_y)],
      mean_paths,
      percentile_paths,
      [render_eq_legend(width, padding, chart_height, show_percentiles)],
    ]),
  )
}

fn find_max_chests(eq: EquipmentCurveResult, show_percentiles: Bool) -> Float {
  let max_a = get_max_from_milestones(eq.system_a, show_percentiles)
  let max_b = get_max_from_milestones(eq.system_b, show_percentiles)
  float.max(max_a, max_b)
}

fn get_max_from_milestones(
  result: ColorCurveResult,
  show_percentiles: Bool,
) -> Float {
  list.fold(result.milestones, 0.0, fn(acc, m: EquipmentMilestone) {
    let val = case show_percentiles {
      True -> float.max(m.mean, float.max(m.p90, m.p95))
      False -> m.mean
    }
    float.max(acc, val)
  })
}

fn round_up_nice(val: Float) -> Float {
  case val <=. 0.0 {
    True -> 100.0
    False -> {
      // Округляем до ближайшего "красивого" числа вверх
      let magnitude = float.truncate(log10(val))
      let base = power(10.0, int.to_float(magnitude))
      let normalized = val /. base
      let nice = case normalized <=. 1.0 {
        True -> 1.0
        False ->
          case normalized <=. 2.0 {
            True -> 2.0
            False ->
              case normalized <=. 5.0 {
                True -> 5.0
                False -> 10.0
              }
          }
      }
      nice *. base
    }
  }
}

@external(javascript, "../math_ffi.mjs", "log10")
fn log10(x: Float) -> Float

@external(javascript, "../math_ffi.mjs", "power")
fn power(base: Float, exp: Float) -> Float

/// Build SVG path string from milestones, starting from initial_equipped point at Y=0
fn build_eq_path(
  milestones: List(EquipmentMilestone),
  initial_equipped: Int,
  x_scale: fn(Int) -> Int,
  y_scale: fn(Float) -> Int,
  get_value: fn(EquipmentMilestone) -> Float,
) -> String {
  // Start point at (initial_equipped, 0)
  let start =
    "M "
    <> int.to_string(x_scale(initial_equipped))
    <> " "
    <> int.to_string(y_scale(0.0))

  milestones
  |> list.fold(start, fn(acc, m) {
    let x = x_scale(m.units)
    let y = y_scale(get_value(m))
    acc <> " L " <> int.to_string(x) <> " " <> int.to_string(y)
  })
}

fn render_eq_grid(
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_y: Float,
) -> Element(Msg) {
  // Vertical grid lines every 3 units (0, 3, 6, 9, 12, 15, 18)
  let v_lines =
    [0, 3, 6, 9, 12, 15, 18]
    |> list.map(fn(units) {
      let x = padding + units * chart_width / 18
      svg.line([
        attribute.attribute("x1", int.to_string(x)),
        attribute.attribute("y1", int.to_string(padding)),
        attribute.attribute("x2", int.to_string(x)),
        attribute.attribute("y2", int.to_string(padding + chart_height)),
        attribute.attribute("stroke", "#e5e7eb"),
        attribute.attribute("stroke-dasharray", "4"),
      ])
    })

  // Horizontal grid lines: ~5 lines
  let y_step = max_y /. 5.0
  let h_lines =
    [1, 2, 3, 4, 5]
    |> list.map(fn(i) {
      let val = int.to_float(i) *. y_step
      let y =
        padding
        + chart_height
        - float.round(val /. max_y *. int.to_float(chart_height))
      svg.line([
        attribute.attribute("x1", int.to_string(padding)),
        attribute.attribute("y1", int.to_string(y)),
        attribute.attribute("x2", int.to_string(padding + chart_width)),
        attribute.attribute("y2", int.to_string(y)),
        attribute.attribute("stroke", "#e5e7eb"),
        attribute.attribute("stroke-dasharray", "4"),
      ])
    })

  svg.g([class("grid")], list.append(v_lines, h_lines))
}

fn render_eq_axes(
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_y: Float,
) -> Element(Msg) {
  // X axis: 0, 3, 6, 9, 12, 15, 18
  let x_labels =
    [0, 3, 6, 9, 12, 15, 18]
    |> list.map(fn(units) {
      let x = padding + units * chart_width / 18
      svg.text(
        [
          attribute.attribute("x", int.to_string(x)),
          attribute.attribute("y", int.to_string(padding + chart_height + 20)),
          attribute.attribute("text-anchor", "middle"),
          class("axis-label"),
        ],
        int.to_string(units),
      )
    })

  // X axis title
  let x_title =
    svg.text(
      [
        attribute.attribute("x", int.to_string(padding + chart_width / 2)),
        attribute.attribute("y", int.to_string(padding + chart_height + 40)),
        attribute.attribute("text-anchor", "middle"),
        class("axis-label"),
      ],
      "Юниты с полным сетом",
    )

  // Y axis labels
  let y_step = max_y /. 5.0
  let y_labels =
    [0, 1, 2, 3, 4, 5]
    |> list.map(fn(i) {
      let val = int.to_float(i) *. y_step
      let y =
        padding
        + chart_height
        - float.round(val /. max_y *. int.to_float(chart_height))
      svg.text(
        [
          attribute.attribute("x", int.to_string(padding - 10)),
          attribute.attribute("y", int.to_string(y + 4)),
          attribute.attribute("text-anchor", "end"),
          class("axis-label"),
        ],
        int.to_string(float.round(val)),
      )
    })

  // Y axis title
  let y_title =
    svg.text(
      [
        attribute.attribute("x", int.to_string(15)),
        attribute.attribute("y", int.to_string(padding + chart_height / 2)),
        attribute.attribute("text-anchor", "middle"),
        attribute.attribute(
          "transform",
          "rotate(-90, 15, " <> int.to_string(padding + chart_height / 2) <> ")",
        ),
        class("axis-label"),
      ],
      "Сундуки",
    )

  svg.g(
    [class("axes")],
    list.flatten([x_labels, [x_title], y_labels, [y_title]]),
  )
}

fn render_eq_legend(
  width: Int,
  padding: Int,
  chart_height: Int,
  show_percentiles: Bool,
) -> Element(Msg) {
  let base_y = padding + chart_height + 50
  let center_x = width / 2
  let col_width = 140
  let row_height = 18
  let color = "#6366f1"

  // Row 1: Systems (solid vs dashed)
  let systems_row =
    svg.g([], [
      // С дубликатами - сплошная
      svg.line([
        attribute.attribute("x1", int.to_string(center_x - col_width)),
        attribute.attribute("y1", int.to_string(base_y - 4)),
        attribute.attribute("x2", int.to_string(center_x - col_width + 25)),
        attribute.attribute("y2", int.to_string(base_y - 4)),
        attribute.attribute("stroke", color),
        attribute.attribute("stroke-width", "3"),
      ]),
      svg.text(
        [
          attribute.attribute("x", int.to_string(center_x - col_width + 30)),
          attribute.attribute("y", int.to_string(base_y)),
          class("legend-text"),
        ],
        "С дубликатами",
      ),
      // Без дубликатов - пунктир
      svg.line([
        attribute.attribute("x1", int.to_string(center_x + 20)),
        attribute.attribute("y1", int.to_string(base_y - 4)),
        attribute.attribute("x2", int.to_string(center_x + 45)),
        attribute.attribute("y2", int.to_string(base_y - 4)),
        attribute.attribute("stroke", color),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-dasharray", "8,4"),
      ]),
      svg.text(
        [
          attribute.attribute("x", int.to_string(center_x + 50)),
          attribute.attribute("y", int.to_string(base_y)),
          class("legend-text"),
        ],
        "Без дубликатов",
      ),
    ])

  // Row 2: Percentile line widths (only if percentiles shown)
  let percentile_row = case show_percentiles {
    False -> svg.g([], [])
    True ->
      svg.g([], [
        // Mean - thick
        svg.line([
          attribute.attribute("x1", int.to_string(center_x - col_width - 30)),
          attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
          attribute.attribute("x2", int.to_string(center_x - col_width - 5)),
          attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "3"),
        ]),
        svg.text(
          [
            attribute.attribute("x", int.to_string(center_x - col_width)),
            attribute.attribute("y", int.to_string(base_y + row_height)),
            class("legend-text"),
          ],
          "Среднее",
        ),
        // p90 - medium
        svg.line([
          attribute.attribute("x1", int.to_string(center_x - 20)),
          attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
          attribute.attribute("x2", int.to_string(center_x + 5)),
          attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1.5"),
          attribute.attribute("opacity", "0.6"),
        ]),
        svg.text(
          [
            attribute.attribute("x", int.to_string(center_x + 10)),
            attribute.attribute("y", int.to_string(base_y + row_height)),
            class("legend-text"),
          ],
          "p90",
        ),
        // p95 - thin
        svg.line([
          attribute.attribute("x1", int.to_string(center_x + 60)),
          attribute.attribute("y1", int.to_string(base_y + row_height - 4)),
          attribute.attribute("x2", int.to_string(center_x + 85)),
          attribute.attribute("y2", int.to_string(base_y + row_height - 4)),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "1"),
          attribute.attribute("opacity", "0.4"),
        ]),
        svg.text(
          [
            attribute.attribute("x", int.to_string(center_x + 90)),
            attribute.attribute("y", int.to_string(base_y + row_height)),
            class("legend-text"),
          ],
          "p95",
        ),
      ])
  }

  svg.g([class("legend")], [systems_row, percentile_row])
}

fn format_float(val: Float, decimals: Int) -> String {
  let multiplier = case decimals {
    1 -> 10.0
    2 -> 100.0
    _ -> 1.0
  }
  let rounded = float.round(val *. multiplier) |> int.to_float
  let result = rounded /. multiplier
  float.to_string(result)
}

fn format_diff(val: Float) -> String {
  let sign = case val >. 0.0 {
    True -> "+"
    False -> ""
  }
  sign <> format_float(val, 1)
}

// ============================================================================
// Инвентарь
// ============================================================================

fn view_inventory_tab(model: Model) -> Element(Msg) {
  let tab_class = case model.inventory_panel_open {
    True -> "inventory-side-tab hidden"
    False -> "inventory-side-tab"
  }

  button([class(tab_class), on_click(ToggleInventoryPanel)], [
    text("Мой инвентарь"),
  ])
}

fn view_inventory_side_panel(model: Model) -> Element(Msg) {
  let panel_class = case model.inventory_panel_open {
    True -> "side-panel side-panel--right inventory-side-panel open"
    False -> "side-panel side-panel--right inventory-side-panel"
  }

  div([class(panel_class)], [
    view_inv_panel_header(),
    // Дисклеймер
    div([class("panel-disclaimer")], [
      text("Заполните инвентарь для индивидуального расчёта"),
    ]),
    view_inventory_panel_content(model),
  ])
}

fn view_inventory_panel_content(model: Model) -> Element(Msg) {
  div([class("inventory-panel-content")], [
    // Overlay для закрытия меню настроек
    case model.inventory_settings_menu_open {
      True ->
        div(
          [class("settings-overlay"), on_click(CloseInventorySettingsMenu)],
          [],
        )
      False -> text("")
    },
    // Кнопка "Поделиться"
    div([class("panel-share-row")], [
      button([class("share-btn"), on_click(CopyShareLink)], [text("Поделиться")]),
    ]),
    // Уведомление о копировании
    view_share_notification(model),
    // Фильтры
    view_inventory_filters(model),
    // Таблица
    view_inventory_table(model),
  ])
}

fn view_share_notification(model: Model) -> Element(Msg) {
  case model.share_notification {
    Some(msg) ->
      div([class("share-notification"), on_click(HideShareNotification)], [
        text(msg),
        span([class("close-btn")], [text(" ×")]),
      ])
    None -> text("")
  }
}

fn view_inv_panel_header() -> Element(Msg) {
  div([class("panel-header")], [
    h2([], [text("Мой инвентарь")]),
    button([class("panel-close-btn"), on_click(ToggleInventoryPanel)], [
      text("x"),
    ]),
  ])
}

fn view_inventory_filters(model: Model) -> Element(Msg) {
  let stats = sets_inventory.get_stats(model.inventory)

  div([class("inventory-filters")], [
    // Overlay для закрытия меню статистики
    case model.inventory_stats_menu_open {
      True ->
        div([class("settings-overlay"), on_click(CloseInventoryStatsMenu)], [])
      False -> text("")
    },
    // Фильтр по фракции (селект) - с опцией "Все"
    div([class("filter-group")], [
      label([], [text("Фракция:")]),
      select(
        [
          class("filter-select"),
          on_input(fn(s) {
            InventorySetFilterFaction(inventory_view.parse_faction_filter(s))
          }),
        ],
        [
          option(
            [value("all"), selected(model.inventory_filter_faction == None)],
            "Все",
          ),
          option(
            [
              value("light"),
              selected(model.inventory_filter_faction == Some(Light)),
            ],
            "Свет",
          ),
          option(
            [
              value("dark"),
              selected(model.inventory_filter_faction == Some(Dark)),
            ],
            "Тьма",
          ),
        ],
      ),
    ]),
    // Фильтр по редкости
    div([class("filter-group")], [
      label([], [text("Редкость:")]),
      select(
        [
          class("filter-select"),
          on_input(fn(s) {
            InventorySetFilterColor(inventory_view.parse_color_filter(s))
          }),
        ],
        [
          option(
            [value("all"), selected(model.inventory_filter_color == None)],
            "Все",
          ),
          option(
            [
              value("blue"),
              selected(model.inventory_filter_color == Some(Blue)),
            ],
            "Синий",
          ),
          option(
            [
              value("green"),
              selected(model.inventory_filter_color == Some(Green)),
            ],
            "Зелёный",
          ),
          option(
            [
              value("purple"),
              selected(model.inventory_filter_color == Some(Purple)),
            ],
            "Фиолетовый",
          ),
        ],
      ),
    ]),
    // Статистика + настройки
    div([class("filter-group inventory-stats")], [
      view_inventory_stats_button(model, stats),
      view_inventory_settings_button(model),
    ]),
  ])
}

/// Кнопка настроек инвентаря с выпадающим меню
fn view_inventory_settings_button(model: Model) -> Element(Msg) {
  div([class("inventory-settings-wrapper")], [
    button(
      [class("inventory-settings-btn"), on_click(ToggleInventorySettingsMenu)],
      [text("⚙")],
    ),
    case model.inventory_settings_menu_open {
      True ->
        div([class("chart-settings-menu")], [
          button([class("settings-menu-btn"), on_click(InventoryFillAll)], [
            text("Добавить все"),
          ]),
          button([class("settings-menu-btn"), on_click(InventoryClearAll)], [
            text("Убрать все"),
          ]),
        ])
      False -> text("")
    },
  ])
}

/// Кнопка статистики с выпадающим меню
fn view_inventory_stats_button(
  model: Model,
  stats: sets_inventory.InventoryStats,
) -> Element(Msg) {
  div([class("inventory-stats-wrapper")], [
    button([class("inventory-stats-btn"), on_click(ToggleInventoryStatsMenu)], [
      span([class("help-icon")], [text("?")]),
      text(" " <> int.to_string(stats.total)),
    ]),
    case model.inventory_stats_menu_open {
      True -> inventory_view.view_inventory_stats_menu(stats)
      False -> text("")
    },
  ])
}

fn view_inventory_table(model: Model) -> Element(Msg) {
  // Фильтруем по фильтру фракции и редкости
  // При None показываем все фракции
  let all_sets = sets_game_data.generate_all_set_ids()
  let filtered_sets =
    sets_game_data.filter_sets(
      all_sets,
      model.inventory_filter_faction,
      model.inventory_filter_color,
    )

  div([class("inventory-table-container")], [
    // Заголовок
    div([class("inventory-row header")], [
      div([class("col-entity")], [text("Юнит/Герой")]),
      div([class("col-color")], [text("Редк.")]),
      div([class("col-set")], [text("Сет")]),
      div([class("col-slots")], [text("Слоты")]),
      div([class("col-progress")], [text("Прогр.")]),
    ]),
    // Строки данных
    div(
      [class("inventory-rows")],
      list.map(filtered_sets, fn(set_id) { view_inventory_row(model, set_id) }),
    ),
  ])
}

fn view_inventory_row(model: Model, set_id: SetId) -> Element(Msg) {
  let slots = sets_inventory.get_slots(model.inventory, set_id)
  let SetId(name, entity_type, color, set_num) = set_id
  let owned_count = sets_inventory.count_owned(slots)
  let needed = sets_game_data.items_needed(entity_type)
  let is_complete = owned_count >= needed

  let row_class = case is_complete {
    True -> "inventory-row complete"
    False -> "inventory-row"
  }

  div([class(row_class)], [
    div([class("col-entity")], [text(name)]),
    div([class("col-color " <> inventory_view.color_class(color))], [
      text(inventory_view.color_short(color)),
    ]),
    div([class("col-set")], [text(int.to_string(set_num))]),
    div([class("col-slots")], [
      view_slot_checkbox(set_id, 1, slots.slot1),
      view_slot_checkbox(set_id, 2, slots.slot2),
      view_slot_checkbox(set_id, 3, slots.slot3),
      view_slot_checkbox(set_id, 4, slots.slot4),
    ]),
    div([class("col-progress")], [
      text(int.to_string(owned_count) <> "/" <> int.to_string(needed)),
    ]),
  ])
}

fn view_slot_checkbox(
  set_id: SetId,
  slot: Int,
  is_checked: Bool,
) -> Element(Msg) {
  input([
    type_("checkbox"),
    checked(is_checked),
    on_check(fn(_) { InventoryToggleSlot(set_id, slot) }),
  ])
}

// ============================================================================
// Сохранение и сравнение симуляций
// ============================================================================

fn view_save_section(model: Model) -> Element(Msg) {
  case model.comparison_result {
    Some(_) -> {
      let sims_count = list.length(model.comparison_state.saved_simulations)
      let is_full = sims_count >= max_saved_simulations

      div([class("save-section")], [
        button(
          [
            class("btn btn-success save-button"),
            on_click(OpenSaveDialog),
            disabled(is_full),
          ],
          [
            text(case is_full {
              True -> "Лимит (" <> int.to_string(max_saved_simulations) <> ")"
              False -> "Сохранить результат"
            }),
          ],
        ),
        case sims_count > 0 {
          True ->
            button(
              [
                class("btn btn-primary compare-toggle-btn"),
                on_click(ToggleComparisonPanel),
              ],
              [text("Сравнить (" <> int.to_string(sims_count) <> ")")],
            )
          False -> element.none()
        },
      ])
    }
    None -> element.none()
  }
}

fn view_save_dialog(model: Model) -> Element(Msg) {
  case model.save_dialog_open {
    False -> element.none()
    True ->
      div([class("modal-overlay")], [
        div([class("modal-dialog save-dialog")], [
          h2([], [text("Сохранить симуляцию")]),
          div([class("dialog-content")], [
            div([class("form-group")], [
              label([], [text("Название:")]),
              input([
                type_("text"),
                value(model.pending_simulation_name),
                on_input(SetSimulationName),
                class("form-input simulation-name-input"),
              ]),
            ]),
            view_simulation_preview(model),
          ]),
          div([class("dialog-actions")], [
            button(
              [class("btn btn-secondary cancel-btn"), on_click(CloseSaveDialog)],
              [
                text("Отмена"),
              ],
            ),
            button([class("btn btn-primary"), on_click(SaveCurrentSimulation)], [
              text("Сохранить"),
            ]),
          ]),
        ]),
      ])
  }
}

fn view_simulation_preview(model: Model) -> Element(Msg) {
  div([class("simulation-preview")], [
    p([], [
      text(
        "Фракция: "
        <> case model.selected_faction {
          Light -> "Свет"
          Dark -> "Тьма"
        },
      ),
    ]),
    p([], [text("Месяцев: " <> int.to_string(model.params.months))]),
    p([], [text("Синих/мес: " <> int.to_string(model.params.blue_per_month))]),
    p([], [text("Зелёных/мес: " <> int.to_string(model.params.green_per_month))]),
    p([], [
      text("Фиолетовых/мес: " <> int.to_string(model.params.purple_per_month)),
    ]),
  ])
}

// ============================================================================
// Панель сравнения симуляций
// ============================================================================

fn view_comparison_panel(model: Model) -> Element(Msg) {
  let panel_class = case model.comparison_panel_open {
    True -> "comparison-panel open"
    False -> "comparison-panel"
  }

  div([class(panel_class)], [
    view_comparison_header(),
    view_simulations_list(model),
    view_drop_system_selector(model),
    view_multi_comparison_chart(model),
    view_multi_comparison_table(model),
  ])
}

fn view_comparison_header() -> Element(Msg) {
  div([class("comparison-header")], [
    h2([], [text("Сравнение симуляций")]),
    button([class("panel-close-btn"), on_click(ToggleComparisonPanel)], [
      text("x"),
    ]),
  ])
}

fn view_simulations_list(model: Model) -> Element(Msg) {
  let sims = model.comparison_state.saved_simulations

  div([class("simulations-list")], [
    h3([], [text("Сохранённые симуляции")]),
    div(
      [class("sims-scroll")],
      list.index_map(sims, fn(sim, idx) {
        view_simulation_item(model, sim, idx)
      }),
    ),
  ])
}

fn view_simulation_item(
  model: Model,
  sim: SavedSimulation,
  idx: Int,
) -> Element(Msg) {
  let is_visible = list.contains(model.comparison_state.visible_ids, sim.id)
  let is_base = model.comparison_state.base_id == Some(sim.id)
  let color = get_chart_color(idx)

  div([class("simulation-item")], [
    // Чекбокс для графика
    input([
      type_("checkbox"),
      checked(is_visible),
      on_check(fn(_) { ToggleSimulationVisibility(sim.id) }),
      class("chart-checkbox"),
    ]),
    // Цветовой индикатор
    span(
      [
        class("color-indicator"),
        attribute.attribute("style", "background-color: " <> color),
      ],
      [],
    ),
    // Имя симуляции
    span([class("sim-name")], [text(sim.name)]),
    // Радио для базовой
    label([class("base-radio-label")], [
      input([
        type_("radio"),
        name("base-sim"),
        checked(is_base),
        on_click(SetBaseSimulation(sim.id)),
      ]),
      text("База"),
    ]),
    // Кнопка удаления
    button([class("delete-sim-btn"), on_click(DeleteSimulation(sim.id))], [
      text("x"),
    ]),
  ])
}

fn get_chart_color(index: Int) -> String {
  case index % 5 {
    0 -> "#6366f1"
    // indigo
    1 -> "#f97316"
    // orange
    2 -> "#22c55e"
    // green
    3 -> "#ef4444"
    // red
    4 -> "#8b5cf6"
    // violet
    _ -> "#6366f1"
  }
}

fn view_drop_system_selector(model: Model) -> Element(Msg) {
  div([class("drop-system-selector")], [
    label([], [text("Система на графике:")]),
    select(
      [
        class("system-select"),
        on_input(fn(s) { SetChartDropSystem(parse_drop_system(s)) }),
      ],
      [
        option(
          [
            value("with_dup"),
            selected(model.comparison_state.chart_system == WithDuplicates),
          ],
          "С дубликатами",
        ),
        option(
          [
            value("no_dup"),
            selected(model.comparison_state.chart_system == NoDuplicates),
          ],
          "Без дубликатов",
        ),
      ],
    ),
  ])
}

fn parse_drop_system(s: String) -> DropSystem {
  case s {
    "with_dup" -> WithDuplicates
    _ -> NoDuplicates
  }
}

// ============================================================================
// График сравнения нескольких симуляций
// ============================================================================

fn view_multi_comparison_chart(model: Model) -> Element(Msg) {
  let visible_sims = get_visible_simulations(model)

  case list.length(visible_sims) {
    0 ->
      div([class("no-sims-message")], [
        text("Выберите симуляции для отображения"),
      ])
    _ ->
      render_multi_sim_chart(visible_sims, model.comparison_state.chart_system)
  }
}

fn get_visible_simulations(model: Model) -> List(#(SavedSimulation, Int)) {
  model.comparison_state.saved_simulations
  |> list.index_map(fn(sim, idx) { #(sim, idx) })
  |> list.filter(fn(pair) {
    list.contains(model.comparison_state.visible_ids, { pair.0 }.id)
  })
}

fn render_multi_sim_chart(
  sims: List(#(SavedSimulation, Int)),
  system: DropSystem,
) -> Element(Msg) {
  let width = 700
  let height = 350
  let padding = 50
  let legend_width = 120
  let chart_width = width - padding * 2 - legend_width
  let chart_height = height - padding * 2

  // Находим максимальный месяц
  let max_month =
    sims
    |> list.map(fn(pair) { { pair.0 }.params.months })
    |> list.fold(12, fn(acc, m) { int.max(acc, m) })

  let max_y = 18.0

  let x_scale = fn(month: Int) -> Int {
    padding + month * chart_width / max_month
  }

  let y_scale = fn(val: Float) -> Int {
    padding
    + chart_height
    - float.round(val /. max_y *. int.to_float(chart_height))
  }

  // Строим линии для каждой симуляции (3 линии на симуляцию по редкостям)
  let paths =
    list.flat_map(sims, fn(pair) {
      let #(sim, idx) = pair
      let curve = get_system_curve(sim.result, system)
      let dash = get_dash_pattern(idx)
      [
        #(
          build_path_for_field(curve, x_scale, y_scale, fn(r) {
            r.mean_blue_sets
          }),
          "#3b82f6",
          dash,
          sim.name,
          "Синие",
        ),
        #(
          build_path_for_field(curve, x_scale, y_scale, fn(r) {
            r.mean_green_sets
          }),
          "#22c55e",
          dash,
          sim.name,
          "Зелёные",
        ),
        #(
          build_path_for_field(curve, x_scale, y_scale, fn(r) {
            r.mean_purple_sets
          }),
          "#a855f7",
          dash,
          sim.name,
          "Фиолет.",
        ),
      ]
    })

  svg.svg(
    [
      attribute.attribute(
        "viewBox",
        "0 0 " <> int.to_string(width) <> " " <> int.to_string(height),
      ),
      class("multi-comparison-chart"),
    ],
    list.flatten([
      [render_grid_units(padding, chart_width, chart_height)],
      [render_axes_units(padding, chart_width, chart_height, max_month)],
      list.map(paths, fn(p) {
        let #(path, color, dash, _name, _rarity) = p
        svg.path([
          attribute.attribute("d", path),
          attribute.attribute("stroke", color),
          attribute.attribute("stroke-width", "2"),
          attribute.attribute("fill", "none"),
          attribute.attribute("stroke-dasharray", dash),
        ])
      }),
      [render_multi_legend(sims, width, padding)],
    ]),
  )
}

fn get_dash_pattern(idx: Int) -> String {
  case idx {
    0 -> ""
    1 -> "8,4"
    2 -> "2,4"
    3 -> "12,4,2,4"
    _ -> ""
  }
}

fn get_system_curve(
  result: ComparisonResult,
  system: DropSystem,
) -> List(AggregatedResult) {
  case system {
    WithDuplicates -> result.system_a.progress_curve
    NoDuplicates -> result.system_b.progress_curve
  }
}

fn render_multi_legend(
  sims: List(#(SavedSimulation, Int)),
  width: Int,
  padding: Int,
) -> Element(Msg) {
  let legend_x = width - 130
  let base_y = padding
  let row_height = 16

  // Легенда редкостей (цвета)
  let rarity_legend =
    svg.g([], [
      // Синие
      svg.line([
        attribute.attribute("x1", int.to_string(legend_x)),
        attribute.attribute("y1", int.to_string(base_y)),
        attribute.attribute("x2", int.to_string(legend_x + 15)),
        attribute.attribute("y2", int.to_string(base_y)),
        attribute.attribute("stroke", "#3b82f6"),
        attribute.attribute("stroke-width", "2"),
      ]),
      svg.text(
        [
          attribute.attribute("x", int.to_string(legend_x + 20)),
          attribute.attribute("y", int.to_string(base_y + 4)),
          class("legend-text"),
        ],
        "Синие",
      ),
      // Зелёные
      svg.line([
        attribute.attribute("x1", int.to_string(legend_x)),
        attribute.attribute("y1", int.to_string(base_y + row_height)),
        attribute.attribute("x2", int.to_string(legend_x + 15)),
        attribute.attribute("y2", int.to_string(base_y + row_height)),
        attribute.attribute("stroke", "#22c55e"),
        attribute.attribute("stroke-width", "2"),
      ]),
      svg.text(
        [
          attribute.attribute("x", int.to_string(legend_x + 20)),
          attribute.attribute("y", int.to_string(base_y + row_height + 4)),
          class("legend-text"),
        ],
        "Зелёные",
      ),
      // Фиолетовые
      svg.line([
        attribute.attribute("x1", int.to_string(legend_x)),
        attribute.attribute("y1", int.to_string(base_y + row_height * 2)),
        attribute.attribute("x2", int.to_string(legend_x + 15)),
        attribute.attribute("y2", int.to_string(base_y + row_height * 2)),
        attribute.attribute("stroke", "#a855f7"),
        attribute.attribute("stroke-width", "2"),
      ]),
      svg.text(
        [
          attribute.attribute("x", int.to_string(legend_x + 20)),
          attribute.attribute("y", int.to_string(base_y + row_height * 2 + 4)),
          class("legend-text"),
        ],
        "Фиолет.",
      ),
    ])

  // Легенда симуляций (стили линий)
  let sim_legend_start_y = base_y + row_height * 3 + 10
  let sim_legends =
    list.index_map(sims, fn(pair, i) {
      let #(sim, idx) = pair
      let dash = get_dash_pattern(idx)
      let y = sim_legend_start_y + i * row_height

      svg.g([], [
        svg.line([
          attribute.attribute("x1", int.to_string(legend_x)),
          attribute.attribute("y1", int.to_string(y)),
          attribute.attribute("x2", int.to_string(legend_x + 15)),
          attribute.attribute("y2", int.to_string(y)),
          attribute.attribute("stroke", "#666"),
          attribute.attribute("stroke-width", "2"),
          attribute.attribute("stroke-dasharray", dash),
        ]),
        svg.text(
          [
            attribute.attribute("x", int.to_string(legend_x + 20)),
            attribute.attribute("y", int.to_string(y + 4)),
            class("legend-text"),
          ],
          truncate_name(sim.name, 10),
        ),
      ])
    })

  svg.g([class("legend")], [rarity_legend, svg.g([], sim_legends)])
}

fn truncate_name(name: String, max_len: Int) -> String {
  case string_length(name) > max_len {
    True -> string_slice(name, 0, max_len - 2) <> ".."
    False -> name
  }
}

@external(javascript, "../string_ffi.mjs", "stringLength")
fn string_length(s: String) -> Int

@external(javascript, "../string_ffi.mjs", "stringSlice")
fn string_slice(s: String, start: Int, end: Int) -> String

// ============================================================================
// Таблица сравнения нескольких симуляций
// ============================================================================

fn view_multi_comparison_table(model: Model) -> Element(Msg) {
  case model.comparison_state.base_id {
    None ->
      div([class("no-base-message")], [
        text("Выберите базовую симуляцию для сравнения"),
      ])
    Some(base_id) -> {
      case
        army_storage.find_by_id(
          model.comparison_state.saved_simulations,
          base_id,
        )
      {
        None -> element.none()
        Some(base_sim) -> {
          let visible = get_visible_simulations(model)
          let others =
            list.filter(visible, fn(pair) { { pair.0 }.id != base_id })

          div([class("multi-comparison-table-container")], [
            h3([], [text("Сравнение с базовой: " <> base_sim.name)]),
            table([class("multi-comparison-table")], [
              view_multi_table_header(base_sim, others),
              view_multi_table_body(model, base_sim, others),
            ]),
          ])
        }
      }
    }
  }
}

fn view_multi_table_header(
  base: SavedSimulation,
  others: List(#(SavedSimulation, Int)),
) -> Element(Msg) {
  thead([], [
    tr(
      [],
      list.flatten([
        [
          th([], [text("Параметр")]),
          th([class("base-col")], [
            text(truncate_name(base.name, 10) <> " (база)"),
          ]),
        ],
        list.map(others, fn(pair) {
          th([], [text(truncate_name({ pair.0 }.name, 10))])
        }),
      ]),
    ),
  ])
}

fn view_multi_table_body(
  model: Model,
  base: SavedSimulation,
  others: List(#(SavedSimulation, Int)),
) -> Element(Msg) {
  let system = model.comparison_state.chart_system
  let base_stats = get_system_stats(base.result, system)
  let other_stats =
    list.map(others, fn(pair) { get_system_stats({ pair.0 }.result, system) })

  tbody(
    [],
    list.flatten([
      // Секция "Исходные параметры"
      [
        tr([class("section-header")], [
          td([attribute.attribute("colspan", "10")], [
            text("Исходные параметры"),
          ]),
        ]),
      ],
      [
        view_param_row_int(
          "Месяцев",
          base.params.months,
          list.map(others, fn(p) { { p.0 }.params.months }),
        ),
      ],
      [
        view_param_row_int(
          "Синих/мес",
          base.params.blue_per_month,
          list.map(others, fn(p) { { p.0 }.params.blue_per_month }),
        ),
      ],
      [
        view_param_row_int(
          "Зелёных/мес",
          base.params.green_per_month,
          list.map(others, fn(p) { { p.0 }.params.green_per_month }),
        ),
      ],
      [
        view_param_row_int(
          "Фиол./мес",
          base.params.purple_per_month,
          list.map(others, fn(p) { { p.0 }.params.purple_per_month }),
        ),
      ],
      [
        view_param_row_int(
          "Сеты синие",
          base.initial_sets.blue_sets,
          list.map(others, fn(p) { { p.0 }.initial_sets.blue_sets }),
        ),
      ],
      [
        view_param_row_int(
          "Сеты зелён.",
          base.initial_sets.green_sets,
          list.map(others, fn(p) { { p.0 }.initial_sets.green_sets }),
        ),
      ],
      [
        view_param_row_int(
          "Сеты фиол.",
          base.initial_sets.purple_sets,
          list.map(others, fn(p) { { p.0 }.initial_sets.purple_sets }),
        ),
      ],
      // Секция "Результаты"
      [
        tr([class("section-header")], [
          td([attribute.attribute("colspan", "10")], [
            text(
              "Результаты ("
              <> case system {
                WithDuplicates -> "с дубликатами"
                NoDuplicates -> "без дубликатов"
              }
              <> ")",
            ),
          ]),
        ]),
      ],
      [
        view_result_row_float(
          "Ср. синих сетов",
          base_stats.avg_blue_sets,
          list.map(other_stats, fn(s) { s.avg_blue_sets }),
        ),
      ],
      [
        view_result_row_float(
          "Ср. зелён. сетов",
          base_stats.avg_green_sets,
          list.map(other_stats, fn(s) { s.avg_green_sets }),
        ),
      ],
      [
        view_result_row_float(
          "Ср. фиол. сетов",
          base_stats.avg_purple_sets,
          list.map(other_stats, fn(s) { s.avg_purple_sets }),
        ),
      ],
    ]),
  )
}

fn get_system_stats(result: ComparisonResult, system: DropSystem) -> FinalStats {
  case system {
    WithDuplicates -> result.system_a.final_stats
    NoDuplicates -> result.system_b.final_stats
  }
}

fn view_param_row_int(
  label_text: String,
  base_val: Int,
  other_vals: List(Int),
) -> Element(Msg) {
  tr(
    [],
    list.flatten([
      [
        td([], [text(label_text)]),
        td([class("base-val")], [text(int.to_string(base_val))]),
      ],
      list.map(other_vals, fn(val) {
        let diff = val - base_val
        td([class(int_diff_class(diff))], [
          text(int.to_string(val) <> " (" <> format_int_diff(diff) <> ")"),
        ])
      }),
    ]),
  )
}

fn view_result_row_float(
  label_text: String,
  base_val: Float,
  other_vals: List(Float),
) -> Element(Msg) {
  tr(
    [],
    list.flatten([
      [
        td([], [text(label_text)]),
        td([class("base-val")], [text(format_float(base_val, 2))]),
      ],
      list.map(other_vals, fn(val) {
        let diff = val -. base_val
        td([class(float_diff_class(diff))], [
          text(format_float(val, 2) <> " (" <> format_float_diff(diff) <> ")"),
        ])
      }),
    ]),
  )
}

fn int_diff_class(diff: Int) -> String {
  case diff > 0 {
    True -> "positive"
    False ->
      case diff < 0 {
        True -> "negative"
        False -> "neutral"
      }
  }
}

fn float_diff_class(diff: Float) -> String {
  case diff >. 0.001 {
    True -> "positive"
    False ->
      case diff <. -0.001 {
        True -> "negative"
        False -> "neutral"
      }
  }
}

fn format_int_diff(diff: Int) -> String {
  case diff > 0 {
    True -> "+" <> int.to_string(diff)
    False -> int.to_string(diff)
  }
}

fn format_float_diff(diff: Float) -> String {
  case diff >. 0.0 {
    True -> "+" <> format_float(diff, 2)
    False -> format_float(diff, 2)
  }
}

// ============================================================================
// Панель профилей
// ============================================================================

fn view_profiles_panel(model: Model) -> Element(Msg) {
  let panel_class = case model.profiles_panel_open {
    True -> "profiles-panel open"
    False -> "profiles-panel"
  }

  div([class(panel_class)], [
    view_profiles_header(),
    view_save_profile_section(model),
    view_profiles_list(model),
  ])
}

fn view_profiles_header() -> Element(Msg) {
  div([class("profiles-header")], [
    h2([], [text("Профили инвентаря")]),
    button([class("panel-close-btn"), on_click(ToggleProfilesPanel)], [
      text("x"),
    ]),
  ])
}

fn view_save_profile_section(model: Model) -> Element(Msg) {
  let is_full = list.length(model.saved_profiles) >= max_profiles
  let stats = sets_inventory.get_stats(model.inventory)

  div([class("save-profile-section")], [
    div([class("current-inventory-stats")], [
      p([], [text("Текущий инвентарь:")]),
      span([class("stat-item")], [text("Всего: " <> int.to_string(stats.total))]),
      span([class("stat-item blue")], [text("С: " <> int.to_string(stats.blue))]),
      span([class("stat-item green")], [
        text("З: " <> int.to_string(stats.green)),
      ]),
      span([class("stat-item purple")], [
        text("Ф: " <> int.to_string(stats.purple)),
      ]),
    ]),
    button(
      [
        class("save-profile-btn"),
        on_click(OpenProfileSaveDialog),
        disabled(is_full),
      ],
      [
        text(case is_full {
          True -> "Лимит профилей (" <> int.to_string(max_profiles) <> ")"
          False -> "Сохранить текущий"
        }),
      ],
    ),
  ])
}

fn view_profiles_list(model: Model) -> Element(Msg) {
  case list.length(model.saved_profiles) {
    0 ->
      div([class("no-profiles-message")], [
        text("Нет сохранённых профилей"),
      ])
    _ ->
      div(
        [class("profiles-list")],
        list.map(model.saved_profiles, view_profile_item),
      )
  }
}

fn view_profile_item(profile: Profile) -> Element(Msg) {
  let stats = sets_inventory.get_stats(profile.inventory)

  div([class("profile-item")], [
    div([class("profile-info")], [
      span([class("profile-name")], [text(profile.name)]),
      div([class("profile-stats")], [
        span([class("stat-item")], [
          text("Всего: " <> int.to_string(stats.total)),
        ]),
        span([class("stat-item blue")], [
          text("С: " <> int.to_string(stats.blue)),
        ]),
        span([class("stat-item green")], [
          text("З: " <> int.to_string(stats.green)),
        ]),
        span([class("stat-item purple")], [
          text("Ф: " <> int.to_string(stats.purple)),
        ]),
      ]),
    ]),
    div([class("profile-actions")], [
      button([class("load-profile-btn"), on_click(LoadProfile(profile.id))], [
        text("Загрузить"),
      ]),
      button(
        [class("delete-profile-btn"), on_click(DeleteProfile(profile.id))],
        [
          text("x"),
        ],
      ),
    ]),
  ])
}

fn view_profile_save_dialog(model: Model) -> Element(Msg) {
  case model.profile_save_dialog_open {
    False -> element.none()
    True -> {
      let stats = sets_inventory.get_stats(model.inventory)

      div([class("modal-overlay")], [
        div([class("modal-dialog profile-save-dialog")], [
          h2([], [text("Сохранить профиль")]),
          div([class("dialog-content")], [
            div([class("form-group")], [
              label([], [text("Название профиля:")]),
              input([
                type_("text"),
                value(model.pending_profile_name),
                on_input(SetProfileName),
                class("form-input profile-name-input"),
              ]),
            ]),
            div([class("inventory-preview")], [
              h3([], [text("Статистика инвентаря")]),
              p([], [text("Всего вещей: " <> int.to_string(stats.total))]),
              p([class("blue")], [text("Синих: " <> int.to_string(stats.blue))]),
              p([class("green")], [
                text("Зелёных: " <> int.to_string(stats.green)),
              ]),
              p([class("purple")], [
                text("Фиолетовых: " <> int.to_string(stats.purple)),
              ]),
            ]),
          ]),
          div([class("dialog-actions")], [
            button(
              [
                class("btn btn-secondary cancel-btn"),
                on_click(CloseProfileSaveDialog),
              ],
              [
                text("Отмена"),
              ],
            ),
            button([class("btn btn-primary"), on_click(SaveCurrentProfile)], [
              text("Сохранить"),
            ]),
          ]),
        ]),
      ])
    }
  }
}
