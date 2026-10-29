# wlfun — гайд для агентов

Gleam → JavaScript калькуляторы для WL. Lustre (Elm-like MVU), web workers под тяжёлые Monte Carlo, FFI слой на JS.

Канонический инструкционный файл — `AGENTS.md`; `CLAUDE.md` — symlink на него (один канон, без параллельных правок).

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
| Тесты | `gleam test` (не в pipe — редиректить в `/tmp/test-wlfun.txt`) |
| Формат (как в CI) | `gleam format --check src test` |
| Один HTML | `./build_single_html.sh` |

## Доменные особенности

- Inventory: 288 items/color (36 entities × 2 sets × 4 items). Light offset = 0, Dark offset = 144.
- У каждой entity 8 слотов (2 sets × 4 items). Юнитам надо 3/4 в сете, героям 4/4.
- Воркер принимает данные как **string или object** в зависимости от вызывающего — обрабатывать оба варианта.
- Gleam `Option` ↔ JS FFI: `new Some(x)` / `new None()`. JS-массивы перед передачей в Gleam — оборачивать `toList()`.

## Worktree workflow

Инфраструктура клонирует подход clarinet:

- Feature-работа — через `EnterWorktree`: Edit/Write и записывающие агенты **блокируются** на `main` хуками `require-worktree.sh` / `require-worktree-agent.sh`. Exempt (правятся на `main` напрямую): `.claude/*`, `.zcode/*`, `AGENTS.md`, `CLAUDE.md`. Читающие агенты `feature-dev:code-explorer` / `feature-dev:code-reviewer` — разрешены.
- `git checkout`/`switch` в корневом каталоге запрещён (`block-branch-switch.sh`). `git checkout -- <file>` для restore — разрешён.
- При завершении сессии внутри worktree `worktree-stop.sh` спрашивает выбор: **push+PR / keep / discard**. Один из трёх — обязателен.
- `ExitWorktree(remove)` требует `discard_changes=true`, если есть коммиты не в `main`.
- После `gh pr create` фоновой задачей запускается `pr-monitor.sh` → отчёт `/tmp/pr-<N>-report.md`.

## Bash anti-patterns

`bash-anti-patterns.sh` блокирует:
- Ведущие `cat <file>` / `grep` / `find` — использовать Read / Grep / Glob.
- Команды, начинающиеся с `#` (комментарий не выполняется).
- Тест-команды (`pytest`, `make test*`, `gleam test`, `uv run pytest`) в pipe (буферизует stdout) — редиректить в `/tmp/test-wlfun.txt`.
- Escape: добавить `# bash-ok` в конец команды.

## Правила

`.zcode/rules/README.md` — индекс path-scoped правил (пока пуст); `.claude/rules/README.md` — symlink на него. Глобальные правила (`~/.zcode/rules/`, `~/.claude/rules/`) подгружаются соответствующим клиентом.

## Харнес: .zcode/ канонический, .claude/ локальный

`.zcode/` — канонический enforcement-слой (`config.json`, `hooks/`, `agents/`, `rules/`), tracked в git. `.claude/` — локальная копия для Claude Code, игнорируется через `.git/info/exclude`; её `hooks/`, `agents/`, `rules/` — symlinks в `.zcode/`. Править канон в `.zcode/`, а не копии.

Чтобы залить файл из `.claude/` — снять строку `.claude/` из `.git/info/exclude` или сделать `git add --force <path>`.

> Worktree-нюанс: `git worktree add` создаёт собственный `$GIT_DIR/info/exclude`. Если в новом worktree `.claude/` начнёт появляться в `git status` — продублировать строку `.claude/` в `.git/worktrees/<name>/info/exclude`.
