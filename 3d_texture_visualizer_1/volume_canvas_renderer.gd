extends ColorRect

# UI-based volume renderer using canvas shader
# This renders the volume by interrogating the 3D scene directly

@export var volume_texture_path: String = "res://3d_texture_visualizer_1/six_pointed_cross_texture3d.tres"
@export var camera_node_path: NodePath = "../Camera3D"

@onready var camera_3d: Camera3D
var volume_material: ShaderMaterial
var volume_texture: ImageTexture3D

func _ready():
    setup_canvas_renderer()
    load_volume_texture()

func setup_canvas_renderer():
    # Get camera reference
    if has_node(camera_node_path):
        camera_3d = get_node(camera_node_path)
    else:
        print("Camera not found at path: ", camera_node_path)
        return
    
    # Create canvas shader material
    volume_material = ShaderMaterial.new()
    var shader = load("res://3d_texture_visualizer_1/volume_canvas_shader.gdshader")
    volume_material.shader = shader
    
    # Apply to this TextureRect
    material = volume_material
    
    # Set up the texture rect to fill the screen
    anchor_left = 0.0
    anchor_top = 0.0
    anchor_right = 1.0
    anchor_bottom = 1.0
    
    # Make sure it's behind other UI elements
    z_index = -1

func load_volume_texture():
    if ResourceLoader.exists(volume_texture_path):
        volume_texture = load(volume_texture_path)
        if volume_texture and volume_material:
            volume_material.set_shader_parameter("volume_texture", volume_texture)
            print("Canvas renderer: Successfully loaded 3D texture: ", volume_texture_path)
        else:
            print("Canvas renderer: Failed to load 3D texture from: ", volume_texture_path)
    else:
        print("Canvas renderer: 3D texture file not found: ", volume_texture_path)

func _process(_delta):
    if camera_3d and volume_material:
        update_camera_uniforms()

func update_camera_uniforms():
    # Get camera transform and projection matrices
    var camera_transform = camera_3d.global_transform
    var camera_projection = camera_3d.get_camera_projection()
    
    # Get screen size
    var viewport_size = get_viewport().get_visible_rect().size
    
    # Pass to shader
    volume_material.set_shader_parameter("camera_transform", camera_transform)
    volume_material.set_shader_parameter("camera_projection", camera_projection)
    volume_material.set_shader_parameter("screen_size", viewport_size)

# Debug functions
func set_volume_texture_path(path: String):
    volume_texture_path = path
    load_volume_texture()

func get_current_volume_path() -> String:
    return volume_texture_path
