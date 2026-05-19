/// Общие функции для отображения инвентаря
/// Используется в sets_view и army_view

import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/attribute.{class}
import items_calculator/game_data.{type Faction, type ItemColor, Blue, Dark, Green, Light, Purple}
import sets_calculator/sets_inventory.{type InventoryStats}

/// CSS класс для цвета
pub fn color_class(color: ItemColor) -> String {
  case color {
    Blue -> "color-blue"
    Green -> "color-green"
    Purple -> "color-purple"
  }
}

/// Короткое название цвета (для таблицы)
pub fn color_short(color: ItemColor) -> String {
  case color {
    Blue -> "С"
    Green -> "З"
    Purple -> "Ф"
  }
}

/// Отображение меню статистики инвентаря
pub fn view_inventory_stats_menu(stats: InventoryStats) -> Element(msg) {
  div([class("inventory-stats-menu")], [
    div([class("stats-menu-title")], [text("Статистика инвентаря")]),
    div([class("stats-menu-item")], [
      span([class("stats-label")], [text("Всего вещей:")]),
      span([class("stats-value")], [text(int.to_string(stats.total))]),
    ]),
    div([class("stats-menu-divider")], []),
    div([class("stats-menu-subtitle")], [text("По редкости:")]),
    div([class("stats-menu-item")], [
      span([class("stats-label color-blue-text")], [text("Синих:")]),
      span([class("stats-value")], [text(int.to_string(stats.blue))]),
    ]),
    div([class("stats-menu-item")], [
      span([class("stats-label color-green-text")], [text("Зелёных:")]),
      span([class("stats-value")], [text(int.to_string(stats.green))]),
    ]),
    div([class("stats-menu-item")], [
      span([class("stats-label color-purple-text")], [text("Фиолетовых:")]),
      span([class("stats-value")], [text(int.to_string(stats.purple))]),
    ]),
    div([class("stats-menu-divider")], []),
    div([class("stats-menu-subtitle")], [text("По фракции:")]),
    div([class("stats-menu-item")], [
      span([class("stats-label")], [text("Свет:")]),
      span([class("stats-value")], [text(int.to_string(stats.light))]),
    ]),
    div([class("stats-menu-item")], [
      span([class("stats-label")], [text("Тьма:")]),
      span([class("stats-value")], [text(int.to_string(stats.dark))]),
    ]),
  ])
}

/// Парсинг фильтра фракции из строки
pub fn parse_faction_filter(s: String) -> Option(Faction) {
  case s {
    "light" -> Some(Light)
    "dark" -> Some(Dark)
    _ -> None
  }
}

/// Парсинг фильтра цвета из строки
pub fn parse_color_filter(s: String) -> Option(ItemColor) {
  case s {
    "blue" -> Some(Blue)
    "green" -> Some(Green)
    "purple" -> Some(Purple)
    _ -> None
  }
}
