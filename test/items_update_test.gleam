import gleam/option.{None}
import items_calculator/game_data.{Green, Light}
import items_calculator/items_model.{
  type Model, Model, UserChangedCurrentLevel, UserChangedTargetLevel,
}
import items_calculator/items_update

fn base_model() -> Model {
  Model(
    selected_faction: Light,
    selected_unit: None,
    selected_color: Green,
    current_level: 1,
    target_level: 2,
    result: None,
  )
}

pub fn current_level_catchup_bumps_target_test() {
  // Current catches up with the target: target must move above it
  let model = Model(..base_model(), target_level: 8)
  let new = items_update.update(model, UserChangedCurrentLevel("8"))
  assert new.current_level == 8
  assert new.target_level == 9
}

pub fn current_level_9_forces_target_10_test() {
  let model = Model(..base_model(), target_level: 5)
  let new = items_update.update(model, UserChangedCurrentLevel("9"))
  assert new.current_level == 9
  assert new.target_level == 10
}

pub fn valid_target_untouched_test() {
  let model = Model(..base_model(), target_level: 9)
  let new = items_update.update(model, UserChangedCurrentLevel("5"))
  assert new.current_level == 5
  assert new.target_level == 9
}

pub fn target_not_above_current_rejected_test() {
  let model = Model(..base_model(), current_level: 7, target_level: 7)
  let new = items_update.update(model, UserChangedTargetLevel("3"))
  assert new.target_level == 7
}
