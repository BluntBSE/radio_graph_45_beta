extends Node

# Interactive controller for the winding number demo
# Allows switching between different test objects and controlling visualization

@onready var voxelizer:WindingNumber = get_parent()
@onready var test_sphere = %TestSphere
@onready var test_box = %TestBox
@onready var info_label = %InfoLabel

func _ready():
    # Set initial target
    voxelizer.target_mesh_instance = test_sphere
    update_info_display()

func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_SPACE:
                print("\n=== MANUAL RE-VOXELIZATION ===")
                voxelizer.start_voxelization()
                update_info_display()
            
            KEY_T:
                voxelizer.show_debug_cubes = !voxelizer.show_debug_cubes
                print("Debug cubes: ", "ON" if voxelizer.show_debug_cubes else "OFF")
                if voxelizer.show_debug_cubes and voxelizer.generated_texture3d:
                    voxelizer.display_voxels_as_cubes()
                else:
                    clear_debug_cubes()
                update_info_display()
            
            KEY_1:
                print("\n=== SWITCHING TO SPHERE ===")
                voxelizer.target_mesh_instance = test_sphere
                voxelizer.start_voxelization()
                update_info_display()
            
            KEY_2:
                print("\n=== SWITCHING TO BOX ===")
                voxelizer.target_mesh_instance = test_box
                voxelizer.start_voxelization()
                update_info_display()
            
            KEY_EQUAL, KEY_PLUS:
                if voxelizer.voxel_resolution < 64:
                    voxelizer.voxel_resolution += 4
                    print("Resolution increased to: ", voxelizer.voxel_resolution)
                    update_info_display()
            
            KEY_MINUS:
                if voxelizer.voxel_resolution > 8:
                    voxelizer.voxel_resolution -= 4
                    print("Resolution decreased to: ", voxelizer.voxel_resolution)
                    update_info_display()

func clear_debug_cubes():
    for child in voxelizer.get_children():
        if child.name.begins_with("VoxelCube"):
            child.queue_free()

func update_info_display():
    if not info_label:
        return
    
    var current_mesh = "None"
    if voxelizer.target_mesh_instance == test_sphere:
        current_mesh = "Sphere"
    elif voxelizer.target_mesh_instance == test_box:
        current_mesh = "Box"
    
    var voxel_count = 0
    if voxelizer.generated_texture3d and voxelizer.texture_slices:
        # Count non-zero voxels
        for z in range(voxelizer.voxel_resolution):
            var layer_data = voxelizer.texture_slices[z].get_data()
            for byte in layer_data:
                if byte > 0:
                    voxel_count += 1
    
    var info_text = """[b]Winding Number Voxelizer Demo[/b]

[color=cyan]Current Mesh:[/color] %s
[color=cyan]Resolution:[/color] %d³ (%d total voxels)
[color=cyan]Interior Voxels:[/color] %d
[color=cyan]Debug Cubes:[/color] %s

[color=yellow]Controls:[/color]
[color=white]Space[/color] - Re-voxelize current mesh
[color=white]T[/color] - Toggle debug cube display
[color=white]1[/color] - Switch to sphere
[color=white]2[/color] - Switch to box
[color=white]+/-[/color] - Adjust resolution

[color=lime]Algorithm Benefits:[/color]
• Mathematically precise
• No physics engine dependency
• Works with any closed mesh
• Handles complex topology
• 100%% reliable interior detection""" % [
        current_mesh,
        voxelizer.voxel_resolution,
        voxelizer.voxel_resolution * voxelizer.voxel_resolution * voxelizer.voxel_resolution,
        voxel_count,
        "ON" if voxelizer.show_debug_cubes else "OFF"
    ]
    
    info_label.text = info_text
