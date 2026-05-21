import army_simulator/army_model.{type Profile}
import gleam/option.{type Option, None, Some}
import items_calculator/game_data.{type Faction, type ItemColor, Blue, Light}
import plinth/browser/worker.{type Worker}
import sets_calculator/sets_game_data.{type EntityType, type SetId, RegularUnit}
import sets_calculator/sets_inventory.{
  type Inventory, type OwnedCounts, type OwnedSlots, empty_counts, empty_slots,
}

/// Тип цели для расчета (устаревший, оставлен для совместимости)
pub type GoalType {
  /// Конкретный сет (Сет 1 синего Мечника)
  GoalSpecificSet
  /// Любой сет на конкретного юнита/героя (любой синий Мечника)
  GoalAnySetOnEntity
  /// Любой сет на фракцию (любой синий Света)
  GoalAnySetOnFaction
  /// Первый попавшийся сет редкости
  GoalFirstSetOfColor
  /// Дубликаты вещей
  GoalDuplicates
}

/// Идентификатор узла в дереве сетов
pub type TreeNodeId {
  /// Узел фракции (Свет/Тьма)
  FactionNode(Faction)
  /// Узел юнита/героя (фракция, имя, тип)
  EntityNode(Faction, String, EntityType)
}

/// Активная цель с результатом расчёта
pub type ActiveGoal {
  ActiveGoal(
    /// Метка для отображения
    label: String,
    /// Кривая вероятности
    probability_curve: Option(List(#(Int, Float))),
    /// Цвет на графике
    chart_color: String,
  )
}

/// Режим отображения результатов
pub type ViewMode {
  /// Простой режим - только вероятность с пояснением
  SimpleMode
  /// Режим графика - полный график кривой
  ChartMode
}

/// Модель калькулятора сетов
pub type Model {
  Model(
    /// Тип цели (устаревшее, для совместимости)
    goal_type: GoalType,
    /// Выбранная фракция (для GoalAnySetOnFaction и фильтрации)
    selected_faction: Option(Faction),
    /// Выбранный юнит или герой
    selected_entity: Option(String),
    /// Тип выбранной сущности
    selected_entity_type: EntityType,
    /// Выбранная редкость (глобальный параметр для всех целей)
    selected_color: ItemColor,
    /// Номер сета (1 или 2)
    selected_set_number: Int,
    /// Имеющиеся вещи (bool)
    owned_slots: OwnedSlots,
    /// Счётчики дубликатов для слотов
    owned_counts: OwnedCounts,
    /// Максимум попыток для графика
    max_attempts: Int,
    // === Новые поля для панели целей ===
    /// Активные цели с результатами расчёта
    active_goals: List(ActiveGoal),
    /// Раскрытые узлы дерева
    expanded_tree_nodes: List(TreeNodeId),
    /// Выбранные сеты в дереве
    selected_sets: List(SetId),
    /// Включен ли чекбокс "Конкретный сет"
    specific_set_enabled: Bool,
    /// Включен ли чекбокс "Любой сет фракции"
    any_faction_enabled: Bool,
    /// Выбранная фракция для "Любой сет фракции"
    any_faction_faction: Faction,
    /// Включен ли чекбокс "Дубликаты"
    duplicates_enabled: Bool,
    /// Строковое значение для input max_attempts
    max_attempts_str: String,
    /// Результат расчета: список (попытки, вероятность)
    probability_curve: Option(List(#(Int, Float))),
    /// Результат бутстрап-расчёта для сравнения (только для GoalDuplicates)
    bootstrap_curve: Option(List(#(Int, Float))),
    /// Глобальный инвентарь сетов
    inventory: Inventory,
    /// Развернута ли секция инвентаря
    inventory_expanded: Bool,
    /// Фильтр инвентаря по фракции
    inventory_filter_faction: Option(Faction),
    /// Фильтр инвентаря по редкости
    inventory_filter_color: Option(ItemColor),
    /// Минимум раз, сколько вещь должна выпасть (K)
    min_duplicates_per_item: Int,
    /// Минимум вещей с таким количеством дубликатов (N)
    min_items_with_duplicates: Int,
    /// Строковое значение для input min_duplicates
    min_duplicates_str: String,
    /// Строковое значение для input min_items
    min_items_str: String,
    /// Автоматически пересчитывать бутстрап при изменении параметров
    bootstrap_auto_update: Bool,
    /// Режим отображения результатов
    view_mode: ViewMode,
    /// Web Worker для тяжёлых вычислений
    worker: Option(Worker),
    /// Идёт ли вычисление
    is_computing: Bool,
    /// Уведомление о копировании share link
    share_notification: Option(String),
    /// Открыто ли меню настроек графика
    settings_menu_open: Bool,
    /// Открыто ли меню настроек инвентаря
    inventory_settings_menu_open: Bool,
    /// Открыто ли меню статистики инвентаря
    inventory_stats_menu_open: Bool,
    /// Открыта ли боковая панель инвентаря
    inventory_panel_open: Bool,
    /// Список сохранённых профилей (общий с army_simulator)
    saved_profiles: List(Profile),
    /// Открыта ли панель профилей
    profiles_panel_open: Bool,
    /// Открыт ли диалог сохранения профиля
    profile_save_dialog_open: Bool,
    /// Имя профиля для сохранения
    pending_profile_name: String,
  )
}

/// Сообщения калькулятора
pub type Msg {
  /// Изменение типа цели (устаревшее)
  SetGoalType(String)
  /// Выбор фракции
  SelectFaction(String)
  /// Выбор юнита/героя
  SelectEntity(String)
  /// Выбор типа сущности (юнит/герой)
  SelectEntityType(String)
  /// Выбор редкости (глобальный)
  SelectColor(String)
  /// Выбор номера сета
  SelectSetNumber(Int)
  /// Переключение слота имеющейся вещи
  ToggleOwnedSlot(Int)
  /// Изменение макс. попыток
  SetMaxAttempts(String)
  /// Сброс имеющихся вещей
  ResetOwnedSlots

  // === Новые сообщения для панели целей ===
  /// Переключить чекбокс "Конкретный сет"
  ToggleSpecificSetGoal
  /// Переключить чекбокс "Любой сет фракции"
  ToggleAnyFactionGoal
  /// Переключить чекбокс "Дубликаты"
  ToggleDuplicatesGoal
  /// Выбор фракции для "Любой сет фракции"
  SetAnyFactionFaction(String)
  /// Раскрыть/свернуть узел дерева
  ToggleTreeNode(TreeNodeId)
  /// Выбрать/отменить сет в дереве
  ToggleSetSelection(SetId)
  /// Выбрать все сеты в узле
  SelectAllInNode(TreeNodeId)
  /// Отменить все сеты в узле
  DeselectAllInNode(TreeNodeId)
  /// Развернуть/свернуть секцию инвентаря
  ToggleInventorySection
  /// Переключить слот в инвентаре
  InventoryToggleSlot(SetId, Int)
  /// Установить фильтр инвентаря по фракции
  InventorySetFilterFaction(Option(Faction))
  /// Установить фильтр инвентаря по редкости
  InventorySetFilterColor(Option(ItemColor))
  /// Установить счётчик в инвентаре (set_id, slot, value_str)
  InventorySetCount(SetId, Int, String)
  /// Изменение минимума дубликатов на вещь
  SetMinDuplicates(String)
  /// Изменение минимума вещей с дубликатами
  SetMinItems(String)
  /// Переключить автообновление бутстрапа
  ToggleBootstrapAutoUpdate
  /// Запустить пересчёт бутстрапа вручную
  RunBootstrap
  /// Переключение режима отображения
  SetViewMode(ViewMode)
  /// Worker готов к работе
  WorkerReady(Worker)
  /// Результат вычислений получен (analytic, bootstrap)
  ComputationResult(List(#(Int, Float)), Option(List(#(Int, Float))))
  /// Ошибка worker
  WorkerError(String)
  /// Копировать share link
  CopyShareLink
  /// Share link скопирован успешно
  ShareLinkCopied
  /// Ошибка копирования share link
  ShareLinkError(String)
  /// Скрыть уведомление о share link
  HideShareNotification
  /// Переключить меню настроек графика
  ToggleSettingsMenu
  /// Закрыть меню настроек графика (клик вне)
  CloseSettingsMenu
  /// Переключить меню настроек инвентаря
  ToggleInventorySettingsMenu
  /// Закрыть меню настроек инвентаря
  CloseInventorySettingsMenu
  /// Отметить все слоты в текущем фильтре
  InventoryFillAll
  /// Убрать все слоты в текущем фильтре
  InventoryClearAll
  /// Сбросить счётчики в текущем фильтре
  InventoryResetCounts
  /// Переключить меню статистики инвентаря
  ToggleInventoryStatsMenu
  /// Закрыть меню статистики инвентаря
  CloseInventoryStatsMenu
  /// Переключить боковую панель инвентаря
  ToggleInventoryPanel
  // === Управление профилями ===
  /// Переключить панель профилей
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
}

/// Инициализация модели
pub fn init() -> Model {
  init_with_inventory(sets_inventory.empty())
}

/// Инициализация модели с загруженным инвентарём
pub fn init_with_inventory(inventory: Inventory) -> Model {
  Model(
    goal_type: GoalSpecificSet,
    selected_faction: Some(Light),
    selected_entity: None,
    selected_entity_type: RegularUnit,
    selected_color: Blue,
    selected_set_number: 1,
    owned_slots: empty_slots(),
    owned_counts: empty_counts(),
    max_attempts: 18,
    // Новые поля для панели целей
    active_goals: [],
    expanded_tree_nodes: [],
    selected_sets: [],
    specific_set_enabled: False,
    any_faction_enabled: False,
    any_faction_faction: Light,
    duplicates_enabled: False,
    max_attempts_str: "100",
    probability_curve: None,
    bootstrap_curve: None,
    inventory: inventory,
    inventory_expanded: False,
    inventory_filter_faction: None,
    inventory_filter_color: None,
    min_duplicates_per_item: 2,
    min_items_with_duplicates: 1,
    min_duplicates_str: "2",
    min_items_str: "1",
    bootstrap_auto_update: False,
    view_mode: SimpleMode,
    worker: None,
    is_computing: False,
    share_notification: None,
    settings_menu_open: False,
    inventory_settings_menu_open: False,
    inventory_stats_menu_open: False,
    inventory_panel_open: False,
    saved_profiles: [],
    profiles_panel_open: False,
    profile_save_dialog_open: False,
    pending_profile_name: "",
  )
}

/// Преобразование типа цели в строку
pub fn goal_type_to_string(gt: GoalType) -> String {
  case gt {
    GoalSpecificSet -> "specific"
    GoalAnySetOnEntity -> "entity"
    GoalAnySetOnFaction -> "faction"
    GoalFirstSetOfColor -> "color"
    GoalDuplicates -> "duplicates"
  }
}

/// Преобразование строки в тип цели
pub fn string_to_goal_type(s: String) -> GoalType {
  case s {
    "entity" -> GoalAnySetOnEntity
    "faction" -> GoalAnySetOnFaction
    "color" -> GoalFirstSetOfColor
    "duplicates" -> GoalDuplicates
    _ -> GoalSpecificSet
  }
}

/// Название типа цели для UI
pub fn goal_type_label(gt: GoalType) -> String {
  case gt {
    GoalSpecificSet -> "Конкретный сет"
    GoalAnySetOnEntity -> "Любой сет юнита/героя"
    GoalAnySetOnFaction -> "Любой сет фракции"
    GoalFirstSetOfColor -> "Любой сет редкости"
    GoalDuplicates -> "Дубликаты вещей"
  }
}
