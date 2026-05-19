import gleam/option.{type Option, None}
import gleam/list
import plinth/browser/worker.{type Worker}
import items_calculator/game_data.{type Faction, type ItemColor, Light}
import sets_calculator/sets_inventory.{type Inventory}
import sets_calculator/sets_game_data.{type SetId}

/// Параметры симуляции
pub type SimulationParams {
  SimulationParams(
    blue_per_month: Int,
    green_per_month: Int,
    purple_per_month: Int,
    months: Int,
    num_simulations: Int,
  )
}

/// Тип системы выпадения
pub type DropSystem {
  WithDuplicates
  NoDuplicates
}

/// Агрегированный результат за месяц
pub type AggregatedResult {
  AggregatedResult(
    month: Int,
    mean_blue_sets: Float,
    mean_green_sets: Float,
    mean_purple_sets: Float,
  )
}

/// Финальная статистика
pub type FinalStats {
  FinalStats(
    avg_blue_sets: Float,
    avg_green_sets: Float,
    avg_purple_sets: Float,
    avg_total_items: Float,
  )
}

/// Результаты симуляции для одной системы
pub type SystemResult {
  SystemResult(
    system: DropSystem,
    progress_curve: List(AggregatedResult),
    final_stats: FinalStats,
  )
}

/// Результаты сравнения двух систем
pub type ComparisonResult {
  ComparisonResult(system_a: SystemResult, system_b: SystemResult)
}

/// Режим отображения результатов
pub type ResultViewMode {
  ChartMode
  TableMode
  EquipmentCurveMode
}

/// Одна контрольная точка кривой экипировки
pub type EquipmentMilestone {
  EquipmentMilestone(units: Int, mean: Float, p90: Float, p95: Float)
}

/// Результат кривой для одного цвета + одной системы
pub type ColorCurveResult {
  ColorCurveResult(milestones: List(EquipmentMilestone))
}

/// Полный результат кривой экипировки
pub type EquipmentCurveResult {
  EquipmentCurveResult(
    system_a: ColorCurveResult,
    system_b: ColorCurveResult,
    initial_equipped: InitialSetsSnapshot,
  )
}

/// Начальное количество юнитов с сетами
pub type InitialSetsSnapshot {
  InitialSetsSnapshot(blue_sets: Int, green_sets: Int, purple_sets: Int)
}

/// Сохранённая симуляция
pub type SavedSimulation {
  SavedSimulation(
    id: String,
    name: String,
    params: SimulationParams,
    faction: Faction,
    initial_sets: InitialSetsSnapshot,
    result: ComparisonResult,
    created_at: Int,
  )
}

/// Профиль инвентаря
pub type Profile {
  Profile(
    id: String,
    name: String,
    inventory: Inventory,
    created_at: Int,
  )
}

/// Максимальное количество профилей
pub const max_profiles = 10

/// Состояние сравнения симуляций
pub type ComparisonState {
  ComparisonState(
    /// Сохранённые симуляции (макс 5)
    saved_simulations: List(SavedSimulation),
    /// ID симуляций для отображения на графике
    visible_ids: List(String),
    /// ID базовой симуляции для таблицы
    base_id: Option(String),
    /// Система выпадения для графика сравнения
    chart_system: DropSystem,
  )
}

/// Начальное состояние сравнения
pub fn empty_comparison_state() -> ComparisonState {
  ComparisonState(
    saved_simulations: [],
    visible_ids: [],
    base_id: None,
    chart_system: NoDuplicates,
  )
}

/// Модель калькулятора
pub type Model {
  Model(
    selected_faction: Faction,
    params: SimulationParams,
    comparison_result: Option(ComparisonResult),
    worker: Option(Worker),
    is_computing: Bool,
    progress: Float,
    view_mode: ResultViewMode,
    error_message: Option(String),
    /// Глобальный инвентарь (общий с sets_calculator)
    inventory: Inventory,
    /// Открыта ли боковая панель инвентаря
    inventory_panel_open: Bool,
    /// Фильтр инвентаря по редкости
    inventory_filter_color: Option(ItemColor),
    /// Состояние сравнения симуляций
    comparison_state: ComparisonState,
    /// Открыта ли панель сравнения
    comparison_panel_open: Bool,
    /// Открыт ли диалог сохранения
    save_dialog_open: Bool,
    /// Имя симуляции для сохранения
    pending_simulation_name: String,
    /// Список сохранённых профилей
    saved_profiles: List(Profile),
    /// Открыта ли панель профилей
    profiles_panel_open: Bool,
    /// Открыт ли диалог сохранения профиля
    profile_save_dialog_open: Bool,
    /// Имя профиля для сохранения
    pending_profile_name: String,
    /// Открыто ли меню расширенных настроек симуляции
    settings_menu_open: Bool,
    /// Открыто ли меню статистики инвентаря
    inventory_stats_menu_open: Bool,
    /// Фильтр инвентаря по фракции (None = текущая selected_faction)
    inventory_filter_faction: Option(Faction),
    /// Уведомление о копировании share link
    share_notification: Option(String),
    /// Открыто ли меню настроек инвентаря
    inventory_settings_menu_open: Bool,
    /// Результат кривой экипировки
    equipment_curve_result: Option(EquipmentCurveResult),
    /// Показывать ли перцентили (p90, p95) на графике
    show_percentiles: Bool,
  )
}

/// Сообщения калькулятора
pub type Msg {
  SelectFaction(String)
  SetBluePerMonth(String)
  SetGreenPerMonth(String)
  SetPurplePerMonth(String)
  SetMonths(String)
  SetNumSimulations(String)
  RunSimulation
  WorkerReady(Worker)
  SimulationProgress(Float)
  SimulationResult(ComparisonResult, Option(EquipmentCurveResult))
  WorkerError(String)
  SetViewMode(ResultViewMode)
  /// Переключить боковую панель инвентаря
  ToggleInventoryPanel
  /// Переключить слот в инвентаре
  InventoryToggleSlot(SetId, Int)
  /// Установить фильтр инвентаря по редкости
  InventorySetFilterColor(Option(ItemColor))
  /// Заполнить все видимые слоты
  InventoryFillAll
  /// Очистить все видимые слоты
  InventoryClearAll
  // === Сохранение симуляций ===
  /// Открыть диалог сохранения
  OpenSaveDialog
  /// Закрыть диалог сохранения
  CloseSaveDialog
  /// Изменить имя симуляции
  SetSimulationName(String)
  /// Сохранить текущую симуляцию
  SaveCurrentSimulation
  /// Удалить симуляцию по ID
  DeleteSimulation(String)
  // === Сравнение симуляций ===
  /// Переключить видимость на графике
  ToggleSimulationVisibility(String)
  /// Установить базовую симуляцию
  SetBaseSimulation(String)
  /// Выбрать систему выпадения для графика
  SetChartDropSystem(DropSystem)
  /// Открыть/закрыть панель сравнения
  ToggleComparisonPanel
  /// Симуляции загружены из storage
  SimulationsLoaded(List(SavedSimulation))
  // === Управление профилями ===
  /// Открыть/закрыть панель профилей
  ToggleProfilesPanel
  /// Открыть диалог сохранения профиля
  OpenProfileSaveDialog
  /// Закрыть диалог сохранения профиля
  CloseProfileSaveDialog
  /// Изменить имя профиля
  SetProfileName(String)
  /// Сохранить текущий инвентарь как профиль
  SaveCurrentProfile
  /// Загрузить профиль
  LoadProfile(String)
  /// Удалить профиль
  DeleteProfile(String)
  /// Профили загружены из storage
  ProfilesLoaded(List(Profile))
  /// Переключить меню настроек симуляции
  ToggleSettingsMenu
  /// Закрыть меню настроек симуляции
  CloseSettingsMenu
  /// Переключить меню статистики инвентаря
  ToggleInventoryStatsMenu
  /// Закрыть меню статистики инвентаря
  CloseInventoryStatsMenu
  /// Установить фильтр инвентаря по фракции
  InventorySetFilterFaction(Option(Faction))
  // === Share инвентаря ===
  /// Копировать share link
  CopyShareLink
  /// Share link скопирован
  ShareLinkCopied
  /// Ошибка копирования share link
  ShareLinkError(String)
  /// Скрыть уведомление о share link
  HideShareNotification
  // === Меню настроек инвентаря ===
  /// Переключить меню настроек инвентаря
  ToggleInventorySettingsMenu
  /// Закрыть меню настроек инвентаря
  CloseInventorySettingsMenu
  /// Переключить отображение перцентилей
  TogglePercentiles
}

/// Инициализация модели с пустым инвентарём
pub fn init() -> Model {
  init_with_inventory(sets_inventory.empty())
}

/// Инициализация модели с заданным инвентарём
pub fn init_with_inventory(inventory: Inventory) -> Model {
  Model(
    selected_faction: Light,
    params: SimulationParams(
      blue_per_month: 17,
      green_per_month: 7,
      purple_per_month: 3,
      months: 12,
      num_simulations: 1000,
    ),
    comparison_result: None,
    worker: None,
    is_computing: False,
    progress: 0.0,
    view_mode: ChartMode,
    error_message: None,
    inventory: inventory,
    inventory_panel_open: False,
    inventory_filter_color: None,
    comparison_state: empty_comparison_state(),
    comparison_panel_open: False,
    save_dialog_open: False,
    pending_simulation_name: "",
    saved_profiles: [],
    profiles_panel_open: False,
    profile_save_dialog_open: False,
    pending_profile_name: "",
    settings_menu_open: False,
    inventory_stats_menu_open: False,
    inventory_filter_faction: None,
    share_notification: None,
    inventory_settings_menu_open: False,
    equipment_curve_result: None,
    show_percentiles: False,
  )
}

/// Получить количество сохранённых симуляций
pub fn saved_count(model: Model) -> Int {
  list.length(model.comparison_state.saved_simulations)
}

/// Максимальное количество сохранённых симуляций
pub const max_saved_simulations = 5
