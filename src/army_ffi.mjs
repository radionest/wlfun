import { toList } from "../gleam_stdlib/gleam.mjs";
import { Some, None } from "../gleam_stdlib/gleam/option.mjs";
import {
  SimulationProgress,
  SimulationResult,
  WorkerError,
  ComparisonResult,
  SystemResult,
  AggregatedResult,
  FinalStats,
  WithDuplicates,
  NoDuplicates,
  InitialSetsSnapshot,
  EquipmentMilestone,
  ColorCurveResult,
  EquipmentCurveResult,
} from "./army_simulator/army_model.mjs";

// Данные армии (15 юнитов + 3 героя на фракцию)
const ARMY_LIGHT = [
  // Юниты (slotsNeeded = 3)
  { name: "Рабочий", slotsNeeded: 3 },
  { name: "Гном", slotsNeeded: 3 },
  { name: "Мечник", slotsNeeded: 3 },
  { name: "Шлюп", slotsNeeded: 3 },
  { name: "Вертолет", slotsNeeded: 3 },
  { name: "Арча", slotsNeeded: 3 },
  { name: "Гвард", slotsNeeded: 3 },
  { name: "Конь", slotsNeeded: 3 },
  { name: "Лиса", slotsNeeded: 3 },
  { name: "Байк", slotsNeeded: 3 },
  { name: "Маг", slotsNeeded: 3 },
  { name: "Каравелла", slotsNeeded: 3 },
  { name: "Стреломет", slotsNeeded: 3 },
  { name: "Хилка", slotsNeeded: 3 },
  { name: "Снайп", slotsNeeded: 3 },
  // Герои (slotsNeeded = 4)
  { name: "Палыч", slotsNeeded: 4 },
  { name: "Берин", slotsNeeded: 4 },
  { name: "Цесса", slotsNeeded: 4 },
];

const ARMY_DARK = [
  // Юниты
  { name: "Раб", slotsNeeded: 3 },
  { name: "Скелук", slotsNeeded: 3 },
  { name: "Громила", slotsNeeded: 3 },
  { name: "Шхуна", slotsNeeded: 3 },
  { name: "Нафт", slotsNeeded: 3 },
  { name: "Камик", slotsNeeded: 3 },
  { name: "Топор", slotsNeeded: 3 },
  { name: "Варг", slotsNeeded: 3 },
  { name: "Бур", slotsNeeded: 3 },
  { name: "Яд", slotsNeeded: 3 },
  { name: "Зомби", slotsNeeded: 3 },
  { name: "Галеон", slotsNeeded: 3 },
  { name: "Катапа", slotsNeeded: 3 },
  { name: "Некр", slotsNeeded: 3 },
  { name: "Ракетчик", slotsNeeded: 3 },
  // Герои
  { name: "Грокк", slotsNeeded: 4 },
  { name: "Жаба", slotsNeeded: 4 },
  { name: "Жрун", slotsNeeded: 4 },
];

/**
 * Парсит ответ от Web Worker и возвращает соответствующий Msg
 */
export function parseWorkerResponse(data) {
  console.log("[ArmyFFI] Received data:", data);
  try {
    // data приходит как JSON, нужно распарсить если это строка
    const parsed = typeof data === "string" ? JSON.parse(data) : data;
    console.log("[ArmyFFI] Parsed data:", parsed);

    if (parsed.type === "progress") {
      return new SimulationProgress(parsed.progress);
    }

    if (parsed.type === "result") {
      const result = parsed.result;

      // Парсим систему A (с дубликатами)
      const systemA = parseSystemResult(result.systemA, new WithDuplicates());

      // Парсим систему B (без дубликатов)
      const systemB = parseSystemResult(result.systemB, new NoDuplicates());

      // Парсим кривую экипировки
      let eqCurve = new None();
      if (result.equipmentCurve) {
        eqCurve = new Some(parseEquipmentCurveResult(result.equipmentCurve));
      }

      return new SimulationResult(new ComparisonResult(systemA, systemB), eqCurve);
    }

    if (parsed.type === "error") {
      return new WorkerError(parsed.error || "Unknown error");
    }

    return new WorkerError("Unknown message type: " + parsed.type);
  } catch (e) {
    console.error("[ArmyFFI] Parse error:", e);
    return new WorkerError("Parse error: " + e.message);
  }
}

function parseSystemResult(data, systemType) {
  console.log("[ArmyFFI] parseSystemResult data:", data);
  console.log("[ArmyFFI] data.progressCurve:", data.progressCurve);
  console.log("[ArmyFFI] progressCurve length:", data.progressCurve?.length);
  // Парсим progress_curve
  const progressCurve = (data.progressCurve || []).map(
    (r) => new AggregatedResult(
      r.month,
      r.meanBlueSets || 0,
      r.meanGreenSets || 0,
      r.meanPurpleSets || 0
    )
  );
  console.log("[ArmyFFI] mapped progressCurve:", progressCurve);
  console.log("[ArmyFFI] mapped progressCurve length:", progressCurve.length);

  // Парсим final_stats
  const fs = data.finalStats || {};
  const finalStats = new FinalStats(
    fs.avgBlueSets || 0,
    fs.avgGreenSets || 0,
    fs.avgPurpleSets || 0,
    fs.avgTotalItems || 0
  );

  return new SystemResult(
    systemType,
    toList(progressCurve),
    finalStats
  );
}

/**
 * Генерирует уникальный ID для симуляции
 */
export function generateSimulationId() {
  return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
}

/**
 * Возвращает текущий timestamp
 */
export function currentTimestamp() {
  return Date.now();
}

/**
 * Парсит полный результат кривой экипировки
 */
function parseEquipmentCurveResult(data) {
  const systemA = parseCurveResult(data.systemA);
  const systemB = parseCurveResult(data.systemB);
  const ie = data.initialEquipped || {};
  const initialEquipped = new InitialSetsSnapshot(ie.blue || 0, ie.green || 0, ie.purple || 0);
  return new EquipmentCurveResult(systemA, systemB, initialEquipped);
}

/**
 * Парсит milestones для одной системы
 */
function parseCurveResult(data) {
  const milestones = (data.milestones || []).map(
    (m) => new EquipmentMilestone(m.units, m.mean || 0, m.p90 || 0, m.p95 || 0)
  );
  return new ColorCurveResult(toList(milestones));
}

/**
 * Подсчитывает количество предметов в сете
 */
function countSetItems(inventory, startIdx, setSize) {
  let count = 0;
  for (let i = 0; i < setSize; i++) {
    if (inventory[startIdx + i] > 0) {
      count++;
    }
  }
  return count;
}

/**
 * Рассчитывает начальное количество юнитов с полными сетами
 * @param {string} inventoryJson - JSON с инвентарём { blue: [...288], green: [...288], purple: [...288] }
 * @param {string} factionStr - "light" или "dark"
 * @returns {InitialSetsSnapshot}
 */
export function calculateInitialSets(inventoryJson, factionStr) {
  const inventory = JSON.parse(inventoryJson);
  const army = factionStr === "light" ? ARMY_LIGHT : ARMY_DARK;
  const factionOffset = factionStr === "light" ? 0 : 144;

  let blueSets = 0;
  let greenSets = 0;
  let purpleSets = 0;

  for (let i = 0; i < army.length; i++) {
    const slotsNeeded = army[i].slotsNeeded;
    const baseIndex = factionOffset + i * 8;

    for (const [color, inv] of Object.entries(inventory)) {
      const set1 = countSetItems(inv, baseIndex, 4);
      const set2 = countSetItems(inv, baseIndex + 4, 4);
      const bestSet = Math.max(set1, set2);

      if (bestSet >= slotsNeeded) {
        if (color === "blue") blueSets++;
        else if (color === "green") greenSets++;
        else if (color === "purple") purpleSets++;
      }
    }
  }

  return new InitialSetsSnapshot(blueSets, greenSets, purpleSets);
}
