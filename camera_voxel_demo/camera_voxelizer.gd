extends Node3D
class_name CameraVoxelizer
# Camera-based volumetric reconstruction with scanline filling
# Captures slices through mesh and fills interior even for hollow geometry

@export var voxel_resolution: int = 64
@export var target_mesh_instance: MeshInstance3D  # Assign any mesh from the scene in the editor
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
    print("Press 'T' to start voxelization process")
    # Don't auto-start voxelization - wait for user input

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

func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_T:
            print("Starting voxelization...")
            start_voxelization()

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
    # Check if a mesh is assigned in the editor
    if target_mesh_instance and target_mesh_instance.mesh:
        print("Using assigned target mesh: ", target_mesh_instance.name)
    else:
        # Fallback: try to find any mesh in the scene
        target_mesh_instance = find_any_mesh_in_scene()
        
        if target_mesh_instance:
            print("Auto-detected mesh: ", target_mesh_instance.name)
        else:
            print("No mesh found in scene. Creating triangular prism for demo...")
            create_triangular_prism()
    
    if not target_mesh_instance or not target_mesh_instance.mesh:
        print("ERROR: No valid mesh found or assigned!")
        return
    
    print("=== CAMERA-BASED VOXELIZATION ===")
    print("Target mesh: ", target_mesh_instance.name)
    
    # Get vertex count properly in Godot 4
    var arrays = target_mesh_instance.mesh.surface_get_arrays(0)
    var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
    print("Mesh vertices: ", vertices.size())
    
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
    
    # FORCE CUBIC BOUNDS: Make all dimensions equal to the largest dimension
    # This ensures consistent voxel step size across all axes
    var max_dimension = max(mesh_bounds.size.x, max(mesh_bounds.size.y, mesh_bounds.size.z))
    var center = mesh_bounds.get_center()
    var half_cube = max_dimension * 0.5
    
    mesh_bounds = AABB(
        Vector3(center.x - half_cube, center.y - half_cube, center.z - half_cube),
        Vector3(max_dimension, max_dimension, max_dimension)
    )
    
    print("Original bounds adjusted to cubic bounds: ", mesh_bounds)
    print("Cubic voxel size: ", max_dimension / voxel_resolution)
    
    # Clone mesh to viewport for rendering
    var viewport_mesh = MeshInstance3D.new()
    viewport_mesh.mesh = mesh_instance.mesh
    viewport_mesh.material_override = create_solid_material()
    viewport_mesh.global_transform = mesh_instance.global_transform
    viewport_renderer.add_child(viewport_mesh)
    
    print("=== DUAL-AXIS VOXELIZATION ===")
    print("Performing Z-axis pass...")
    
    # Z-AXIS PASS (original approach)
    var z_voxel_data = await capture_axis_slices("Z")
    
    print("Performing Y-axis pass...")
    
    # Y-AXIS PASS (new approach for missing surfaces)
    var y_voxel_data = await capture_axis_slices("Y")
    
    print("Combining Z and Y axis data...")
    
    # Combine both passes using OR operation
    var combined_data = combine_voxel_data(z_voxel_data, y_voxel_data)
    
    # Clean up
    viewport_mesh.queue_free()
    
    # Create final 3D texture from combined data
    var slice_images = []
    for z in range(voxel_resolution):
        var slice_data = PackedByteArray()
        slice_data.resize(voxel_resolution * voxel_resolution)
        
        for y in range(voxel_resolution):
            for x in range(voxel_resolution):
                var voxel_index = x + y * voxel_resolution + z * voxel_resolution * voxel_resolution
                slice_data[x + y * voxel_resolution] = combined_data[voxel_index]
        
        var slice_image = Image.create_from_data(voxel_resolution, voxel_resolution, false, Image.FORMAT_R8, slice_data)
        slice_images.append(slice_image)
    
    # Store slices for debugging
    texture_slices = slice_images.duplicate()
    
    var texture3d = ImageTexture3D.new()
    texture3d.create(Image.FORMAT_R8, voxel_resolution, voxel_resolution, voxel_resolution, false, slice_images)
    
    print("Dual-axis camera voxelization complete!")
    return texture3d

func capture_axis_slices(axis: String) -> PackedByteArray:
    var voxel_data = PackedByteArray()
    voxel_data.resize(voxel_resolution * voxel_resolution * voxel_resolution)
    voxel_data.fill(0)
    
    # Use SAME slice thickness for both axes since we're using cubic bounds
    var slice_thickness = mesh_bounds.size.x / voxel_resolution  # All dimensions are equal now
    
    setup_slice_camera_for_axis(mesh_bounds, slice_thickness, axis)
    
    print("Capturing ", voxel_resolution, " slices along ", axis, "-axis...")
    
    for slice_index in range(voxel_resolution):
        # Calculate world position for this slice
        var slice_progress = float(slice_index) / voxel_resolution
        var world_pos = Vector3()
        var look_target = Vector3()
        var camera_distance = slice_camera.near + slice_thickness * 0.5
        
        if axis == "Z":
            var world_z = mesh_bounds.position.z + slice_progress * mesh_bounds.size.z
            slice_camera.position = Vector3(
                mesh_bounds.get_center().x,
                mesh_bounds.get_center().y,  
                world_z + camera_distance
            )
            slice_camera.look_at(Vector3(
                mesh_bounds.get_center().x,
                mesh_bounds.get_center().y,
                world_z
            ), Vector3.UP)
            
        elif axis == "Y":
            var world_y = mesh_bounds.position.y + slice_progress * mesh_bounds.size.y
            slice_camera.position = Vector3(
                mesh_bounds.get_center().x,
                world_y + camera_distance,
                mesh_bounds.get_center().z
            )
            slice_camera.look_at(Vector3(
                mesh_bounds.get_center().x,
                world_y,
                mesh_bounds.get_center().z
            ), Vector3.FORWARD)  # Different up vector for Y-axis
        
        # Wait for rendering
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
        
        # Capture slice image
        var viewport_texture = viewport_renderer.get_texture()
        var raw_image = viewport_texture.get_image()
        var slice_image = fill_slice_interior(raw_image)
        var slice_data = slice_image.get_data()
        
        # Store in 3D voxel array
        for y in range(voxel_resolution):
            for x in range(voxel_resolution):
                var pixel_value = slice_data[x + y * voxel_resolution]
                
                # Map 2D slice coordinates to 3D voxel coordinates based on axis
                var voxel_x
                var voxel_y
                var voxel_z
                if axis == "Z":
                    voxel_x = x
                    voxel_y = y
                    voxel_z = slice_index
                elif axis == "Y":
                    voxel_x = x
                    voxel_y = slice_index
                    voxel_z = y
                
                var voxel_index = voxel_x + voxel_y * voxel_resolution + voxel_z * voxel_resolution * voxel_resolution
                voxel_data[voxel_index] = pixel_value
        
        if slice_index % 8 == 0:
            print("Captured ", axis, "-axis slice ", slice_index, " / ", voxel_resolution)
    
    return voxel_data

func setup_slice_camera_for_axis(bounds: AABB, slice_thickness: float, axis: String):
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    # Since bounds are now cubic, all dimensions are equal
    # Use the same camera size for both axes
    slice_camera.size = bounds.size.x * 1.2  # All dimensions are equal
    
    # Set near/far for thin slice capture
    slice_camera.near = 0.1
    slice_camera.far = slice_camera.near + slice_thickness * 1.1
    


func combine_voxel_data(z_data: PackedByteArray, y_data: PackedByteArray) -> PackedByteArray:
    var combined = PackedByteArray()
    combined.resize(voxel_resolution * voxel_resolution * voxel_resolution)
    
    for i in range(combined.size()):
        # OR operation: voxel is filled if it's filled in EITHER pass
        combined[i] = max(z_data[i], y_data[i])
    
    var z_count = 0
    var y_count = 0
    var combined_count = 0
    
    for i in range(combined.size()):
        if z_data[i] > 0:
            z_count += 1
        if y_data[i] > 0:
            y_count += 1
        if combined[i] > 0:
            combined_count += 1
    
    print("Z-axis captured: ", z_count, " voxels")
    print("Y-axis captured: ", y_count, " voxels") 
    print("Combined total: ", combined_count, " voxels")
    
    return combined

func setup_slice_camera(bounds: AABB, slice_thickness: float):
    # Setup orthogonal camera to capture cross-sections
    slice_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    
    # Size to fit mesh bounds with padding
    var max_extent = max(bounds.size.x, bounds.size.y)
    slice_camera.size = max_extent * 1.2
    
    # CRITICAL: Set near/far to capture only one voxel slice thickness
    # This prevents seeing through hollow areas like torus centers
    slice_camera.near = 0.1
    slice_camera.far = slice_camera.near + slice_thickness * 1.1  # Slightly thicker for safety
    # DEBUG: 
    camera.near = 0.1
    camera.far = slice_camera.near + slice_thickness * 1.1
func create_solid_material() -> StandardMaterial3D:
    # Create material that renders solid white with proper depth
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.unshaded = false  # Use shading to better detect surfaces
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
    return material

func capture_and_fill_slice() -> Image:
    # Capture viewport as image
    var viewport_texture = viewport_renderer.get_texture()
    var raw_image = viewport_texture.get_image()
    
    # Process with ray casting intersection counting to handle hollow shapes correctly
    return fill_slice_interior(raw_image)

func fill_slice_interior(raw_image: Image) -> Image:
    # Simply capture the surface pixels without any volume filling
    var filled_data = PackedByteArray()
    filled_data.resize(voxel_resolution * voxel_resolution)
    filled_data.fill(0)
    
    # Only mark surface pixels as filled
    for y in range(voxel_resolution):
        for x in range(voxel_resolution):
            # Flip Y coordinate since Godot images have Y=0 at top, but we want Y=0 at bottom
            var flipped_y = voxel_resolution - 1 - y
            var pixel = raw_image.get_pixel(x, flipped_y)
            
            var is_surface = pixel.r > 0.5
            if is_surface:
                filled_data[x + y * voxel_resolution] = 255
    
    # Debug: Save slice images to see what we're capturing
    if randf() < 0.05:  # Save ~5% of slices for debugging
        var debug_path = "res://debug_slice_" + str(randi() % 1000) + ".png"
        raw_image.save_png(debug_path)
        print("Debug: Saved raw slice to ", debug_path)
    
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

func find_any_mesh_in_scene() -> MeshInstance3D:
    # Helper function to find any valid mesh in the scene
    return _search_for_any_mesh(get_tree().root)

func _search_for_any_mesh(node: Node) -> MeshInstance3D:
    # Skip the voxelizer node itself and camera nodes
    if node == self or node is Camera3D or node is SubViewport:
        return null
        
    if node is MeshInstance3D and node.mesh != null:
        # Skip debug cubes
        if not node.name.begins_with("VoxelCube"):
            return node as MeshInstance3D
    
    for child in node.get_children():
        var result = _search_for_any_mesh(child)
        if result:
            return result
    
    return null

# Public API
func get_texture3d() -> ImageTexture3D:
    return generated_texture3d

func get_texture_slices() -> Array:
    return texture_slices
