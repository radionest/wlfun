import gleeunit/should
import items_calculator/game_data.{Blue, Green}
import sets_calculator/sets_game_data.{RegularUnit, SetId}
import sets_calculator/sets_inventory.{
  OwnedCounts, OwnedSlots, count_owned, counts_to_slots, empty, empty_counts,
  empty_slots, get_all_counts_list, get_counts, get_slots, key_to_set_id,
  set_id_to_key, set_slot_count, sync_slots_to_counts, toggle_slot,
}
import gleam/list

// ============================================================================
// Тесты empty_slots и empty_counts
// ============================================================================

pub fn empty_slots_all_false_test() {
  let slots = empty_slots()
  slots.slot1 |> should.be_false
  slots.slot2 |> should.be_false
  slots.slot3 |> should.be_false
  slots.slot4 |> should.be_false
}

pub fn empty_counts_all_zero_test() {
  let counts = empty_counts()
  counts.slot1 |> should.equal(0)
  counts.slot2 |> should.equal(0)
  counts.slot3 |> should.equal(0)
  counts.slot4 |> should.equal(0)
}

// ============================================================================
// Тесты count_owned
// ============================================================================

pub fn count_owned_empty_test() {
  count_owned(empty_slots())
  |> should.equal(0)
}

pub fn count_owned_one_test() {
  count_owned(OwnedSlots(True, False, False, False))
  |> should.equal(1)
}

pub fn count_owned_all_test() {
  count_owned(OwnedSlots(True, True, True, True))
  |> should.equal(4)
}

pub fn count_owned_mixed_test() {
  count_owned(OwnedSlots(True, False, True, False))
  |> should.equal(2)
}

// ============================================================================
// Тесты counts_to_slots
// ============================================================================

pub fn counts_to_slots_all_zero_test() {
  counts_to_slots(OwnedCounts(0, 0, 0, 0))
  |> should.equal(OwnedSlots(False, False, False, False))
}

pub fn counts_to_slots_all_positive_test() {
  counts_to_slots(OwnedCounts(1, 2, 3, 4))
  |> should.equal(OwnedSlots(True, True, True, True))
}

pub fn counts_to_slots_mixed_test() {
  counts_to_slots(OwnedCounts(0, 5, 0, 1))
  |> should.equal(OwnedSlots(False, True, False, True))
}

// ============================================================================
// Тесты sync_slots_to_counts
// ============================================================================

pub fn sync_slots_to_counts_empty_test() {
  sync_slots_to_counts(empty_slots(), empty_counts())
  |> should.equal(empty_counts())
}

pub fn sync_slots_to_counts_enable_slot_test() {
  // Если слот включён и count=0, должен стать 1
  let slots = OwnedSlots(True, False, False, False)
  let counts = OwnedCounts(0, 0, 0, 0)
  let result = sync_slots_to_counts(slots, counts)
  result.slot1 |> should.equal(1)
}

pub fn sync_slots_to_counts_preserve_higher_test() {
  // Если слот включён и count>1, должен сохраниться
  let slots = OwnedSlots(True, True, False, False)
  let counts = OwnedCounts(5, 3, 2, 1)
  let result = sync_slots_to_counts(slots, counts)
  result.slot1 |> should.equal(5)
  result.slot2 |> should.equal(3)
  result.slot3 |> should.equal(0)
  result.slot4 |> should.equal(0)
}

// ============================================================================
// Тесты set_id_to_key и key_to_set_id
// ============================================================================

pub fn set_id_to_key_format_test() {
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let key = set_id_to_key(set_id)
  key |> should.equal("Мечник|u|b|1")
}

pub fn key_to_set_id_valid_test() {
  let result = key_to_set_id("Мечник|u|b|1")
  result |> should.be_ok
  let assert Ok(set_id) = result
  set_id.entity_name |> should.equal("Мечник")
  set_id.set_number |> should.equal(1)
}

pub fn key_to_set_id_invalid_test() {
  key_to_set_id("invalid")
  |> should.be_error
}

pub fn set_id_roundtrip_test() {
  let original = SetId("Лиса", RegularUnit, Green, 2)
  let key = set_id_to_key(original)
  let assert Ok(decoded) = key_to_set_id(key)
  decoded.entity_name |> should.equal(original.entity_name)
  decoded.set_number |> should.equal(original.set_number)
}

// ============================================================================
// Тесты empty inventory
// ============================================================================

pub fn empty_inventory_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  get_slots(inv, set_id) |> should.equal(empty_slots())
  get_counts(inv, set_id) |> should.equal(empty_counts())
}

// ============================================================================
// Тесты toggle_slot
// ============================================================================

pub fn toggle_slot_enables_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = toggle_slot(inv, set_id, 1)
  let slots = get_slots(inv2, set_id)
  slots.slot1 |> should.be_true
  slots.slot2 |> should.be_false
}

pub fn toggle_slot_disables_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  // Включаем и выключаем
  let inv2 = toggle_slot(inv, set_id, 1)
  let inv3 = toggle_slot(inv2, set_id, 1)
  let slots = get_slots(inv3, set_id)
  slots.slot1 |> should.be_false
}

pub fn toggle_slot_syncs_counts_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = toggle_slot(inv, set_id, 2)
  let counts = get_counts(inv2, set_id)
  counts.slot2 |> should.equal(1)
}

pub fn toggle_slot_multiple_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 =
    inv
    |> toggle_slot(set_id, 1)
    |> toggle_slot(set_id, 3)
  let slots = get_slots(inv2, set_id)
  slots.slot1 |> should.be_true
  slots.slot2 |> should.be_false
  slots.slot3 |> should.be_true
  slots.slot4 |> should.be_false
}

pub fn toggle_slot_invalid_slot_no_change_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = toggle_slot(inv, set_id, 5)
  get_slots(inv2, set_id) |> should.equal(empty_slots())
}

// ============================================================================
// Тесты set_slot_count
// ============================================================================

pub fn set_slot_count_updates_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = set_slot_count(inv, set_id, 2, 5)
  let counts = get_counts(inv2, set_id)
  counts.slot2 |> should.equal(5)
}

pub fn set_slot_count_syncs_slots_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = set_slot_count(inv, set_id, 3, 3)
  let slots = get_slots(inv2, set_id)
  slots.slot3 |> should.be_true
}

pub fn set_slot_count_zero_disables_slot_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = set_slot_count(inv, set_id, 1, 5)
  let inv3 = set_slot_count(inv2, set_id, 1, 0)
  let slots = get_slots(inv3, set_id)
  slots.slot1 |> should.be_false
}

pub fn set_slot_count_multiple_slots_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 =
    inv
    |> set_slot_count(set_id, 1, 2)
    |> set_slot_count(set_id, 4, 10)
  let counts = get_counts(inv2, set_id)
  counts.slot1 |> should.equal(2)
  counts.slot2 |> should.equal(0)
  counts.slot3 |> should.equal(0)
  counts.slot4 |> should.equal(10)
}

// ============================================================================
// Тесты get_all_counts_list
// ============================================================================

pub fn get_all_counts_list_length_test() {
  let inv = empty()
  get_all_counts_list(inv, Blue)
  |> list.length
  |> should.equal(288)
}

pub fn get_all_counts_list_empty_all_zeros_test() {
  let inv = empty()
  let counts_list = get_all_counts_list(inv, Blue)
  let sum = list.fold(counts_list, 0, fn(acc, x) { acc + x })
  sum |> should.equal(0)
}

pub fn get_all_counts_list_with_data_test() {
  let inv = empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = set_slot_count(inv, set_id, 1, 5)
  let counts_list = get_all_counts_list(inv2, Blue)
  // Должен быть хотя бы один ненулевой элемент
  let sum = list.fold(counts_list, 0, fn(acc, x) { acc + x })
  sum |> should.equal(5)
}

pub fn get_all_counts_list_different_colors_independent_test() {
  let inv = empty()
  let set_id_blue = SetId("Мечник", RegularUnit, Blue, 1)
  let set_id_green = SetId("Мечник", RegularUnit, Green, 1)
  let inv2 =
    inv
    |> set_slot_count(set_id_blue, 1, 3)
    |> set_slot_count(set_id_green, 2, 7)

  let blue_sum =
    get_all_counts_list(inv2, Blue)
    |> list.fold(0, fn(acc, x) { acc + x })
  let green_sum =
    get_all_counts_list(inv2, Green)
    |> list.fold(0, fn(acc, x) { acc + x })

  blue_sum |> should.equal(3)
  green_sum |> should.equal(7)
}
