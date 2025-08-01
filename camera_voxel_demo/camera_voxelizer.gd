extends Node3D
class_name CameraVoxelizer
# Camera-based volumetric reconstruction with scanline filling
# Captures slices through mesh and fills interior even for hollow geometry

@export var voxel_resolution: int = 64
@export var target_mesh_instance: MeshInstance3D
@export var show_debug_cubes: bool = true

var viewport_renderer: SubViewport
var slice_camera: Camera3D
var generated_texture3d: ImageTexture3D
var texture_slices: Array
var mesh_bounds: AABB
var camera: Camera3D

func _ready():
    setup_camera()
    setup_viewport_renderer()
    call_deferred("start_voxelization")

func setup_camera():
    # Create main scene camera
    camera = Camera3D.new()
    camera.name = "SceneCamera"
    
    # Load camera controller if available
    var controller_script = load("res://attempt_2/winding_number_demo/camera_controller.gd")
    if controller_script:
        camera.set_script(controller_script)
    
    camera.position = Vector3(0, 0, 5)
    add_child(camera)
    camera.current = true
    
    print("Camera controls: Right-click to capture mouse, WASD to move, QE for up/down")

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
    # Find or create target mesh
    if not target_mesh_instance:
        target_mesh_instance = find_mesh_by_name("TriangularPrism")
        
    if not target_mesh_instance:
        print("Creating triangular prism for demo...")
        create_triangular_prism()
    
    print("=== CAMERA-BASED VOXELIZATION ===")
    print("Target mesh: ", target_mesh_instance.name)
    print("Resolution: ", voxel_resolution, "³")
    
    var start_time = Time.get_ticks_msec()
    generated_texture3d = await voxelize_mesh_camera_based(target_mesh_instance)
    var end_time = Time.get_ticks_msec()
    
    print("Camera voxelization completed in ", end_time - start_time, " ms")
    
    if generated_texture3d:
        save_result()
        
    if show_debug_cubes:
        display_voxels_as_cubes()

func create_triangular_prism() -> MeshInstance3D:
    # Create a triangular prism mesh for demonstration (clearly oriented with point up)
    var array_mesh = ArrayMesh.new()
    var arrays = []
    arrays.resize(Mesh.ARRAY_MAX)
    
    # Triangular prism vertices - POINT UP to test Y orientation
    var vertices = PackedVector3Array([
        # Front triangle (Z = -1) - point up
        Vector3(0, 1.5, -1), Vector3(-1, -1, -1), Vector3(1, -1, -1),
        # Back triangle (Z = 1) - point up  
        Vector3(0, 1.5, 1), Vector3(-1, -1, 1), Vector3(1, -1, 1),
    ])
    
    # Indices for triangular faces
    var indices = PackedInt32Array([
        # Front triangle
        0, 1, 2,
        # Back triangle
        3, 5, 4,
        # Side faces
        0, 3, 4, 0, 4, 1,  # Left side
        0, 2, 5, 0, 5, 3,  # Right side
        1, 4, 5, 1, 5, 2   # Bottom side
    ])
    
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    
    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    
    # Create mesh instance
    target_mesh_instance = MeshInstance3D.new()
    target_mesh_instance.name = "TriangularPrism"
    target_mesh_instance.mesh = array_mesh
    
    # Create material with clear orientation
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.GREEN
    material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
    material.emission_enabled = true
    material.emission = Color.GREEN * 0.2
    target_mesh_instance.material_override = material
    
    add_child(target_mesh_instance)
    
    print("Created triangular prism with POINT UP (Y+ direction)")
    return target_mesh_instance

func voxelize_mesh_camera_based(mesh_instance: MeshInstance3D) -> ImageTexture3D:
    if not mesh_instance or not mesh_instance.mesh:
        print("ERROR: Invalid mesh instance!")
        return null
    
    # Calculate mesh bounds
    var local_aabb = mesh_instance.get_aabb()
    mesh_bounds = mesh_instance.global_transform * local_aabb
    
    # Add padding
    var padding = mesh_bounds.size * 0.1
    mesh_bounds = mesh_bounds.grow(padding.length())
    
    print("Voxel bounds: ", mesh_bounds)
    
    # Clone mesh to viewport for rendering
    var viewport_mesh = MeshInstance3D.new()
    viewport_mesh.mesh = mesh_instance.mesh
    viewport_mesh.material_override = create_solid_material()
    viewport_mesh.global_transform = mesh_instance.global_transform
    viewport_renderer.add_child(viewport_mesh)
    
    # Setup camera for slice capture
    setup_slice_camera(mesh_bounds)
    
    # Generate slices by panning camera through Z positions
    var slice_images = []
    
    print("Capturing ", voxel_resolution, " slices...")
    
    for z_slice in range(voxel_resolution):
        # Calculate world Z position for this slice
        var z_progress = float(z_slice) / voxel_resolution
        var world_z = mesh_bounds.position.z + z_progress * mesh_bounds.size.z
        
        # Position camera looking at this Z slice
        slice_camera.position = Vector3(
            mesh_bounds.get_center().x,
            mesh_bounds.get_center().y,  
            world_z + mesh_bounds.size.z * 0.6  # Camera outside mesh
        )
        slice_camera.look_at(Vector3(
            mesh_bounds.get_center().x,
            mesh_bounds.get_center().y,
            world_z
        ), Vector3.UP)
        
        # Wait for rendering
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
        
        # Capture and process this slice
        var slice_image = capture_and_fill_slice()
        slice_images.append(slice_image)
        
        if z_slice % 16 == 0:
            print("Captured slice ", z_slice, " / ", voxel_resolution)
    
    # Store slices for debugging
    texture_slices = slice_images.duplicate()
    
    # Clean up
    viewport_mesh.queue_free()
    
    # Create 3D texture
    var texture3d = ImageTexture3D.new()
    texture3d.create(Image.FORMAT_R8, voxel_resolution, voxel_resolution, voxel_resolution, false, slice_images)
    
    print("Camera-based voxelization complete!")
    return texture3d

func setup_slice_camera(bounds: AABB):
    # Setup orthogonal camera to capture cross-sections
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    # Size to fit mesh bounds with padding
    var max_extent = max(bounds.size.x, bounds.size.y)
    slice_camera.size = max_extent * 1.2
    slice_camera.near = 0.1
    slice_camera.far = bounds.size.z * 2.0

func create_solid_material() -> StandardMaterial3D:
    # Create material that renders solid white
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.unshaded = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func capture_and_fill_slice() -> Image:
    # Capture viewport as image
    var viewport_texture = viewport_renderer.get_texture()
    var raw_image = viewport_texture.get_image()
    
    # Process with scanline filling to fill hollow interiors
    return fill_slice_interior(raw_image)

func fill_slice_interior(raw_image: Image) -> Image:
    # Use scanline filling to fill the interior of shapes
    var filled_data = PackedByteArray()
    filled_data.resize(voxel_resolution * voxel_resolution)
    filled_data.fill(0)
    
    # Process each scanline (row) separately
    for y in range(voxel_resolution):
        # Find intersections with mesh surface on this scanline
        var intersections = []
        
        for x in range(voxel_resolution):
            # Flip Y coordinate since Godot images have Y=0 at top, but we want Y=0 at bottom
            var flipped_y = voxel_resolution - 1 - y
            var pixel = raw_image.get_pixel(x, flipped_y)
            if pixel.r > 0.5:  # Surface detected
                intersections.append(x)
        
        # Fill between pairs of intersections
        if intersections.size() >= 2:
            # Sort intersections
            intersections.sort()
            
            # Fill between pairs
            for i in range(0, intersections.size() - 1, 2):
                var start_x = intersections[i]
                var end_x = intersections[i + 1] if i + 1 < intersections.size() else intersections[i]
                
                # Fill pixels between intersections
                for x in range(start_x, end_x + 1):
                    if x >= 0 and x < voxel_resolution:
                        filled_data[x + y * voxel_resolution] = 255
        
        # Also mark surface pixels themselves
        for x in intersections:
            if x >= 0 and x < voxel_resolution:
                filled_data[x + y * voxel_resolution] = 255
    
    return Image.create_from_data(voxel_resolution, voxel_resolution, false, Image.FORMAT_R8, filled_data)

func save_result():
    if generated_texture3d:
        var save_path = "res://camera_voxel_" + target_mesh_instance.name.to_lower() + "_" + str(voxel_resolution) + ".tres"
        var result = ResourceSaver.save(generated_texture3d, save_path)
        if result == OK:
            print("Texture3D saved to: ", save_path)
        else:
            print("Failed to save Texture3D")

func display_voxels_as_cubes():
    if not generated_texture3d or texture_slices.is_empty():
        print("No texture data to display!")
        return
    
    print("Creating voxel cube visualization...")
    
    # Clear existing debug cubes
    for child in get_children():
        if child.name.begins_with("VoxelCube"):
            child.queue_free()
    
    var cube_mesh = BoxMesh.new()
    var voxel_size = mesh_bounds.size / voxel_resolution * 0.8
    cube_mesh.size = voxel_size
    
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.MAGENTA
    material.emission_enabled = true
    material.emission = Color.MAGENTA * 0.2
    
    var displayed_count = 0
    
    for z in range(voxel_resolution):
        var slice_image = texture_slices[z]
        var slice_data = slice_image.get_data()
        
        for y in range(voxel_resolution):
            for x in range(voxel_resolution):
                var pixel_index = x + y * voxel_resolution
                
                if slice_data[pixel_index] > 0:
                    var cube = MeshInstance3D.new()
                    cube.name = "VoxelCube_" + str(x) + "_" + str(y) + "_" + str(z)
                    cube.mesh = cube_mesh
                    cube.material_override = material
                    
                    # Position in world space
                    var world_pos = Vector3(
                        mesh_bounds.position.x + (float(x) + 0.5) / voxel_resolution * mesh_bounds.size.x,
                        mesh_bounds.position.y + (float(y) + 0.5) / voxel_resolution * mesh_bounds.size.y,
                        mesh_bounds.position.z + (float(z) + 0.5) / voxel_resolution * mesh_bounds.size.z
                    )
                    cube.position = world_pos
                    
                    add_child(cube)
                    displayed_count += 1
    
    print("Displayed ", displayed_count, " filled voxels")

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

# Public API
func get_texture3d() -> ImageTexture3D:
    return generated_texture3d

func get_texture_slices() -> Array:
    return texture_slices
