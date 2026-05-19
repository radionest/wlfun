import { toList } from "../gleam_stdlib/gleam.mjs";
import { None, Some } from "../gleam_stdlib/gleam/option.mjs";
import { ComputationResult, WorkerError } from "./sets_calculator/sets_model.mjs";

/**
 * Преобразует JS массив [[n, prob], ...] в Gleam List(#(Int, Float))
 */
function curveToGleamList(curve) {
  if (!curve || !Array.isArray(curve)) {
    return toList([]);
  }

  const tuples = curve.map(([n, prob]) => [Math.floor(n), prob]);
  return toList(tuples);
}

/**
 * Парсит ответ от Web Worker и возвращает соответствующий Msg
 */
export function parseWorkerResponse(data) {
  try {
    if (data.type === 'error') {
      return new WorkerError(data.error || 'Unknown error');
    }

    if (data.type === 'result') {
      const curve = data.curve;

      // Проверяем, это BothResult или простой массив
      if (curve && typeof curve === 'object' && curve.analytic) {
        // BothResult - есть и analytic и bootstrap
        const analyticList = curveToGleamList(curve.analytic);
        const bootstrapList = curve.bootstrap
          ? new Some(curveToGleamList(curve.bootstrap))
          : new None();

        return new ComputationResult(analyticList, bootstrapList);
      } else if (Array.isArray(curve)) {
        // Простой массив - только analytic
        const analyticList = curveToGleamList(curve);
        return new ComputationResult(analyticList, new None());
      }
    }

    return new WorkerError('Unknown response format');
  } catch (error) {
    return new WorkerError(error.message || 'Parse error');
  }
}
