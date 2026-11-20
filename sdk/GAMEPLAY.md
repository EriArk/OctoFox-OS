# Игровой персонаж в Godot SDK

У каждого участника игры могут быть свои параметры, предмет в руке и способ перемещения. Игра выбирает модули отдельно и задаёт кнопки, баланс, сохранение и владельца симуляции. Все три модуля работают офлайн.

## Здоровье и ресурсы

Создайте экземпляр [character_vitals.gd](godot/character_vitals.gd) для каждого персонажа. Аргументы `configure` задают максимум HP, рейтинг брони, максимум щита, энергии и маны. По умолчанию у персонажа 100 HP. Остальные показатели отключены нулевым значением.

```gdscript
const Vitals = preload("res://character_vitals.gd")
var vitals := Vitals.new()

func spawn_actor():
    vitals.configure(100, 50, 30, 80, 20)

func hit_example():
    vitals.take_damage(60)
    # Щит поглотил 30, оставшиеся 30 при броне 50 сняли 20 HP.
```

После щита входящий урон умножается на `100 / (100 + armor)`. Щит расходуется, рейтинг брони сохраняется. `try_spend(&"mana", 5)` или `try_spend(&"energy", 5)` оплачивает действие полностью и возвращает результат. `restore(pool, amount)` восполняет выбранную шкалу до её максимума. Игра сама выбирает момент лечения, задержку зарядки или скорость регенерации. Подпишите HUD на `changed`, обработчик поражения на `defeated`. При возрождении вызовите `refill()`. Поражённого персонажа нельзя вылечить обычной регенерацией.

## Предмет в руке

[character_equipment.gd](godot/character_equipment.gd) держит один активный экземпляр. Передайте его ID из инвентаря игры или подтверждённого инвентаря профиля. Определение [held_item.gd](godot/held_item.gd) задаёт категорию, команду, сцену модели, кость руки и смещение хвата. Есть стартовые определения [оружия](godot/items/weapon.tres), [девайса](godot/items/device.tres) и [удочки](godot/items/fishing_rod.tres). Чтобы добавить графику, назначьте корнем своей модели Node3D и выставьте `grip` в координатах выбранной кисти.

```gdscript
const Equipment = preload("res://character_equipment.gd")
const Rod = preload("res://items/fishing_rod.tres")
var hand := Equipment.new()

func start_equipment():
    add_child(hand)
    hand.used.connect(on_item_used)

func select_rod(owned_instance_id: String, rig: Skeleton3D):
    return hand.equip(owned_instance_id, Rod, rig)

func on_item_used(instance_id: String, action: StringName):
    if action == &"cast":
        fishing.begin_cast(instance_id) # Игровая механика рыбалки
```

Вызовите `use_item()` по команде игрока. Категории по умолчанию передают `attack`, `activate` и `cast`. Игра обрабатывает эффект, расход ресурса и перезарядку. Для серверной симуляции можно опустить скелет. При снятии, продаже, отзыве доступа или смене персонажа вызовите `unequip()`. После смены внешности передайте скелет нового аватара при повторном экипировании. Экипировка по ID не создаёт лот и не меняет права собственности.

## Джетпак, слайд и буллетджамп

К прежнему вызову [мотора](LOCOMOTION.md) добавился необязательный последний аргумент. Пустое значение включает обычное движение. Слайд и буллетджамп передаются один раз на нажатие, джетпак — на каждом физическом такте, пока доступна тяга. Пример использует уже рассчитанные игрой направление и состояния кнопок.

```gdscript
var action: StringName = &""
var thrust_cost := 8.0 * delta
if controls_enabled and vitals.health > 0:
    if leap_pressed:
        action = &"bullet_jump"
    elif slide_pressed:
        action = &"slide"
    elif thrust_held and vitals.energy >= thrust_cost:
        action = &"jetpack"

var can_move := controls_enabled and vitals.health > 0
motor.step(delta, direction, sprint, crouch, jump_pressed, can_move, walk, action)
if motor.gait == "jetpack":
    vitals.try_spend(&"energy", thrust_cost)
motion.advance(delta, motor.actual_speed, can_move, motor.crouched,
               body.is_on_floor(), motor.gait)
```

- **Слайд** начинается с разбега на земле. Капсула становится ниже, скорость постепенно падает. После слайда персонаж встаёт при наличии места над головой.
- **Буллетджамп** стартует с земли, в том числе из слайда. Персонаж получает импульс вверх и вперёд и вращается вокруг продольной оси. Для нового толчка нужно приземлиться.
- **Джетпак** даёт управляемую тягу с ограничением вертикальной скорости. Когда запрос прекращается, снова действует обычная гравитация.

Три скелетных клипа находятся в [mobility.tres](godot/animations/mobility.tres), используют риг общего аватара и поставляются вместе с каталогом `animations/`. Слайд и джетпак зациклены, буллетджамп проигрывается один раз. Смена поз сохраняет исходные размеры тела и привязку одежды. Скрипты работают с теми же единицами и системой координат, что и обычная ходьба.

## Проверка

Из корня репозитория запустите импорт Godot 4.7 и проверки:

```sh
godot --headless --path sdk/godot --editor --import
godot --headless --fixed-fps 60 --path sdk/godot -s tests/gameplay.gd
godot --headless --fixed-fps 60 --path sdk/godot -s tests/mobility_poses.gd -- --descriptor=/absolute/path/to/sample.json
```

Первый сценарий проверяет расчёт урона, расход и восстановление ресурсов, действие и крепление предмета, физические переходы и отзыв управления. Второй загружает аватар через обычный SDK presenter и проверяет воспроизведение всех трёх клипов и возврат к стойке.
