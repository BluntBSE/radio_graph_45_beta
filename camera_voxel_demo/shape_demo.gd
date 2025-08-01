extends Node3D
# Enhanced camera voxelizer with multiple shape examples

@export var current_shape_index: int = 0
@export var voxel_resolution: int = 32

var voxelizer: CameraVoxelizer
var shapes: Array[MeshInstance3D] = []
var shape_names = ["Triangular Prism", "Hollow Cube", "Torus", "Pyramid"]

func _ready():
    create_all_shapes()
    setup_ui()

func create_all_shapes():
    # Create different shapes to demonstrate camera voxelization
    shapes.append(create_triangular_prism())
    shapes.append(create_hollow_cube())
    shapes.append(create_torus())
    shapes.append(create_pyramid())
    
    # Hide all but the first
    for i in range(shapes.size()):
        shapes[i].visible = (i == current_shape_index)

func create_triangular_prism() -> MeshInstance3D:
    var array_mesh = ArrayMesh.new()
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    
    var vertices = PackedVector3Array([
        # Front triangle
        Vector3(0, 1.5, -1), Vector3(-1.5, -1.5, -1), Vector3(1.5, -1.5, -1),
        # Back triangle
        Vector3(0, 1.5, 1), Vector3(-1.5, -1.5, 1), Vector3(1.5, -1.5, 1),
    ])
    
    var indices = PackedInt32Array([
        0, 1, 2,  # Front
        3, 5, 4,  # Back  
        0, 3, 4, 0, 4, 1,  # Left side
        0, 2, 5, 0, 5, 3,  # Right side
        1, 4, 5, 1, 5, 2   # Bottom
    ])
    
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    
    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "TriangularPrism"
    mesh_instance.mesh = array_mesh
    mesh_instance.material_override = create_shape_material(Color.GREEN)
    add_child(mesh_instance)
    return mesh_instance

func create_hollow_cube() -> MeshInstance3D:
    var array_mesh = ArrayMesh.new()
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    
    # Hollow cube - just the 6 faces
    var vertices = PackedVector3Array([
        # Front face
        Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
        # Back face  
        Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
    ])
    
    var indices = PackedInt32Array([
        # Front
        0, 1, 2, 0, 2, 3,
        # Back
        4, 6, 5, 4, 7, 6,
        # Left
        4, 0, 3, 4, 3, 7,
        # Right
        1, 5, 6, 1, 6, 2,
        # Top
        3, 2, 6, 3, 6, 7,
        # Bottom
        4, 1, 0, 4, 5, 1
    ])
    
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    
    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "HollowCube"
    mesh_instance.mesh = array_mesh
    mesh_instance.material_override = create_shape_material(Color.BLUE)
    add_child(mesh_instance)
    return mesh_instance

func create_torus() -> MeshInstance3D:
    # Create a simple torus using Godot's TorusMesh
    var torus_mesh = TorusMesh.new()
    torus_mesh.inner_radius = 0.5
    torus_mesh.outer_radius = 1.2
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "Torus"
    mesh_instance.mesh = torus_mesh
    mesh_instance.material_override = create_shape_material(Color.ORANGE)
    add_child(mesh_instance)
    return mesh_instance

func create_pyramid() -> MeshInstance3D:
    var array_mesh = ArrayMesh.new()
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    
    var vertices = PackedVector3Array([
        # Base square
        Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1),
        # Apex
        Vector3(0, 1.5, 0)
    ])
    
    var indices = PackedInt32Array([
        # Base
        0, 2, 1, 0, 3, 2,
        # Sides
        0, 1, 4,  # Front
        1, 2, 4,  # Right
        2, 3, 4,  # Back
        3, 0, 4   # Left
    ])
    
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    
    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "Pyramid"
    mesh_instance.mesh = array_mesh
    mesh_instance.material_override = create_shape_material(Color.RED)
    add_child(mesh_instance)
    return mesh_instance

func create_shape_material(color: Color) -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.emission_enabled = true
    material.emission = color * 0.1
    return material

func setup_ui():
    # Create UI for shape switching
    var ui = Control.new()
    ui.name = "UI"
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(ui)
    
    var vbox = VBoxContainer.new()
    vbox.position = Vector2(20, 20)
    ui.add_child(vbox)
    
    var title = Label.new()
    title.text = "Camera-Based Voxelizer Demo"
    title.add_theme_font_size_override("font_size", 20)
    vbox.add_child(title)
    
    var info = Label.new()
    info.text = "Camera pans through mesh taking snapshots.\nScanline filling ensures hollow shapes are solid.\nPress buttons to switch shapes and voxelize."
    vbox.add_child(info)
    
    vbox.add_child(HSeparator.new())
    
    # Shape selection buttons
    for i in range(shape_names.size()):
        var button = Button.new()
        button.text = shape_names[i]
        button.pressed.connect(func(): switch_to_shape(i))
        vbox.add_child(button)
    
    var separator = HSeparator.new()
    vbox.add_child(separator)
    
    var voxelize_button = Button.new()
    voxelize_button.text = "Voxelize Current Shape"
    voxelize_button.pressed.connect(start_voxelization)
    vbox.add_child(voxelize_button)
    
    var res_label = Label.new()
    res_label.text = "Resolution: " + str(voxel_resolution)
    vbox.add_child(res_label)

func switch_to_shape(index: int):
    if index >= 0 and index < shapes.size():
        # Hide all shapes
        for shape in shapes:
            shape.visible = false
        
        # Show selected shape
        current_shape_index = index
        shapes[current_shape_index].visible = true
        
        print("Switched to shape: ", shape_names[index])

func start_voxelization():
    if voxelizer:
        voxelizer.queue_free()
    
    # Create new voxelizer
    voxelizer = CameraVoxelizer.new()
    voxelizer.name = "Voxelizer"
    voxelizer.voxel_resolution = voxel_resolution
    voxelizer.target_mesh_instance = shapes[current_shape_index]
    voxelizer.show_debug_cubes = true
    add_child(voxelizer)
    
    print("Starting voxelization of: ", shape_names[current_shape_index])

func _input(event: InputEvent):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_1, KEY_2, KEY_3, KEY_4:
                var index = event.keycode - KEY_1
                if index < shapes.size():
                    switch_to_shape(index)
            KEY_SPACE:
                start_voxelization()
            KEY_C:
                clear_voxelization()

func clear_voxelization():
    if voxelizer:
        voxelizer.queue_free()
        voxelizer = null
        print("Cleared voxelization")
