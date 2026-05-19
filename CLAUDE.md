# wlfun — Claude guide

Gleam → JavaScript калькуляторы для WL. Lustre (Elm-like MVU), web workers под тяжёлые Monte Carlo, FFI слой на JS.

## Стек и компоновка

- **Язык**: Gleam, target `javascript` (см. `gleam.toml`).
- **Фреймворк**: Lustre (`>= 5.2`) для UI, `lustre_dev_tools` для dev-сервера.
- **Воркеры**: `boosting_simulation_worker.js`, `probability_worker.js` — long-running Monte Carlo, общаются через `postMessage`.
- **FFI**: каждое `*_ffi.mjs` в `src/` — мост JS↔Gleam (`gleam_stdlib/gleam.mjs` для `toList`, `gleam/option.mjs` для `Some`/`None`).
- **Хранение**: `varasto` (typed localStorage), JSON через `gleam_json`, DOM через `plinth`.
- **Калькуляторы** в `src/`: `army_simulator/`, `bp_calculator/`, `items_calculator/`, `sets_calculator/`. Общий код — `shared/`. Вход — `wl_calculators.gleam`.

## Команды

| Что | Как |
|---|---|
| Сборка | `gleam build` |
| Dev-сервер | `gleam run -m lustre/dev start` |
| Тесты | `gleam test` |
| Один HTML | `./build_single_html.sh` |

## Доменные особенности

- Inventory: 288 items/color (36 entities × 2 sets × 4 items). Light offset = 0, Dark offset = 144.
- У каждой entity 8 слотов (2 sets × 4 items). Юнитам надо 3/4 в сете, героям 4/4.
- Воркер принимает данные как **string или object** в зависимости от вызывающего — обрабатывать оба варианта.
- Gleam `Option` ↔ JS FFI: `new Some(x)` / `new None()`. JS-массивы перед передачей в Gleam — оборачивать `toList()`.

## Worktree workflow

Инфраструктура клонирует подход clarinet:

- Feature-работа — через `EnterWorktree`. Мелкие правки/typos можно делать в `master`, но Edit/Write/Agent с записью **блокируются** хуками `require-worktree.sh` / `require-worktree-agent.sh` (читающие агенты — `code-explorer`, `code-reviewer` — разрешены).
- `git checkout`/`switch` в корневом каталоге запрещён (`block-branch-switch.sh`). `git checkout -- <file>` для restore — разрешён.
- При завершении сессии внутри worktree `worktree-stop.sh` спрашивает выбор: **push+PR / keep / discard**. Один из трёх — обязателен.
- `ExitWorktree(remove)` требует `discard_changes=true`, если есть коммиты не в `master`.
- После `gh pr create` фоновой задачей запускается `pr-monitor.sh` → отчёт `/tmp/pr-<N>-report.md`.

## Bash anti-patterns

`bash-anti-patterns.sh` блокирует:
- Ведущие `cat <file>` / `grep` / `find` — использовать Read / Grep / Glob.
- Команды, начинающиеся с `#` (комментарий не выполняется).
- pytest/test в pipe (буферизует stdout). Здесь актуально для `gleam test` — редиректить в `/tmp/test-wlfun.txt`.
- Escape: добавить `# bash-ok` в конец команды.

## Правила

`.claude/rules/README.md` — индекс path-scoped правил (пока пуст). Глобальное `~/.claude/rules/gleam.md` подгружается автоматически.

## Локальность .claude/

Вся папка `.claude/` игнорируется через `.git/info/exclude` — per-repo локальный gitignore, лежит внутри `.git/`, в коммиты не попадает и при `git clone` не передаётся. Семантика для `git status`/`git add` — как у `.gitignore`. Инфраструктура чисто локальная, в `origin/master` не уходит.

Если потребуется частично залить какой-то файл из `.claude/` — снять строку `.claude/` из `.git/info/exclude` или сделать `git add --force <path>`.

CLAUDE.md в корне проекта **не** игнорируется — он tracked.

> Worktree-нюанс: `git worktree add` создаёт собственный `$GIT_DIR/info/exclude`. Если в новом worktree `.claude/` начнёт появляться в `git status` — продублировать строку в `.git/worktrees/<name>/info/exclude`.
