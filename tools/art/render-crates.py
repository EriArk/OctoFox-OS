"""Blender 4.5.3: reproduce the Kenney-based catalogue assets (offline renderer).
SPDX-License-Identifier: GPL-3.0-or-later
Run: blender -b -t 4 --python tools/art/render-crates.py
Kenney source geometry retains CC0; see models/kenney/LICENSE.txt.
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]/"assets/crates"
OUT=ROOT/"low-poly"
OUT.mkdir(exist_ok=True)
PALETTES={
 'new': ('#798d64','#e6bc65','#fff0ba','spark'),
 'strategy': ('#708aab','#e6cf9b','#f8e6b4','tower'),
 'tools': ('#557f87','#a8babc','#ffe0a0','gear'),
 'adventure': ('#487d73','#e4bc70','#eae1bd','mountain'),
 'workshop': ('#638fa4','#d8d9c9','#eaba78','wrench'),
 'arcade': ('#bd7463','#7b789d','#ffe2a0','bolt'),
}
def mat(name,colour,metal=0):
 c=[int(colour[i:i+2],16)/255 for i in (1,3,5)]
 c=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in c]
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1)
 bs.inputs['Roughness'].default_value=.58;bs.inputs['Metallic'].default_value=metal
 return m

def icon_mesh(points,material):
 # A genuine, thin extruded mesh on the front of the case.
 n=len(points);vs=[(x,y,z+.28) for y in (-.679,-.699) for x,z in points]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new('emblem');mesh.from_pydata(vs,[],faces);mesh.update()
 o=bpy.data.objects.new('emblem',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 return o

def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
stats={}
for key,(body_c,band_c,emblem_c,symbol) in PALETTES.items():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'models/kenney/chest.glb'))
 body=mat('paint',body_c);band=mat('edge bands',band_c,.15);inside=mat('interior','#253f43');accent=mat('emblem',emblem_c)
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  o.animation_data_clear()
  o.data.materials.clear()
  for m in (inside,band,body):o.data.materials.append(m)
  uv=o.data.uv_layers.active.data
  for poly in o.data.polygons:
   u=uv[poly.loop_start].uv.x;poly.material_index=0 if u<.2 else (1 if u<.6 else 2)
 # Widen the common parent, keeping the inherited lid pivot.
 chest=bpy.data.objects['chest'];chest.scale.x=1.8
 lid=bpy.data.objects['lid'];lid.rotation_mode='XYZ';lid.rotation_euler=(0,0,0)
 lid.keyframe_insert('rotation_euler',frame=1)
 lid.rotation_euler.x=math.radians(-100);lid.keyframe_insert('rotation_euler',frame=25)
 bpy.context.scene.frame_set(1)
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.219,depth=.035,location=(0,-.665,.28),rotation=(math.pi/2,0,0))
 plate=bpy.context.object;plate.name='category badge';plate.data.materials.append(inside)
 if symbol=='mountain':points=[(-.16,-.09),(-.045,.12),(.01,.02),(.07,.095),(.16,-.09)]
 elif symbol=='bolt':points=[(.015,.16),(-.13,-.025),(-.025,-.025),(-.055,-.15),(.13,.055),(.02,.055)]
 elif symbol=='spark':points=[(0,.18),(.045,.055),(.16,0),(.045,-.05),(0,-.16),(-.045,-.05),(-.16,0),(-.045,.055)]
 elif symbol=='tower':points=[(-.13,-.14),(.13,-.14),(.10,-.07),(.09,.08),(.13,.08),(.13,.16),(.065,.16),(.065,.11),(.025,.11),(.025,.16),(-.025,.16),(-.025,.11),(-.065,.11),(-.065,.16),(-.13,.16),(-.13,.08),(-.09,.08),(-.10,-.07)]
 elif symbol=='gear':points=[((.17 if i%4 in (0,1) else .12)*math.cos(i*math.pi/12),(.17 if i%4 in (0,1) else .12)*math.sin(i*math.pi/12)) for i in range(24)]
 else:points=[(-.14,-.10),(-.10,-.14),(.055,.015),(.12,.015),(.16,.06),(.16,.125),(.10,.07),(.065,.105),(.12,.16),(.05,.16),(.015,.12),(.015,.055)]
 icon_mesh(points,accent)
 scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=25
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.render.resolution_x=512;scene.render.resolution_y=448;scene.render.resolution_percentage=100
 scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
 scene.view_settings.view_transform='AgX'
 scene.world=bpy.data.worlds.new('studio');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.62,.72,.8,1)
 scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
 bpy.ops.object.camera_add(location=(2.0,-7,2.7));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=3.15;aim(camera,(0,0,.60));scene.camera=camera
 # Fit the union of closed/open bounds once; keep the camera fixed through opening.
 bpy.context.view_layer.update()
 coords=[]
 for frame in (1,25):
  scene.frame_set(frame);bpy.context.view_layer.update()
  inv=camera.matrix_world.inverted()
  coords.extend(inv @ o.matrix_world @ Vector(v) for o in scene.objects if o.type=='MESH' for v in o.bound_box)
 xmin,xmax=min(v.x for v in coords),max(v.x for v in coords)
 ymin,ymax=min(v.y for v in coords),max(v.y for v in coords)
 camera.location += camera.matrix_world.to_quaternion() @ Vector(((xmin+xmax)/2,(ymin+ymax)/2,0))
 camera.data.ortho_scale=max(xmax-xmin,(ymax-ymin)*512/448)*1.12
 scene.frame_set(1)
 for name,loc,power,size in [('key',(-3,-4,6),450,4),('fill',(4,-1,3),180,3),('rim',(0,4,5),400,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name=name;o.data.energy=power;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,.5))
 meshes=[o for o in scene.objects if o.type=='MESH']
 stats[key]={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'meshes':len(meshes),'render_size':[512,448]}
 bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=chest
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'models'/f'{key}.glb'),use_selection=True,export_format='GLB',export_animations=True,export_frame_range=True)
 for i,frame in enumerate((1,6,11,16,21,25)):
  scene.frame_set(frame);scene.render.filepath=str(OUT/f'{key}-{i}.png');bpy.ops.render.render(write_still=True)
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2)+'\n')
