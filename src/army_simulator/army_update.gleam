import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/effect.{type Effect}
import army_simulator/army_model.{
  type Model, type Msg, CloseSaveDialog, CloseProfileSaveDialog, CloseSettingsMenu,
  CloseInventoryStatsMenu, CloseInventorySettingsMenu,
  ComparisonState, CopyShareLink, DeleteProfile, DeleteSimulation,
  HideShareNotification, InventoryClearAll, InventoryFillAll,
  InventorySetFilterColor, InventorySetFilterFaction, InventoryToggleSlot, LoadProfile, Model,
  OpenProfileSaveDialog, OpenSaveDialog, Profile, ProfilesLoaded, RunSimulation,
  SaveCurrentProfile, SaveCurrentSimulation, SavedSimulation, SelectFaction,
  SetBaseSimulation, SetBluePerMonth, SetChartDropSystem, SetGreenPerMonth,
  SetMonths, SetNumSimulations, SetProfileName, SetPurplePerMonth,
  SetSimulationName, SetViewMode, ShareLinkCopied, ShareLinkError,
  SimulationProgress, SimulationResult,
  SimulationsLoaded, ToggleComparisonPanel, ToggleInventoryPanel,
  ToggleInventorySettingsMenu, ToggleInventoryStatsMenu,
  TogglePercentiles, ToggleProfilesPanel, ToggleSettingsMenu,
  ToggleSimulationVisibility,
  WorkerError, WorkerReady,
}
import army_simulator/army_worker
import army_simulator/army_storage
import items_calculator/game_data
import sets_calculator/sets_inventory.{type Inventory}
import sets_calculator/sets_storage
import sets_calculator/sets_game_data
import sets_calculator/sets_uri
import plinth/browser/clipboard

// FFI для генерации ID
@external(javascript, "../army_ffi.mjs", "generateSimulationId")
fn generate_id() -> String

@external(javascript, "../army_ffi.mjs", "currentTimestamp")
fn current_timestamp() -> Int

/// Синхронизация инвентаря (вызывается из app_update)
pub fn sync_inventory(model: Model, inventory: Inventory) -> Model {
  Model(..model, inventory: inventory)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SelectFaction(faction_str) -> {
      let faction = game_data.string_to_faction(faction_str)
      #(Model(..model, selected_faction: faction), effect.none())
    }

    SetBluePerMonth(value) -> {
      case int.parse(value) {
        Ok(n) -> {
          let new_params = army_model.SimulationParams(..model.params, blue_per_month: n)
          #(Model(..model, params: new_params), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }

    SetGreenPerMonth(value) -> {
      case int.parse(value) {
        Ok(n) -> {
          let new_params = army_model.SimulationParams(..model.params, green_per_month: n)
          #(Model(..model, params: new_params), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }

    SetPurplePerMonth(value) -> {
      case int.parse(value) {
        Ok(n) -> {
          let new_params = army_model.SimulationParams(..model.params, purple_per_month: n)
          #(Model(..model, params: new_params), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }

    SetMonths(value) -> {
      case int.parse(value) {
        Ok(n) -> {
          let new_params = army_model.SimulationParams(..model.params, months: n)
          #(Model(..model, params: new_params), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }

    SetNumSimulations(value) -> {
      case int.parse(value) {
        Ok(n) -> {
          let new_params = army_model.SimulationParams(..model.params, num_simulations: n)
          #(Model(..model, params: new_params), effect.none())
        }
        Error(_) -> #(model, effect.none())
      }
    }

    RunSimulation -> {
      case model.worker {
        Some(w) -> {
          army_worker.run_simulation(w, model.params, model.selected_faction, model.inventory)
          #(
            Model(..model, is_computing: True, progress: 0.0, comparison_result: None, equipment_curve_result: None, error_message: None),
            effect.none(),
          )
        }
        None -> {
          // Worker ещё не готов, инициализируем
          #(
            Model(..model, is_computing: True, progress: 0.0, error_message: None),
            army_worker.init_worker(),
          )
        }
      }
    }

    WorkerReady(w) -> {
      // Worker готов, если уже ждём вычислений - запускаем
      case model.is_computing {
        True -> {
          army_worker.run_simulation(w, model.params, model.selected_faction, model.inventory)
          #(Model(..model, worker: Some(w)), effect.none())
        }
        False -> #(Model(..model, worker: Some(w)), effect.none())
      }
    }

    SimulationProgress(progress) -> {
      #(Model(..model, progress: progress), effect.none())
    }

    SimulationResult(result, eq_curve) -> {
      #(
        Model(..model, comparison_result: Some(result), equipment_curve_result: eq_curve, is_computing: False, progress: 1.0),
        effect.none(),
      )
    }

    WorkerError(err) -> {
      #(Model(..model, is_computing: False, error_message: option.Some("Ошибка: " <> err)), effect.none())
    }

    SetViewMode(mode) -> {
      #(Model(..model, view_mode: mode), effect.none())
    }

    ToggleInventoryPanel -> {
      #(Model(..model, inventory_panel_open: !model.inventory_panel_open), effect.none())
    }

    InventoryToggleSlot(set_id, slot) -> {
      let new_inventory = sets_inventory.toggle_slot(model.inventory, set_id, slot)
      sets_storage.save(new_inventory)
      #(Model(..model, inventory: new_inventory), effect.none())
    }

    InventorySetFilterColor(color_opt) -> {
      #(Model(..model, inventory_filter_color: color_opt), effect.none())
    }

    InventoryFillAll -> {
      // Получаем все сеты и фильтруем по фильтру фракции (или selected_faction по умолчанию)
      let all_sets = sets_game_data.generate_all_set_ids()
      let faction_filter = case model.inventory_filter_faction {
        Some(f) -> Some(f)
        None -> Some(model.selected_faction)
      }
      let filtered = sets_game_data.filter_sets(
        all_sets,
        faction_filter,
        model.inventory_filter_color,
      )
      let new_inv = sets_inventory.fill_all_slots(model.inventory, filtered)
      sets_storage.save(new_inv)
      #(Model(..model, inventory: new_inv), effect.none())
    }

    InventoryClearAll -> {
      let all_sets = sets_game_data.generate_all_set_ids()
      let faction_filter = case model.inventory_filter_faction {
        Some(f) -> Some(f)
        None -> Some(model.selected_faction)
      }
      let filtered = sets_game_data.filter_sets(
        all_sets,
        faction_filter,
        model.inventory_filter_color,
      )
      let new_inv = sets_inventory.clear_all_slots(model.inventory, filtered)
      sets_storage.save(new_inv)
      #(Model(..model, inventory: new_inv), effect.none())
    }

    // === Сохранение симуляций ===
    OpenSaveDialog -> {
      let default_name =
        "Симуляция " <> int.to_string(
          list.length(model.comparison_state.saved_simulations) + 1,
        )
      #(
        Model(..model, save_dialog_open: True, pending_simulation_name: default_name),
        effect.none(),
      )
    }

    CloseSaveDialog -> {
      #(Model(..model, save_dialog_open: False), effect.none())
    }

    SetSimulationName(name) -> {
      #(Model(..model, pending_simulation_name: name), effect.none())
    }

    SaveCurrentSimulation -> {
      case model.comparison_result {
        Some(result) -> {
          let snapshot = army_worker.calculate_initial_sets(model.inventory, model.selected_faction)
          let new_sim =
            SavedSimulation(
              id: generate_id(),
              name: model.pending_simulation_name,
              params: model.params,
              faction: model.selected_faction,
              initial_sets: snapshot,
              result: result,
              created_at: current_timestamp(),
            )
          let new_sims =
            army_storage.add_simulation(
              model.comparison_state.saved_simulations,
              new_sim,
            )
          army_storage.save(new_sims)
          let new_state =
            ComparisonState(..model.comparison_state, saved_simulations: new_sims)
          #(
            Model(..model, comparison_state: new_state, save_dialog_open: False),
            effect.none(),
          )
        }
        None -> #(model, effect.none())
      }
    }

    DeleteSimulation(id) -> {
      let new_sims =
        army_storage.remove_simulation(model.comparison_state.saved_simulations, id)
      army_storage.save(new_sims)
      // Убираем из visible_ids и base_id если нужно
      let new_visible =
        list.filter(model.comparison_state.visible_ids, fn(vid) { vid != id })
      let new_base = case model.comparison_state.base_id {
        Some(base_id) if base_id == id -> None
        other -> other
      }
      let new_state =
        ComparisonState(
          ..model.comparison_state,
          saved_simulations: new_sims,
          visible_ids: new_visible,
          base_id: new_base,
        )
      #(Model(..model, comparison_state: new_state), effect.none())
    }

    // === Сравнение симуляций ===
    ToggleSimulationVisibility(id) -> {
      let visible = model.comparison_state.visible_ids
      let new_visible = case list.contains(visible, id) {
        True -> list.filter(visible, fn(v) { v != id })
        False -> [id, ..visible]
      }
      let new_state =
        ComparisonState(..model.comparison_state, visible_ids: new_visible)
      #(Model(..model, comparison_state: new_state), effect.none())
    }

    SetBaseSimulation(id) -> {
      let new_state =
        ComparisonState(..model.comparison_state, base_id: Some(id))
      #(Model(..model, comparison_state: new_state), effect.none())
    }

    SetChartDropSystem(system) -> {
      let new_state =
        ComparisonState(..model.comparison_state, chart_system: system)
      #(Model(..model, comparison_state: new_state), effect.none())
    }

    ToggleComparisonPanel -> {
      #(
        Model(..model, comparison_panel_open: !model.comparison_panel_open),
        effect.none(),
      )
    }

    SimulationsLoaded(sims) -> {
      let new_state =
        ComparisonState(..model.comparison_state, saved_simulations: sims)
      #(Model(..model, comparison_state: new_state), effect.none())
    }

    // === Управление профилями ===
    ToggleProfilesPanel -> {
      #(
        Model(..model, profiles_panel_open: !model.profiles_panel_open),
        effect.none(),
      )
    }

    OpenProfileSaveDialog -> {
      let default_name =
        "Профиль " <> int.to_string(list.length(model.saved_profiles) + 1)
      #(
        Model(..model, profile_save_dialog_open: True, pending_profile_name: default_name),
        effect.none(),
      )
    }

    CloseProfileSaveDialog -> {
      #(Model(..model, profile_save_dialog_open: False), effect.none())
    }

    SetProfileName(name) -> {
      #(Model(..model, pending_profile_name: name), effect.none())
    }

    SaveCurrentProfile -> {
      let new_profile =
        Profile(
          id: generate_id(),
          name: model.pending_profile_name,
          inventory: model.inventory,
          created_at: current_timestamp(),
        )
      let new_profiles = army_storage.add_profile(model.saved_profiles, new_profile)
      army_storage.save_profiles(new_profiles)
      #(
        Model(..model, saved_profiles: new_profiles, profile_save_dialog_open: False),
        effect.none(),
      )
    }

    LoadProfile(id) -> {
      case army_storage.find_profile_by_id(model.saved_profiles, id) {
        Some(profile) -> {
          // Сохраняем инвентарь профиля в глобальное хранилище
          sets_storage.save(profile.inventory)
          #(Model(..model, inventory: profile.inventory), effect.none())
        }
        None -> #(model, effect.none())
      }
    }

    DeleteProfile(id) -> {
      let new_profiles = army_storage.remove_profile(model.saved_profiles, id)
      army_storage.save_profiles(new_profiles)
      #(Model(..model, saved_profiles: new_profiles), effect.none())
    }

    ProfilesLoaded(profiles) -> {
      #(Model(..model, saved_profiles: profiles), effect.none())
    }

    // === Меню настроек симуляции ===
    ToggleSettingsMenu -> {
      #(Model(..model, settings_menu_open: !model.settings_menu_open), effect.none())
    }

    CloseSettingsMenu -> {
      #(Model(..model, settings_menu_open: False), effect.none())
    }

    // === Меню статистики инвентаря ===
    ToggleInventoryStatsMenu -> {
      #(Model(..model, inventory_stats_menu_open: !model.inventory_stats_menu_open), effect.none())
    }

    CloseInventoryStatsMenu -> {
      #(Model(..model, inventory_stats_menu_open: False), effect.none())
    }

    // === Фильтр инвентаря по фракции ===
    InventorySetFilterFaction(faction_opt) -> {
      #(Model(..model, inventory_filter_faction: faction_opt), effect.none())
    }

    // === Share инвентаря ===
    CopyShareLink -> {
      let url = sets_uri.generate_share_url(model.inventory)
      // Копируем в буфер обмена (результат Promise игнорируем)
      let _ = clipboard.write_text(url)
      // Показываем уведомление сразу (оптимистично)
      #(Model(..model, share_notification: Some("Ссылка скопирована!")), effect.none())
    }

    ShareLinkCopied -> {
      #(Model(..model, share_notification: Some("Ссылка скопирована!")), effect.none())
    }

    ShareLinkError(_) -> {
      #(Model(..model, share_notification: Some("Ошибка копирования")), effect.none())
    }

    HideShareNotification -> {
      #(Model(..model, share_notification: None), effect.none())
    }

    // === Меню настроек инвентаря ===
    ToggleInventorySettingsMenu -> {
      #(Model(..model, inventory_settings_menu_open: !model.inventory_settings_menu_open), effect.none())
    }

    CloseInventorySettingsMenu -> {
      #(Model(..model, inventory_settings_menu_open: False), effect.none())
    }

    TogglePercentiles -> {
      #(Model(..model, show_percentiles: !model.show_percentiles), effect.none())
    }
  }
}

/// Эффект загрузки симуляций из localStorage
pub fn load_saved_simulations() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let sims = army_storage.load()
    dispatch(SimulationsLoaded(sims))
  })
}

/// Эффект загрузки профилей из localStorage
pub fn load_saved_profiles() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    let profiles = army_storage.load_profiles()
    dispatch(ProfilesLoaded(profiles))
  })
}
