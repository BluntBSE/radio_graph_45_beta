extends Node3D
class_name CameraBasedVoxelizer
# Camera-based volumetric reconstruction
# Uses SubViewport rendering + depth analysis for 3D texture generation

@export var voxel_resolution: int = 64
@export var target_mesh_instance: MeshInstance3D

var viewport_renderer: SubViewport
var slice_camera: Camera3D
var generated_texture3d: ImageTexture3D

func _ready():
    setup_viewport_renderer()

func setup_viewport_renderer():
    # Create SubViewport for off-screen rendering
    viewport_renderer = SubViewport.new()
    viewport_renderer.name = "VolumeRenderer"
    viewport_renderer.size = Vector2i(voxel_resolution, voxel_resolution)
    viewport_renderer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_renderer.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    
    # Create camera for slice capturing
    slice_camera = Camera3D.new()
    slice_camera.name = "SliceCamera"
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    # Add to viewport
    viewport_renderer.add_child(slice_camera)
    add_child(viewport_renderer)

func voxelize_mesh_camera_based(mesh_instance: MeshInstance3D) -> ImageTexture3D:
    if not mesh_instance or not mesh_instance.mesh:
        print("ERROR: Invalid mesh instance!")
        return null
    
    print("=== CAMERA-BASED VOXELIZATION ===")
    print("Target mesh: ", mesh_instance.name)
    print("Resolution: ", voxel_resolution, "³")
    
    # Get mesh bounds
    var mesh_aabb = mesh_instance.get_aabb()
    var world_transform = mesh_instance.global_transform
    mesh_aabb = world_transform * mesh_aabb
    
    print("Mesh bounds: ", mesh_aabb)
    
    # Clone mesh to viewport for rendering
    var viewport_mesh = MeshInstance3D.new()
    viewport_mesh.mesh = mesh_instance.mesh
    viewport_mesh.material_override = create_depth_material()
    viewport_renderer.add_child(viewport_mesh)
    
    # Setup orthogonal camera for slice capture
    setup_slice_camera(mesh_aabb)
    
    # Generate slices by moving camera through Z positions
    var slice_images = []
    
    for z_slice in range(voxel_resolution):
        # Position camera for this slice
        var z_progress = float(z_slice) / (voxel_resolution - 1)
        var world_z = mesh_aabb.position.z + z_progress * mesh_aabb.size.z
        
        slice_camera.position = Vector3(
            mesh_aabb.get_center().x,
            mesh_aabb.get_center().y,
            world_z + mesh_aabb.size.z * 0.6  # Camera outside looking at slice
        )
        slice_camera.look_at(Vector3(mesh_aabb.get_center().x, mesh_aabb.get_center().y, world_z))
        
        # Force render and capture
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
        
        var slice_image = capture_slice()
        slice_images.append(slice_image)
        
        if z_slice % 16 == 0:
            print("Generated slice ", z_slice, " / ", voxel_resolution)
    
    # Clean up viewport mesh
    viewport_mesh.queue_free()
    
    # Create 3D texture from slices
    var texture3d = ImageTexture3D.new()
    texture3d.create(Image.FORMAT_R8, voxel_resolution, voxel_resolution, voxel_resolution, false, slice_images)
    
    print("Camera-based voxelization complete!")
    return texture3d

func setup_slice_camera(bounds: AABB):
    # Setup orthogonal camera to capture cross-sections
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    # Size orthogonal frustum to fit mesh bounds
    var max_extent = max(bounds.size.x, bounds.size.y)
    slice_camera.size = max_extent * 1.1  # Add some padding
    
    slice_camera.near = 0.1
    slice_camera.far = bounds.size.z * 2.0

func create_depth_material() -> ShaderMaterial:
    # Create material that renders depth information
    var material = ShaderMaterial.new()
    var shader = Shader.new()
    
    # Simple depth-writing shader
    shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

void fragment() {
    // Output white for surfaces, black for empty space
    ALBEDO = vec3(1.0);
    ALPHA = 1.0;
}
"""
    
    material.shader = shader
    return material

func capture_slice() -> Image:
    # Capture current viewport content as slice
    var viewport_texture = viewport_renderer.get_texture()
    var slice_image = viewport_texture.get_image()
    
    # Process image to create binary inside/outside data
    return process_slice_for_volume(slice_image)

func process_slice_for_volume(raw_image: Image) -> Image:
    # Convert rendered slice to volumetric data
    # This is where the "fill inside hollow shapes" logic goes
    
    var volume_data = PackedByteArray()
    volume_data.resize(voxel_resolution * voxel_resolution)
    
    for y in range(voxel_resolution):
        for x in range(voxel_resolution):
            # Sample the rendered image
            var pixel = raw_image.get_pixel(x, y)
            
            # Simple approach: if pixel is not black, mark as inside
            # More sophisticated: use depth buffer analysis
            var is_inside = pixel.r > 0.1  # Threshold for surface detection
            
            # TODO: Implement scanline filling for hollow shapes
            # For now, just copy surface detection
            volume_data[x + y * voxel_resolution] = 255 if is_inside else 0
    
    return Image.create_from_data(voxel_resolution, voxel_resolution, false, Image.FORMAT_R8, volume_data)

func start_camera_voxelization():
    # Find target mesh (similar to existing logic)
    target_mesh_instance = find_mesh_by_name("b_skull")
    if target_mesh_instance:
        print("Found target mesh: ", target_mesh_instance.name)
        generated_texture3d = await voxelize_mesh_camera_based(target_mesh_instance)
        
        if generated_texture3d:
            save_result()
    else:
        print("ERROR: Could not find target mesh!")

func save_result():
    if generated_texture3d:
        var save_path = "res://camera_voxelized_" + target_mesh_instance.name.to_lower() + "_" + str(voxel_resolution) + ".tres"
        var result = ResourceSaver.save(generated_texture3d, save_path)
        if result == OK:
            print("Camera-based Texture3D saved to: ", save_path)
        else:
            print("Failed to save Texture3D")

func find_mesh_by_name(mesh_name: String) -> MeshInstance3D:
    return _search_for_mesh(get_tree().root, mesh_name)

func _search_for_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
    if node is MeshInstance3D and node.name == mesh_name:
        return node as MeshInstance3D
    
    for child in node.get_children():
        var result = _search_for_mesh(child, mesh_name)
        if result:
            return result
    
    return null
