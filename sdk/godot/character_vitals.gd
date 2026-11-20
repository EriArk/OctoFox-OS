# SPDX-License-Identifier: GPL-3.0-or-later
class_name OctoFoxCharacterVitals
extends RefCounted
## One instance per actor. The simulation owner configures the pools and handles defeat.
signal changed
signal defeated
var max_health := 100.0
var max_shield := 0.0
var max_energy := 0.0
var max_mana := 0.0
var health := 100.0
var shield := 0.0
var energy := 0.0
var mana := 0.0
var armor := 0.0

func configure(hp: float, armor_rating := 0.0, shields := 0.0, energy_capacity := 0.0, mana_capacity := 0.0) -> bool:
	for value: float in [hp, armor_rating, shields, energy_capacity, mana_capacity]:
		if not is_finite(value) or value < 0.0: return false
	if hp == 0.0: return false
	max_health = hp
	armor = armor_rating
	max_shield = shields
	max_energy = energy_capacity
	max_mana = mana_capacity
	refill()
	return true

func refill() -> void:
	health = max_health
	shield = max_shield
	energy = max_energy
	mana = max_mana
	changed.emit()

## Shields absorb raw damage first. A rating of 100 halves damage reaching health.
func take_damage(amount: float) -> void:
	if health <= 0.0 or not is_finite(amount) or amount <= 0.0: return
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health = maxf(0.0, health - (amount - absorbed) / (1.0 + armor / 100.0))
	if health == 0.0: defeated.emit()
	changed.emit()

## A game can call restore with rate * delta for regeneration.
func restore(pool: StringName, amount: float) -> bool:
	if health <= 0.0 or not is_finite(amount) or amount <= 0.0: return false
	if pool not in [&"health", &"shield", &"energy", &"mana"]: return false
	var before: float = get(pool)
	var after := minf(before + amount, get("max_" + pool))
	if before == after: return false
	set(pool, after)
	changed.emit()
	return true

func try_spend(pool: StringName, amount: float) -> bool:
	if health <= 0.0 or pool not in [&"energy", &"mana"]: return false
	if not is_finite(amount) or amount < 0.0: return false
	var balance: float = get(pool)
	if amount > balance: return false
	if amount > 0.0:
		set(pool, balance - amount)
		changed.emit()
	return true
