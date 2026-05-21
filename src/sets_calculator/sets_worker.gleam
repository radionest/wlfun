/// Модуль для работы с Web Worker для тяжёлых вычислений
import gleam/json
import lustre/effect.{type Effect}
import plinth/browser/worker.{type Worker}
import sets_calculator/sets_model.{type Msg, WorkerError, WorkerReady}

/// Параметры для вычисления кривой дубликатов
pub type CalculationParams {
  CalculationParams(
    min_duplicates: Int,
    min_items: Int,
    max_attempts: Int,
    num_simulations: Int,
    initial_counts: List(Int),
    pool_size: Int,
    include_bootstrap: Bool,
  )
}

/// Инициализировать Web Worker и настроить обработчик сообщений
pub fn init_worker() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    case worker.new("/probability_worker.js") {
      Ok(w) -> {
        // Настраиваем обработчик сообщений от worker
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

/// Отправить задание на вычисление в worker
pub fn calculate(wrk: Worker, params: CalculationParams) -> Nil {
  let message = encode_calculation_request(params)
  worker.post_message(wrk, message)
}

/// Кодирование запроса для worker
fn encode_calculation_request(params: CalculationParams) -> json.Json {
  let calc_type = case params.include_bootstrap {
    True -> "calculate_both"
    False -> "calculate_analytic"
  }

  json.object([
    #("type", json.string(calc_type)),
    #("requestId", json.string("calc_1")),
    #(
      "params",
      json.object([
        #("minDuplicates", json.int(params.min_duplicates)),
        #("minItems", json.int(params.min_items)),
        #("maxAttempts", json.int(params.max_attempts)),
        #("numSimulations", json.int(params.num_simulations)),
        #("poolSize", json.int(params.pool_size)),
        #("includeBootstrap", json.bool(params.include_bootstrap)),
        #("initialCounts", json.array(params.initial_counts, json.int)),
      ]),
    ),
  ])
}

/// FFI для парсинга ответа от worker
@external(javascript, "../sets_worker_ffi.mjs", "parseWorkerResponse")
fn parse_worker_response_ffi(data: json.Json) -> Msg
