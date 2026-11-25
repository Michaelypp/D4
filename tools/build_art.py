# /// script
# requires-python = "==3.13.*"
# dependencies = ["bpy==5.2.*"]
# ///
"""Blender as a library: build the kit, art/dragon_kit.glb and art/dragon_kit.blend.

deno task art      uses Blender 5.2 (the header above)
deno task art:lts  uses Blender 4.5 LTS, for Intel Macs, which Blender 5 dropped
deno task blender  opens art/dragon_kit.blend in the Blender app, to look around

Every piece fills one 1x1 grid cell and is made by a builder function listed in
PIECES (the robot and belt) or TILES (the restaurant). The game picks up each mesh by name.

Conventions the game relies on (Blender coordinates, Z up):
  - A cell spans x and y from -0.5 to 0.5. +Y is the direction of travel.
  - Openings must match Kit.OPENINGS in core/kit.gd: the head and tail join the
    body at the back and front, the turn joins the back and the right side.
  - Floors lie with their top at z = 0; everything else stands on z = 0.

Editing by hand in Blender instead:
  The game loads only art/dragon_kit.glb, never the .blend. After editing a .blend in
  Blender, export it yourself with File > Export > glTF 2.0 (.glb/.gltf):
    Format: glTF Binary (.glb)        File: art/dragon_kit.glb
    Include: no Limit to boxes ticked; Cameras and Punctual Lights unticked
    Transform: +Y Up ticked           Mesh: Apply Modifiers ticked
  and keep the object names (head, straight, turn, tail, floor, wall, ...).
  WARNING: deno task art rewrites BOTH art/dragon_kit.blend and art/dragon_kit.glb,
  erasing hand edits. Before editing, File > Save As a copy such as art/my_kit.blend
  (deno task blender art/my_kit.blend reopens it). The tradeoff: from then on the
  kit lives in that file, not in this script, so a change here no longer reaches it
  unless you redo it by hand, and a .blend is hard to review in a diff.
"""

from pathlib import Path

import bpy  # first: importing bpy is what makes bmesh and mathutils available
import bmesh
from mathutils import Matrix

# Paths from this file, not the current directory, so the script works from anywhere.
# Build them with pathlib rather than gluing strings together, as Blender's gotchas advise:
# https://docs.blender.org/api/current/info_gotchas_file_paths_and_encoding.html
ART = Path(__file__).resolve().parent.parent / "art"
GLB = ART / "dragon_kit.glb"
BLEND = ART / "dragon_kit.blend"



MATERIALS = []  # every material, in order; a face's material_index points into this list
PALETTE = {}  # builder material key -> index in MATERIALS; filled in by make_materials()


def reset_scene():
    """Start from an empty file, so nothing from Blender's default scene (cube, camera,
    light) or an earlier run leaks into the kit."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


# --- Materials ------------------------------------------------------------------


def pbr_material(name, color, metallic=0.0, roughness=0.5, emission=None, strength=1.0):
    """A Principled BSDF using only inputs glTF keeps. Returns its index in MATERIALS.
    Emission above about 1 blooms in the game, because the stage has glow switched on."""
    material = bpy.data.materials.new(name)
    if bpy.app.version < (5, 0):  # 4.x starts without nodes; 5.x always has them and deprecates use_nodes
        material.use_nodes = True
    # Find the node by type, not by its name, which a non-English Blender may translate:
    # https://terminalskills.io/skills/blender-scripting (section 9, Assign materials)
    bsdf = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = srgb(color)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:  # glTF keeps a color up to 1 plus a strength (KHR_materials_emissive_strength)
        bsdf.inputs["Emission Color"].default_value = srgb(emission)
        bsdf.inputs["Emission Strength"].default_value = strength
    material.diffuse_color = srgb(color)  # the viewport's solid color, for the GUI
    MATERIALS.append(material)
    return len(MATERIALS) - 1


def srgb(hex_code):
    """A hex color as Blender wants it: linear RGBA."""
    channels = [int(hex_code.lstrip("#")[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels) + (1.0,)


def make_materials():
    """One material per builder material key. Runs after reset_scene(), which would erase them."""
    PALETTE.update({
        "#": pbr_material("Charcoal Housing", "#26363d", metallic=0.2, roughness=0.45),
        "*": pbr_material("Brass and Bamboo", "#c78848", metallic=0.25, roughness=0.3),
        "e": pbr_material("Cyan Display", "#77f4e1", emission="#5be9e3", strength=4.0),
        "r": pbr_material("Robot Shell", "#0085bd", metallic=0.15, roughness=0.35),
        "o": pbr_material("Salmon Accent", "#ff826d", emission="#ff7859", strength=3.0),
        "s": pbr_material("Ceramic", "#ded8c6", roughness=0.85),
        "t": pbr_material("Teal Rubber", "#426c6a", roughness=0.9),
        "w": pbr_material("Walnut", "#714630", roughness=0.9),
    })


# --- Builders: each adds one piece's geometry to a bmesh ------------------------------
# bmesh builds meshes from data alone, with no edit mode or selection involved; Blender
# calls it the best way to create and edit faces:
# https://docs.blender.org/api/current/info_gotchas_meshes.html


def box(bm, material, size, center):
    transform = Matrix.Translation(center) @ Matrix.Diagonal((*size, 1.0))
    cube = bmesh.ops.create_cube(bm, size=1.0, matrix=transform)
    for face in {face for vertex in cube["verts"] for face in vertex.link_faces}:
        face.material_index = PALETTE[material]


def build_head(bm):
    box(bm, "#", (0.64, 0.74, 0.24), (0, -0.10, 0.15))
    box(bm, "r", (0.79, 0.72, 0.46), (0, 0.02, 0.46))
    box(bm, "#", (0.64, 0.11, 0.24), (0, 0.36, 0.54))
    for x in (-0.16, 0.16):
        box(bm, "e", (0.12, 0.03, 0.11), (x, 0.425, 0.55))
    box(bm, "#", (0.70, 0.52, 0.06), (0, 0, 0.72))
    box(bm, "e", (0.54, 0.09, 0.03), (0, 0.16, 0.76))


def build_straight(bm):
    box(bm, "#", (0.61, 1.0, 0.17), (0, 0, 0.12))
    for y in (-0.38, -0.13, 0.13, 0.38):
        box(bm, "t", (0.47, 0.16, 0.05), (0, y, 0.23))
    for x in (-0.28, 0.28):
        box(bm, "*", (0.06, 1.0, 0.06), (x, 0, 0.24))


def build_turn(bm):
    box(bm, "#", (0.62, 0.76, 0.17), (0, -0.12, 0.12))
    box(bm, "#", (0.19, 0.54, 0.17), (0.405, 0, 0.12))
    for y in (-0.38, -0.14, 0.10):
        box(bm, "t", (0.46, 0.15, 0.05), (0, y, 0.23))
    box(bm, "t", (0.14, 0.44, 0.05), (0.42, 0, 0.23))
    box(bm, "*", (0.06, 0.76, 0.06), (-0.28, -0.12, 0.24))
    box(bm, "*", (0.79, 0.06, 0.06), (0.105, 0.25, 0.24))


def build_tail(bm):
    box(bm, "#", (0.60, 0.77, 0.17), (0, 0.115, 0.12))
    for y in (-0.05, 0.16, 0.38):
        box(bm, "t", (0.43, 0.14, 0.05), (0, y, 0.23))
    box(bm, "o", (0.27, 0.05, 0.07), (0, -0.27, 0.15))


def build_floor(bm):
    box(bm, "#", (1.0, 1.0, 0.10), (0, 0, -0.20))
    box(bm, "s", (0.97, 0.97, 0.15), (0, 0, -0.075))


def build_wall(bm):
    box(bm, "w", (1.0, 1.0, 0.30), (0, 0, 0.15))
    box(bm, "t", (1.0, 1.0, 0.07), (0, 0, 0.335))


def build_counter(bm):
    build_floor(bm)
    box(bm, "w", (0.98, 0.70, 0.55), (0, 0, 0.275))
    box(bm, "*", (1.0, 0.80, 0.10), (0, 0, 0.60))
    box(bm, "s", (0.54, 0.30, 0.04), (0, 0, 0.67))
    box(bm, "o", (0.25, 0.12, 0.05), (0, 0, 0.715))


def build_table(bm):
    build_floor(bm)
    box(bm, "w", (0.24, 0.24, 0.40), (0, 0, 0.20))
    box(bm, "*", (0.86, 0.86, 0.11), (0, 0, 0.455))
    box(bm, "t", (0.38, 0.52, 0.02), (0, 0, 0.51))
    box(bm, "s", (0.27, 0.27, 0.04), (0, 0, 0.54))



PIECES = {  # the robot kit; the game finds each mesh by these names
    "head": build_head,
    "straight": build_straight,
    "turn": build_turn,
    "tail": build_tail,
}
TILES = {  # one entry per kind in core/board.gd's TILES; a new kind is one builder and one line
    "floor": build_floor,
    "wall": build_wall,
    "counter": build_counter,
    "table": build_table,
}


# --- Objects and layout ---------------------------------------------------------


def make_object(scene, name, build, location=(0, 0, 0)):
    """Run a builder on a fresh bmesh and turn the result into a mesh object called name.
    The game uses only the mesh; location just spreads the kit out for model viewers."""
    bm = bmesh.new()
    build(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    # Keep only the materials this object uses, renumbering faces to match.
    used = sorted({p.material_index for p in mesh.polygons})
    mesh.polygons.foreach_set("material_index", [used.index(p.material_index) for p in mesh.polygons])
    for index in used:
        mesh.materials.append(MATERIALS[index])
    # bpy.data creates the object directly; bpy.ops.mesh.primitive_*_add would depend on
    # the active object and selection, which an operator reads from the context:
    # https://docs.blender.org/api/current/info_gotchas_operators.html
    obj = bpy.data.objects.new(name, mesh)
    # Blender quietly changes a name that is too long or already taken, and the game
    # finds pieces by name, so fail loudly instead:
    # https://docs.blender.org/api/current/info_gotchas_internal_data_and_python_objects.html
    if obj.name != name:
        raise ValueError(f"Blender renamed {name!r} to {obj.name!r}; pick a shorter, unique name")
    obj.location = location
    scene.collection.objects.link(obj)


def lay_out_kit(scene):
    """One row per registry, so a GLB viewer shows a tidy catalog instead of every piece
    stacked on the origin. Each mesh is still modeled around its own cell's center."""
    spacing = 1.5
    for row, registry in enumerate([PIECES, TILES]):
        for column, (name, build) in enumerate(registry.items()):
            make_object(scene, name, build, location=(column * spacing, -row * spacing, 0))


# --- Export ---------------------------------------------------------------------


def export():
    """Write the .glb the game loads, then the .blend for the Blender app.
    glTF export has no data API, only an operator, so every option that could depend
    on what is selected or active is spelled out. These match the steps in the docstring.
    Enum values such as 'GLB' get single quotes, Blender's own style:
    https://docs.blender.org/api/current/info_best_practice.html"""
    bpy.ops.export_scene.gltf(
        filepath=str(GLB),
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    # No art/dragon_kit.blend1 backup: the script is the backup, and the next run rewrites this.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))


def main():
    reset_scene()
    make_materials()
    lay_out_kit(bpy.context.scene)
    export()
    print(f"Built {GLB.name} and {BLEND.name} with Blender {bpy.app.version_string}")


# Run only as a script, not when another file imports this one for its builders:
# https://docs.python.org/3/library/__main__.html
if __name__ == "__main__":
    main()
