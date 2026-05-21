import app_model.{
  type AppModel, type AppMsg, ArmyMsg, ArmySimulatorRoute, BattlePassRoute,
  BpMsg, ItemsGradeRoute, ItemsMsg, NavigateTo, SetsCalculatorRoute, SetsMsg,
  ToggleTheme,
}
import army_simulator/army_model.{ToggleProfilesPanel}
import army_simulator/army_view
import bp_calculator/bp_view
import gleam/int
import gleam/list
import items_calculator/items_view
import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, nav}
import lustre/event.{on_click}
import sets_calculator/sets_view
import theme.{Dark, Light}

pub fn view(model: AppModel) -> Element(AppMsg) {
  let theme_class = "app-container " <> theme.theme_class(model.theme)

  div([class(theme_class)], [
    // Навигационная панель
    navigation(model),
    // Контент текущего калькулятора
    div([class("calculator-content")], [
      case model.route {
        BattlePassRoute ->
          // Маппинг сообщений BP калькулятора
          element.map(bp_view.view(model.bp_model), BpMsg)

        ItemsGradeRoute ->
          // Маппинг сообщений Items калькулятора
          element.map(items_view.view(model.items_model), ItemsMsg)

        SetsCalculatorRoute ->
          // Маппинг сообщений Sets калькулятора
          element.map(sets_view.view(model.sets_model), SetsMsg)

        ArmySimulatorRoute ->
          // Маппинг сообщений Army симулятора
          element.map(army_view.view(model.army_model), ArmyMsg)
      },
    ]),
  ])
}

/// Навигационная панель
fn navigation(model: AppModel) -> Element(AppMsg) {
  nav([class("main-nav")], [
    div([class("nav-tabs")], [
      button(
        [
          class(nav_button_class(model.route == BattlePassRoute)),
          on_click(NavigateTo(BattlePassRoute)),
        ],
        [text("Боевой пропуск")],
      ),
      button(
        [
          class(nav_button_class(model.route == ItemsGradeRoute)),
          on_click(NavigateTo(ItemsGradeRoute)),
        ],
        [text("Улучшение предметов")],
      ),
      button(
        [
          class(nav_button_class(model.route == SetsCalculatorRoute)),
          on_click(NavigateTo(SetsCalculatorRoute)),
        ],
        [text("Шансы выпадения предметов")],
      ),
      button(
        [
          class(nav_button_class(model.route == ArmySimulatorRoute)),
          on_click(NavigateTo(ArmySimulatorRoute)),
        ],
        [text("Симуляция прокачки")],
      ),
    ]),

    // Правая часть навигации
    div([class("nav-right")], [
      // Кнопка профилей (только для симулятора прокачки)
      case model.route {
        ArmySimulatorRoute -> {
          let count = list.length(model.army_model.saved_profiles)
          button(
            [class("profiles-button"), on_click(ArmyMsg(ToggleProfilesPanel))],
            [text("Профили (" <> int.to_string(count) <> ")")],
          )
        }
        _ -> element.none()
      },
      // Ссылка обратной связи
      a(
        [
          class("feedback-link"),
          attribute.href("https://t.me/radionest"),
          attribute.target("_blank"),
        ],
        [text("Обратная связь")],
      ),
      // Переключатель темы
      button(
        [
          class("theme-btn"),
          on_click(ToggleTheme),
        ],
        [
          text(case model.theme {
            Light -> "Тьма"
            Dark -> "Свет"
          }),
        ],
      ),
    ]),
  ])
}

fn nav_button_class(is_active: Bool) -> String {
  case is_active {
    True -> "nav-tab active"
    False -> "nav-tab"
  }
}
