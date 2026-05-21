import app_model.{
  type AppModel, type AppMsg, AppModel, ArmyMsg, BpMsg, ItemsMsg, NavigateTo,
  SetsMsg, ToggleTheme,
}
import army_simulator/army_model
import army_simulator/army_update
import bp_calculator/bp_update
import items_calculator/game_data
import items_calculator/items_update
import lustre/effect.{type Effect}
import sets_calculator/sets_model
import sets_calculator/sets_update
import theme.{Dark, Light}

pub fn update(model: AppModel, msg: AppMsg) -> #(AppModel, Effect(AppMsg)) {
  case msg {
    // Навигация
    NavigateTo(route) -> {
      #(AppModel(..model, route: route), effect.none())
    }

    // Переключение темы
    ToggleTheme -> {
      let new_theme = case model.theme {
        Light -> Dark
        Dark -> Light
      }
      theme.save(new_theme)
      #(AppModel(..model, theme: new_theme), effect.none())
    }

    // Делегирование в BP калькулятор
    BpMsg(bp_msg) -> {
      let new_bp_model = bp_update.update(model.bp_model, bp_msg)
      #(AppModel(..model, bp_model: new_bp_model), effect.none())
    }

    // Делегирование в Items калькулятор
    ItemsMsg(items_msg) -> {
      let new_items_model = items_update.update(model.items_model, items_msg)
      // Синхронизация темы с фракцией из Items калькулятора
      let new_theme = case new_items_model.selected_faction {
        game_data.Light -> Light
        game_data.Dark -> Dark
      }
      // Сохраняем тему только если она изменилась
      case new_theme != model.theme {
        True -> theme.save(new_theme)
        False -> Nil
      }
      #(
        AppModel(..model, items_model: new_items_model, theme: new_theme),
        effect.none(),
      )
    }

    // Делегирование в Sets калькулятор
    SetsMsg(sets_msg) -> {
      let #(new_sets_model, sets_effect) =
        sets_update.update(model.sets_model, sets_msg)
      // Синхронизируем инвентарь с army_model
      let new_army_model =
        army_update.sync_inventory(model.army_model, new_sets_model.inventory)
      // Синхронизируем профили с army_model
      let new_army_model =
        army_model.Model(
          ..new_army_model,
          saved_profiles: new_sets_model.saved_profiles,
        )
      #(
        AppModel(
          ..model,
          sets_model: new_sets_model,
          army_model: new_army_model,
        ),
        effect.map(sets_effect, SetsMsg),
      )
    }

    // Делегирование в Army симулятор
    ArmyMsg(army_msg) -> {
      let #(new_army_model, army_effect) =
        army_update.update(model.army_model, army_msg)
      // Синхронизируем инвентарь с sets_model
      let new_sets_model =
        sets_update.sync_inventory(model.sets_model, new_army_model.inventory)
      // Синхронизируем профили с sets_model
      let new_sets_model =
        sets_model.Model(
          ..new_sets_model,
          saved_profiles: new_army_model.saved_profiles,
        )
      #(
        AppModel(
          ..model,
          army_model: new_army_model,
          sets_model: new_sets_model,
        ),
        effect.map(army_effect, ArmyMsg),
      )
    }
  }
}
