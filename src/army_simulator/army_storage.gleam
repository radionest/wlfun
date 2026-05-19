import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import plinth/javascript/storage as plinth_storage
import varasto
import army_simulator/army_model.{
  type AggregatedResult, type ComparisonResult, type DropSystem, type FinalStats,
  type InitialSetsSnapshot, type Profile, type SavedSimulation, type SimulationParams,
  type SystemResult, AggregatedResult, ComparisonResult, FinalStats,
  InitialSetsSnapshot, NoDuplicates, Profile, SavedSimulation, SimulationParams,
  SystemResult, WithDuplicates, max_saved_simulations, max_profiles,
}
import items_calculator/game_data.{type Faction, Dark, Light}
import sets_calculator/sets_inventory.{
  type Inventory, type OwnedSlots, type OwnedCounts,
  OwnedSlots, OwnedCounts, from_counts_list, from_slots_list, counts_to_list,
}

const storage_key = "wl_army_simulations"

const profiles_storage_key = "wl_army_profiles"

// ========== Декодеры ==========

fn faction_decoder() -> decode.Decoder(Faction) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "light" -> decode.success(Light)
      "dark" -> decode.success(Dark)
      _ -> decode.success(Light)
    }
  })
}

fn drop_system_decoder() -> decode.Decoder(DropSystem) {
  decode.string
  |> decode.then(fn(s) {
    case s {
      "with_duplicates" -> decode.success(WithDuplicates)
      "no_duplicates" -> decode.success(NoDuplicates)
      _ -> decode.success(NoDuplicates)
    }
  })
}

fn simulation_params_decoder() -> decode.Decoder(SimulationParams) {
  use blue <- decode.field("blue_per_month", decode.int)
  use green <- decode.field("green_per_month", decode.int)
  use purple <- decode.field("purple_per_month", decode.int)
  use months <- decode.field("months", decode.int)
  use num <- decode.field("num_simulations", decode.int)
  decode.success(SimulationParams(blue, green, purple, months, num))
}

fn initial_sets_decoder() -> decode.Decoder(InitialSetsSnapshot) {
  use blue <- decode.field("blue_sets", decode.int)
  use green <- decode.field("green_sets", decode.int)
  use purple <- decode.field("purple_sets", decode.int)
  decode.success(InitialSetsSnapshot(blue, green, purple))
}

fn final_stats_decoder() -> decode.Decoder(FinalStats) {
  use avg_blue <- decode.field("avg_blue_sets", decode.float)
  use avg_green <- decode.field("avg_green_sets", decode.float)
  use avg_purple <- decode.field("avg_purple_sets", decode.float)
  use avg_total <- decode.field("avg_total_items", decode.float)
  decode.success(FinalStats(avg_blue, avg_green, avg_purple, avg_total))
}

fn aggregated_result_decoder() -> decode.Decoder(AggregatedResult) {
  use month <- decode.field("month", decode.int)
  use mean_blue <- decode.field("mean_blue_sets", decode.float)
  use mean_green <- decode.field("mean_green_sets", decode.float)
  use mean_purple <- decode.field("mean_purple_sets", decode.float)
  decode.success(AggregatedResult(month, mean_blue, mean_green, mean_purple))
}

fn system_result_decoder() -> decode.Decoder(SystemResult) {
  use system <- decode.field("system", drop_system_decoder())
  use curve <- decode.field("progress_curve", decode.list(aggregated_result_decoder()))
  use stats <- decode.field("final_stats", final_stats_decoder())
  decode.success(SystemResult(system, curve, stats))
}

fn comparison_result_decoder() -> decode.Decoder(ComparisonResult) {
  use system_a <- decode.field("system_a", system_result_decoder())
  use system_b <- decode.field("system_b", system_result_decoder())
  decode.success(ComparisonResult(system_a, system_b))
}

fn saved_simulation_decoder() -> decode.Decoder(SavedSimulation) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use params <- decode.field("params", simulation_params_decoder())
  use faction <- decode.field("faction", faction_decoder())
  use initial_sets <- decode.field("initial_sets", initial_sets_decoder())
  use result <- decode.field("result", comparison_result_decoder())
  use created_at <- decode.field("created_at", decode.int)
  decode.success(SavedSimulation(id, name, params, faction, initial_sets, result, created_at))
}

fn simulations_list_decoder() -> decode.Decoder(List(SavedSimulation)) {
  decode.list(saved_simulation_decoder())
}

// ========== Энкодеры ==========

fn faction_encoder(f: Faction) -> json.Json {
  case f {
    Light -> json.string("light")
    Dark -> json.string("dark")
  }
}

fn drop_system_encoder(s: DropSystem) -> json.Json {
  case s {
    WithDuplicates -> json.string("with_duplicates")
    NoDuplicates -> json.string("no_duplicates")
  }
}

fn simulation_params_encoder(p: SimulationParams) -> json.Json {
  json.object([
    #("blue_per_month", json.int(p.blue_per_month)),
    #("green_per_month", json.int(p.green_per_month)),
    #("purple_per_month", json.int(p.purple_per_month)),
    #("months", json.int(p.months)),
    #("num_simulations", json.int(p.num_simulations)),
  ])
}

fn initial_sets_encoder(s: InitialSetsSnapshot) -> json.Json {
  json.object([
    #("blue_sets", json.int(s.blue_sets)),
    #("green_sets", json.int(s.green_sets)),
    #("purple_sets", json.int(s.purple_sets)),
  ])
}

fn final_stats_encoder(f: FinalStats) -> json.Json {
  json.object([
    #("avg_blue_sets", json.float(f.avg_blue_sets)),
    #("avg_green_sets", json.float(f.avg_green_sets)),
    #("avg_purple_sets", json.float(f.avg_purple_sets)),
    #("avg_total_items", json.float(f.avg_total_items)),
  ])
}

fn aggregated_result_encoder(a: AggregatedResult) -> json.Json {
  json.object([
    #("month", json.int(a.month)),
    #("mean_blue_sets", json.float(a.mean_blue_sets)),
    #("mean_green_sets", json.float(a.mean_green_sets)),
    #("mean_purple_sets", json.float(a.mean_purple_sets)),
  ])
}

fn system_result_encoder(s: SystemResult) -> json.Json {
  json.object([
    #("system", drop_system_encoder(s.system)),
    #("progress_curve", json.array(s.progress_curve, aggregated_result_encoder)),
    #("final_stats", final_stats_encoder(s.final_stats)),
  ])
}

fn comparison_result_encoder(c: ComparisonResult) -> json.Json {
  json.object([
    #("system_a", system_result_encoder(c.system_a)),
    #("system_b", system_result_encoder(c.system_b)),
  ])
}

fn saved_simulation_encoder(sim: SavedSimulation) -> json.Json {
  json.object([
    #("id", json.string(sim.id)),
    #("name", json.string(sim.name)),
    #("params", simulation_params_encoder(sim.params)),
    #("faction", faction_encoder(sim.faction)),
    #("initial_sets", initial_sets_encoder(sim.initial_sets)),
    #("result", comparison_result_encoder(sim.result)),
    #("created_at", json.int(sim.created_at)),
  ])
}

fn simulations_list_encoder(sims: List(SavedSimulation)) -> json.Json {
  json.array(sims, saved_simulation_encoder)
}

// ========== Публичные функции ==========

/// Загрузить симуляции из localStorage
pub fn load() -> List(SavedSimulation) {
  case plinth_storage.local() {
    Error(_) -> []
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, simulations_list_decoder(), simulations_list_encoder)
      case varasto.get(storage, storage_key) {
        Ok(sims) -> sims
        Error(_) -> []
      }
    }
  }
}

/// Сохранить список симуляций в localStorage
pub fn save(simulations: List(SavedSimulation)) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, simulations_list_decoder(), simulations_list_encoder)
      let _ = varasto.set(storage, storage_key, simulations)
      Nil
    }
  }
}

/// Добавить новую симуляцию (удаляет старейшую если > max)
pub fn add_simulation(
  simulations: List(SavedSimulation),
  new_sim: SavedSimulation,
) -> List(SavedSimulation) {
  let updated = [new_sim, ..simulations]
  case list.length(updated) > max_saved_simulations {
    True -> list.take(updated, max_saved_simulations)
    False -> updated
  }
}

/// Удалить симуляцию по ID
pub fn remove_simulation(
  simulations: List(SavedSimulation),
  id: String,
) -> List(SavedSimulation) {
  list.filter(simulations, fn(sim) { sim.id != id })
}

/// Найти симуляцию по ID
pub fn find_by_id(
  simulations: List(SavedSimulation),
  id: String,
) -> Option(SavedSimulation) {
  list.find(simulations, fn(sim) { sim.id == id })
  |> option.from_result
}

// ========== Декодеры/Энкодеры для профилей ==========

/// Декодер для OwnedSlots
fn owned_slots_decoder() -> decode.Decoder(OwnedSlots) {
  use s1 <- decode.field("s1", decode.bool)
  use s2 <- decode.field("s2", decode.bool)
  use s3 <- decode.field("s3", decode.bool)
  use s4 <- decode.field("s4", decode.bool)
  decode.success(OwnedSlots(slot1: s1, slot2: s2, slot3: s3, slot4: s4))
}

/// Декодер для одной записи слотов
fn slot_entry_decoder() -> decode.Decoder(#(String, OwnedSlots)) {
  use key <- decode.field("k", decode.string)
  use slots <- decode.field("v", owned_slots_decoder())
  decode.success(#(key, slots))
}

/// Декодер для OwnedCounts
fn owned_counts_decoder() -> decode.Decoder(OwnedCounts) {
  use c1 <- decode.field("c1", decode.int)
  use c2 <- decode.field("c2", decode.int)
  use c3 <- decode.field("c3", decode.int)
  use c4 <- decode.field("c4", decode.int)
  decode.success(OwnedCounts(slot1: c1, slot2: c2, slot3: c3, slot4: c4))
}

/// Декодер для одной записи счётчиков
fn count_entry_decoder() -> decode.Decoder(#(String, OwnedCounts)) {
  use key <- decode.field("k", decode.string)
  use counts <- decode.field("v", owned_counts_decoder())
  decode.success(#(key, counts))
}

/// Декодер для Inventory (поддержка нового формата с counts и миграция старого со slots)
fn inventory_decoder() -> decode.Decoder(Inventory) {
  // Пробуем декодировать counts (новый формат или старый со slots+counts)
  use counts <- decode.optional_field("counts", [], decode.list(count_entry_decoder()))
  use slots <- decode.optional_field("slots", [], decode.list(slot_entry_decoder()))

  // Если есть counts - используем их
  case counts {
    [_, ..] -> decode.success(from_counts_list(counts))
    [] -> {
      // Если counts пусто, но есть slots - мигрируем из slots
      case slots {
        [_, ..] -> decode.success(from_slots_list(slots))
        [] -> decode.success(sets_inventory.empty())
      }
    }
  }
}

/// Энкодер для OwnedCounts
fn owned_counts_encoder(counts: OwnedCounts) -> json.Json {
  let OwnedCounts(c1, c2, c3, c4) = counts
  json.object([
    #("c1", json.int(c1)),
    #("c2", json.int(c2)),
    #("c3", json.int(c3)),
    #("c4", json.int(c4)),
  ])
}

/// Энкодер для записи счётчиков
fn count_entry_encoder(entry: #(String, OwnedCounts)) -> json.Json {
  let #(key, counts) = entry
  json.object([#("k", json.string(key)), #("v", owned_counts_encoder(counts))])
}

/// Энкодер для Inventory (только counts)
fn inventory_encoder(inventory: Inventory) -> json.Json {
  json.object([
    #("counts", json.array(counts_to_list(inventory), count_entry_encoder)),
  ])
}

/// Декодер для Profile
fn profile_decoder() -> decode.Decoder(Profile) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use inventory <- decode.field("inventory", inventory_decoder())
  use created_at <- decode.field("created_at", decode.int)
  decode.success(Profile(id, name, inventory, created_at))
}

/// Декодер для списка профилей
fn profiles_list_decoder() -> decode.Decoder(List(Profile)) {
  decode.list(profile_decoder())
}

/// Энкодер для Profile
fn profile_encoder(profile: Profile) -> json.Json {
  json.object([
    #("id", json.string(profile.id)),
    #("name", json.string(profile.name)),
    #("inventory", inventory_encoder(profile.inventory)),
    #("created_at", json.int(profile.created_at)),
  ])
}

/// Энкодер для списка профилей
fn profiles_list_encoder(profiles: List(Profile)) -> json.Json {
  json.array(profiles, profile_encoder)
}

// ========== Публичные функции для профилей ==========

/// Загрузить профили из localStorage
pub fn load_profiles() -> List(Profile) {
  case plinth_storage.local() {
    Error(_) -> []
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, profiles_list_decoder(), profiles_list_encoder)
      case varasto.get(storage, profiles_storage_key) {
        Ok(profiles) -> profiles
        Error(_) -> []
      }
    }
  }
}

/// Сохранить список профилей в localStorage
pub fn save_profiles(profiles: List(Profile)) -> Nil {
  case plinth_storage.local() {
    Error(_) -> Nil
    Ok(raw_storage) -> {
      let storage =
        varasto.new(raw_storage, profiles_list_decoder(), profiles_list_encoder)
      let _ = varasto.set(storage, profiles_storage_key, profiles)
      Nil
    }
  }
}

/// Добавить новый профиль (удаляет старейший если > max)
pub fn add_profile(
  profiles: List(Profile),
  new_profile: Profile,
) -> List(Profile) {
  let updated = [new_profile, ..profiles]
  case list.length(updated) > max_profiles {
    True -> list.take(updated, max_profiles)
    False -> updated
  }
}

/// Удалить профиль по ID
pub fn remove_profile(
  profiles: List(Profile),
  id: String,
) -> List(Profile) {
  list.filter(profiles, fn(p) { p.id != id })
}

/// Найти профиль по ID
pub fn find_profile_by_id(
  profiles: List(Profile),
  id: String,
) -> Option(Profile) {
  list.find(profiles, fn(p) { p.id == id })
  |> option.from_result
}
