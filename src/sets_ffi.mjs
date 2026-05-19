// FFI функции для калькулятора сетов

export function floatToString(f) {
  return Math.floor(f).toString();
}

export function floatToFixed(f, decimals) {
  return f.toFixed(decimals);
}

// Случайное целое число от 0 до max-1
export function randomInt(max) {
  return Math.floor(Math.random() * max);
}

// Запуск одной симуляции дубликатов
// Возвращает количество вещей с >= minDuplicates попаданиями
export function runDuplicateSimulation(attempts, poolSize, minDuplicates) {
  const counts = new Array(poolSize).fill(0);
  for (let i = 0; i < attempts; i++) {
    const item = Math.floor(Math.random() * poolSize);
    counts[item]++;
  }
  let itemsWithDuplicates = 0;
  for (let i = 0; i < poolSize; i++) {
    if (counts[i] >= minDuplicates) {
      itemsWithDuplicates++;
    }
  }
  return itemsWithDuplicates;
}

// Бутстрап для одной точки M
// Возвращает вероятность (доля успешных симуляций)
export function bootstrapPoint(attempts, poolSize, minDuplicates, minItems, numSimulations) {
  let successes = 0;
  for (let sim = 0; sim < numSimulations; sim++) {
    const itemsWithDups = runDuplicateSimulation(attempts, poolSize, minDuplicates);
    if (itemsWithDups >= minItems) {
      successes++;
    }
  }
  return successes / numSimulations;
}

// Конвертация Gleam List в JS Array (использует встроенный метод toArray)
function gleamListToArray(gleamList) {
  return gleamList.toArray();
}

// Запуск симуляции с начальными счётчиками
function runDuplicateSimulationWithInitial(
  attempts,
  poolSize,
  minDuplicates,
  initialCountsArray  // JS Array<number> длиной poolSize
) {
  // Копируем начальные счётчики
  const counts = [...initialCountsArray];
  for (let i = 0; i < attempts; i++) {
    const item = Math.floor(Math.random() * poolSize);
    counts[item]++;
  }
  let itemsWithDuplicates = 0;
  for (let i = 0; i < poolSize; i++) {
    if (counts[i] >= minDuplicates) {
      itemsWithDuplicates++;
    }
  }
  return itemsWithDuplicates;
}

// Бутстрап с начальными счётчиками (принимает Gleam List и конвертирует в Array)
export function bootstrapPointWithInitial(
  attempts,
  poolSize,
  minDuplicates,
  minItems,
  numSimulations,
  initialCountsGleamList  // Gleam List
) {
  // Конвертируем Gleam List в JS Array один раз перед симуляциями
  const initialCountsArray = gleamListToArray(initialCountsGleamList);

  let successes = 0;
  for (let sim = 0; sim < numSimulations; sim++) {
    const itemsWithDups = runDuplicateSimulationWithInitial(
      attempts, poolSize, minDuplicates, initialCountsArray
    );
    if (itemsWithDups >= minItems) {
      successes++;
    }
  }
  return successes / numSimulations;
}
