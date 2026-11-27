# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Providers read the current profile on demand. No inventory or result cache lives here.
var providers:Dictionary={}

func register(activity:String,kind:String,facility:String,owned_results:Callable) -> void:
 assert(owned_results.is_valid() and not activity.is_empty() and not kind.is_empty())
 if not providers.has(facility):providers[facility]={}
 assert(not providers[facility].has(activity))
 providers[facility][activity]={"kind":kind,"read":owned_results}

func results(facility:String) -> Array:
 var rows:Array=[]
 var sources:Dictionary=providers.get(facility,{})
 for activity in sources:
  var source:Dictionary=sources[activity]
  for item:Dictionary in source.read.call():
   var result:=item.duplicate()
   result["activity"]=activity
   result["result_type"]=source.kind
   rows.append(result)
 return rows
