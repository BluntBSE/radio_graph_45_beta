extends Node3D

# Volume settings
var volume_resolution: int = 128
var volume_min: Vector3 = Vector3(-10, -10, -10)  # Adjust to encompass your scene
var volume_max: Vector3 = Vector3(10, 10, 10)
var volume_texture: ImageTexture3D

func _ready():
    bake_scene_to_volume()

# Search the entire scene tree for TestPrism objects
func find_test_prisms(node: Node, objects_to_bake: Array):
    if node is MeshInstance3D and node.name.begins_with("TestPrism"):
        objects_to_bake.append(node)
    for child in node.get_children():
        find_test_prisms(child, objects_to_bake)

func print_all_meshes(node: Node, depth: int = 0):
    var indent = "  ".repeat(depth)
    if node is MeshInstance3D:
        print(indent + "Found MeshInstance3D: " + node.name + " at " + str(node.global_position))
    for child in node.get_children():
        print_all_meshes(child, depth + 1)

func bake_scene_to_volume():
    print("Starting volume baking...")
    var start_time = Time.get_ticks_msec()
    
    # Get all objects to bake (adjust selector as needed)
    var objects_to_bake = []
    
    # Start search from the scene root
    find_test_prisms(get_tree().current_scene, objects_to_bake)
    
    # Debug: Print all MeshInstance3D nodes found in scene
    print("DEBUG - All MeshInstance3D nodes in scene:")
    print_all_meshes(get_tree().current_scene)
    
    print("Baking ", objects_to_bake.size(), " objects...")
    
    # Debug: Print object positions and volume bounds
    for obj in objects_to_bake:
        print("Object '", obj.name, "' position: ", obj.global_position)
    print("Volume bounds: ", volume_min, " to ", volume_max)
    
    # Create volume data
    var volume_data = PackedByteArray()
    var voxel_size = (volume_max - volume_min) / volume_resolution
    
    # For each voxel
    for z in range(volume_resolution):
        for y in range(volume_resolution):
            for x in range(volume_resolution):
                # Convert voxel coordinates to world position - FIXED CALCULATION
                var world_pos = volume_min + Vector3(x, y, z) * voxel_size
                
                # Debug: Print a few sample world positions
                if x == 64 and y == 64 and z == 64:
                    print("Center voxel (64,64,64) maps to world pos: ", world_pos)
                
                # Test if this point is inside any object
                var density = 0.0
                for obj in objects_to_bake:
                    if point_inside_mesh(obj, world_pos):
                        density = 1.0
                        # Debug: Print when density is found
                        if z == 64 and y == 64 and x == 64: # Only print for center voxel to avoid spam
                            print("Density found at center voxel for object: ", obj.name)
                        break
                
                # Store as byte (0-255)
                volume_data.append(int(density * 255))
        
        # Progress indicator
        if z % 16 == 0:
            print("Progress: ", z, "/", volume_resolution)
    
    # Create 3D texture from multiple 2D slices
    volume_texture = ImageTexture3D.new()
    var images = []
    
    for z in range(volume_resolution):
        var slice_data = PackedByteArray()
        for y in range(volume_resolution):
            for x in range(volume_resolution):
                var index = x + y * volume_resolution + z * volume_resolution * volume_resolution
                slice_data.append(volume_data[index])
        
        var slice_image = Image.create_from_data(
            volume_resolution, 
            volume_resolution, 
            false, 
            Image.FORMAT_R8, 
            slice_data
        )
        images.append(slice_image)
    
    volume_texture.create(Image.FORMAT_R8, volume_resolution, volume_resolution, volume_resolution, false, images)
    
    # Apply to shader
    var lens_material = %XRayLens.material_override
    lens_material.set_shader_parameter("volume_texture", volume_texture)
    lens_material.set_shader_parameter("volume_min", volume_min)
    lens_material.set_shader_parameter("volume_max", volume_max)
    
    var end_time = Time.get_ticks_msec()
    print("Volume baking complete! Took ", end_time - start_time, "ms")

func point_inside_mesh(mesh_instance: MeshInstance3D, world_point: Vector3) -> bool:
    # Method 1: Use AABB for quick approximation (fallback)
    var aabb = mesh_instance.get_aabb()
    var local_point = mesh_instance.to_local(world_point)
    
    # Simple AABB test (fast but not accurate for complex shapes)
    if not aabb.has_point(local_point):
        return false
    
    # Debug: If we're testing the center voxel, print AABB info
    if world_point.distance_to(Vector3.ZERO) < 0.5:  # Close to center
        print("AABB test passed for center point! AABB: ", aabb, " Local point: ", local_point)
    
    # Method 2: Ray casting (more accurate but needs collision shapes)
    var space_state = get_world_3d().direct_space_state
    if space_state == null:
        print("Warning: No physics space available, using AABB only")
        return true  # Fall back to AABB result
    
    var query = PhysicsRayQueryParameters3D.create(
        world_point + Vector3(0, 1000, 0),  # Start from far above
        world_point - Vector3(0, 1000, 0)   # End far below
    )
    
    var intersection_count = 0
    var result = space_state.intersect_ray(query)
    
    # Debug: Print ray casting results for center point
    if world_point.distance_to(Vector3.ZERO) < 0.5:
        if result.is_empty():
            print("No ray intersections found - object likely has no collision shape")
            return true  # Fall back to AABB result
        else:
            print("Ray hit: ", result.collider.name if result.has("collider") else "unknown")
    
    while result:
        # Accept collision with ANY object in the TestPrism family (StaticBody3D or MeshInstance3D)
        if result.collider.name.begins_with("TestPrism") or result.collider == mesh_instance:
            intersection_count += 1
        # Continue ray from intersection point
        query.from = result.position + Vector3(0, -0.01, 0)
        result = space_state.intersect_ray(query)
    
    return intersection_count % 2 == 1  # Odd = inside
    
