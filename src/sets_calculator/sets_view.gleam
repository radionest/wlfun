import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element, text}
import lustre/element/html.{div, h1, h2, label, select, option, input, button, span}
import lustre/attribute.{class, value, selected, type_, id, checked}
import lustre/event.{on_change, on_click, on_input}
import items_calculator/game_data.{type Faction, type ItemColor, type Unit, Blue, Green, Purple, Light, Dark}
import sets_calculator/sets_model.{
  type Model, type Msg, type ActiveGoal,
  FactionNode, EntityNode,
  GoalDuplicates, SimpleMode, ChartMode,
  SetMaxAttempts,
  InventoryToggleSlot, InventorySetFilterFaction,
  InventorySetFilterColor, InventorySetCount, SetMinDuplicates, SetMinItems,
  SetViewMode,
  ToggleInventorySettingsMenu, CloseInventorySettingsMenu,
  InventoryFillAll, InventoryClearAll, InventoryResetCounts,
  ToggleInventoryStatsMenu, CloseInventoryStatsMenu,
  CopyShareLink, HideShareNotification,
  // Новые сообщения для панели целей
  ToggleSpecificSetGoal, ToggleAnyFactionGoal, ToggleDuplicatesGoal,
  SetAnyFactionFaction, ToggleTreeNode, ToggleSetSelection,
  SelectAllInNode, DeselectAllInNode, SelectColor,
  // Боковая панель инвентаря
  ToggleInventoryPanel,
  // Профили
  ToggleProfilesPanel, OpenProfileSaveDialog, CloseProfileSaveDialog,
  SetProfileName, SaveCurrentProfile, LoadProfile, DeleteProfile,
}
import army_simulator/army_model.{type Profile, max_profiles}
import sets_calculator/sets_game_data.{
  type Hero, type SetId, RegularUnit, HeroEntity, SetId,
  items_needed, generate_all_set_ids, filter_sets,
}
import sets_calculator/sets_chart.{ChartCurve}
import sets_calculator/sets_inventory.{type InventoryStats, count_owned, get_stats}
import shared/inventory_view

pub fn view(model: Model) -> Element(Msg) {
  let wrapper_class = case model.inventory_panel_open, model.profiles_panel_open {
    True, _ -> "sets-calculator-wrapper inventory-open"
    _, True -> "sets-calculator-wrapper profiles-open"
    _, _ -> "sets-calculator-wrapper"
  }

  div([class(wrapper_class)], [
    // Основной контент
    view_main_content(model),
    // Вкладка "Мой инвентарь" справа
    view_inventory_tab(model),
    // Выдвижная панель инвентаря
    view_inventory_side_panel(model),
    // Вкладка "Вернуться" слева (мобильные)
    view_back_tab(model),
    // Вкладка "Профили" слева
    view_profiles_tab(model),
    // Панель профилей слева
    view_profiles_panel(model),
    // Диалог сохранения профиля
    view_profile_save_dialog(model),
  ])
}

/// Основной контент калькулятора
fn view_main_content(model: Model) -> Element(Msg) {
  div([class("sets-calculator")], [
    h1([], [text("Калькулятор шансов собрать сет")]),
    div([class("form-section")], [
      // Глобальный выбор редкости
      view_color_select(model),
      // Панель целей с чекбоксами
      view_goals_panel(model),
      // Максимум попыток
      view_max_attempts(model),
    ]),
    view_results(model),
  ])
}

/// Боковая вкладка "Мой инвентарь"
fn view_inventory_tab(model: Model) -> Element(Msg) {
  let tab_class = case model.inventory_panel_open {
    True -> "inventory-side-tab hidden"
    False -> "inventory-side-tab"
  }

  button([class(tab_class), on_click(ToggleInventoryPanel)], [
    text("Мой инвентарь"),
  ])
}

/// Выдвижная боковая панель инвентаря
fn view_inventory_side_panel(model: Model) -> Element(Msg) {
  let panel_class = case model.inventory_panel_open {
    True -> "side-panel side-panel--right inventory-side-panel open"
    False -> "side-panel side-panel--right inventory-side-panel"
  }

  div([class(panel_class)], [
    // Заголовок с кнопкой закрытия
    view_panel_header(),
    // Дисклеймер
    div([class("panel-disclaimer")], [
      text("Заполните инвентарь для индивидуального расчёта"),
    ]),
    // Контент инвентаря
    view_inventory_panel_content(model),
  ])
}

/// Заголовок панели инвентаря
fn view_panel_header() -> Element(Msg) {
  div([class("panel-header")], [
    h2([], [text("Мой инвентарь")]),
    button([class("panel-close-btn"), on_click(ToggleInventoryPanel)], [
      text("×"),
    ]),
  ])
}

/// Контент боковой панели инвентаря
fn view_inventory_panel_content(model: Model) -> Element(Msg) {
  div([class("inventory-panel-content")], [
    // Overlay для закрытия меню
    case model.inventory_settings_menu_open {
      True -> div([class("settings-overlay"), on_click(CloseInventorySettingsMenu)], [])
      False -> text("")
    },
    // Кнопка "Поделиться"
    div([class("panel-share-row")], [
      button([class("share-btn"), on_click(CopyShareLink)], [
        text("Поделиться"),
      ]),
    ]),
    // Уведомление о копировании
    view_share_notification(model),
    // Фильтры
    view_inventory_filters(model),
    // Таблица сетов
    view_inventory_table(model),
  ])
}

/// Вкладка "Вернуться к подсчету шансов" (мобильные)
fn view_back_tab(model: Model) -> Element(Msg) {
  case model.inventory_panel_open {
    True ->
      button([class("back-side-tab"), on_click(ToggleInventoryPanel)], [
        text("Вернуться к подсчету шансов"),
      ])
    False -> text("")
  }
}

// ============================================================================
// Панель целей с чекбоксами (новая версия)
// ============================================================================

/// Панель выбора целей с чекбоксами
fn view_goals_panel(model: Model) -> Element(Msg) {
  div([class("goals-panel")], [
    h2([], [text("Цели расчета")]),
    // Чекбокс 1: Конкретный сет
    view_specific_set_goal(model),
    // Чекбокс 2: Любой сет фракции
    view_any_faction_goal(model),
    // Чекбокс 3: Дубликаты
    view_duplicates_goal(model),
  ])
}

/// Чекбокс "Конкретный сет" с древовидным списком
fn view_specific_set_goal(model: Model) -> Element(Msg) {
  let selected_count = list.length(model.selected_sets)

  div([class("goal-item")], [
    div([class("goal-header")], [
      input([
        type_("checkbox"),
        id("goal-specific"),
        checked(model.specific_set_enabled),
        on_click(ToggleSpecificSetGoal),
      ]),
      label([attribute.for("goal-specific")], [text("Выбранные сеты")]),
      case model.specific_set_enabled && selected_count > 0 {
        True -> span([class("selected-count")], [
          text(" (" <> int.to_string(selected_count) <> " выбрано)")
        ])
        False -> text("")
      },
    ]),
    // Древовидный список (показывается если включен)
    case model.specific_set_enabled {
      True -> view_sets_tree(model)
      False -> text("")
    },
  ])
}

/// Чекбокс "Любой сет фракции"
fn view_any_faction_goal(model: Model) -> Element(Msg) {
  div([class("goal-item")], [
    div([class("goal-header")], [
      input([
        type_("checkbox"),
        id("goal-any-faction"),
        checked(model.any_faction_enabled),
        on_click(ToggleAnyFactionGoal),
      ]),
      label([attribute.for("goal-any-faction")], [text("Любой сет фракции")]),
    ]),
    case model.any_faction_enabled {
      True -> view_faction_buttons_for_goal(model.any_faction_faction)
      False -> text("")
    },
  ])
}

/// Кнопки выбора фракции для "Любой сет фракции"
fn view_faction_buttons_for_goal(current_faction: Faction) -> Element(Msg) {
  let light_class = case current_faction {
    Light -> "faction-btn light active"
    Dark -> "faction-btn light"
  }
  let dark_class = case current_faction {
    Dark -> "faction-btn dark active"
    Light -> "faction-btn dark"
  }

  div([class("goal-params")], [
    div([class("faction-buttons")], [
      button(
        [class(light_class), on_click(SetAnyFactionFaction("light"))],
        [text("Свет")],
      ),
      button(
        [class(dark_class), on_click(SetAnyFactionFaction("dark"))],
        [text("Тьма")],
      ),
    ]),
  ])
}

/// Чекбокс "Дубликаты"
fn view_duplicates_goal(model: Model) -> Element(Msg) {
  div([class("goal-item")], [
    div([class("goal-header")], [
      input([
        type_("checkbox"),
        id("goal-duplicates"),
        checked(model.duplicates_enabled),
        on_click(ToggleDuplicatesGoal),
      ]),
      label([attribute.for("goal-duplicates")], [text("Дубликаты")]),
    ]),
    case model.duplicates_enabled {
      True -> view_duplicate_params(model)
      False -> text("")
    },
  ])
}

/// Параметры для дубликатов (K и N)
fn view_duplicate_params(model: Model) -> Element(Msg) {
  div([class("goal-params duplicate-params")], [
    div([class("param-row")], [
      label([], [text("Мин. раз выпала вещь:")]),
      input([
        type_("number"),
        id("min-duplicates-goal"),
        value(model.min_duplicates_str),
        attribute.min("1"),
        attribute.max("50"),
        on_input(SetMinDuplicates),
      ]),
    ]),
    div([class("param-row")], [
      label([], [text("Мин. вещей с дубликатами:")]),
      input([
        type_("number"),
        id("min-items-goal"),
        value(model.min_items_str),
        attribute.min("1"),
        attribute.max("288"),
        on_input(SetMinItems),
      ]),
    ]),
  ])
}

// ============================================================================
// Древовидный список сетов
// ============================================================================

/// Древовидный список для выбора конкретных сетов
fn view_sets_tree(model: Model) -> Element(Msg) {
  div([class("sets-tree")], [
    view_faction_branch(model, Light, "Свет"),
    view_faction_branch(model, Dark, "Тьма"),
  ])
}

/// Ветка фракции
fn view_faction_branch(model: Model, faction: Faction, faction_label: String) -> Element(Msg) {
  let node_id = FactionNode(faction)
  let is_expanded = list.contains(model.expanded_tree_nodes, node_id)

  div([class("tree-branch faction-branch")], [
    // Заголовок с иконкой раскрытия
    div([class("tree-node-header")], [
      button([class("expand-btn"), on_click(ToggleTreeNode(node_id))], [
        text(case is_expanded { True -> "▼ " False -> "▶ " }),
        span([class("node-label")], [text(faction_label)]),
      ]),
      // Быстрые действия
      button([class("tree-action"), on_click(SelectAllInNode(node_id))], [text("Все")]),
      button([class("tree-action"), on_click(DeselectAllInNode(node_id))], [text("Нет")]),
    ]),
    // Дочерние узлы
    case is_expanded {
      True -> div([class("tree-children")], get_entity_branches(model, faction))
      False -> text("")
    },
  ])
}

/// Получить все ветки юнитов и героев для фракции
fn get_entity_branches(model: Model, faction: Faction) -> List(Element(Msg)) {
  // Юниты
  let unit_branches = game_data.units_by_faction(faction)
    |> list.map(fn(u: Unit) {
      view_entity_branch(model, faction, u.name, RegularUnit)
    })

  // Герои
  let hero_branches = sets_game_data.heroes_by_faction(faction)
    |> list.map(fn(h: Hero) {
      view_entity_branch(model, faction, h.name, HeroEntity)
    })

  list.append(unit_branches, hero_branches)
}

/// Ветка юнита/героя
fn view_entity_branch(model: Model, faction: Faction, name: String, entity_type: sets_game_data.EntityType) -> Element(Msg) {
  let node_id = EntityNode(faction, name, entity_type)
  let is_expanded = list.contains(model.expanded_tree_nodes, node_id)
  let type_suffix = case entity_type {
    HeroEntity -> " (герой)"
    RegularUnit -> ""
  }

  div([class("tree-branch entity-branch")], [
    // Заголовок
    div([class("tree-node-header")], [
      button([class("expand-btn"), on_click(ToggleTreeNode(node_id))], [
        text(case is_expanded { True -> "▼ " False -> "▶ " }),
        span([class("node-label")], [text(name <> type_suffix)]),
      ]),
    ]),
    // Чекбоксы сетов
    case is_expanded {
      True -> view_set_checkboxes(model, name, entity_type)
      False -> text("")
    },
  ])
}

/// Чекбоксы для сетов (Сет 1 и Сет 2)
fn view_set_checkboxes(model: Model, entity_name: String, entity_type: sets_game_data.EntityType) -> Element(Msg) {
  let set1_id = SetId(entity_name, entity_type, model.selected_color, 1)
  let set2_id = SetId(entity_name, entity_type, model.selected_color, 2)

  let set1_selected = list.contains(model.selected_sets, set1_id)
  let set2_selected = list.contains(model.selected_sets, set2_id)

  // Прогресс из инвентаря
  let set1_owned = count_owned(sets_inventory.get_slots(model.inventory, set1_id))
  let set2_owned = count_owned(sets_inventory.get_slots(model.inventory, set2_id))
  let needed = items_needed(entity_type)

  div([class("tree-children set-checkboxes")], [
    div([class("set-checkbox-item")], [
      input([
        type_("checkbox"),
        checked(set1_selected),
        on_click(ToggleSetSelection(set1_id)),
      ]),
      span([class("set-label")], [text("Сет 1")]),
      span([class("set-progress")], [
        text(" (" <> int.to_string(set1_owned) <> "/" <> int.to_string(needed) <> ")"),
      ]),
    ]),
    div([class("set-checkbox-item")], [
      input([
        type_("checkbox"),
        checked(set2_selected),
        on_click(ToggleSetSelection(set2_id)),
      ]),
      span([class("set-label")], [text("Сет 2")]),
      span([class("set-progress")], [
        text(" (" <> int.to_string(set2_owned) <> "/" <> int.to_string(needed) <> ")"),
      ]),
    ]),
  ])
}

/// Селект редкости
fn view_color_select(model: Model) -> Element(Msg) {
  let blue_class = case model.selected_color {
    Blue -> "color-btn blue active"
    _ -> "color-btn blue"
  }
  let green_class = case model.selected_color {
    Green -> "color-btn green active"
    _ -> "color-btn green"
  }
  let purple_class = case model.selected_color {
    Purple -> "color-btn purple active"
    _ -> "color-btn purple"
  }

  div([class("form-group color-select-group")], [
    label([], [text("Редкость:")]),
    div([class("color-buttons")], [
      button(
        [class(blue_class), on_click(SelectColor("blue"))],
        [text("Синий")],
      ),
      button(
        [class(green_class), on_click(SelectColor("green"))],
        [text("Зелёный")],
      ),
      button(
        [class(purple_class), on_click(SelectColor("purple"))],
        [text("Фиолетовый")],
      ),
    ]),
  ])
}

/// Поле максимального количества попыток
fn view_max_attempts(model: Model) -> Element(Msg) {
  div([class("form-group max-attempts")], [
    label([], [text("Сколько вещей планируете набрать:")]),
    input([
      type_("number"),
      id("max-attempts"),
      value(model.max_attempts_str),
      attribute.min("10"),
      attribute.max("1000"),
      on_input(SetMaxAttempts),
    ]),
  ])
}

/// Результаты - график или простой режим
fn view_results(model: Model) -> Element(Msg) {
  // Показываем индикатор загрузки, если идёт вычисление
  case model.is_computing {
    True ->
      div([class("results-section computing")], [
        div([class("computing-indicator")], [
          span([class("spinner")], []),
          text("Вычисление..."),
        ]),
      ])
    False -> {
      // Получаем активные цели с кривыми
      let goals_with_curves = list.filter(model.active_goals, fn(g: ActiveGoal) {
        option.is_some(g.probability_curve)
      })

      case list.is_empty(goals_with_curves) {
        True ->
          div([class("results-placeholder")], [
            text("Выберите хотя бы одну цель для расчёта"),
          ])
        False ->
          div([class("results-section")], [
            h2([], [text("Результаты расчёта")]),
            view_mode_tabs(model),
            case model.view_mode {
              SimpleMode -> view_simple_results(model, goals_with_curves)
              ChartMode -> view_chart_results(model, goals_with_curves)
            },
          ])
      }
    }
  }
}

/// Простой режим - список всех целей с вероятностями
fn view_simple_results(model: Model, goals: List(ActiveGoal)) -> Element(Msg) {
  div([class("simple-results")],
    list.map(goals, fn(goal: ActiveGoal) {
      view_simple_result_item(model, goal)
    })
  )
}

/// Элемент простого режима для одной цели
fn view_simple_result_item(model: Model, goal: ActiveGoal) -> Element(Msg) {
  case goal.probability_curve {
    None -> text("")
    Some(curve) -> {
      let prob = find_prob_at_n(curve, model.max_attempts)
      let percent = format_percent(prob)

      div([class("simple-result-item")], [
        span([class("goal-color-dot"), attribute.attribute("style", "background-color: " <> goal.chart_color)], []),
        span([class("goal-label")], [text(goal.label)]),
        span([class("goal-probability")], [text(percent)]),
      ])
    }
  }
}

/// Режим графика - мульти-чарт со всеми кривыми
fn view_chart_results(_model: Model, goals: List(ActiveGoal)) -> Element(Msg) {
  // Преобразуем ActiveGoal в ChartCurve
  let curves = goals
    |> list.filter_map(fn(goal: ActiveGoal) {
      case goal.probability_curve {
        Some(data) -> Ok(ChartCurve(label: goal.label, data: data, color: goal.chart_color))
        None -> Error(Nil)
      }
    })

  case list.is_empty(curves) {
    True -> div([class("results-placeholder")], [text("Нет данных для графика")])
    False ->
      div([class("chart-container multi-chart-container")], [
        sets_chart.render_multi_chart(curves, 600, 350),
        view_multi_key_probabilities(goals),
      ])
  }
}

/// Ключевые вероятности для мульти-режима
fn view_multi_key_probabilities(goals: List(ActiveGoal)) -> Element(Msg) {
  div([class("multi-key-probabilities")],
    list.map(goals, fn(goal: ActiveGoal) {
      case goal.probability_curve {
        None -> text("")
        Some(curve) ->
          div([class("goal-key-probs")], [
            div([class("goal-key-header")], [
              span([class("goal-color-dot"), attribute.attribute("style", "background-color: " <> goal.chart_color)], []),
              span([class("goal-key-label")], [text(goal.label)]),
            ]),
            view_key_probs_inline(curve),
          ])
      }
    })
  )
}

/// Ключевые вероятности в одну строку
fn view_key_probs_inline(curve: List(#(Int, Float))) -> Element(Msg) {
  let n_for_50 = find_n_for_prob(curve, 0.5)
  let n_for_90 = find_n_for_prob(curve, 0.9)

  div([class("key-probs-inline")], [
    span([class("key-prob-item")], [
      text("50%: " <> format_n(n_for_50)),
    ]),
    span([class("key-prob-item")], [
      text("90%: " <> format_n(n_for_90)),
    ]),
  ])
}

/// Табы для переключения режима отображения
fn view_mode_tabs(model: Model) -> Element(Msg) {
  let simple_class = case model.view_mode {
    SimpleMode -> "mode-tab active"
    ChartMode -> "mode-tab"
  }
  let chart_class = case model.view_mode {
    ChartMode -> "mode-tab active"
    SimpleMode -> "mode-tab"
  }

  div([class("mode-tabs")], [
    button([class(simple_class), on_click(SetViewMode(SimpleMode))], [text("Простой")]),
    button([class(chart_class), on_click(SetViewMode(ChartMode))], [text("График")]),
  ])
}

/// Найти вероятность при N попытках
fn find_prob_at_n(curve: List(#(Int, Float)), n: Int) -> Float {
  case list.find(curve, fn(p) { p.0 == n }) {
    Ok(#(_, prob)) -> prob
    Error(_) -> {
      // Если точка не найдена, взять последнюю
      case list.last(curve) {
        Ok(#(_, prob)) -> prob
        Error(_) -> 0.0
      }
    }
  }
}

fn find_n_for_prob(curve: List(#(Int, Float)), target: Float) -> Int {
  case list.find(curve, fn(p) { p.1 >=. target }) {
    Ok(#(n, _)) -> n
    Error(_) -> -1
  }
}

fn format_percent(p: Float) -> String {
  let percent = p *. 100.0
  let rounded = float_round(percent, 1)
  rounded <> "%"
}

fn float_round(f: Float, decimals: Int) -> String {
  let multiplier = pow10(decimals)
  let rounded = int.to_float(float_to_int(f *. multiplier +. 0.5)) /. multiplier
  float_to_string_fixed(rounded, decimals)
}

fn pow10(n: Int) -> Float {
  case n {
    0 -> 1.0
    1 -> 10.0
    2 -> 100.0
    _ -> 10.0 *. pow10(n - 1)
  }
}

fn float_to_int(f: Float) -> Int {
  case f <. 0.0 {
    True -> 0 - float_to_int(0.0 -. f)
    False -> {
      // Простое усечение
      let str = float_to_string_simple(f)
      case int.parse(str) {
        Ok(n) -> n
        Error(_) -> 0
      }
    }
  }
}

@external(javascript, "../sets_ffi.mjs", "floatToString")
fn float_to_string_simple(f: Float) -> String

@external(javascript, "../sets_ffi.mjs", "floatToFixed")
fn float_to_string_fixed(f: Float, decimals: Int) -> String

fn format_n(n: Int) -> String {
  case n {
    -1 -> ">макс"
    _ -> int.to_string(n)
  }
}

// ============================================
// Секция инвентаря (боковая панель)
// ============================================

/// Кнопка настроек инвентаря с выпадающим меню
fn view_inventory_settings_button(model: Model) -> Element(Msg) {
  div([class("inventory-settings-wrapper")], [
    button([class("inventory-settings-btn"), on_click(ToggleInventorySettingsMenu)], [text("⚙")]),
    case model.inventory_settings_menu_open {
      True -> view_inventory_settings_menu()
      False -> text("")
    },
  ])
}

/// Выпадающее меню настроек инвентаря
fn view_inventory_settings_menu() -> Element(Msg) {
  div([class("chart-settings-menu")], [
    button([class("settings-menu-btn"), on_click(InventoryFillAll)], [text("Добавить все")]),
    button([class("settings-menu-btn"), on_click(InventoryClearAll)], [text("Убрать все")]),
    button([class("settings-menu-btn"), on_click(InventoryResetCounts)], [text("Сбросить счётчики")]),
  ])
}

/// Уведомление о копировании share link
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

fn view_inventory_filters(model: Model) -> Element(Msg) {
  let stats = get_stats(model.inventory)

  div([class("inventory-filters")], [
    // Фильтр по фракции
    div([class("filter-group")], [
      label([], [text("Фракция:")]),
      select([on_change(fn(s) { InventorySetFilterFaction(inventory_view.parse_faction_filter(s)) })], [
        option([value("all"), selected(model.inventory_filter_faction == None)], "Все"),
        option([value("light"), selected(model.inventory_filter_faction == Some(Light))], "Свет"),
        option([value("dark"), selected(model.inventory_filter_faction == Some(Dark))], "Тьма"),
      ]),
    ]),
    // Фильтр по редкости
    div([class("filter-group")], [
      label([], [text("Редкость:")]),
      select([on_change(fn(s) { InventorySetFilterColor(inventory_view.parse_color_filter(s)) })], [
        option([value("all"), selected(model.inventory_filter_color == None)], "Все"),
        option([value("blue"), selected(model.inventory_filter_color == Some(Blue))], "Синий"),
        option([value("green"), selected(model.inventory_filter_color == Some(Green))], "Зелёный"),
        option([value("purple"), selected(model.inventory_filter_color == Some(Purple))], "Фиолетовый"),
      ]),
    ]),
    // Счётчик вещей с меню статистики и кнопка настроек
    div([class("filter-group inventory-stats")], [
      view_inventory_stats_button(model, stats),
      view_inventory_settings_button(model),
    ]),
  ])
}

/// Кнопка статистики с выпадающим меню
fn view_inventory_stats_button(model: Model, stats: InventoryStats) -> Element(Msg) {
  div([class("inventory-stats-wrapper")], [
    // Overlay для закрытия меню при клике вне
    case model.inventory_stats_menu_open {
      True -> div([class("settings-overlay"), on_click(CloseInventoryStatsMenu)], [])
      False -> text("")
    },
    // Кнопка с иконкой ? и числом
    button([class("inventory-stats-btn"), on_click(ToggleInventoryStatsMenu)], [
      span([class("help-icon")], [text("?")]),
      text(" " <> int.to_string(stats.total)),
    ]),
    // Выпадающее меню со статистикой
    case model.inventory_stats_menu_open {
      True -> inventory_view.view_inventory_stats_menu(stats)
      False -> text("")
    },
  ])
}

fn view_inventory_table(model: Model) -> Element(Msg) {
  // Получить отфильтрованный список сетов
  let all_sets = generate_all_set_ids()
  let filtered_sets = filter_sets(all_sets, model.inventory_filter_faction, model.inventory_filter_color)
  let is_duplicates_mode = model.goal_type == GoalDuplicates

  let header_class = case is_duplicates_mode {
    True -> "inventory-row header duplicates-mode"
    False -> "inventory-row header"
  }

  div([class("inventory-table")], [
    // Заголовок таблицы
    div([class(header_class)], [
      div([class("col-entity")], [text("Юнит/Герой")]),
      div([class("col-color")], [text("Редк.")]),
      div([class("col-set")], [text("Сет")]),
      div([class("col-slots")], [text(case is_duplicates_mode {
        True -> "С1 С2 С3 С4"
        False -> "Слоты"
      })]),
      div([class("col-progress")], [text("Прогр.")]),
    ]),
    // Строки данных
    div([class("inventory-rows")],
      list.map(filtered_sets, fn(set_id) { view_inventory_row(model, set_id, is_duplicates_mode) })
    ),
  ])
}

fn view_inventory_row(model: Model, set_id: SetId, is_duplicates_mode: Bool) -> Element(Msg) {
  let slots = sets_inventory.get_slots(model.inventory, set_id)
  let counts = sets_inventory.get_counts(model.inventory, set_id)
  let SetId(name, entity_type, color, set_num) = set_id
  let owned_count = count_owned(slots)
  let needed = items_needed(entity_type)
  let is_complete = owned_count >= needed

  let base_class = case is_duplicates_mode {
    True -> "inventory-row duplicates-mode"
    False -> "inventory-row"
  }
  let row_class = case is_complete {
    True -> base_class <> " complete"
    False -> base_class
  }

  div([class(row_class)], [
    div([class("col-entity")], [text(name)]),
    div([class("col-color " <> inventory_view.color_class(color))], [text(inventory_view.color_short(color))]),
    div([class("col-set")], [text(int.to_string(set_num))]),
    div([class("col-slots")], case is_duplicates_mode {
      True -> [
        view_inv_slot_count_input(set_id, 1, counts.slot1),
        view_inv_slot_count_input(set_id, 2, counts.slot2),
        view_inv_slot_count_input(set_id, 3, counts.slot3),
        view_inv_slot_count_input(set_id, 4, counts.slot4),
      ]
      False -> [
        view_inv_slot_checkbox(set_id, 1, slots.slot1),
        view_inv_slot_checkbox(set_id, 2, slots.slot2),
        view_inv_slot_checkbox(set_id, 3, slots.slot3),
        view_inv_slot_checkbox(set_id, 4, slots.slot4),
      ]
    }),
    div([class("col-progress")], [
      text(int.to_string(owned_count) <> "/" <> int.to_string(needed)),
    ]),
  ])
}

fn view_inv_slot_checkbox(set_id: SetId, slot: Int, is_checked: Bool) -> Element(Msg) {
  input([
    type_("checkbox"),
    checked(is_checked),
    on_click(InventoryToggleSlot(set_id, slot)),
  ])
}

fn view_inv_slot_count_input(set_id: SetId, slot: Int, count: Int) -> Element(Msg) {
  div([class("slot-count-wrapper")], [
    span([class("slot-label-mobile")], [text("С" <> int.to_string(slot))]),
    input([
      type_("number"),
      class("inv-count-input"),
      value(int.to_string(count)),
      attribute.min("0"),
      on_input(fn(v) { InventorySetCount(set_id, slot, v) }),
    ]),
  ])
}


// ============================================================================
// Панель профилей
// ============================================================================

/// Вкладка "Профили" слева
fn view_profiles_tab(model: Model) -> Element(Msg) {
  let tab_class = case model.profiles_panel_open {
    True -> "profiles-side-tab hidden"
    False -> "profiles-side-tab"
  }

  button([class(tab_class), on_click(ToggleProfilesPanel)], [
    text("Профили"),
  ])
}

/// Панель профилей (слева)
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

/// Заголовок панели профилей
fn view_profiles_header() -> Element(Msg) {
  div([class("profiles-header")], [
    h2([], [text("Профили инвентаря")]),
    button([class("panel-close-btn"), on_click(ToggleProfilesPanel)], [
      text("x"),
    ]),
  ])
}

/// Секция сохранения профиля
fn view_save_profile_section(model: Model) -> Element(Msg) {
  let is_full = list.length(model.saved_profiles) >= max_profiles
  let stats = get_stats(model.inventory)

  div([class("save-profile-section")], [
    div([class("current-inventory-stats")], [
      html.p([], [text("Текущий инвентарь:")]),
      span([class("stat-item")], [text("Всего: " <> int.to_string(stats.total))]),
      span([class("stat-item blue")], [text("С: " <> int.to_string(stats.blue))]),
      span([class("stat-item green")], [text("З: " <> int.to_string(stats.green))]),
      span([class("stat-item purple")], [text("Ф: " <> int.to_string(stats.purple))]),
    ]),
    button(
      [
        class("save-profile-btn"),
        on_click(OpenProfileSaveDialog),
        attribute.disabled(is_full),
      ],
      [text(case is_full {
        True -> "Лимит профилей (" <> int.to_string(max_profiles) <> ")"
        False -> "Сохранить текущий"
      })],
    ),
  ])
}

/// Список профилей
fn view_profiles_list(model: Model) -> Element(Msg) {
  case list.length(model.saved_profiles) {
    0 -> div([class("no-profiles-message")], [
      text("Нет сохранённых профилей"),
    ])
    _ -> div([class("profiles-list")],
      list.map(model.saved_profiles, view_profile_item)
    )
  }
}

/// Один профиль в списке
fn view_profile_item(profile: Profile) -> Element(Msg) {
  let stats = get_stats(profile.inventory)

  div([class("profile-item")], [
    div([class("profile-info")], [
      span([class("profile-name")], [text(profile.name)]),
      div([class("profile-stats")], [
        span([class("stat-item")], [text("Всего: " <> int.to_string(stats.total))]),
        span([class("stat-item blue")], [text("С: " <> int.to_string(stats.blue))]),
        span([class("stat-item green")], [text("З: " <> int.to_string(stats.green))]),
        span([class("stat-item purple")], [text("Ф: " <> int.to_string(stats.purple))]),
      ]),
    ]),
    div([class("profile-actions")], [
      button([class("load-profile-btn"), on_click(LoadProfile(profile.id))], [
        text("Загрузить"),
      ]),
      button([class("delete-profile-btn"), on_click(DeleteProfile(profile.id))], [
        text("x"),
      ]),
    ]),
  ])
}

/// Диалог сохранения профиля
fn view_profile_save_dialog(model: Model) -> Element(Msg) {
  case model.profile_save_dialog_open {
    False -> element.none()
    True -> {
      let stats = get_stats(model.inventory)

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
              html.h3([], [text("Статистика инвентаря")]),
              html.p([], [text("Всего вещей: " <> int.to_string(stats.total))]),
              html.p([class("blue")], [text("Синих: " <> int.to_string(stats.blue))]),
              html.p([class("green")], [text("Зелёных: " <> int.to_string(stats.green))]),
              html.p([class("purple")], [text("Фиолетовых: " <> int.to_string(stats.purple))]),
            ]),
          ]),
          div([class("dialog-actions")], [
            button([class("btn btn-secondary cancel-btn"), on_click(CloseProfileSaveDialog)], [
              text("Отмена"),
            ]),
            button([class("btn btn-primary"), on_click(SaveCurrentProfile)], [
              text("Сохранить"),
            ]),
          ]),
        ]),
      ])
    }
  }
}

