extends Node3D
class_name WindingNumber
# Winding Number Voxelization Demo
# Converts any mesh to a Texture3D using mathematically robust winding number algorithm

@export var voxel_resolution: int = 64  # Higher resolution
@export var target_mesh_instance: MeshInstance3D
@export var show_debug_cubes: bool = true


var generated_texture3d: ImageTexture3D
var texture_slices: Array  # Store individual slices for access
var mesh_bounds: AABB  # Store mesh bounds for debug visualization
var camera: Camera3D  # Camera for scene navigation

func _ready():
    # Set up camera first
    setup_camera()
    
    # Wait for scene to load, then voxelize
    call_deferred("start_voxelization")

func setup_camera():
    # Create camera if it doesn't exist
    camera = Camera3D.new()
    camera.name = "VoxelCamera"
    
    # Load and attach the camera controller script
    var script = load("res://attempt_2/winding_number_demo/camera_controller.gd")
    camera.set_script(script)
    
    # Position camera at a good viewing distance
    camera.position = Vector3(0, 0, 10)
    #camera.look_at(Vector3.ZERO, Vector3.UP)
    
    add_child(camera)
    
    # Make it the current camera
    camera.current = true
    
    print("Camera controls: Right-click to capture mouse, WASD to move, QE for up/down, Shift for speed")

# Helper function to find a mesh by name in the scene tree
func find_mesh_by_name(mesh_name: String) -> MeshInstance3D:
    return _search_for_mesh(get_tree().root, mesh_name)

func _search_for_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
    # Check if this node is a MeshInstance3D with the target name
    if node is MeshInstance3D and node.name == mesh_name:
        return node as MeshInstance3D
    
    # Recursively search children
    for child in node.get_children():
        var result = _search_for_mesh(child, mesh_name)
        if result:
            return result
    
    return null

func start_voxelization():
    # Force use of b_skull mesh
    target_mesh_instance = find_mesh_by_name("b_skull")
    if target_mesh_instance:
        print("Found and using target mesh: b_skull")
    else:
        print("ERROR: Could not find b_skull mesh!")
        return
    
    if not target_mesh_instance.mesh:
        print("ERROR: b_skull has no mesh!")
        return
    
    print("=== WINDING NUMBER VOXELIZATION DEMO ===")
    print("Target mesh: ", target_mesh_instance.name)
    print("Resolution: ", voxel_resolution, "³ = ", voxel_resolution * voxel_resolution * voxel_resolution, " voxels")
    
    var start_time = Time.get_ticks_msec()
    generated_texture3d = voxelize_mesh_to_texture3d(target_mesh_instance.mesh, voxel_resolution)
    var end_time = Time.get_ticks_msec()
    
    print("Voxelization completed in ", end_time - start_time, " ms")
    
    # Save the texture3D automatically
    if generated_texture3d:
        var save_path = "res://voxelized_" + target_mesh_instance.name.to_lower() + "_" + str(voxel_resolution) + ".tres"
        var result = ResourceSaver.save(generated_texture3d, save_path)
        if result == OK:
            print("Texture3D saved to: ", save_path)
        else:
            print("Failed to save Texture3D: ", result)
    
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
    
    # Calculate bounds - proper AABB initialization
    if vertices.size() == 0:
        print("ERROR: No vertices in mesh!")
        return null
    
    var mesh_aabb = AABB(vertices[0], Vector3.ZERO)  # Start with first vertex
    for i in range(1, vertices.size()):
        mesh_aabb = mesh_aabb.expand(vertices[i])
    
    print("Initial mesh bounds: ", mesh_aabb)
    
    # Add some padding
    var padding = mesh_aabb.size * 0.1
    mesh_aabb = mesh_aabb.grow(padding.length())
    
    # Store bounds for debug visualization
    mesh_bounds = mesh_aabb
    
    print("Voxel bounds: ", mesh_aabb)
    print("Voxel size per unit: ", mesh_aabb.size / resolution)
    
    # Build BVH for acceleration
    var bvh_start_time = Time.get_ticks_msec()
    var bvh_root = build_bvh(vertices, indices)
    var bvh_end_time = Time.get_ticks_msec()
    print("BVH built in ", bvh_end_time - bvh_start_time, " ms")
    
    # Create 3D texture data
    var image_data = PackedByteArray()
    image_data.resize(resolution * resolution * resolution)
    image_data.fill(0)  # Initialize to empty
    
    print("\n--- Processing Voxels with BVH Acceleration ---")
    var inside_count = 0
    var total_voxels = resolution * resolution * resolution
    var progress_step = max(1, total_voxels / 10)  # Ensure progress_step is at least 1
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
                
                # Test if point is inside using BVH-accelerated winding number
                var is_inside = point_inside_mesh_winding_number_bvh(world_pos, vertices, indices, bvh_root)
                
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
    texture3d.create(Image.FORMAT_R8, resolution, resolution, resolution, false, images)
    
    # Store the slices for later access
    texture_slices = images.duplicate()
    
    print("Created Texture3D: ", resolution, "×", resolution, "×", resolution)
    return texture3d

# BVH Node for spatial acceleration
class BVHNode:
    var bbox: AABB
    var triangles: Array  # Array of triangle indices
    var left: BVHNode
    var right: BVHNode
    var is_leaf: bool = false
    
    func _init(triangle_list: Array = []):
        triangles = triangle_list
        is_leaf = triangles.size() <= 8  # Leaf threshold

# Build BVH tree for fast triangle culling
func build_bvh(vertices: PackedVector3Array, indices: PackedInt32Array) -> BVHNode:
    print("Building BVH for ", indices.size() / 3, " triangles...")
    
    # Create triangle list with indices and centroids
    var triangles = []
    for i in range(0, indices.size(), 3):
        var v0 = vertices[indices[i]]
        var v1 = vertices[indices[i + 1]]
        var v2 = vertices[indices[i + 2]]
        var centroid = (v0 + v1 + v2) / 3.0
        triangles.append({
            "index": i,
            "centroid": centroid,
            "bbox": AABB(v0, Vector3.ZERO).expand(v1).expand(v2)
        })
    
    var root = build_bvh_recursive(triangles, 0)
    print("BVH built with depth: ", get_bvh_depth(root))
    return root

func build_bvh_recursive(triangles: Array, depth: int) -> BVHNode:
    var node = BVHNode.new()
    
    # Calculate bounding box for all triangles
    if triangles.size() > 0:
        node.bbox = triangles[0].bbox
        for i in range(1, triangles.size()):
            node.bbox = node.bbox.merge(triangles[i].bbox)
    
    # Leaf node
    if triangles.size() <= 8 or depth > 20:
        node.is_leaf = true
        for triangle in triangles:
            node.triangles.append(triangle.index)
        return node
    
    # Choose split axis (longest axis)
    var size = node.bbox.size
    var axis = 0
    if size.y > size.x and size.y > size.z:
        axis = 1
    elif size.z > size.x and size.z > size.y:
        axis = 2
    
    # Sort triangles by centroid on chosen axis
    triangles.sort_custom(func(a, b): 
        if axis == 0:
            return a.centroid.x < b.centroid.x
        elif axis == 1:
            return a.centroid.y < b.centroid.y
        else:
            return a.centroid.z < b.centroid.z
    )
    
    # Split in half
    var mid = triangles.size() / 2
    var left_triangles = triangles.slice(0, mid)
    var right_triangles = triangles.slice(mid)
    
    # Recursively build children
    node.left = build_bvh_recursive(left_triangles, depth + 1)
    node.right = build_bvh_recursive(right_triangles, depth + 1)
    
    return node

func get_bvh_depth(node: BVHNode) -> int:
    if node == null or node.is_leaf:
        return 1
    return 1 + max(get_bvh_depth(node.left), get_bvh_depth(node.right))

# Winding number algorithm with BVH acceleration
func point_inside_mesh_winding_number_bvh(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array, bvh_root: BVHNode) -> bool:
    var winding_number = 0.0
    
    # Traverse BVH and sum solid angles from relevant triangles
    winding_number = calculate_winding_number_bvh(point, vertices, indices, bvh_root)
    
    # Normalize by 4π (total solid angle of sphere)
    winding_number /= (4.0 * PI)
    
    # Point is inside if winding number magnitude > 0.5
    return abs(winding_number) > 0.5

func calculate_winding_number_bvh(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array, node: BVHNode) -> float:
    if node == null:
        return 0.0
    
    # Check if point is close enough to this node's bounding box
    var distance_to_bbox = node.bbox.distance_to(point)
    var bbox_size = node.bbox.size.length()
    
    # Skip distant nodes - they contribute negligibly to winding number
    if distance_to_bbox > bbox_size * 2.0:
        return 0.0
    
    if node.is_leaf:
        var winding_contribution = 0.0
        # Process triangles in this leaf
        for tri_index in node.triangles:
            var v0 = vertices[indices[tri_index]]
            var v1 = vertices[indices[tri_index + 1]]
            var v2 = vertices[indices[tri_index + 2]]
            
            # Additional distance check for individual triangles
            var triangle_center = (v0 + v1 + v2) / 3.0
            var max_triangle_size = max(v0.distance_to(v1), max(v1.distance_to(v2), v2.distance_to(v0)))
            if point.distance_to(triangle_center) > max_triangle_size * 3.0:
                continue
            
            var solid_angle = calculate_solid_angle(point, v0, v1, v2)
            winding_contribution += solid_angle
        
        return winding_contribution
    else:
        # Recurse into children
        var left_contribution = calculate_winding_number_bvh(point, vertices, indices, node.left)
        var right_contribution = calculate_winding_number_bvh(point, vertices, indices, node.right)
        return left_contribution + right_contribution

# Original algorithm for comparison (kept for fallback)
func point_inside_mesh_winding_number(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
    var winding_number = 0.0
    
    # Sum solid angles from all triangles
    for i in range(0, indices.size(), 3):
        var v0 = vertices[indices[i]]
        var v1 = vertices[indices[i + 1]]
        var v2 = vertices[indices[i + 2]]
        
        # Quick distance check - skip triangles that are very far away
        var triangle_center = (v0 + v1 + v2) / 3.0
        var max_triangle_size = max(v0.distance_to(v1), max(v1.distance_to(v2), v2.distance_to(v0)))
        if point.distance_to(triangle_center) > max_triangle_size * 3.0:
            continue  # Triangle is too far to significantly affect winding number
        
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
    var images = texture_slices  # Use stored slices instead of trying to extract from texture3d
    
    # Create cube mesh
    var cube_mesh = BoxMesh.new()
    var voxel_world_size = min(mesh_bounds.size.x, mesh_bounds.size.y, mesh_bounds.size.z) / voxel_resolution * 0.8
    cube_mesh.size = Vector3(voxel_world_size, voxel_world_size, voxel_world_size)
    
    # Create material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.CYAN
    material.emission_enabled = true
    material.emission = Color.CYAN * 0.3
    
    var displayed_count = 0
    
    # Display voxels
    for z in range(voxel_resolution):
        var image = images[z]
        var image_data = image.get_data()
        
        for y in range(voxel_resolution):
            for x in range(voxel_resolution):
                var pixel_index = x + y * voxel_resolution
                
                if image_data[pixel_index] > 0:
                    var cube_instance = MeshInstance3D.new()
                    cube_instance.name = "VoxelCube_" + str(x) + "_" + str(y) + "_" + str(z)
                    cube_instance.mesh = cube_mesh
                    cube_instance.material_override = material
                    
                    # Position cube in world space (same transformation as voxelization)
                    var world_pos = Vector3(
                        mesh_bounds.position.x + (float(x) + 0.5) / voxel_resolution * mesh_bounds.size.x,
                        mesh_bounds.position.y + (float(y) + 0.5) / voxel_resolution * mesh_bounds.size.y,
                        mesh_bounds.position.z + (float(z) + 0.5) / voxel_resolution * mesh_bounds.size.z
                    )
                    cube_instance.position = world_pos
                    
                    add_child(cube_instance)
                    displayed_count += 1
    
    print("Displayed ", displayed_count, " voxel cubes")

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
            var layer_data = texture_slices[i].get_data()
            file.store_var(layer_data)
        
        file.close()
        print("Saved Texture3D data to: ", filepath)
    else:
        print("Failed to save file: ", filepath)
