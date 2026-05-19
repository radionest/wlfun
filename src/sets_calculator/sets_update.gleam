import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}
import items_calculator/game_data.{type ItemColor, Light, Dark}
import sets_calculator/sets_model.{
  type Model, type Msg, type TreeNodeId, type ActiveGoal, Model, ActiveGoal,
  FactionNode, EntityNode,
  GoalSpecificSet, GoalAnySetOnEntity, GoalAnySetOnFaction, GoalFirstSetOfColor,
  GoalDuplicates,
  SetGoalType, SelectFaction, SelectEntity, SelectEntityType, SelectColor,
  SelectSetNumber, ToggleOwnedSlot, SetMaxAttempts, ResetOwnedSlots,
  ToggleInventorySection, InventoryToggleSlot, InventorySetFilterFaction,
  InventorySetFilterColor, InventorySetCount, SetMinDuplicates, SetMinItems,
  ToggleBootstrapAutoUpdate, RunBootstrap, SetViewMode,
  WorkerReady, ComputationResult, WorkerError,
  CopyShareLink, ShareLinkCopied, ShareLinkError, HideShareNotification,
  ToggleSettingsMenu, CloseSettingsMenu,
  ToggleInventorySettingsMenu, CloseInventorySettingsMenu,
  InventoryFillAll, InventoryClearAll, InventoryResetCounts,
  ToggleInventoryStatsMenu, CloseInventoryStatsMenu,
  // Новые сообщения для панели целей
  ToggleSpecificSetGoal, ToggleAnyFactionGoal, ToggleDuplicatesGoal,
  SetAnyFactionFaction, ToggleTreeNode, ToggleSetSelection,
  SelectAllInNode, DeselectAllInNode,
  // Боковая панель инвентаря
  ToggleInventoryPanel,
  // Профили
  ToggleProfilesPanel, OpenProfileSaveDialog, CloseProfileSaveDialog,
  SetProfileName, SaveCurrentProfile, LoadProfile, DeleteProfile, ProfilesLoaded,
  string_to_goal_type,
}
import army_simulator/army_model.{Profile}
import army_simulator/army_storage
import sets_calculator/sets_chart
import sets_calculator/sets_uri
import plinth/browser/clipboard
import sets_calculator/sets_inventory.{empty_slots, empty_counts}
import sets_calculator/sets_game_data.{
  type EntityType, type SetId, SetId,
  string_to_entity_type, generate_all_set_ids, filter_sets,
}
import sets_calculator/sets_probability
import sets_calculator/sets_storage

// FFI для генерации ID и timestamp (используем те же что в army)
@external(javascript, "../army_ffi.mjs", "generateSimulationId")
fn generate_id() -> String

@external(javascript, "../army_ffi.mjs", "currentTimestamp")
fn current_timestamp() -> Int

/// Синхронизация инвентаря (вызывается из app_update)
pub fn sync_inventory(model: Model, inventory: sets_inventory.Inventory) -> Model {
  // Обновляем инвентарь и синхронизируем owned_slots/counts для текущего выбранного сета
  case model.selected_entity {
    Some(name) -> {
      let entity_type = sets_game_data.detect_entity_type(name)
      let set_id = SetId(name, entity_type, model.selected_color, model.selected_set_number)
      let slots = sets_inventory.get_slots(inventory, set_id)
      let counts = sets_inventory.get_counts(inventory, set_id)
      Model(..model, inventory: inventory, owned_slots: slots, owned_counts: counts)
    }
    None -> Model(..model, inventory: inventory)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let new_model = case msg {
    SetGoalType(goal_str) -> {
      let goal = string_to_goal_type(goal_str)
      // При смене типа цели сбрасываем некоторые поля
      case goal {
        GoalFirstSetOfColor ->
          Model(
            ..model,
            goal_type: goal,
            selected_faction: None,
            selected_entity: None,
            owned_slots: empty_slots(),
            owned_counts: empty_counts(),
          )
        GoalAnySetOnFaction ->
          Model(
            ..model,
            goal_type: goal,
            selected_entity: None,
            owned_slots: empty_slots(),
            owned_counts: empty_counts(),
          )
        GoalAnySetOnEntity ->
          Model(..model, goal_type: goal, owned_slots: empty_slots(), owned_counts: empty_counts())
        GoalSpecificSet -> Model(..model, goal_type: goal)
        GoalDuplicates ->
          Model(
            ..model,
            goal_type: goal,
            selected_faction: None,
            selected_entity: None,
            owned_slots: empty_slots(),
            owned_counts: empty_counts(),
          )
      }
    }

    SelectFaction(faction_str) -> {
      let faction = game_data.string_to_faction(faction_str)
      Model(
        ..model,
        selected_faction: Some(faction),
        selected_entity: None,
        owned_slots: empty_slots(),
        owned_counts: empty_counts(),
      )
    }

    SelectEntity(name) -> {
      case name {
        "" -> Model(..model, selected_entity: None, owned_slots: empty_slots(), owned_counts: empty_counts())
        _ -> {
          // Автоподстановка из инвентаря
          let set_id = make_set_id(name, model.selected_entity_type, model.selected_color, model.selected_set_number)
          let slots = sets_inventory.get_slots(model.inventory, set_id)
          let counts = sets_inventory.get_counts(model.inventory, set_id)
          Model(..model, selected_entity: Some(name), owned_slots: slots, owned_counts: counts)
        }
      }
    }

    SelectEntityType(type_str) -> {
      let entity_type = string_to_entity_type(type_str)
      Model(
        ..model,
        selected_entity_type: entity_type,
        selected_entity: None,
        owned_slots: empty_slots(),
        owned_counts: empty_counts(),
      )
    }

    SelectColor(color_str) -> {
      let color = game_data.string_to_color(color_str)
      let new_model = Model(..model, selected_color: color, selected_sets: [])
      sync_from_inventory(new_model)
    }

    SelectSetNumber(num) -> {
      let set_num = case num {
        1 -> 1
        _ -> 2
      }
      let new_model = Model(..model, selected_set_number: set_num)
      sync_from_inventory(new_model)
    }

    ToggleOwnedSlot(slot) -> {
      // Переключаем слот через инвентарь (set_slots теперь работает через counts)
      let new_inventory = case make_current_set_id(model) {
        Some(set_id) -> sets_inventory.toggle_slot(model.inventory, set_id, slot)
        None -> model.inventory
      }
      sets_storage.save(new_inventory)
      sets_uri.set_url_hash(new_inventory)
      // Синхронизируем локальные owned_slots и owned_counts
      case make_current_set_id(model) {
        Some(set_id) -> {
          let new_slots = sets_inventory.get_slots(new_inventory, set_id)
          let new_counts = sets_inventory.get_counts(new_inventory, set_id)
          Model(..model, owned_slots: new_slots, owned_counts: new_counts, inventory: new_inventory)
        }
        None -> Model(..model, inventory: new_inventory)
      }
    }

    SetMaxAttempts(attempts_str) -> {
      case int.parse(attempts_str) {
        Ok(n) if n >= 1 && n <= 1000 ->
          Model(..model, max_attempts: n, max_attempts_str: attempts_str)
        Ok(_) -> Model(..model, max_attempts_str: attempts_str)
        Error(_) -> Model(..model, max_attempts_str: attempts_str)
      }
    }

    ResetOwnedSlots -> {
      // Очищаем слоты через инвентарь
      let new_inventory = case make_current_set_id(model) {
        Some(set_id) -> sets_inventory.set_counts(model.inventory, set_id, empty_counts())
        None -> model.inventory
      }
      sets_storage.save(new_inventory)
      sets_uri.set_url_hash(new_inventory)
      Model(..model, owned_slots: empty_slots(), owned_counts: empty_counts(), inventory: new_inventory)
    }

    ToggleInventorySection -> {
      Model(..model, inventory_expanded: !model.inventory_expanded)
    }

    InventoryToggleSlot(set_id, slot) -> {
      let new_inventory = sets_inventory.toggle_slot(model.inventory, set_id, slot)
      sets_storage.save(new_inventory)
      sets_uri.set_url_hash(new_inventory)
      // Если это текущий выбранный сет - синхронизировать owned_slots и counts
      case is_current_set(model, set_id) {
        True -> {
          let new_slots = sets_inventory.get_slots(new_inventory, set_id)
          let new_counts = sets_inventory.get_counts(new_inventory, set_id)
          Model(..model, inventory: new_inventory, owned_slots: new_slots, owned_counts: new_counts)
        }
        False -> Model(..model, inventory: new_inventory)
      }
    }

    InventorySetFilterFaction(faction_opt) -> {
      Model(..model, inventory_filter_faction: faction_opt)
    }

    InventorySetFilterColor(color_opt) -> {
      Model(..model, inventory_filter_color: color_opt)
    }

    InventorySetCount(set_id, slot, value_str) -> {
      case int.parse(value_str) {
        Ok(n) if n >= 0 -> {
          let new_inventory = sets_inventory.set_slot_count(model.inventory, set_id, slot, n)
          sets_storage.save(new_inventory)
          sets_uri.set_url_hash(new_inventory)
          // Если это текущий выбранный сет - синхронизировать owned_slots и counts
          case is_current_set(model, set_id) {
            True -> {
              let new_slots = sets_inventory.get_slots(new_inventory, set_id)
              let new_counts = sets_inventory.get_counts(new_inventory, set_id)
              Model(..model, inventory: new_inventory, owned_slots: new_slots, owned_counts: new_counts)
            }
            False -> Model(..model, inventory: new_inventory)
          }
        }
        _ -> model
      }
    }

    SetMinDuplicates(str) -> {
      case int.parse(str) {
        Ok(n) if n >= 1 && n <= 50 ->
          Model(..model, min_duplicates_per_item: n, min_duplicates_str: str)
        Ok(_) -> Model(..model, min_duplicates_str: str)
        Error(_) -> Model(..model, min_duplicates_str: str)
      }
    }

    SetMinItems(str) -> {
      case int.parse(str) {
        Ok(n) if n >= 1 && n <= 288 ->
          Model(..model, min_items_with_duplicates: n, min_items_str: str)
        Ok(_) -> Model(..model, min_items_str: str)
        Error(_) -> Model(..model, min_items_str: str)
      }
    }

    ToggleBootstrapAutoUpdate -> {
      Model(..model, bootstrap_auto_update: !model.bootstrap_auto_update)
    }

    RunBootstrap -> {
      // Ручной запуск бутстрапа с учётом инвентаря
      let initial_counts = sets_inventory.get_all_counts_list(
        model.inventory,
        model.selected_color,
      )
      let bootstrap = sets_probability.calculate_duplicates_bootstrap_with_inventory(
        model.min_duplicates_per_item,
        model.min_items_with_duplicates,
        model.max_attempts,
        10_000,
        initial_counts,
      )
      Model(..model, bootstrap_curve: Some(bootstrap))
    }

    SetViewMode(mode) -> {
      Model(..model, view_mode: mode)
    }

    // Worker готов к работе
    WorkerReady(wrk) -> {
      // Настраиваем обработчик сообщений
      Model(..model, worker: Some(wrk))
    }

    // Результат вычислений получен
    ComputationResult(analytic, bootstrap) -> {
      Model(
        ..model,
        probability_curve: Some(analytic),
        bootstrap_curve: bootstrap,
        is_computing: False,
      )
    }

    // Ошибка worker
    WorkerError(_err) -> {
      // При ошибке сбрасываем состояние computing
      Model(..model, is_computing: False)
    }

    // Копировать share link
    CopyShareLink -> {
      let url = sets_uri.generate_share_url(model.inventory)
      // Копируем в буфер обмена (результат Promise игнорируем)
      let _ = clipboard.write_text(url)
      // Показываем уведомление сразу (оптимистично)
      Model(..model, share_notification: Some("Ссылка скопирована!"))
    }

    // Share link скопирован успешно
    ShareLinkCopied -> {
      Model(..model, share_notification: Some("Ссылка скопирована!"))
    }

    // Ошибка копирования
    ShareLinkError(err) -> {
      Model(..model, share_notification: Some("Ошибка: " <> err))
    }

    // Скрыть уведомление
    HideShareNotification -> {
      Model(..model, share_notification: None)
    }

    // Переключить меню настроек графика
    ToggleSettingsMenu -> {
      Model(..model, settings_menu_open: !model.settings_menu_open)
    }

    // Закрыть меню настроек (клик вне)
    CloseSettingsMenu -> {
      Model(..model, settings_menu_open: False)
    }

    // Переключить меню настроек инвентаря
    ToggleInventorySettingsMenu -> {
      Model(..model, inventory_settings_menu_open: !model.inventory_settings_menu_open)
    }

    // Закрыть меню настроек инвентаря
    CloseInventorySettingsMenu -> {
      Model(..model, inventory_settings_menu_open: False)
    }

    // Отметить все слоты в текущем фильтре
    InventoryFillAll -> {
      let all_sets = generate_all_set_ids()
      let filtered = filter_sets(all_sets, model.inventory_filter_faction, model.inventory_filter_color)
      let new_inv = sets_inventory.fill_all_slots(model.inventory, filtered)
      sets_storage.save(new_inv)
      sets_uri.set_url_hash(new_inv)
      Model(..model, inventory: new_inv, inventory_settings_menu_open: False)
    }

    // Убрать все слоты в текущем фильтре
    InventoryClearAll -> {
      let all_sets = generate_all_set_ids()
      let filtered = filter_sets(all_sets, model.inventory_filter_faction, model.inventory_filter_color)
      let new_inv = sets_inventory.clear_all_slots(model.inventory, filtered)
      sets_storage.save(new_inv)
      sets_uri.set_url_hash(new_inv)
      Model(..model, inventory: new_inv, inventory_settings_menu_open: False)
    }

    // Сбросить счётчики в текущем фильтре
    InventoryResetCounts -> {
      let all_sets = generate_all_set_ids()
      let filtered = filter_sets(all_sets, model.inventory_filter_faction, model.inventory_filter_color)
      let new_inv = sets_inventory.reset_all_counts(model.inventory, filtered)
      sets_storage.save(new_inv)
      sets_uri.set_url_hash(new_inv)
      Model(..model, inventory: new_inv, inventory_settings_menu_open: False)
    }

    // Переключить меню статистики инвентаря
    ToggleInventoryStatsMenu -> {
      Model(..model, inventory_stats_menu_open: !model.inventory_stats_menu_open)
    }

    // Закрыть меню статистики инвентаря
    CloseInventoryStatsMenu -> {
      Model(..model, inventory_stats_menu_open: False)
    }

    // === Новые обработчики для панели целей ===

    // Переключить чекбокс "Конкретный сет"
    ToggleSpecificSetGoal -> {
      Model(..model, specific_set_enabled: !model.specific_set_enabled)
    }

    // Переключить чекбокс "Любой сет фракции"
    ToggleAnyFactionGoal -> {
      Model(..model, any_faction_enabled: !model.any_faction_enabled)
    }

    // Переключить чекбокс "Дубликаты"
    ToggleDuplicatesGoal -> {
      Model(..model, duplicates_enabled: !model.duplicates_enabled)
    }

    // Выбор фракции для "Любой сет фракции"
    SetAnyFactionFaction(faction_str) -> {
      let faction = case faction_str {
        "dark" -> Dark
        _ -> Light
      }
      Model(..model, any_faction_faction: faction)
    }

    // Раскрыть/свернуть узел дерева
    ToggleTreeNode(node_id) -> {
      let is_expanded = list.contains(model.expanded_tree_nodes, node_id)
      let new_nodes = case is_expanded {
        True -> list.filter(model.expanded_tree_nodes, fn(n) { n != node_id })
        False -> [node_id, ..model.expanded_tree_nodes]
      }
      Model(..model, expanded_tree_nodes: new_nodes)
    }

    // Выбрать/отменить сет в дереве
    ToggleSetSelection(set_id) -> {
      let is_selected = list.contains(model.selected_sets, set_id)
      let new_sets = case is_selected {
        True -> list.filter(model.selected_sets, fn(s) { s != set_id })
        False -> [set_id, ..model.selected_sets]
      }
      Model(..model, selected_sets: new_sets)
    }

    // Выбрать все сеты в узле
    SelectAllInNode(node_id) -> {
      let sets_to_add = get_sets_for_node(model.selected_color, node_id)
      let new_sets = list.fold(sets_to_add, model.selected_sets, fn(acc, s) {
        case list.contains(acc, s) {
          True -> acc
          False -> [s, ..acc]
        }
      })
      Model(..model, selected_sets: new_sets)
    }

    // Отменить все сеты в узле
    DeselectAllInNode(node_id) -> {
      let sets_to_remove = get_sets_for_node(model.selected_color, node_id)
      let new_sets = list.filter(model.selected_sets, fn(s) {
        !list.contains(sets_to_remove, s)
      })
      Model(..model, selected_sets: new_sets)
    }

    // Переключить боковую панель инвентаря
    ToggleInventoryPanel -> {
      Model(..model, inventory_panel_open: !model.inventory_panel_open)
    }

    // === Управление профилями ===
    ToggleProfilesPanel -> {
      Model(..model, profiles_panel_open: !model.profiles_panel_open)
    }

    OpenProfileSaveDialog -> {
      let default_name = "Профиль " <> int.to_string(list.length(model.saved_profiles) + 1)
      Model(..model, profile_save_dialog_open: True, pending_profile_name: default_name)
    }

    CloseProfileSaveDialog -> {
      Model(..model, profile_save_dialog_open: False)
    }

    SetProfileName(name) -> {
      Model(..model, pending_profile_name: name)
    }

    SaveCurrentProfile -> {
      let new_profile = Profile(
        id: generate_id(),
        name: model.pending_profile_name,
        inventory: model.inventory,
        created_at: current_timestamp(),
      )
      let new_profiles = army_storage.add_profile(model.saved_profiles, new_profile)
      army_storage.save_profiles(new_profiles)
      Model(..model, saved_profiles: new_profiles, profile_save_dialog_open: False)
    }

    LoadProfile(id) -> {
      case army_storage.find_profile_by_id(model.saved_profiles, id) {
        Some(profile) -> {
          // Сохраняем инвентарь профиля в глобальное хранилище
          sets_storage.save(profile.inventory)
          sets_uri.set_url_hash(profile.inventory)
          // Синхронизируем owned_slots/counts для текущего сета
          sync_inventory(Model(..model, inventory: profile.inventory), profile.inventory)
        }
        None -> model
      }
    }

    DeleteProfile(id) -> {
      let new_profiles = army_storage.remove_profile(model.saved_profiles, id)
      army_storage.save_profiles(new_profiles)
      Model(..model, saved_profiles: new_profiles)
    }

    ProfilesLoaded(profiles) -> {
      Model(..model, saved_profiles: profiles)
    }
  }

  // Определяем, нужен ли пересчёт для этого сообщения
  let needs_recalculate = case msg {
    WorkerReady(_) | ComputationResult(_, _) | WorkerError(_) -> False
    CopyShareLink | ShareLinkCopied | ShareLinkError(_) | HideShareNotification -> False
    ToggleSettingsMenu | CloseSettingsMenu -> False
    ToggleInventorySettingsMenu | CloseInventorySettingsMenu -> False
    ToggleInventoryStatsMenu | CloseInventoryStatsMenu -> False
    // Раскрытие дерева не требует пересчёта
    ToggleTreeNode(_) -> False
    // Открытие/закрытие панели инвентаря не требует пересчёта
    ToggleInventoryPanel -> False
    // Профили не требуют пересчёта (кроме LoadProfile, который пересчитает через sync_inventory)
    ToggleProfilesPanel | OpenProfileSaveDialog | CloseProfileSaveDialog -> False
    SetProfileName(_) | SaveCurrentProfile | DeleteProfile(_) | ProfilesLoaded(_) -> False
    _ -> True
  }

  case needs_recalculate {
    True -> recalculate(new_model)
    False -> #(new_model, effect.none())
  }
}

fn recalculate(model: Model) -> #(Model, Effect(Msg)) {
  // Строим список активных целей
  let active_goals = build_active_goals(model)

  // Также обновляем старое поле probability_curve для совместимости
  let curve = case model.goal_type {
    GoalDuplicates -> {
      let initial_counts = sets_inventory.get_all_counts_list(
        model.inventory,
        model.selected_color,
      )
      sets_probability.calculate_duplicates_curve_with_inventory(
        model.min_duplicates_per_item,
        model.min_items_with_duplicates,
        model.max_attempts,
        initial_counts,
      )
    }
    _ -> sets_probability.calculate_for_goal(model)
  }

  #(Model(..model, active_goals: active_goals, probability_curve: Some(curve)), effect.none())
}

/// Построить список активных целей с рассчитанными кривыми
fn build_active_goals(model: Model) -> List(ActiveGoal) {
  let colors = sets_chart.chart_colors()
  let mut_index = 0

  // Собираем все активные цели
  let goals = []

  // 1. Выбранные сеты (если включено и выбраны сеты)
  let #(goals, mut_index) = case model.specific_set_enabled && !list.is_empty(model.selected_sets) {
    True -> {
      let color = get_color_at(colors, mut_index)
      let count = list.length(model.selected_sets)

      // Формируем метку
      let label = case count {
        1 -> case list.first(model.selected_sets) {
          Ok(set_id) -> set_id.entity_name <> " Сет " <> int.to_string(set_id.set_number)
          Error(_) -> "Выбранный сет"
        }
        _ -> "Любой из " <> int.to_string(count) <> " сетов"
      }

      let curve = sets_probability.calculate_any_of_sets_curve_with_inventory(
        sets_game_data.pool_size(),
        model.selected_sets,
        model.inventory,
        model.max_attempts,
      )

      let goal = ActiveGoal(
        label: label,
        probability_curve: Some(curve),
        chart_color: color,
      )
      #([goal, ..goals], mut_index + 1)
    }
    False -> #(goals, mut_index)
  }

  // 2. Любой сет фракции (если включено)
  let #(goals, mut_index) = case model.any_faction_enabled {
    True -> {
      let color = get_color_at(colors, mut_index)
      let faction_name = case model.any_faction_faction {
        Light -> "Свет"
        Dark -> "Тьма"
      }
      let label = "Любой сет: " <> faction_name

      let curve = sets_probability.calculate_any_faction_set_curve(
        model.any_faction_faction,
        model.selected_color,
        model.max_attempts,
        model.inventory,
      )

      let goal = ActiveGoal(
        label: label,
        probability_curve: Some(curve),
        chart_color: color,
      )
      #([goal, ..goals], mut_index + 1)
    }
    False -> #(goals, mut_index)
  }

  // 3. Дубликаты (если включено)
  let #(goals, _) = case model.duplicates_enabled {
    True -> {
      let color = get_color_at(colors, mut_index)
      let label = "Дубликаты " <> int.to_string(model.min_duplicates_per_item) <> "x" <> int.to_string(model.min_items_with_duplicates)

      let initial_counts = sets_inventory.get_all_counts_list(
        model.inventory,
        model.selected_color,
      )

      let curve = sets_probability.calculate_duplicates_curve_with_inventory(
        model.min_duplicates_per_item,
        model.min_items_with_duplicates,
        model.max_attempts,
        initial_counts,
      )

      let goal = ActiveGoal(
        label: label,
        probability_curve: Some(curve),
        chart_color: color,
      )
      #([goal, ..goals], mut_index + 1)
    }
    False -> #(goals, mut_index)
  }

  // Возвращаем в правильном порядке
  list.reverse(goals)
}

/// Получить цвет по индексу (с цикличностью)
fn get_color_at(colors: List(String), index: Int) -> String {
  let len = list.length(colors)
  let idx = index % len
  case list.drop(colors, idx) {
    [c, ..] -> c
    [] -> "#6366f1"  // fallback
  }
}

/// Создать SetId из параметров
fn make_set_id(name: String, entity_type: EntityType, color: ItemColor, set_number: Int) -> SetId {
  SetId(
    entity_name: name,
    entity_type: entity_type,
    color: color,
    set_number: set_number,
  )
}

/// Создать SetId для текущего выбранного сета
fn make_current_set_id(model: Model) -> Option(SetId) {
  case model.selected_entity {
    Some(name) -> Some(make_set_id(name, model.selected_entity_type, model.selected_color, model.selected_set_number))
    None -> None
  }
}

/// Проверить, является ли set_id текущим выбранным сетом
fn is_current_set(model: Model, set_id: SetId) -> Bool {
  case make_current_set_id(model) {
    Some(current) -> current == set_id
    None -> False
  }
}

/// Синхронизировать owned_slots и owned_counts из инвентаря для текущего сета
fn sync_from_inventory(model: Model) -> Model {
  case make_current_set_id(model) {
    Some(set_id) -> {
      let slots = sets_inventory.get_slots(model.inventory, set_id)
      let counts = sets_inventory.get_counts(model.inventory, set_id)
      Model(..model, owned_slots: slots, owned_counts: counts)
    }
    None -> Model(..model, owned_slots: empty_slots(), owned_counts: empty_counts())
  }
}

/// Получить все сеты для узла дерева (с учётом редкости)
fn get_sets_for_node(color: ItemColor, node_id: TreeNodeId) -> List(SetId) {
  let all_sets = generate_all_set_ids()
  case node_id {
    FactionNode(faction) -> {
      // Все сеты фракции с данной редкостью
      list.filter(all_sets, fn(s) {
        s.color == color && sets_game_data.entity_belongs_to_faction(s.entity_name, faction)
      })
    }
    EntityNode(_faction, name, entity_type) -> {
      // Сеты конкретного юнита/героя с данной редкостью
      list.filter(all_sets, fn(s) {
        s.color == color &&
        s.entity_name == name &&
        s.entity_type == entity_type
      })
    }
  }
}

/// Эффект загрузки профилей из localStorage
pub fn load_saved_profiles() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let profiles = army_storage.load_profiles()
    dispatch(ProfilesLoaded(profiles))
  })
}
