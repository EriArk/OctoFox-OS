# SPDX-License-Identifier: GPL-3.0-or-later
class_name OctoFoxHeldItem
extends Resource
## Shared item definition. The inventory instance ID is supplied separately when equipping.
enum Kind { WEAPON, DEVICE, FISHING_ROD }
@export var kind := Kind.DEVICE
@export var action: StringName = &"activate"
@export var model: PackedScene
@export_enum("hand.R", "hand.L") var socket := "hand.R"
@export var grip := Transform3D.IDENTITY
