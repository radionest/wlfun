import gleam/int
import lustre/attribute.{class, id, type_, value, for}
import lustre/element.{type Element, text}
import lustre/element/html.{div, h1, label, input, span, p, button}
import lustre/event
import bp_calculator/bp_model.{type Model, type Msg, CalculateLevel, CalculateDailyPoints}
import bp_calculator/battle_pass

/// Главный view
pub fn view(model: Model) -> Element(Msg) {
  div([class("bp-calculator")], [
    h1([class("title")], [text("Боевой пропуск")]),
    div([class("disclaimer")], [
      text("Калькулятор для старой версии БП. Данные для новой версии будут доступны в начале февраля."),
    ]),
    mode_selector(model),
    input_form(model),
    result_section(model),
  ])
}

/// Переключатель режимов
fn mode_selector(model: Model) -> Element(Msg) {
  let level_class = case model.mode {
    CalculateLevel -> "mode-btn active"
    CalculateDailyPoints -> "mode-btn"
  }
  let daily_class = case model.mode {
    CalculateLevel -> "mode-btn"
    CalculateDailyPoints -> "mode-btn active"
  }

  div([class("form-group mode-select")], [
    label([], [text("Режим расчёта:")]),
    div([class("mode-buttons")], [
      button(
        [class(level_class), event.on_click(bp_model.SetMode(CalculateLevel))],
        [text("Рассчитать уровень")],
      ),
      button(
        [class(daily_class), event.on_click(bp_model.SetMode(CalculateDailyPoints))],
        [text("Рассчитать очки")],
      ),
    ]),
  ])
}

/// Форма ввода
fn input_form(model: Model) -> Element(Msg) {
  let current_level_cost = battle_pass.get_level_cost(model.current_level)

  div([class("form")], [
    // Текущий уровень
    div([class("form-group")], [
      label([for("current-level")], [text("Текущий уровень")]),
      input([
        type_("number"),
        id("current-level"),
        value(model.current_level_str),
        attribute.min("1"),
        attribute.max(int.to_string(battle_pass.max_level)),
        event.on_input(bp_model.SetCurrentLevel),
      ]),
    ]),
    // Прогресс в уровне
    div([class("form-group")], [
      label([for("current-progress")], [
        text("Прогресс в уровне"),
        span([class("hint")], [
          text(" / " <> int.to_string(current_level_cost)),
        ]),
      ]),
      input([
        type_("number"),
        id("current-progress"),
        value(model.current_progress_str),
        attribute.min("0"),
        attribute.max(int.to_string(current_level_cost)),
        event.on_input(bp_model.SetCurrentProgress),
      ]),
    ]),
    // Дней осталось
    div([class("form-group")], [
      label([for("days-remaining")], [text("Дней осталось")]),
      input([
        type_("number"),
        id("days-remaining"),
        value(model.days_remaining_str),
        attribute.min("1"),
        event.on_input(bp_model.SetDaysRemaining),
      ]),
    ]),
    // Недельных наград осталось
    div([class("form-group")], [
      label([for("weekly-rewards")], [
        text("Недельных наград"),
        span([class("hint")], [
          text(" (по " <> int.to_string(battle_pass.weekly_reward) <> " очков)"),
        ]),
      ]),
      input([
        type_("number"),
        id("weekly-rewards"),
        value(model.weekly_rewards_str),
        attribute.min("0"),
        event.on_input(bp_model.SetWeeklyRewards),
      ]),
    ]),
    // Условное поле в зависимости от режима
    case model.mode {
      CalculateLevel -> daily_points_input(model)
      CalculateDailyPoints -> target_level_input(model)
    },
  ])
}

/// Поле ввода дневных очков (для режима расчёта уровня)
fn daily_points_input(model: Model) -> Element(Msg) {
  div([class("form-group highlight")], [
    label([for("daily-points")], [text("Очков в день")]),
    input([
      type_("number"),
      id("daily-points"),
      value(model.daily_points_str),
      attribute.min("0"),
      event.on_input(bp_model.SetDailyPoints),
    ]),
  ])
}

/// Поле ввода целевого уровня (для режима расчёта дневных очков)
fn target_level_input(model: Model) -> Element(Msg) {
  div([class("form-group highlight")], [
    label([for("target-level")], [text("Целевой уровень")]),
    input([
      type_("number"),
      id("target-level"),
      value(model.target_level_str),
      attribute.min(int.to_string(model.current_level)),
      attribute.max(int.to_string(battle_pass.max_level)),
      event.on_input(bp_model.SetTargetLevel),
    ]),
  ])
}

/// Секция с результатом
fn result_section(model: Model) -> Element(Msg) {
  div([class("result")], [
    case model.mode {
      CalculateLevel -> calculate_level_result(model)
      CalculateDailyPoints -> calculate_daily_result(model)
    },
  ])
}

/// Результат расчёта достижимого уровня
fn calculate_level_result(model: Model) -> Element(Msg) {
  let total_points =
    battle_pass.calculate_total_available_points(
      model.daily_points,
      model.days_remaining,
      model.weekly_rewards_remaining,
    )

  let result =
    battle_pass.calculate_reachable_level(
      model.current_level,
      model.current_progress,
      total_points,
    )

  let daily_total = model.daily_points * model.days_remaining
  let weekly_total = model.weekly_rewards_remaining * battle_pass.weekly_reward

  div([], [
    div([class("result-header")], [text("Результат")]),
    div([class("result-main")], [
      p([], [
        text("Вы достигнете: "),
        span([class("result-level")], [
          text("Уровень " <> int.to_string(result.level)),
        ]),
      ]),
      case result.level < battle_pass.max_level {
        True ->
          p([class("result-progress")], [
            text(
              "Прогресс: "
              <> int.to_string(result.progress)
              <> " / "
              <> int.to_string(result.level_cost),
            ),
          ])
        False ->
          p([class("result-max")], [text("Максимальный уровень достигнут!")])
      },
    ]),
    div([class("result-details")], [
      p([], [
        text("Очков от ежедневного сбора: " <> int.to_string(daily_total)),
      ]),
      p([], [
        text("Очков от недельных наград: " <> int.to_string(weekly_total)),
      ]),
      p([class("result-total")], [
        text("Всего очков: " <> int.to_string(total_points)),
      ]),
    ]),
  ])
}

/// Результат расчёта необходимых дневных очков
fn calculate_daily_result(model: Model) -> Element(Msg) {
  let result =
    battle_pass.required_daily_points(
      model.current_level,
      model.current_progress,
      model.target_level,
      model.days_remaining,
      model.weekly_rewards_remaining,
    )

  let points_needed =
    battle_pass.points_needed(
      model.current_level,
      model.current_progress,
      model.target_level,
    )

  let weekly_total = model.weekly_rewards_remaining * battle_pass.weekly_reward

  div([], [
    div([class("result-header")], [text("Результат")]),
    case result {
      Ok(daily) -> {
        div([class("result-main")], [
          p([], [
            text("Для достижения уровня " <> int.to_string(model.target_level)),
          ]),
          p([], [
            text("Необходимо: "),
            span([class("result-daily")], [
              text(int.to_string(daily) <> " очков в день"),
            ]),
          ]),
        ])
      }
      Error(err) -> {
        div([class("result-error")], [text(err)])
      }
    },
    div([class("result-details")], [
      p([], [text("Нужно очков всего: " <> int.to_string(points_needed))]),
      p([], [
        text("Очков от недельных наград: " <> int.to_string(weekly_total)),
      ]),
      p([], [
        text(
          "Остаток для ежедневного сбора: "
          <> int.to_string(int.max(0, points_needed - weekly_total)),
        ),
      ]),
    ]),
  ])
}
