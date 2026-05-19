import gleeunit/should
import items_calculator/game_data.{Blue, Green, Purple}
import sets_calculator/sets_game_data.{RegularUnit, SetId}
import sets_calculator/sets_inventory
import sets_calculator/sets_uri.{decode_inventory, encode_inventory}
import gleam/string
import gleam/list

// ============================================================================
// Тесты encode_inventory
// ============================================================================

pub fn encode_empty_inventory_test() {
  let inv = sets_inventory.empty()
  let encoded = encode_inventory(inv)
  // Должен начинаться с v2.
  encoded |> string.starts_with("v2.") |> should.be_true
}

pub fn encode_with_data_starts_with_v2_test() {
  let inv = sets_inventory.empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let inv2 = sets_inventory.set_slot_count(inv, set_id, 1, 3)
  let encoded = encode_inventory(inv2)
  encoded |> string.starts_with("v2.") |> should.be_true
}

pub fn encode_different_data_different_result_test() {
  let inv = sets_inventory.empty()
  let set_id1 = SetId("Мечник", RegularUnit, Blue, 1)
  let set_id2 = SetId("Лиса", RegularUnit, Green, 2)

  let inv1 = sets_inventory.set_slot_count(inv, set_id1, 1, 3)
  let inv2 = sets_inventory.set_slot_count(inv, set_id2, 3, 5)

  let encoded1 = encode_inventory(inv1)
  let encoded2 = encode_inventory(inv2)

  // Разные данные должны давать разные результаты
  { encoded1 != encoded2 } |> should.be_true
}

// ============================================================================
// Тесты decode_inventory
// ============================================================================

pub fn decode_invalid_format_test() {
  decode_inventory("invalid")
  |> should.be_error
}

pub fn decode_invalid_version_test() {
  decode_inventory("v3.somedata")
  |> should.be_error
}

pub fn decode_empty_data_test() {
  // v2 с пустыми данными (base64 пустой строки)
  decode_inventory("v2.")
  |> should.be_ok
}

// ============================================================================
// Тесты encode → decode roundtrip
// ============================================================================

pub fn encode_decode_empty_roundtrip_test() {
  let original = sets_inventory.empty()
  let encoded = encode_inventory(original)
  let decoded = decode_inventory(encoded)
  decoded |> should.be_ok
}

pub fn encode_decode_single_item_roundtrip_test() {
  let inv = sets_inventory.empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let original = sets_inventory.set_slot_count(inv, set_id, 1, 5)

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  // Проверяем что данные сохранились
  let counts = sets_inventory.get_counts(decoded, set_id)
  counts.slot1 |> should.equal(5)
}

pub fn encode_decode_multiple_items_roundtrip_test() {
  let inv = sets_inventory.empty()
  let set_id1 = SetId("Мечник", RegularUnit, Blue, 1)
  let set_id2 = SetId("Лиса", RegularUnit, Green, 2)
  let set_id3 = SetId("Гвард", RegularUnit, Purple, 1)

  let original =
    inv
    |> sets_inventory.set_slot_count(set_id1, 1, 3)
    |> sets_inventory.set_slot_count(set_id1, 2, 7)
    |> sets_inventory.set_slot_count(set_id2, 3, 2)
    |> sets_inventory.set_slot_count(set_id3, 4, 10)

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  // Проверяем все данные
  let counts1 = sets_inventory.get_counts(decoded, set_id1)
  counts1.slot1 |> should.equal(3)
  counts1.slot2 |> should.equal(7)

  let counts2 = sets_inventory.get_counts(decoded, set_id2)
  counts2.slot3 |> should.equal(2)

  let counts3 = sets_inventory.get_counts(decoded, set_id3)
  counts3.slot4 |> should.equal(10)
}

pub fn encode_decode_all_colors_roundtrip_test() {
  let inv = sets_inventory.empty()
  let set_blue = SetId("Рабочий", RegularUnit, Blue, 1)
  let set_green = SetId("Рабочий", RegularUnit, Green, 1)
  let set_purple = SetId("Рабочий", RegularUnit, Purple, 1)

  let original =
    inv
    |> sets_inventory.set_slot_count(set_blue, 1, 1)
    |> sets_inventory.set_slot_count(set_green, 2, 2)
    |> sets_inventory.set_slot_count(set_purple, 3, 3)

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  let counts_blue = sets_inventory.get_counts(decoded, set_blue)
  counts_blue.slot1 |> should.equal(1)

  let counts_green = sets_inventory.get_counts(decoded, set_green)
  counts_green.slot2 |> should.equal(2)

  let counts_purple = sets_inventory.get_counts(decoded, set_purple)
  counts_purple.slot3 |> should.equal(3)
}

pub fn encode_decode_large_counts_roundtrip_test() {
  let inv = sets_inventory.empty()
  let set_id = SetId("Мечник", RegularUnit, Blue, 1)
  let original = sets_inventory.set_slot_count(inv, set_id, 1, 999)

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  let counts = sets_inventory.get_counts(decoded, set_id)
  counts.slot1 |> should.equal(999)
}

pub fn encode_decode_all_slots_filled_roundtrip_test() {
  let inv = sets_inventory.empty()
  let set_id = SetId("Конь", RegularUnit, Green, 2)

  let original =
    inv
    |> sets_inventory.set_slot_count(set_id, 1, 1)
    |> sets_inventory.set_slot_count(set_id, 2, 2)
    |> sets_inventory.set_slot_count(set_id, 3, 3)
    |> sets_inventory.set_slot_count(set_id, 4, 4)

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  let counts = sets_inventory.get_counts(decoded, set_id)
  counts.slot1 |> should.equal(1)
  counts.slot2 |> should.equal(2)
  counts.slot3 |> should.equal(3)
  counts.slot4 |> should.equal(4)
}

// ============================================================================
// Тесты на сохранение количества данных
// ============================================================================

pub fn roundtrip_preserves_total_count_test() {
  let inv = sets_inventory.empty()
  let set_id1 = SetId("Мечник", RegularUnit, Blue, 1)
  let set_id2 = SetId("Гном", RegularUnit, Blue, 2)

  let original =
    inv
    |> sets_inventory.set_slot_count(set_id1, 1, 5)
    |> sets_inventory.set_slot_count(set_id1, 2, 3)
    |> sets_inventory.set_slot_count(set_id2, 1, 2)

  // Сумма до кодирования
  let sum_before =
    sets_inventory.get_all_counts_list(original, Blue)
    |> list.fold(0, fn(acc, x) { acc + x })

  let encoded = encode_inventory(original)
  let assert Ok(decoded) = decode_inventory(encoded)

  // Сумма после декодирования
  let sum_after =
    sets_inventory.get_all_counts_list(decoded, Blue)
    |> list.fold(0, fn(acc, x) { acc + x })

  sum_after |> should.equal(sum_before)
}
