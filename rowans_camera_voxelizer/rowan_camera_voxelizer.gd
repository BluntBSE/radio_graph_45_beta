extends Node3D
class_name RowansCameraVoxelizer

@export var voxel_resolution:int = 128
@export var mesh_to_voxelize:MeshInstance3D
@export var show_debug_cubes: bool = true
@export var volume_reference:MeshInstance3D
var step_size
var viewport_renderer: SubViewport
var slice_camera: Camera3D
var generated_texture3d: ImageTexture3D
var texture_slices: Array



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    setup_viewport_renderer()
    step_size = (volume_reference.mesh.size.x / float(voxel_resolution)) #Cube, so this is equal to all directions
    print("Step size calculated to be ", step_size)
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func setup_viewport_renderer():
    # Create SubViewport for off-screen slice rendering
    viewport_renderer = SubViewport.new()
    viewport_renderer.name = "SliceRenderer"
    viewport_renderer.size = Vector2i(voxel_resolution, voxel_resolution)
    viewport_renderer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    
    # Create orthogonal camera for slice capture
    slice_camera = Camera3D.new()
    slice_camera.name = "SliceCamera"
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    viewport_renderer.add_child(slice_camera)
    add_child(viewport_renderer)
    
    print("Viewport renderer setup complete")



func start_voxelization():
    var arrays = mesh_to_voxelize.mesh.surface_get_arrays(0)
    var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
    print("Mesh vertices: ", vertices.size())
    
    print("Resolution: ", voxel_resolution, "³")
    
