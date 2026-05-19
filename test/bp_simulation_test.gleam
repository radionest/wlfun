import gleeunit/should
import lustre/effect
import lustre/dev/simulate
import bp_calculator/bp_model.{
  type Model, type Msg, CalculateDailyPoints, CalculateLevel, Model,
  SetCurrentLevel, SetDailyPoints, SetMode, SetTargetLevel,
}
import bp_calculator/bp_update
import bp_calculator/bp_view
import bp_calculator/battle_pass

// ============================================================================
// Simulation тесты для BP Calculator
// BP update не использует эффекты, поэтому оборачиваем его
// ============================================================================

fn default_model() -> Model {
  Model(
    mode: CalculateLevel,
    current_level: 1,
    current_progress: 0,
    daily_points: 100,
    days_remaining: 30,
    weekly_rewards_remaining: 4,
    target_level: battle_pass.max_level,
    current_level_str: "1",
    current_progress_str: "0",
    daily_points_str: "100",
    days_remaining_str: "30",
    weekly_rewards_str: "4",
    target_level_str: "60",
  )
}

fn init_fn(_flags: Nil) -> #(Model, effect.Effect(Msg)) {
  #(default_model(), effect.none())
}

fn update_fn(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(bp_update.update(model, msg), effect.none())
}

pub fn bp_mode_switch_updates_model_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetMode(CalculateDailyPoints))

  let model = simulate.model(app)
  model.mode |> should.equal(CalculateDailyPoints)
}

pub fn bp_mode_switch_back_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetMode(CalculateDailyPoints))
    |> simulate.message(SetMode(CalculateLevel))

  let model = simulate.model(app)
  model.mode |> should.equal(CalculateLevel)
}

pub fn bp_set_current_level_updates_model_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetCurrentLevel("25"))

  let model = simulate.model(app)
  model.current_level |> should.equal(25)
  model.current_level_str |> should.equal("25")
}

pub fn bp_set_daily_points_updates_model_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetDailyPoints("500"))

  let model = simulate.model(app)
  model.daily_points |> should.equal(500)
}

pub fn bp_set_target_level_updates_model_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetMode(CalculateDailyPoints))
    |> simulate.message(SetTargetLevel("45"))

  let model = simulate.model(app)
  model.target_level |> should.equal(45)
}

pub fn bp_invalid_level_clamps_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetCurrentLevel("100"))

  let model = simulate.model(app)
  // Должен быть ограничен до max_level (60)
  model.current_level |> should.equal(60)
}

pub fn bp_view_renders_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)

  // Проверяем что view рендерится без ошибок
  let _view = simulate.view(app)
  True |> should.be_true
}

pub fn bp_sequential_updates_test() {
  let app =
    simulate.application(init_fn, update_fn, bp_view.view)
    |> simulate.start(Nil)
    |> simulate.message(SetCurrentLevel("10"))
    |> simulate.message(SetDailyPoints("200"))
    |> simulate.message(SetMode(CalculateDailyPoints))
    |> simulate.message(SetTargetLevel("30"))

  let model = simulate.model(app)
  model.current_level |> should.equal(10)
  model.daily_points |> should.equal(200)
  model.mode |> should.equal(CalculateDailyPoints)
  model.target_level |> should.equal(30)
}
