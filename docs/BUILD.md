# Сборка (Windows, M0)

Проверенная на M0 цепочка упаковки: Godot 4.7 + godot-sandbox + PyInstaller.
Инструменты (редактор Godot, шаблоны экспорта) лежат в `tools/` (gitignored),
вывод сборки — в `build/` (gitignored).

## Предпосылки (уже на машине разработки)

- `tools/godot/Godot_v4.7-stable_win64_console.exe` — редактор/CLI Godot 4.7.
- `tools/export-templates/templates/windows_release_x86_64.exe` — шаблон экспорта
  (из `Godot_v4.7-stable_export_templates.tpz`, распакован как zip).
- `sidecar/.venv/` — venv Python 3.10 с `websockets` и `pyinstaller`.

## 1. Экспорт игры

```
tools/godot/Godot_v4.7-stable_win64_console.exe --headless \
  --path game --export-release "Windows Desktop" \
  build/windows/worldshaper.exe
```

Пресет — `game/export_presets.cfg`, ссылается на кастомный шаблон в `tools/`.
Godot сам кладёт рядом `worldshaper.pck` и DLL расширения песочницы
`libgodot_riscv.windows.template_release.x86_64.dll` — упаковка sandbox работает
без ручного вмешательства.

## 2. Упаковка сайдкара

```
sidecar/.venv/Scripts/python.exe -m PyInstaller --onefile --name sidecar \
  --distpath build/windows --paths sidecar sidecar/main.py
```

Даёт `build/windows/sidecar.exe` (~6.5 МБ). Игра ищет его рядом со своим .exe
(`OS.get_executable_path()` + `/sidecar.exe`) и запускает сама при старте.

## 3. Запуск и самопроверка

Запуск `build/windows/worldshaper.exe`:
- поднимает `sidecar.exe` (автозапуск, ADR-0002);
- пишет `build/windows/sidecar.log` — весь цикл событий;
- при закрытии игры сайдкар завершается сам (нормальный выход — через
  `_exit_tree`; краш/форс-килл — сайдкар видит разрыв сокета и выходит, орфанов нет).

Ожидаемый `sidecar.log` (критерий выхода M0 — событие → мок-реплика):

```
sidecar listening on ws://127.0.0.1:8974
game connected
hello from game v0.0.1
event: session_started (turn 0)
narration sent for 'session_started'
game disconnected
sidecar shutting down
```

## Заметки

- Все запуски Godot с расширением песочницы оборачивать OS-таймаутом при
  автоматизации (см. docs/spikes/0001-godot-sandbox.md).
- Мультиплатформенные шаблоны и подпись — задача M5.
