import gleam/json
import gleam/list
import lustre/effect.{type Effect}
import plinth/browser/worker.{type Worker}
import items_calculator/game_data.{type Faction, type ItemColor, Light, Dark, Blue, Green, Purple}
import army_simulator/army_model.{type Msg, type SimulationParams, type InitialSetsSnapshot, WorkerReady, WorkerError}
import sets_calculator/sets_inventory.{type Inventory}
import sets_calculator/sets_game_data.{SetId}

/// Инициализировать Web Worker
pub fn init_worker() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    case worker.new("/boosting_simulation_worker.js") {
      Ok(w) -> {
        worker.on_message(w, fn(data) {
          let result = parse_worker_response_ffi(data)
          dispatch(result)
        })
        dispatch(WorkerReady(w))
      }
      Error(err) -> {
        dispatch(WorkerError(err))
      }
    }
  })
}

/// Запустить симуляцию
pub fn run_simulation(w: Worker, params: SimulationParams, faction: Faction, inventory: Inventory) -> Nil {
  let message = encode_simulation_request(params, faction, inventory)
  worker.post_message(w, message)
}

/// Кодирование запроса
fn encode_simulation_request(params: SimulationParams, faction: Faction, inventory: Inventory) -> json.Json {
  let faction_str = case faction {
    Light -> "light"
    Dark -> "dark"
  }

  // Сериализуем инвентарь для worker (288 элементов на редкость)
  let initial_inventory = encode_inventory_for_simulation(inventory)

  json.object([
    #("type", json.string("run_comparison")),
    #("requestId", json.string("sim_1")),
    #("params", json.object([
      #("bluePerMonth", json.int(params.blue_per_month)),
      #("greenPerMonth", json.int(params.green_per_month)),
      #("purplePerMonth", json.int(params.purple_per_month)),
      #("months", json.int(params.months)),
      #("numSimulations", json.int(params.num_simulations)),
      #("faction", json.string(faction_str)),
      #("initialInventory", initial_inventory),
    ])),
  ])
}

/// Сериализация инвентаря для Worker
/// Формат: { blue: [0,1,0,1,...288], green: [...], purple: [...] }
/// Порядок: Light сущности (18 × 8 = 144), затем Dark сущности (18 × 8 = 144)
fn encode_inventory_for_simulation(inventory: Inventory) -> json.Json {
  let blue = encode_color_inventory(inventory, Blue)
  let green = encode_color_inventory(inventory, Green)
  let purple = encode_color_inventory(inventory, Purple)

  json.object([
    #("blue", json.array(blue, json.int)),
    #("green", json.array(green, json.int)),
    #("purple", json.array(purple, json.int)),
  ])
}

/// Сериализация инвентаря одной редкости (288 элементов)
fn encode_color_inventory(inventory: Inventory, color: ItemColor) -> List(Int) {
  // Получаем все сущности в порядке: Light, затем Dark
  let light_names = sets_game_data.all_entity_names_by_faction(Light)
  let dark_names = sets_game_data.all_entity_names_by_faction(Dark)
  let all_names = list.append(light_names, dark_names)

  // Для каждой сущности: 2 сета × 4 слота = 8 предметов
  list.flat_map(all_names, fn(name) {
    let entity_type = sets_game_data.detect_entity_type(name)

    // Сет 1 (4 слота)
    let set1 = SetId(name, entity_type, color, 1)
    let slots1 = sets_inventory.get_slots(inventory, set1)

    // Сет 2 (4 слота)
    let set2 = SetId(name, entity_type, color, 2)
    let slots2 = sets_inventory.get_slots(inventory, set2)

    [
      bool_to_int(slots1.slot1), bool_to_int(slots1.slot2),
      bool_to_int(slots1.slot3), bool_to_int(slots1.slot4),
      bool_to_int(slots2.slot1), bool_to_int(slots2.slot2),
      bool_to_int(slots2.slot3), bool_to_int(slots2.slot4),
    ]
  })
}

fn bool_to_int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

/// FFI для парсинга ответа от worker
@external(javascript, "../army_ffi.mjs", "parseWorkerResponse")
fn parse_worker_response_ffi(data: json.Json) -> Msg

/// FFI для расчёта начальных сетов
@external(javascript, "../army_ffi.mjs", "calculateInitialSets")
fn calculate_initial_sets_ffi(inventory_json: String, faction: String) -> InitialSetsSnapshot

/// Рассчитать начальное количество юнитов с полными сетами
pub fn calculate_initial_sets(inventory: Inventory, faction: Faction) -> InitialSetsSnapshot {
  let inv_json = json.to_string(encode_inventory_for_simulation(inventory))
  let faction_str = case faction {
    Light -> "light"
    Dark -> "dark"
  }
  calculate_initial_sets_ffi(inv_json, faction_str)
}
