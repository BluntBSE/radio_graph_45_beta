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
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
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
    
    print("Voxel bounds: ", mesh_bounds)
    
    # Clone mesh to viewport for rendering
    var viewport_mesh = MeshInstance3D.new()
    viewport_mesh.mesh = mesh_instance.mesh
    viewport_mesh.material_override = create_solid_material()
    viewport_mesh.global_transform = mesh_instance.global_transform
    viewport_renderer.add_child(viewport_mesh)
    
    # Setup camera for slice capture  
    var voxel_slice_thickness = mesh_bounds.size.z / voxel_resolution
    setup_slice_camera(mesh_bounds, voxel_slice_thickness)
    
    print("Voxel slice thickness: ", voxel_slice_thickness)
    print("Camera near: ", slice_camera.near, ", far: ", slice_camera.far)
    print("Camera depth of field: ", slice_camera.far - slice_camera.near)
    
    # Generate slices by panning camera through Z positions
    var slice_images = []
    
    print("Capturing ", voxel_resolution, " slices...")
    print("Torus center should be at Z=", mesh_bounds.get_center().z)
    
    for z_slice in range(voxel_resolution):
        # Calculate world Z position for this slice
        var z_progress = float(z_slice) / voxel_resolution
        var world_z = mesh_bounds.position.z + z_progress * mesh_bounds.size.z
        
        # Position camera to look AT this specific slice only
        # Camera must be positioned exactly one slice thickness away
        var camera_distance = slice_camera.near + voxel_slice_thickness * 0.5
        
        slice_camera.position = Vector3(
            mesh_bounds.get_center().x,
            mesh_bounds.get_center().y,  
            world_z + camera_distance  # Positioned for thin slice capture
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
        
        if z_slice % 8 == 0:  # More frequent progress updates
            print("Captured slice ", z_slice, " / ", voxel_resolution, " at Z=", world_z)
            # Debug specific slices around center
            var center_slice = voxel_resolution / 2
            if abs(z_slice - center_slice) <= 2:
                print("  -> Center slice area, should show torus hole if present")
    
    # Store slices for debugging
    texture_slices = slice_images.duplicate()
    
    # Clean up
    viewport_mesh.queue_free()
    
    # Create 3D texture
    var texture3d = ImageTexture3D.new()
    texture3d.create(Image.FORMAT_R8, voxel_resolution, voxel_resolution, voxel_resolution, false, slice_images)
    
    print("Camera-based voxelization complete!")
    return texture3d

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
