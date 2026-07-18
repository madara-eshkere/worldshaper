# Спека: Примитивы и World State (M1)

Статус: черновик v1, 2026-07-18. Реализует границу песочницы из ADR-0006/0013.

## Идея

**Примитивы** — фиксированный конечный алфавит операций, через который что-либо
трогает мир. Механики (в песочнице) НЕ трогают Godot-ноды напрямую — только зовут
Примитивы. Это одновременно:
- **граница безопасности** — вайтлист песочницы = ровно эти функции (ADR-0006);
- **основа лестницы Инженера** — Сборщик компонует Примитивы, Создатель пишет новое
  только когда композиции не хватает (ADR-0004);
- **единственный мутатор World State** — вся запись в мир идёт через них.

## World State (модель)

Единственный источник правды о мире — реестр объектов (ADR-0013), сериализуемый в
JSON. Godot-ноды (спрайты) — лишь представление, синхронизируется по сигналам.

Объект:
```
id: String                       # "player", "table_1", "goblin_3"
{
  "type": String,                # "player" | "prop" | "npc" | "item" | ...
  "cell": Vector2i,              # позиция на сетке (в JSON — [x, y])
  "props": Dictionary,           # hp, name, weight, damage, ... — произвольные
  "tags": Array[String],         # "blocking", "flammable", "container", ...
}
```

World эмитит сигналы для рендерера: `object_added/moved/removed/changed(id)`.

## Алфавит Примитивов v1

Сигнатуры — ориентир; реализуется ядро (отмечено ✓), остальное добавляется по мере
нужды Механик. Все Примитивы **валидируют аргументы** и на мусоре возвращают
безопасный отказ (false/пусто) + debug-событие `primitive_rejected`, НИКОГДА не
роняют движок (гость может звать с чем угодно).

**Запрос (read):**
- ✓ `exists(id) -> bool`
- ✓ `get_object(id) -> Dictionary` (копия, не ссылка)
- ✓ `get_prop(id, key, default=null) -> Variant`
- ✓ `objects_at(cell) -> Array[String]`
- ✓ `find_by_tag(tag) -> Array[String]`
- ✓ `is_walkable(cell) -> bool`
- ✓ `player_cell() -> Vector2i`
- ✓ `distance(a_cell, b_cell) -> int` (манхэттен по сетке)

**Спавн/удаление:**
- ✓ `spawn(type, cell, props={}, tags=[]) -> String` (id или "" при отказе)
- ✓ `despawn(id) -> bool`

**Движение:**
- ✓ `move_to(id, cell) -> bool` (валидирует границы/проходимость)
- `nudge(id, dir) -> bool` (толчок на клетку)

**Модификация:**
- ✓ `set_prop(id, key, value) -> bool`
- ✓ `add_tag(id, tag) -> bool` / ✓ `remove_tag(id, tag) -> bool`
- ✓ `damage(id, amount) -> bool` (hp -= amount, клампится в 0)
- `heal(id, amount) -> bool`

**Правила/проверки:**
- ✓ `roll_check(actor_id, skill, dc) -> bool` (невидимый d20+мод vs DC, ADR-0008)
- ✓ `emit(name, data={}) -> void` (семантическое событие в EventBus)

**Позже (M1+/M4):** `attach_behavior(id, mechanic)`, `animate(id, anim)`,
`give_item/take_item`, `set_rule(key, value)`, `set_goal/complete_goal`.

## Кто зовёт Примитивы

- Доверенный код движка (триггеры, бой) — напрямую.
- Механики в песочнице — только Примитивы, через вайтлист (объект Primitives в
  `add_allowed_object`, методы — в `set_method_allowed_callback`).

## Тесты (хедлесс)

Спавн→запрос, move_to с валидацией (в стену — отказ), set_prop/damage,
find_by_tag, roll_check детерминизм при фиксированном сиде, отказ на битых
аргументах (несуществующий id, клетка вне границ) без краша.
