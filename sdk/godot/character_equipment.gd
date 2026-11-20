# SPDX-License-Identifier: GPL-3.0-or-later
class_name OctoFoxCharacterEquipment
extends Node
## One active handheld item. The game resolves ownership and implements each action.
const Item = preload("held_item.gd")
signal equipped_changed(instance_id: String)
signal used(instance_id: String, action: StringName)
var instance_id := ""
var definition: Item
var _attachment: BoneAttachment3D

## Resolve the item from the current inventory before calling this method.
## Pass a null skeleton for a simulation without graphics.
func equip(id: String, item: Item, rig: Skeleton3D = null) -> bool:
	if id.is_empty() or item == null or item.action.is_empty(): return false
	var attachment: BoneAttachment3D
	if rig != null and item.model != null:
		if rig.find_bone(item.socket) < 0: return false
		var visual := item.model.instantiate()
		if not visual is Node3D:
			if visual != null: visual.free()
			return false
		attachment = BoneAttachment3D.new()
		rig.add_child(attachment)
		attachment.bone_name = item.socket
		attachment.add_child(visual)
		visual.transform = item.grip
	_remove_attachment()
	_attachment = attachment
	instance_id = id
	definition = item
	equipped_changed.emit(id)
	return true

func unequip() -> void:
	if definition == null: return
	_remove_attachment()
	instance_id = ""
	definition = null
	equipped_changed.emit("")

func use_item() -> bool:
	if definition == null: return false
	used.emit(instance_id, definition.action)
	return true

func _remove_attachment() -> void:
	if is_instance_valid(_attachment):
		_attachment.get_parent().remove_child(_attachment)
		_attachment.queue_free()
	_attachment = null

func _exit_tree() -> void:
	unequip()
