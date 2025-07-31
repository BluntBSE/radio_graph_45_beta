extends Node3D

# Winding Number Voxelization Demo
# Converts any mesh to a Texture3D using mathematically robust winding number algorithm

@export var voxel_resolution: int = 32  # Start small for testing
@export var target_mesh_instance: MeshInstance3D
@export var show_debug_cubes: bool = true

var generated_texture3d: ImageTexture3D

func _ready():
    # Wait for scene to load, then voxelize
    call_deferred("start_voxelization")

func start_voxelization():
    if not target_mesh_instance or not target_mesh_instance.mesh:
        print("ERROR: No target mesh assigned!")
        return
    
    print("=== WINDING NUMBER VOXELIZATION DEMO ===")
    print("Target mesh: ", target_mesh_instance.name)
    print("Resolution: ", voxel_resolution, "³ = ", voxel_resolution * voxel_resolution * voxel_resolution, " voxels")
    
    var start_time = Time.get_ticks_msec()
    generated_texture3d = voxelize_mesh_to_texture3d(target_mesh_instance.mesh, voxel_resolution)
    var end_time = Time.get_ticks_msec()
    
    print("Voxelization completed in ", end_time - start_time, " ms")
    
    if show_debug_cubes:
        display_voxels_as_cubes()

func voxelize_mesh_to_texture3d(mesh: Mesh, resolution: int) -> ImageTexture3D:
    print("\n--- Starting Mesh Analysis ---")
    
    # Get mesh data
    var arrays = mesh.surface_get_arrays(0)
    var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
    var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
    
    # Apply the mesh instance's transform to vertices
    var transform = target_mesh_instance.global_transform
    for i in range(vertices.size()):
        vertices[i] = transform * vertices[i]
    
    print("Mesh triangles: ", indices.size() / 3)
    print("Mesh vertices: ", vertices.size())
    
    # Calculate bounds
    var mesh_aabb = AABB()
    for vertex in vertices:
        if mesh_aabb.size == Vector3.ZERO:
            mesh_aabb.position = vertex
        else:
            mesh_aabb = mesh_aabb.expand(vertex)
    
    # Add some padding
    var padding = mesh_aabb.size * 0.1
    mesh_aabb = mesh_aabb.grow(padding.length())
    
    print("Voxel bounds: ", mesh_aabb)
    print("Voxel size per unit: ", mesh_aabb.size / resolution)
    
    # Create 3D texture data
    var image_data = PackedByteArray()
    image_data.resize(resolution * resolution * resolution)
    image_data.fill(0)  # Initialize to empty
    
    print("\n--- Processing Voxels ---")
    var inside_count = 0
    var progress_step = (resolution * resolution * resolution) / 10
    var processed = 0
    
    # Test each voxel position
    for z in range(resolution):
        for y in range(resolution):
            for x in range(resolution):
                # Convert voxel coordinates to world position
                var world_pos = Vector3(
                    mesh_aabb.position.x + (float(x) + 0.5) / resolution * mesh_aabb.size.x,
                    mesh_aabb.position.y + (float(y) + 0.5) / resolution * mesh_aabb.size.y,
                    mesh_aabb.position.z + (float(z) + 0.5) / resolution * mesh_aabb.size.z
                )
                
                # Test if point is inside using winding number
                var is_inside = point_inside_mesh_winding_number(world_pos, vertices, indices)
                
                if is_inside:
                    var voxel_index = x + y * resolution + z * resolution * resolution
                    image_data[voxel_index] = 255
                    inside_count += 1
                
                # Progress reporting
                processed += 1
                if processed % progress_step == 0:
                    var percent = float(processed) / (resolution * resolution * resolution) * 100
                    print("Progress: ", int(percent), "% (", inside_count, " voxels inside)")
    
    print("\nVoxelization complete!")
    print("Interior voxels: ", inside_count, " / ", resolution * resolution * resolution)
    print("Fill ratio: ", float(inside_count) / (resolution * resolution * resolution) * 100, "%")
    
    # Create 3D texture layers (Godot needs 2D slices)
    var images = []
    for z in range(resolution):
        var slice_data = PackedByteArray()
        slice_data.resize(resolution * resolution)
        
        for y in range(resolution):
            for x in range(resolution):
                var source_index = x + y * resolution + z * resolution * resolution
                var slice_index = x + y * resolution
                slice_data[slice_index] = image_data[source_index]
        
        var slice_image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_R8, slice_data)
        images.append(slice_image)
    
    # Create ImageTexture3D
    var texture3d = ImageTexture3D.new()
    texture3d.create_from_images(images)
    
    print("Created Texture3D: ", resolution, "×", resolution, "×", resolution)
    return texture3d

# Winding number algorithm for point-in-mesh testing
func point_inside_mesh_winding_number(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
    var winding_number = 0.0
    
    # Sum solid angles from all triangles
    for i in range(0, indices.size(), 3):
        var v0 = vertices[indices[i]]
        var v1 = vertices[indices[i + 1]]
        var v2 = vertices[indices[i + 2]]
        
        var solid_angle = calculate_solid_angle(point, v0, v1, v2)
        winding_number += solid_angle
    
    # Normalize by 4π (total solid angle of sphere)
    winding_number /= (4.0 * PI)
    
    # Point is inside if winding number magnitude > 0.5
    return abs(winding_number) > 0.5

# Calculate solid angle subtended by triangle from point
func calculate_solid_angle(point: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
    # Translate triangle vertices relative to point
    var a = v0 - point
    var b = v1 - point
    var c = v2 - point
    
    # Get lengths
    var len_a = a.length()
    var len_b = b.length()
    var len_c = c.length()
    
    # Avoid degenerate cases
    if len_a < 1e-6 or len_b < 1e-6 or len_c < 1e-6:
        return 0.0
    
    # Normalize vectors
    a = a / len_a
    b = b / len_b
    c = c / len_c
    
    # Calculate solid angle using L'Huilier's theorem
    var numerator = a.dot(b.cross(c))
    var denominator = 1.0 + a.dot(b) + b.dot(c) + c.dot(a)
    
    if abs(denominator) < 1e-6:
        return 0.0
    
    return 2.0 * atan2(abs(numerator), denominator) * sign(numerator)

# Debug visualization - show voxels as colored cubes
func display_voxels_as_cubes():
    if not generated_texture3d:
        print("No texture3d to display!")
        return
    
    print("\n--- Creating Debug Visualization ---")
    
    # Clear any existing debug cubes
    for child in get_children():
        if child.name.begins_with("VoxelCube"):
            child.queue_free()
    
    # Get texture data back out
    var images = []
    for i in range(voxel_resolution):
        images.append(generated_texture3d.get_layer_data(i))
    
    # Create cube mesh
    var cube_mesh = BoxMesh.new()
    var voxel_world_size = 0.8  # Slightly smaller than grid cell
    cube_mesh.size = Vector3(voxel_world_size, voxel_world_size, voxel_world_size)
    
    # Create material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.CYAN
    material.emission_enabled = true
    material.emission = Color.CYAN * 0.3
    
    var displayed_count = 0
    var max_display = 5000  # Limit for performance
    
    # Display voxels
    for z in range(voxel_resolution):
        var image = images[z]
        var image_data = image.get_data()
        
        for y in range(voxel_resolution):
            for x in range(voxel_resolution):
                var pixel_index = x + y * voxel_resolution
                
                if image_data[pixel_index] > 0 and displayed_count < max_display:
                    var cube_instance = MeshInstance3D.new()
                    cube_instance.name = "VoxelCube_" + str(x) + "_" + str(y) + "_" + str(z)
                    cube_instance.mesh = cube_mesh
                    cube_instance.material_override = material
                    
                    # Position cube in world space
                    cube_instance.position = Vector3(x, y, z) - Vector3(voxel_resolution/2, voxel_resolution/2, voxel_resolution/2)
                    
                    add_child(cube_instance)
                    displayed_count += 1
    
    print("Displayed ", displayed_count, " voxel cubes")
    
    if displayed_count >= max_display:
        print("Note: Limited to ", max_display, " cubes for performance")

# Public function to get the generated texture
func get_texture3d() -> ImageTexture3D:
    return generated_texture3d

# Public function to save texture data
func save_texture3d_data(filepath: String):
    if not generated_texture3d:
        print("No texture to save!")
        return
    
    # Save as a simple data file
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if file:
        file.store_32(voxel_resolution)  # Save resolution
        
        # Save all layer data
        for i in range(voxel_resolution):
            var layer_data = generated_texture3d.get_layer_data(i).get_data()
            file.store_var(layer_data)
        
        file.close()
        print("Saved Texture3D data to: ", filepath)
    else:
        print("Failed to save file: ", filepath)
