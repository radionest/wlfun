// магические числа из игры, не трогать
const POOL_SIZE = 288; // 36 сущностей * 2 сета * 4 предмета
const ITEMS_PER_SET = 4;
const ENTITIES_PER_FACTION = 18; // 15 юнитов + 3 героя

// хардкод армий - лень парсить из игры
// TODO: может вынести в JSON и грузить динамически?
const ARMY_LIGHT = [
  // юниты (slots_needed = 3)
  { name: "Рабочий", type: "unit", slotsNeeded: 3 },
  { name: "Гном", type: "unit", slotsNeeded: 3 },
  { name: "Мечник", type: "unit", slotsNeeded: 3 },
  { name: "Шлюп", type: "unit", slotsNeeded: 3 },
  { name: "Вертолет", type: "unit", slotsNeeded: 3 },
  { name: "Арча", type: "unit", slotsNeeded: 3 },
  { name: "Гвард", type: "unit", slotsNeeded: 3 },
  { name: "Конь", type: "unit", slotsNeeded: 3 },
  { name: "Лиса", type: "unit", slotsNeeded: 3 },
  { name: "Байк", type: "unit", slotsNeeded: 3 },
  { name: "Маг", type: "unit", slotsNeeded: 3 },
  { name: "Каравелла", type: "unit", slotsNeeded: 3 },
  { name: "Стреломет", type: "unit", slotsNeeded: 3 },
  { name: "Хилка", type: "unit", slotsNeeded: 3 },
  { name: "Снайп", type: "unit", slotsNeeded: 3 },
  // герои (slots_needed = 4)
  { name: "Палыч", type: "hero", slotsNeeded: 4 },
  { name: "Берин", type: "hero", slotsNeeded: 4 },
  { name: "Цесса", type: "hero", slotsNeeded: 4 },
];

const ARMY_DARK = [
  // юниты
  { name: "Раб", type: "unit", slotsNeeded: 3 },
  { name: "Скелук", type: "unit", slotsNeeded: 3 },
  { name: "Громила", type: "unit", slotsNeeded: 3 },
  { name: "Шхуна", type: "unit", slotsNeeded: 3 },
  { name: "Нафт", type: "unit", slotsNeeded: 3 },
  { name: "Камик", type: "unit", slotsNeeded: 3 },
  { name: "Топор", type: "unit", slotsNeeded: 3 },
  { name: "Варг", type: "unit", slotsNeeded: 3 },
  { name: "Бур", type: "unit", slotsNeeded: 3 },
  { name: "Яд", type: "unit", slotsNeeded: 3 },
  { name: "Зомби", type: "unit", slotsNeeded: 3 },
  { name: "Галеон", type: "unit", slotsNeeded: 3 },
  { name: "Катапа", type: "unit", slotsNeeded: 3 },
  { name: "Некр", type: "unit", slotsNeeded: 3 },
  { name: "Ракетчик", type: "unit", slotsNeeded: 3 },
  // герои
  { name: "Грокк", type: "hero", slotsNeeded: 4 },
  { name: "Жаба", type: "hero", slotsNeeded: 4 },
  { name: "Жрун", type: "hero", slotsNeeded: 4 },
];

// TODO: добавить обработку отмены вычислений (AbortController вроде)

// type: 'run_comparison'
self.onmessage = function (event) {
  console.log("[ArmyWorker] Raw event:", event);
  console.log("[ArmyWorker] event.data:", event.data);
  console.log("[ArmyWorker] typeof event.data:", typeof event.data);

  // иногда приходит строка, иногда объект - зависит от того как вызывают
  const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
  const { type, params, requestId } = data;
  console.log("[ArmyWorker] Parsed:", { type, params, requestId });

  try {
    if (type === "run_comparison") {
      const result = runComparison(params);
      self.postMessage({
        type: "result",
        requestId,
        result,
      });
    }
  } catch (error) {
    self.postMessage({
      type: "error",
      requestId,
      error: error.message,
    });
  }
};

/**
 * Monte Carlo comparison: System A (with duplicates) vs System B (no duplicates).
 * @param {Object} params - { bluePerMonth, greenPerMonth, purplePerMonth, months, numSimulations, faction, initialInventory }
 */
function runComparison(params) {
  const { bluePerMonth, greenPerMonth, purplePerMonth, months, numSimulations, faction, initialInventory } = params;

  const army = faction === "light" ? ARMY_LIGHT : ARMY_DARK;

  // offset зависит от порядка фракций в инвентаре, если поменють - сломается
  const factionOffset = faction === "light" ? 0 : 144;

  const startInventory = initialInventory || {
    blue: new Array(POOL_SIZE).fill(0),
    green: new Array(POOL_SIZE).fill(0),
    purple: new Array(POOL_SIZE).fill(0),
  };

  const systemAResults = [];
  const systemBResults = [];

  for (let sim = 0; sim < numSimulations; sim++) {
    // система A: с дубликатами (как сейчас)
    systemAResults.push(
      simulateWithDuplicates({
        bluePerMonth,
        greenPerMonth,
        purplePerMonth,
        months,
        army,
        factionOffset,
        initialInventory: startInventory,
      })
    );

    // система B: без дубликатов (как было)
    systemBResults.push(
      simulateNoDuplicates({
        bluePerMonth,
        greenPerMonth,
        purplePerMonth,
        months,
        army,
        factionOffset,
        initialInventory: startInventory,
      })
    );

    // шлём прогресс каждые 50 симуляций чтобы UI не подвисал
    if (sim % 50 === 0) {
      self.postMessage({
        type: "progress",
        progress: sim / numSimulations,
      });
    }
  }

  // Equipment curve: "how many chests to equip N units?"
  const equipmentCurve = computeEquipmentCurve({
    numSimulations,
    army,
    factionOffset,
    initialInventory: startInventory,
  });

  return {
    systemA: aggregateResults(systemAResults, months),
    systemB: aggregateResults(systemBResults, months),
    equipmentCurve,
  };
}

/** System A: any item can drop (1/288), duplicates allowed. */
function simulateWithDuplicates(params) {
  const { bluePerMonth, greenPerMonth, purplePerMonth, months, army, factionOffset, initialInventory } = params;

  // копируем начальный инвентарь чтобы не мутировать оригинал
  // в питоне было бы inventory = {k: v.copy() for k, v in initial.items()}
  const inventory = {
    blue: initialInventory.blue.slice(),
    green: initialInventory.green.slice(),
    purple: initialInventory.purple.slice(),
  };

  const monthlyResults = [];

  for (let month = 1; month <= months; month++) {
    // дропаем предметы за месяц (по всему пулу 288)
    dropItemsWithDuplicates(inventory.blue, bluePerMonth);
    dropItemsWithDuplicates(inventory.green, greenPerMonth);
    dropItemsWithDuplicates(inventory.purple, purplePerMonth);

    // считаем оснащение только для выбранной фракции
    const result = calculateArmyEquipment(army, inventory, factionOffset);
    monthlyResults.push({ month, ...result });
  }

  return monthlyResults;
}

/** @param {number[]} inventory - mutated @param {number} count */
function dropItemsWithDuplicates(inventory, count) {
  // O(n) по количеству дропов, можно оптимизировать но и так норм
  for (let i = 0; i < count; i++) {
    const itemIndex = Math.floor(Math.random() * POOL_SIZE);
    inventory[itemIndex]++;
  }
}

/** System B: no duplicates until all 288 items collected. */
function simulateNoDuplicates(params) {
  const { bluePerMonth, greenPerMonth, purplePerMonth, months, army, factionOffset, initialInventory } = params;

  // унифицированный формат: Array<number> (0/1) как в системе A
  const inventory = {
    blue: initialInventory.blue.slice(),
    green: initialInventory.green.slice(),
    purple: initialInventory.purple.slice(),
  };

  const monthlyResults = [];

  for (let month = 1; month <= months; month++) {
    // дропаем предметы за месяц
    dropItemsNoDuplicates(inventory.blue, bluePerMonth);
    dropItemsNoDuplicates(inventory.green, greenPerMonth);
    dropItemsNoDuplicates(inventory.purple, purplePerMonth);

    const result = calculateArmyEquipment(army, inventory, factionOffset);
    monthlyResults.push({ month, ...result });
  }

  return monthlyResults;
}

/** Guaranteed new item if pool not complete. @param {number[]} inventory - mutated */
function dropItemsNoDuplicates(inventory, count) {
  // собираем индексы пустых слотов для эффективного выбора
  const emptyIndices = [];
  for (let i = 0; i < POOL_SIZE; i++) {
    if (inventory[i] === 0) emptyIndices.push(i);
  }

  // перемешиваем (Fisher-Yates со stackoveflow) и берём первые count
  for (let i = emptyIndices.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [emptyIndices[i], emptyIndices[j]] = [emptyIndices[j], emptyIndices[i]];
  }

  const toFill = Math.min(count, emptyIndices.length);
  for (let i = 0; i < toFill; i++) {
    inventory[emptyIndices[i]] = 1;
  }
}

/**
 * Pool: 36 entities * 2 sets * 4 items = 288. Light: 0-143, Dark: 144-287.
 * @param {number} factionOffset - 0 for light, 144 for dark
 */
function calculateArmyEquipment(army, inventory, factionOffset) {
  let blueSetsComplete = 0;
  let greenSetsComplete = 0;
  let purpleSetsComplete = 0;
  let totalItems = 0;

  // для каждой сущности армии проверяем сеты
  for (let entityIdx = 0; entityIdx < army.length; entityIdx++) {
    const entity = army[entityIdx];
    const slotsNeeded = entity.slotsNeeded;

    // каждая сущность имеет 2 сета по 4 предмета
    // индекс в пуле: factionOffset + entityIdx * 8 (2 сета * 4 предмета)
    const baseIndex = factionOffset + entityIdx * 8;

    // проверяем лучший сет для каждой редкости
    for (const [color, inv] of Object.entries(inventory)) {
      const set1Items = countSetItems(inv, baseIndex, ITEMS_PER_SET);
      const set2Items = countSetItems(inv, baseIndex + ITEMS_PER_SET, ITEMS_PER_SET);

      // берём лучший сет из двух
      const bestSet = Math.max(set1Items, set2Items);

      if (bestSet >= slotsNeeded) {
        if (color === "blue") blueSetsComplete++;
        else if (color === "green") greenSetsComplete++;
        else if (color === "purple") purpleSetsComplete++;
      }

      totalItems += set1Items + set2Items;
    }
  }

  return {
    blueSetsComplete,
    greenSetsComplete,
    purpleSetsComplete,
    totalItems,
  };
}

/** @returns {number} count of items with count > 0 in set */
function countSetItems(inventory, startIdx, setSize) {
  let count = 0;
  for (let i = 0; i < setSize; i++) {
    if (inventory[startIdx + i] > 0) {
      count++;
    }
  }
  return count;
}

/** Mean sets by color for each month across all simulations. */
function aggregateResults(allSimResults, months) {
  const progressCurve = [];

  for (let month = 1; month <= months; month++) {
    // агрегация по цветам сетов
    const blueValues = allSimResults.map((sim) => sim[month - 1].blueSetsComplete);
    const greenValues = allSimResults.map((sim) => sim[month - 1].greenSetsComplete);
    const purpleValues = allSimResults.map((sim) => sim[month - 1].purpleSetsComplete);

    progressCurve.push({
      month,
      meanBlueSets: average(blueValues),
      meanGreenSets: average(greenValues),
      meanPurpleSets: average(purpleValues),
    });
  }

  // финальная статистика (последний месяц)
  const finalMonth = allSimResults.map((sim) => sim[months - 1]);

  const finalStats = {
    avgBlueSets: average(finalMonth.map((r) => r.blueSetsComplete)),
    avgGreenSets: average(finalMonth.map((r) => r.greenSetsComplete)),
    avgPurpleSets: average(finalMonth.map((r) => r.purpleSetsComplete)),
    avgTotalItems: average(finalMonth.map((r) => r.totalItems)),
  };

  return {
    progressCurve,
    finalStats,
  };
}

/** @param {number[]} arr */
function average(arr) {
  if (arr.length === 0) return 0;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

// ============================================================================
// Equipment Curve: "how many chests to equip N units?"
// ============================================================================

const MAX_CHESTS = 10000;

/**
 * Count how many entities in army have a complete set for a single color.
 * @param {Object[]} army
 * @param {number[]} colorInv - inventory array for one color (288 items)
 * @param {number} factionOffset
 * @returns {number}
 */
function calculateColorEquipment(army, colorInv, factionOffset) {
  let equipped = 0;
  for (let i = 0; i < army.length; i++) {
    const slotsNeeded = army[i].slotsNeeded;
    const baseIndex = factionOffset + i * 8;
    const set1 = countSetItems(colorInv, baseIndex, ITEMS_PER_SET);
    const set2 = countSetItems(colorInv, baseIndex + ITEMS_PER_SET, ITEMS_PER_SET);
    if (Math.max(set1, set2) >= slotsNeeded) {
      equipped++;
    }
  }
  return equipped;
}

/**
 * @param {number[]} sorted - must be sorted ascending
 * @param {number} p - percentile in 0..1
 */
function percentile(sorted, p) {
  if (sorted.length === 0) return 0;
  const idx = Math.ceil(p * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

/**
 * Compute equipment curve for both systems (using one representative color).
 * All colors have the same pool structure so curves are statistically identical.
 */
function computeEquipmentCurve(params) {
  const { numSimulations, army, factionOffset, initialInventory } = params;
  const colors = ["blue", "green", "purple"];
  const maxUnits = army.length; // 18

  // Count initial equipped per color (for display)
  const initialEquipped = {};
  for (const color of colors) {
    initialEquipped[color] = calculateColorEquipment(army, initialInventory[color], factionOffset);
  }

  // Run curve only once per system using "blue" as representative color
  const representativeColor = "blue";
  const startEquipped = initialEquipped[representativeColor];

  return {
    systemA: runColorCurve(representativeColor, "withDuplicates", numSimulations, army, factionOffset, initialInventory, maxUnits, startEquipped),
    systemB: runColorCurve(representativeColor, "noDuplicates", numSimulations, army, factionOffset, initialInventory, maxUnits, startEquipped),
    initialEquipped: {
      blue: initialEquipped.blue,
      green: initialEquipped.green,
      purple: initialEquipped.purple,
    },
  };
}

/**
 * Run Monte Carlo for one color + one system. Returns milestones array.
 */
function runColorCurve(color, system, numSimulations, army, factionOffset, initialInventory, maxUnits, startEquipped) {
  // For each sim, record chest count when equipped count reaches each milestone
  // milestoneChests[m] = array of chest counts across sims (for milestone m = startEquipped+1 .. maxUnits)
  const numMilestones = maxUnits - startEquipped;
  if (numMilestones <= 0) {
    return { milestones: [] };
  }

  const milestoneChests = new Array(numMilestones);
  for (let m = 0; m < numMilestones; m++) {
    milestoneChests[m] = [];
  }

  for (let sim = 0; sim < numSimulations; sim++) {
    const inv = initialInventory[color].slice();
    let currentEquipped = startEquipped;
    let chests = 0;
    let nextMilestone = startEquipped + 1;

    if (system === "noDuplicates") {
      // Build empty indices list
      const emptyIndices = [];
      for (let i = 0; i < POOL_SIZE; i++) {
        if (inv[i] === 0) emptyIndices.push(i);
      }
      // Shuffle the empty pool for no-duplicates system
      for (let i = emptyIndices.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [emptyIndices[i], emptyIndices[j]] = [emptyIndices[j], emptyIndices[i]];
      }
      let emptyPtr = 0;

      while (nextMilestone <= maxUnits && chests < MAX_CHESTS) {
        // Drop 1 item (no duplicates)
        if (emptyPtr < emptyIndices.length) {
          inv[emptyIndices[emptyPtr]] = 1;
          emptyPtr++;
        }
        // If pool exhausted, reset empty pool (new cycle)
        if (emptyPtr >= emptyIndices.length) {
          emptyIndices.length = 0;
          for (let i = 0; i < POOL_SIZE; i++) {
            if (inv[i] === 0) emptyIndices.push(i);
          }
          // In no-dup system after all 288 collected, all items are owned
          // But we need to keep going if not all units equipped
          // Actually items stay owned, so re-shuffle remaining empty
          for (let i = emptyIndices.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [emptyIndices[i], emptyIndices[j]] = [emptyIndices[j], emptyIndices[i]];
          }
          emptyPtr = 0;
          // If truly no empty slots left, we can't get more items - break
          if (emptyIndices.length === 0) break;
        }
        chests++;

        const equipped = calculateColorEquipment(army, inv, factionOffset);
        while (nextMilestone <= equipped && nextMilestone <= maxUnits) {
          milestoneChests[nextMilestone - startEquipped - 1].push(chests);
          nextMilestone++;
        }
      }
    } else {
      // With duplicates
      while (nextMilestone <= maxUnits && chests < MAX_CHESTS) {
        // Drop 1 random item
        const idx = Math.floor(Math.random() * POOL_SIZE);
        inv[idx]++;
        chests++;

        const equipped = calculateColorEquipment(army, inv, factionOffset);
        while (nextMilestone <= equipped && nextMilestone <= maxUnits) {
          milestoneChests[nextMilestone - startEquipped - 1].push(chests);
          nextMilestone++;
        }
      }
    }

    // Fill remaining milestones with MAX_CHESTS if not reached
    for (let m = nextMilestone - startEquipped - 1; m < numMilestones; m++) {
      milestoneChests[m].push(MAX_CHESTS);
    }
  }

  // Aggregate: compute mean, p90, p95 for each milestone
  const milestones = [];
  for (let m = 0; m < numMilestones; m++) {
    const arr = milestoneChests[m];
    arr.sort((a, b) => a - b);
    milestones.push({
      units: startEquipped + m + 1,
      mean: average(arr),
      p90: percentile(arr, 0.9),
      p95: percentile(arr, 0.95),
    });
  }

  return { milestones };
}
