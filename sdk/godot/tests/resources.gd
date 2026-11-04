# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
func _initialize() -> void:
    var path := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--resource="): path=arg.trim_prefix("--resource=")
    var script=load("res://avatar_presenter.gd")
    if script==null: quit(1);return
    var bytes := FileAccess.get_file_as_bytes(path)
    var plain: PackedByteArray = script._resource_bytes(bytes)
    if plain!="TrainerOS cross-reader fixture".to_utf8_buffer(): quit(2);return
    for offset in [0,4,8,24,bytes.size()-1]:
        var damaged := bytes.duplicate()
        damaged[offset] ^= 1
        if not script._resource_bytes(damaged).is_empty(): quit(3);return
    if not script._resource_bytes(bytes.slice(0,bytes.size()-1)).is_empty(): quit(4);return
    print("TAV1 C++/Godot interoperability and rejection checks passed")
    quit(0)
