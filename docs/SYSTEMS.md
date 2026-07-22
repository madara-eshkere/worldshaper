# Обзор систем рантайма (M1)

Карта того, как устроен движок к концу M1. Цель документа — чтобы **человек или ИИ
мог добавлять контент как ДАННЫЕ, не трогая движок** (это и есть фундамент под
ИИ-Режиссёра/Инженера). Термины — в [CONTEXT.md](../CONTEXT.md), решения — в
[docs/adr](adr). Полный «контракт для ИИ» (исчерпывающий список Примитивов + строгая
схема) — первая задача M2 (B-021); здесь — рабочая карта.

## Слои (снизу вверх)

1. **World State** ([world_state.gd](../game/scripts/world_state.gd), автозагрузка `World`) —
   единственный источник правды: тайл-карта (`set_map/is_walkable`) + реестр объектов
   `id → {type, cell, props, tags}`. Сериализуется в JSON. **Только Примитивы пишут сюда.**
2. **Примитивы** ([primitives.gd](../game/scripts/primitives.gd)) — фиксированный
   алфавит-мутатор (query/spawn/move/set_prop/tag/damage/heal/roll_check/emit…). Каждый
   валидирует аргументы и безопасно отказывает. Список: `Primitives.PRIMITIVE_NAMES`.
   Спека: [docs/specs/primitives.md](specs/primitives.md).
3. **Механики** ([mechanic_runner.gd](../game/scripts/mechanic_runner.gd)) — ДАННЫЕ,
   не код: `{steps:[{prim, args}]}` с подстановкой `$actor/$target/$cell`. Крутит
   доверенный интерпретатор; вызывать можно только имена из `PRIMITIVE_NAMES`.
   Спека: [docs/specs/mechanics.md](specs/mechanics.md).
4. **Рефлексы** ([trigger_system.gd](../game/scripts/trigger_system.gd)) — Скриптовые
   триггеры (событие+условие → Механика) и Эскалации (счётчики). Данные, ноль LLM.
5. **Планировщик ходов** ([turn_scheduler.gd](../game/scripts/turn_scheduler.gd),
   ADR-0016) — энергетический: независимые актёры, ход по `next_at`, скорость = частота.
6. **Виды** — `world_grid` (тайлы+туман), `entity_renderer` (объекты по цвету/форме из
   props), `player` (ввод+вид), HUD-ы. Читают World, не пишут.

## Как добавить контент (всё — данные)

- **Карту:** `World.set_map(w, h, tiles)` (0=пол, 1=стена). Пример — `level.gd::_build_map`.
- **Объект:** `prim.spawn(type, cell, props, tags)`. Теги-роли: `enemy`, `blocking`,
  `item`, `pit`, `interactable`, `corpse`, `destructible`, `flying`, `exit`.
- **Существо:** класс данными в [bestiary.gd](../game/scripts/bestiary.gd)
  (`hp/atk/def/str/dex/speed/flying/color/glyph/name`) → `Bestiary.spawn(prim, cls, cell)`.
- **Механику:** положить в Библиотеку ([library.gd](../game/scripts/library.gd)) как
  данные; повесить на триггер или интеракцию.
- **Триггер/интеракцию/победу:** `triggers.register_trigger(...)`,
  `interactions.register(...)`, `win.set_predicate({...})`. Пример — весь `level.gd`.

## Ключевые характеристики

- **d20** ([character_sheet.gd](../game/scripts/character_sheet.gd)): STR/DEX/CON/INT/CHA/PER,
  HP из класса+CON, `atk/def` производные, `speed` из DEX ([speed.gd](../game/scripts/speed.gd)).
  Проверки — Примитив `roll_check(actor, ability, dc)`, невидимы (ADR-0008).

## Словарь событий (EventBus)

Ход/действия: `player_moved`, `player_interacted`, `player_waited`, `used_item`,
`picked_up`, `bumped_wall`, `bumped_object`.
Бой (однозначные): `player_hit_enemy {enemy,name,hit,damage,killed}`,
`enemy_hit_player {enemy,name,hit,damage}`, `enemy_slain {enemy,name}`, `player_died`.
Мир: `fell_into_pit`, `climbed_out_of_pit`, `enemy_fell_into_pit {who}`, `stun_tick`,
`level_complete`, `game_over` (через оверлей), `primitive_rejected`, `mechanic_error`.

## Правила, которые нельзя нарушать (для будущего кода/ИИ)

- Уровень/существа/карта — **данные**, не хардкод в движковых скриптах (урок B-006/B-024).
- В World пишут **только Примитивы**; логика не зависит от Видов.
- Механика — **композиция Примитивов-данных**, не сырой код (сырой код = M4-песочница).
- Занятость строгая: два актёра не в одной клетке. Скорость решает частоту, не «клетки».
- Каждое изменение — под тестом (`game/tests/*`, запуск headless как сцена).
