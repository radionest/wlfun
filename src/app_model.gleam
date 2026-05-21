import army_simulator/army_model
import army_simulator/army_update
import bp_calculator/bp_model
import items_calculator/items_model
import lustre/effect.{type Effect}
import sets_calculator/sets_model
import sets_calculator/sets_storage
import sets_calculator/sets_uri
import sets_calculator/sets_worker
import theme.{type Theme}

/// Маршруты приложения
pub type Route {
  BattlePassRoute
  ItemsGradeRoute
  SetsCalculatorRoute
  ArmySimulatorRoute
}

/// Корневая модель SPA
pub type AppModel {
  AppModel(
    route: Route,
    theme: Theme,
    bp_model: bp_model.Model,
    items_model: items_model.Model,
    sets_model: sets_model.Model,
    army_model: army_model.Model,
  )
}

/// Корневые сообщения
pub type AppMsg {
  // Навигация
  NavigateTo(Route)

  // Переключение темы
  ToggleTheme

  // Делегирование сообщений в калькуляторы
  BpMsg(bp_model.Msg)
  ItemsMsg(items_model.Msg)
  SetsMsg(sets_model.Msg)
  ArmyMsg(army_model.Msg)
}

/// Инициализация с загрузкой сохраненных данных
pub fn init(_flags) -> #(AppModel, Effect(AppMsg)) {
  let saved_theme = theme.load()

  // Приоритет: URL hash > localStorage
  let inventory = case sets_uri.parse_url_hash() {
    Ok(inv) -> inv
    Error(_) -> sets_storage.load()
  }

  let model =
    AppModel(
      route: ItemsGradeRoute,
      theme: saved_theme,
      bp_model: bp_model.init(),
      items_model: items_model.init(),
      sets_model: sets_model.init_with_inventory(inventory),
      army_model: army_model.init_with_inventory(inventory),
    )

  // Инициализируем Web Worker для sets_calculator
  let init_worker_effect = effect.map(sets_worker.init_worker(), SetsMsg)

  // Загружаем сохранённые симуляции для army_simulator
  let load_sims_effect =
    effect.map(army_update.load_saved_simulations(), ArmyMsg)

  // Загружаем сохранённые профили для army_simulator
  let load_profiles_effect =
    effect.map(army_update.load_saved_profiles(), ArmyMsg)

  #(
    model,
    effect.batch([init_worker_effect, load_sims_effect, load_profiles_effect]),
  )
}
