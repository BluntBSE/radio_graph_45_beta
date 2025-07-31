extends Node3D

# 3D Volume Viewer with free camera movement
# This renders the 3D texture as a proper volume in 3D space

@onready var camera_3d = $Camera3D
@onready var volume_mesh = $VolumeMesh
@onready var ui_overlay = $UIOverlay

# Camera movement settings
@export var movement_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var scroll_speed: float = 2.0

# Camera rotation variables
var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0

# Volume texture reference
var volume_texture: ImageTexture3D
var volume_material: ShaderMaterial

func _ready():
    setup_camera()
    setup_volume_renderer()
    load_volume_texture()
    setup_ui()

func setup_camera():
    # Set initial camera position
    camera_3d.position = Vector3(0, 0, 3)
    rotation_x = camera_3d.rotation.x
    rotation_y = camera_3d.rotation.y

func setup_volume_renderer():
    # Create a cube mesh for volume rendering
    var box_mesh = BoxMesh.new()
    box_mesh.size = Vector3(2, 2, 2)  # 2x2x2 cube centered at origin
    volume_mesh.mesh = box_mesh
    
    # Create volume rendering material
    volume_material = ShaderMaterial.new()
    var shader = load("res://3d_texture_visualizer_1/volume_3d_shader.gdshader")
    volume_material.shader = shader
    volume_mesh.material_override = volume_material

func load_volume_texture():
    var texture_path = "res://3d_texture_visualizer_1/six_pointed_cross_texture3d.tres"
    
    if ResourceLoader.exists(texture_path):
        volume_texture = load(texture_path)
        if volume_texture and volume_material:
            volume_material.set_shader_parameter("volume_texture", volume_texture)
            print("Successfully loaded 3D texture for volume rendering")
        else:
            print("Failed to load 3D texture from: ", texture_path)
    else:
        print("3D texture file not found. Please run texture3d_generator.tscn first.")

func setup_ui():
    # Add some basic UI instructions
    if ui_overlay:
        ui_overlay.show_instructions()

func _input(event):
    # Handle ESC key to release mouse
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            mouse_captured = false
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    
    # Handle mouse capture for look controls
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if event.pressed:
                mouse_captured = true
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            else:
                mouse_captured = false
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_3d.position += camera_3d.transform.basis.z * -scroll_speed * 0.1
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_3d.position += camera_3d.transform.basis.z * scroll_speed * 0.1
    
    # Handle mouse movement for looking around
    if event is InputEventMouseMotion and mouse_captured:
        rotation_y -= event.relative.x * mouse_sensitivity
        rotation_x -= event.relative.y * mouse_sensitivity
        
        # Clamp vertical rotation to prevent camera flipping
        rotation_x = clamp(rotation_x, -PI/2, PI/2)
        
        # Apply rotation
        camera_3d.rotation.x = rotation_x
        camera_3d.rotation.y = rotation_y

func _process(delta):
    if not mouse_captured:
        return
        
    # Handle WASD movement
    var input_vector = Vector3()
    
    # Get input for WASD keys
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
        input_vector -= camera_3d.transform.basis.z
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
        input_vector += camera_3d.transform.basis.z
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
        input_vector -= camera_3d.transform.basis.x
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
        input_vector += camera_3d.transform.basis.x
    
    # Vertical movement with Q/E
    if Input.is_key_pressed(KEY_Q):
        input_vector -= camera_3d.transform.basis.y
    if Input.is_key_pressed(KEY_E):
        input_vector += camera_3d.transform.basis.y
    
    # Apply movement
    if input_vector.length() > 0:
        input_vector = input_vector.normalized()
        camera_3d.position += input_vector * movement_speed * delta
