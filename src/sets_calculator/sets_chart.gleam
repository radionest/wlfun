import gleam/int
import gleam/float
import gleam/list
import gleam/string
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import lustre/element/svg.{svg, line, polyline, text as svg_text, rect, g}
import lustre/attribute.{attribute, class}

/// Отрисовка SVG графика вероятности
pub fn render_chart(
  data: List(#(Int, Float)),
  bootstrap_data: Option(List(#(Int, Float))),
  width: Int,
  height: Int,
) -> Element(msg) {
  let padding = 50
  let chart_width = width - padding - 20
  let chart_height = height - padding - 30

  // Находим максимальное X
  let max_x = case list.last(data) {
    Ok(#(x, _)) -> x
    Error(_) -> 100
  }

  // Элементы бутстрап-кривой (если есть)
  let bootstrap_elements = case bootstrap_data {
    Some(bs_data) -> [
      render_bootstrap_line(bs_data, padding, chart_width, chart_height, max_x),
      render_legend(padding, chart_width),
    ]
    None -> []
  }

  svg(
    [
      attribute("viewBox", "0 0 " <> int.to_string(width) <> " " <> int.to_string(height)),
      attribute("preserveAspectRatio", "xMidYMid meet"),
      class("probability-chart"),
    ],
    list.flatten([
      [
        // Фон
        rect([
          attribute("x", "0"),
          attribute("y", "0"),
          attribute("width", int.to_string(width)),
          attribute("height", int.to_string(height)),
          attribute("fill", "var(--bg-card, #1a1a2e)"),
          attribute("rx", "8"),
        ]),
        // Сетка
        render_grid(padding, chart_width, chart_height),
        // Оси
        render_axes(padding, chart_width, chart_height),
        // Заливка под графиком (основная)
        render_area(data, padding, chart_width, chart_height, max_x),
        // Линия графика (основная - аналитика)
        render_line(data, padding, chart_width, chart_height, max_x),
      ],
      bootstrap_elements,
      [
        // Метки осей
        render_x_labels(padding, chart_width, chart_height, max_x),
        render_y_labels(padding, chart_height),
        // Заголовки осей
        render_axis_titles(width, height, padding),
      ],
    ]),
  )
}

/// Сетка графика
fn render_grid(padding: Int, chart_width: Int, chart_height: Int) -> Element(msg) {
  let p = int.to_string(padding)
  let right = int.to_string(padding + chart_width)
  let bottom = int.to_string(padding + chart_height)

  // Горизонтальные линии сетки (каждые 20%)
  let h_lines = list.map([0.2, 0.4, 0.6, 0.8], fn(ratio) {
    let y = padding + float_to_int(int.to_float(chart_height) *. { 1.0 -. ratio })
    let y_str = int.to_string(y)
    line([
      attribute("x1", p),
      attribute("y1", y_str),
      attribute("x2", right),
      attribute("y2", y_str),
      attribute("stroke", "var(--border-color, #333)"),
      attribute("stroke-opacity", "0.3"),
      attribute("stroke-dasharray", "4 4"),
    ])
  })

  // Вертикальные линии сетки (каждые 25%)
  let v_lines = list.map([0.25, 0.5, 0.75], fn(ratio) {
    let x = padding + float_to_int(int.to_float(chart_width) *. ratio)
    let x_str = int.to_string(x)
    line([
      attribute("x1", x_str),
      attribute("y1", p),
      attribute("x2", x_str),
      attribute("y2", bottom),
      attribute("stroke", "var(--border-color, #333)"),
      attribute("stroke-opacity", "0.3"),
      attribute("stroke-dasharray", "4 4"),
    ])
  })

  g([], list.append(h_lines, v_lines))
}

/// Оси X и Y
fn render_axes(padding: Int, chart_width: Int, chart_height: Int) -> Element(msg) {
  let p = int.to_string(padding)
  let right = int.to_string(padding + chart_width)
  let bottom = int.to_string(padding + chart_height)

  g([], [
    // Ось Y
    line([
      attribute("x1", p),
      attribute("y1", p),
      attribute("x2", p),
      attribute("y2", bottom),
      attribute("stroke", "var(--text-secondary, #888)"),
      attribute("stroke-width", "2"),
    ]),
    // Ось X
    line([
      attribute("x1", p),
      attribute("y1", bottom),
      attribute("x2", right),
      attribute("y2", bottom),
      attribute("stroke", "var(--text-secondary, #888)"),
      attribute("stroke-width", "2"),
    ]),
  ])
}

/// Линия графика
fn render_line(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
) -> Element(msg) {
  let points = data_to_points(data, padding, chart_width, chart_height, max_x)

  polyline([
    attribute("points", points),
    attribute("fill", "none"),
    attribute("stroke", "var(--accent, #6366f1)"),
    attribute("stroke-width", "2.5"),
    attribute("stroke-linecap", "round"),
    attribute("stroke-linejoin", "round"),
  ])
}

/// Заливка под графиком
fn render_area(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
) -> Element(msg) {
  let points_str = data_to_points(data, padding, chart_width, chart_height, max_x)

  // Добавляем точки для замыкания области
  let bottom_y = int.to_string(padding + chart_height)
  let start_x = int.to_string(padding)
  let end_x = int.to_string(padding + chart_width)

  let area_points = points_str <> " " <> end_x <> "," <> bottom_y <> " " <> start_x <> "," <> bottom_y

  svg.polygon([
    attribute("points", area_points),
    attribute("fill", "var(--accent, #6366f1)"),
    attribute("fill-opacity", "0.15"),
  ])
}

/// Преобразование данных в строку точек для SVG
fn data_to_points(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
) -> String {
  let max_x_f = int.to_float(max_x)
  let chart_w_f = int.to_float(chart_width)
  let chart_h_f = int.to_float(chart_height)
  let padding_f = int.to_float(padding)

  data
  |> list.map(fn(point) {
    let #(x, y) = point
    let px = padding_f +. { int.to_float(x) /. max_x_f *. chart_w_f }
    let py = padding_f +. chart_h_f -. { y *. chart_h_f }
    int.to_string(float_to_int(px)) <> "," <> int.to_string(float_to_int(py))
  })
  |> string.join(" ")
}

/// Метки оси X
fn render_x_labels(
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
) -> Element(msg) {
  let bottom = padding + chart_height + 20
  let bottom_str = int.to_string(bottom)

  // Метки: 0, 25%, 50%, 75%, 100% от max_x
  let labels = [0.0, 0.25, 0.5, 0.75, 1.0]
  |> list.map(fn(ratio) {
    let value = float_to_int(int.to_float(max_x) *. ratio)
    let x = padding + float_to_int(int.to_float(chart_width) *. ratio)
    svg_text(
      [
        attribute("x", int.to_string(x)),
        attribute("y", bottom_str),
        attribute("text-anchor", "middle"),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "11"),
      ],
      int.to_string(value),
    )
  })

  g([], labels)
}

/// Метки оси Y
fn render_y_labels(padding: Int, chart_height: Int) -> Element(msg) {
  let x = padding - 10
  let x_str = int.to_string(x)

  // Метки: 0%, 20%, 40%, 60%, 80%, 100%
  let labels = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
  |> list.map(fn(ratio) {
    let y = padding + float_to_int(int.to_float(chart_height) *. { 1.0 -. ratio })
    let label = int.to_string(float_to_int(ratio *. 100.0)) <> "%"
    svg_text(
      [
        attribute("x", x_str),
        attribute("y", int.to_string(y + 4)),
        attribute("text-anchor", "end"),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "10"),
      ],
      label,
    )
  })

  g([], labels)
}

/// Заголовки осей
fn render_axis_titles(width: Int, height: Int, padding: Int) -> Element(msg) {
  g([], [
    // Заголовок оси X
    svg_text(
      [
        attribute("x", int.to_string(width / 2)),
        attribute("y", int.to_string(height - 5)),
        attribute("text-anchor", "middle"),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "12"),
      ],
      "Количество вещей",
    ),
    // Заголовок оси Y (вертикальный)
    svg_text(
      [
        attribute("x", int.to_string(15)),
        attribute("y", int.to_string(padding + 60)),
        attribute("text-anchor", "middle"),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "12"),
        attribute("transform", "rotate(-90, 15, " <> int.to_string(padding + 60) <> ")"),
      ],
      "Вероятность",
    ),
  ])
}

/// Преобразование Float в Int (усечение)
fn float_to_int(f: Float) -> Int {
  case f <. 0.0 {
    True -> {
      let pos = float.truncate(0.0 -. f)
      0 - pos
    }
    False -> float.truncate(f)
  }
}

/// Линия бутстрап-симуляции (оранжевая, пунктирная)
fn render_bootstrap_line(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
) -> Element(msg) {
  let points = data_to_points(data, padding, chart_width, chart_height, max_x)

  polyline([
    attribute("points", points),
    attribute("fill", "none"),
    attribute("stroke", "#f97316"),  // оранжевый
    attribute("stroke-width", "2"),
    attribute("stroke-linecap", "round"),
    attribute("stroke-linejoin", "round"),
    attribute("stroke-dasharray", "6 3"),  // пунктир
  ])
}

/// Легенда графика
fn render_legend(padding: Int, chart_width: Int) -> Element(msg) {
  let legend_x = padding + chart_width - 120
  let legend_y = padding + 10

  g([], [
    // Фон легенды
    rect([
      attribute("x", int.to_string(legend_x - 5)),
      attribute("y", int.to_string(legend_y - 5)),
      attribute("width", "125"),
      attribute("height", "45"),
      attribute("fill", "var(--bg-card, #1a1a2e)"),
      attribute("fill-opacity", "0.9"),
      attribute("rx", "4"),
      attribute("stroke", "var(--border-color, #333)"),
    ]),
    // Аналитика (синяя)
    line([
      attribute("x1", int.to_string(legend_x)),
      attribute("y1", int.to_string(legend_y + 10)),
      attribute("x2", int.to_string(legend_x + 20)),
      attribute("y2", int.to_string(legend_y + 10)),
      attribute("stroke", "var(--accent, #6366f1)"),
      attribute("stroke-width", "2.5"),
    ]),
    svg_text(
      [
        attribute("x", int.to_string(legend_x + 25)),
        attribute("y", int.to_string(legend_y + 14)),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "11"),
      ],
      "Аналитика",
    ),
    // Бутстрап (оранжевая пунктирная)
    line([
      attribute("x1", int.to_string(legend_x)),
      attribute("y1", int.to_string(legend_y + 28)),
      attribute("x2", int.to_string(legend_x + 20)),
      attribute("y2", int.to_string(legend_y + 28)),
      attribute("stroke", "#f97316"),
      attribute("stroke-width", "2"),
      attribute("stroke-dasharray", "6 3"),
    ]),
    svg_text(
      [
        attribute("x", int.to_string(legend_x + 25)),
        attribute("y", int.to_string(legend_y + 32)),
        attribute("fill", "var(--text-secondary, #888)"),
        attribute("font-size", "11"),
      ],
      "Бутстрап",
    ),
  ])
}

// ============================================================================
// Multi-chart для нескольких кривых
// ============================================================================

/// Цвета для разных кривых
pub fn chart_colors() -> List(String) {
  [
    "#6366f1",  // indigo (основной)
    "#f97316",  // orange
    "#22c55e",  // green
    "#ef4444",  // red
    "#8b5cf6",  // violet
    "#06b6d4",  // cyan
    "#ec4899",  // pink
    "#eab308",  // yellow
  ]
}

/// Тип данных для одной кривой
pub type ChartCurve {
  ChartCurve(
    label: String,
    data: List(#(Int, Float)),
    color: String,
  )
}

/// Отрисовка SVG графика с несколькими кривыми
pub fn render_multi_chart(
  curves: List(ChartCurve),
  width: Int,
  height: Int,
) -> Element(msg) {
  let padding = 50
  let chart_width = width - padding - 20
  let chart_height = height - padding - 30

  // Находим максимальное X по всем кривым
  let max_x = curves
    |> list.flat_map(fn(c) {
      case list.last(c.data) {
        Ok(#(x, _)) -> [x]
        Error(_) -> []
      }
    })
    |> list.fold(1, fn(acc, x) {
      case x > acc {
        True -> x
        False -> acc
      }
    })

  // Отрисовка каждой кривой (заливка + линия)
  let curve_elements = curves
    |> list.flat_map(fn(curve) {
      [
        render_area_colored(curve.data, padding, chart_width, chart_height, max_x, curve.color),
        render_line_colored(curve.data, padding, chart_width, chart_height, max_x, curve.color),
      ]
    })

  svg(
    [
      attribute("viewBox", "0 0 " <> int.to_string(width) <> " " <> int.to_string(height)),
      attribute("preserveAspectRatio", "xMidYMid meet"),
      class("probability-chart multi-chart"),
    ],
    list.flatten([
      [
        // Фон
        rect([
          attribute("x", "0"),
          attribute("y", "0"),
          attribute("width", int.to_string(width)),
          attribute("height", int.to_string(height)),
          attribute("fill", "var(--bg-card, #1a1a2e)"),
          attribute("rx", "8"),
        ]),
        // Сетка
        render_grid(padding, chart_width, chart_height),
        // Оси
        render_axes(padding, chart_width, chart_height),
      ],
      // Все кривые
      curve_elements,
      [
        // Легенда
        render_multi_legend(curves, padding, chart_width),
        // Метки осей
        render_x_labels(padding, chart_width, chart_height, max_x),
        render_y_labels(padding, chart_height),
        // Заголовки осей
        render_axis_titles(width, height, padding),
      ],
    ]),
  )
}

/// Линия графика с заданным цветом
fn render_line_colored(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
  color: String,
) -> Element(msg) {
  let points = data_to_points(data, padding, chart_width, chart_height, max_x)

  polyline([
    attribute("points", points),
    attribute("fill", "none"),
    attribute("stroke", color),
    attribute("stroke-width", "2.5"),
    attribute("stroke-linecap", "round"),
    attribute("stroke-linejoin", "round"),
  ])
}

/// Заливка под графиком с заданным цветом
fn render_area_colored(
  data: List(#(Int, Float)),
  padding: Int,
  chart_width: Int,
  chart_height: Int,
  max_x: Int,
  color: String,
) -> Element(msg) {
  let points_str = data_to_points(data, padding, chart_width, chart_height, max_x)

  let bottom_y = int.to_string(padding + chart_height)
  let start_x = int.to_string(padding)
  let end_x = int.to_string(padding + chart_width)

  let area_points = points_str <> " " <> end_x <> "," <> bottom_y <> " " <> start_x <> "," <> bottom_y

  svg.polygon([
    attribute("points", area_points),
    attribute("fill", color),
    attribute("fill-opacity", "0.1"),
  ])
}

/// Легенда для нескольких кривых
fn render_multi_legend(curves: List(ChartCurve), padding: Int, chart_width: Int) -> Element(msg) {
  let count = list.length(curves)
  case count {
    0 -> g([], [])
    _ -> {
      let legend_x = padding + chart_width - 140
      let legend_y = padding + 10
      let item_height = 18
      let legend_height = count * item_height + 10

      g([], [
        // Фон легенды
        rect([
          attribute("x", int.to_string(legend_x - 5)),
          attribute("y", int.to_string(legend_y - 5)),
          attribute("width", "145"),
          attribute("height", int.to_string(legend_height)),
          attribute("fill", "var(--bg-card, #1a1a2e)"),
          attribute("fill-opacity", "0.9"),
          attribute("rx", "4"),
          attribute("stroke", "var(--border-color, #333)"),
        ]),
        // Элементы легенды
        g([], render_legend_items(curves, legend_x, legend_y, item_height, 0)),
      ])
    }
  }
}

/// Рекурсивный рендер элементов легенды
fn render_legend_items(
  curves: List(ChartCurve),
  legend_x: Int,
  legend_y: Int,
  item_height: Int,
  index: Int,
) -> List(Element(msg)) {
  case curves {
    [] -> []
    [curve, ..rest] -> {
      let y_offset = legend_y + index * item_height + 10
      let truncated_label = truncate_label(curve.label, 16)
      let items = [
        line([
          attribute("x1", int.to_string(legend_x)),
          attribute("y1", int.to_string(y_offset)),
          attribute("x2", int.to_string(legend_x + 20)),
          attribute("y2", int.to_string(y_offset)),
          attribute("stroke", curve.color),
          attribute("stroke-width", "2.5"),
        ]),
        svg_text(
          [
            attribute("x", int.to_string(legend_x + 25)),
            attribute("y", int.to_string(y_offset + 4)),
            attribute("fill", "var(--text-secondary, #888)"),
            attribute("font-size", "10"),
          ],
          truncated_label,
        ),
      ]
      list.append(items, render_legend_items(rest, legend_x, legend_y, item_height, index + 1))
    }
  }
}

/// Обрезать метку до максимальной длины
fn truncate_label(label: String, max_len: Int) -> String {
  case string.length(label) > max_len {
    True -> string.slice(label, 0, max_len - 1) <> "…"
    False -> label
  }
}
