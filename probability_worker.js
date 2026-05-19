// TODO: может использовать какую-нибудь библиотеку для рандома?

/**
 * @param {number} minDuplicates - min hits to count as "duplicated"
 * @returns {number} count of items that reached threshold
 */
function runDuplicateSimulation(attempts, poolSize, minDuplicates, initialCounts) {
  // Copy initial counts or create zeros list
  const counts = initialCounts ? [...initialCounts] : new Array(poolSize).fill(0)

  for (let i = 0; i < attempts; i++) {
    const item = Math.floor(Math.random() * poolSize)
    counts[item]++
  }

  let itemsWithDuplicates = 0
  for (let i = 0; i < poolSize; i++) {
    if (counts[i] >= minDuplicates) {
      itemsWithDuplicates++
    }
  }
  // console.log('simulation done, items with dups:', itemsWithDuplicates)
  return itemsWithDuplicates
}

/** @returns {number} probability estimate (success ratio) */
function bootstrapPoint(attempts, poolSize, minDuplicates, minItems, numSimulations, initialCounts) {
  let successes = 0
  for (let sim = 0; sim < numSimulations; sim++) {
    const itemsWithDups = runDuplicateSimulation(attempts, poolSize, minDuplicates, initialCounts)
    if (itemsWithDups >= minItems) {
      successes++
    }
  }
  return successes / numSimulations
}

/**
 * FIXME: это очень медленно для больших maxAttempts, надо бы оптимизировать
 * @returns {Array<[number, number]>} [attempts, probability] pairs
 */
function calculateBootstrapCurve(params) {
  const { minDuplicates, minItems, maxAttempts, numSimulations, initialCounts, poolSize } = params

  // TODO: добавить progress callback чтобы показывать прогресс в UI
  const curve = []
  for (let m = 0; m <= maxAttempts; m++) {
    const prob = bootstrapPoint(m, poolSize, minDuplicates, minItems, numSimulations, initialCounts)
    curve.push([m, prob])
    // console.log(`bootstrap progress: ${m}/${maxAttempts}`)
  }
  return curve
}

// это всё по формулам из википедии и stackoverflow

/** Poisson CDF: P(X <= k). копипаста со stackoverflow */
function poissonCdf(k, lambda) {
  if (lambda <= 0) return 1.0
  if (k < 0) return 0.0

  // считаем через рекуррентную формулу, чтобы не переполнить float факториалами
  const eNegLambda = Math.exp(-lambda)
  let sum = eNegLambda
  let pI = eNegLambda

  for (let i = 1; i <= k; i++) {
    pI = pI * lambda / i  // это P(X=i) = P(X=i-1) * lambda / i
    sum += pI
  }
  return sum
}

/**
 * P(X >= k) via Poisson approximation.
 * аппроксимация Пуассона работает только когда n большое и p маленькое
 */
function probAtLeastKHits(n, k, p) {
  if (k <= 0) return 1.0
  if (k > n) return 0.0

  const lambda = n * p
  return 1.0 - poissonCdf(k - 1, lambda)
}

/*
// старая версия через точный биномиальный расчёт
// не работает для больших n из-за переполнения факториалов
// оставлю на всякий случай
function probAtLeastKHitsExact(n, k, p) {
  if (k <= 0) return 1.0
  if (k > n) return 0.0

  let sum = 0
  for (let i = k; i <= n; i++) {
    // C(n, i) * p^i * (1-p)^(n-i)
    const binomCoeff = factorial(n) / (factorial(i) * factorial(n - i))
    sum += binomCoeff * Math.pow(p, i) * Math.pow(1 - p, n - i)
  }
  return sum
}

function factorial(n) {
  if (n <= 1) return 1
  let result = 1
  for (let i = 2; i <= n; i++) {
    result *= i
  }
  return result  // overflow при n > 170 примерно
}
*/

/**
 * Binomial PMF: [P(X=0), P(X=1), ..., P(X=n)] via recurrence.
 * это работает, не трогать
 */
function binomialPmf(n, p) {
  if (n === 0) return [1.0]

  // edge cases
  if (p >= 1.0) {
    const result = new Array(n + 1).fill(0)
    result[n] = 1.0
    return result
  }

  if (p <= 0.0) {
    const result = new Array(n + 1).fill(0)
    result[0] = 1.0
    return result
  }

  const q = 1.0 - p
  const result = new Array(n + 1)
  let prevProb = Math.pow(q, n)  // P(X=0) = q^n
  result[0] = prevProb

  // P(X=k) = P(X=k-1) * (n-k+1)/k * p/q
  for (let k = 1; k <= n; k++) {
    const ratio = ((n - k + 1) / k) * (p / q)
    prevProb = prevProb * ratio
    result[k] = prevProb
  }
  return result
}

/**
 * Convolution: если X ~ distA и Y ~ distB, то X + Y ~ convolve(distA, distB)
 */
function convolve(distA, distB) {
  const lenA = distA.length
  const lenB = distB.length
  const resultLen = lenA + lenB - 1
  const result = new Array(resultLen).fill(0)

  // можно было бы через FFT сделать
  // но для наших размеров и так норм
  // TODO: если будет тормозить - переписать через FFT
  for (let i = 0; i < lenA; i++) {
    for (let j = 0; j < lenB; j++) {
      result[i + j] += distA[i] * distB[j]
    }
  }
  return result
}

/** @param {number[][]} distributions */
function convolveAll(distributions) {
  if (distributions.length === 0) return [1.0]

  return distributions.reduce((acc, dist) => convolve(acc, dist))
}

/** @returns {Array<[number, number]>} [count, numItems] tuples */
function groupCounts(counts) {
  const groups = new Map()  
  for (const count of counts) {
    groups.set(count, (groups.get(count) || 0) + 1)
  }
  return Array.from(groups.entries())
}

/** P(S >= n) — sums up tail of distribution */
function probAtLeastFromDist(dist, n) {
  return dist.slice(n).reduce((sum, p) => sum + p, 0)
}

/**
 * Poisson-Binomial convolution: groups items by initial count,
 * builds binomial dist for each group, convolves to get total.
 * @param {number} pItem - 1/poolSize
 */
function calculatePointWithConvolution(attempts, minDuplicates, minItems, groups, pItem) {
  // Build binomial distribution for each group
  const distributions = groups.map(([initialCount, numItems]) => {
    const needed = Math.max(0, minDuplicates - initialCount)
    const pSuccess = probAtLeastKHits(attempts, needed, pItem)
    return binomialPmf(numItems, pSuccess)
  })

  // Convolve all to get total distribution
  const totalDist = convolveAll(distributions)

  // P(S >= min_items)
  return probAtLeastFromDist(totalDist, minItems)
}

/**
 * TODO: кэшировать результаты для одинаковых параметров?
 * хотя воркер и так каждый раз пересоздаётся наверное
 * @returns {Array<[number, number]>} [attempts, probability] pairs
 */
function calculateAnalyticCurve(params) {
  const { minDuplicates, minItems, maxAttempts, initialCounts, poolSize } = params

  const pItem = 1.0 / poolSize
  const groups = groupCounts(initialCounts)

  // console.log('groups:', groups)
  // console.log('pItem:', pItem)

  const curve = []
  for (let m = 0; m <= maxAttempts; m++) {
    const prob = calculatePointWithConvolution(m, minDuplicates, minItems, groups, pItem)
    curve.push([m, prob])
  }
  return curve
}

// TODO: добавить обработку отмены вычислений (AbortController или что там в воркерах)

// type: 'calculate_bootstrap' | 'calculate_analytic' | 'calculate_both'
self.onmessage = function(event) {
  const { type, params, requestId } = event.data

  // console.log('worker received:', type, params)

  let result
  try {
    switch (type) {
      case 'calculate_bootstrap':
        result = calculateBootstrapCurve(params)
        break

      case 'calculate_analytic':
        result = calculateAnalyticCurve(params)
        break

      case 'calculate_both':
        result = {
          analytic: calculateAnalyticCurve(params),
          bootstrap: params.includeBootstrap ? calculateBootstrapCurve(params) : null
        }
        break

      default:
        throw new Error(`Unknown calculation type: ${type}`)
    }

    self.postMessage({
      type: 'result',
      requestId,
      curve: result
    })

  } catch (error) {
    // console.error('worker error:', error)
    self.postMessage({
      type: 'error',
      requestId,
      error: error.message
    })
  }
}

// console.log('probability worker loaded!')
