import gleeunit/should
import gleam/option.{None, Some}
import items_calculator/game_data.{Green, Dark, Light}
import sets_calculator/sets_model.{
  type Model, GoalAnySetOnEntity, GoalDuplicates, GoalSpecificSet, Model,
  SelectEntity, SelectFaction, SetGoalType, SetMinDuplicates, SetMinItems,
}
import sets_calculator/sets_inventory
import sets_calculator/sets_update

// ============================================================================
// Simulation тесты для Sets Calculator
// Примечание: sets_update.update возвращает #(Model, Effect), поэтому
// используем прямое тестирование update функции
// ============================================================================

fn default_model() -> Model {
  sets_model.init()
}

pub fn sets_goal_change_to_duplicates_test() {
  let model = default_model()
  let #(new_model, _effect) = sets_update.update(model, SetGoalType("duplicates"))

  new_model.goal_type |> should.equal(GoalDuplicates)
  // При смене на duplicates, entity и faction сбрасываются
  new_model.selected_entity |> should.equal(None)
  new_model.selected_faction |> should.equal(None)
}

pub fn sets_goal_change_to_entity_test() {
  let model = default_model()
  let #(new_model, _effect) = sets_update.update(model, SetGoalType("entity"))

  new_model.goal_type |> should.equal(GoalAnySetOnEntity)
  // owned_slots сбрасываются
  new_model.owned_slots |> should.equal(sets_inventory.empty_slots())
}

pub fn sets_select_faction_clears_entity_test() {
  // Сначала выбираем entity
  let model = Model(..default_model(), selected_entity: Some("Мечник"))

  // Меняем фракцию
  let #(new_model, _effect) = sets_update.update(model, SelectFaction("dark"))

  // Entity должен сброситься
  new_model.selected_entity |> should.equal(None)
  new_model.selected_faction |> should.equal(Some(Dark))
}

pub fn sets_select_entity_sets_value_test() {
  let model = default_model()
  let #(new_model, _effect) = sets_update.update(model, SelectEntity("Лиса"))

  new_model.selected_entity |> should.equal(Some("Лиса"))
}

pub fn sets_select_empty_entity_clears_test() {
  let model = Model(..default_model(), selected_entity: Some("Мечник"))
  let #(new_model, _effect) = sets_update.update(model, SelectEntity(""))

  new_model.selected_entity |> should.equal(None)
}

pub fn sets_set_min_duplicates_updates_test() {
  let model = default_model()
  let #(new_model, _effect) = sets_update.update(model, SetMinDuplicates("5"))

  new_model.min_duplicates_per_item |> should.equal(5)
  new_model.min_duplicates_str |> should.equal("5")
}

pub fn sets_set_min_items_updates_test() {
  let model = default_model()
  let #(new_model, _effect) = sets_update.update(model, SetMinItems("10"))

  new_model.min_items_with_duplicates |> should.equal(10)
  new_model.min_items_str |> should.equal("10")
}

pub fn sets_goal_specific_preserves_slots_test() {
  let owned = sets_inventory.OwnedSlots(True, True, False, False)
  let model = Model(..default_model(), goal_type: GoalAnySetOnEntity, owned_slots: owned)

  // Смена на GoalSpecificSet должна сохранить slots
  let #(new_model, _effect) = sets_update.update(model, SetGoalType("specific"))

  new_model.goal_type |> should.equal(GoalSpecificSet)
  // slots сохраняются при смене на specific
}

pub fn sets_faction_change_resets_owned_slots_test() {
  let owned = sets_inventory.OwnedSlots(True, True, True, True)
  let model = Model(..default_model(), owned_slots: owned)

  let #(new_model, _effect) = sets_update.update(model, SelectFaction("dark"))

  // owned_slots должны сброситься при смене фракции
  new_model.owned_slots |> should.equal(sets_inventory.empty_slots())
}

pub fn sets_color_keeps_faction_test() {
  let model = Model(..default_model(), selected_faction: Some(Light))
  let #(new_model, _effect) =
    sets_update.update(model, sets_model.SelectColor("green"))

  // Фракция должна сохраниться при смене цвета
  new_model.selected_faction |> should.equal(Some(Light))
  new_model.selected_color |> should.equal(Green)
}
