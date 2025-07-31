extends Node3D
class_name VoxelBaker2

# Volume settings
var volume_resolution: int = 128
var volume_min: Vector3 = Vector3(-10, -10, -10)
var volume_max: Vector3 = Vector3(10, 10, 10)
var volume_texture: ImageTexture3D

func _ready():
    bake_scene_to_volume()

func bake_scene_to_volume():
    print("Starting volume baking...")
    var start_time = Time.get_ticks_msec()
    
    # Get only MeshInstance3D children to bake
    var objects_to_bake = []
    for child in get_children():
        if child is MeshInstance3D:
            objects_to_bake.append(child)
    
    print("Baking ", objects_to_bake.size(), " MeshInstance3D objects...")
    
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
                # Convert voxel coordinates to world position
                var world_pos = volume_min + Vector3(x, y, z) * voxel_size
                
                # Debug: Print center voxel position
                if x == 64 and y == 64 and z == 64:
                    print("Center voxel (64,64,64) maps to world pos: ", world_pos)
                
                # Test if this point is inside any object
                var density = 0.0
                for obj in objects_to_bake:
                    if point_inside_mesh(obj, world_pos):
                        density = 1.0
                        # Debug: Print when density is found
                        if z == 64 and y == 64 and x == 64:
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
    if lens_material:
        lens_material.set_shader_parameter("volume_texture", volume_texture)
        lens_material.set_shader_parameter("volume_min", volume_min)
        lens_material.set_shader_parameter("volume_max", volume_max)
    else:
        print("Warning: XRayLens material not found!")
    
    var end_time = Time.get_ticks_msec()
    print("Volume baking complete! Took ", end_time - start_time, "ms")

func point_inside_mesh(mesh_instance: MeshInstance3D, world_point: Vector3) -> bool:
    # Method 1: Use AABB for quick approximation
    var aabb = mesh_instance.get_aabb()
    var local_point = mesh_instance.to_local(world_point)
    
    # Simple AABB test
    if not aabb.has_point(local_point):
        return false
    
    # Debug: If we're testing the center voxel, print AABB info
    if world_point.distance_to(Vector3.ZERO) < 0.5:
        print("AABB test passed for center point! AABB: ", aabb, " Local point: ", local_point)
    
    # Method 2: Ray casting (more accurate but needs collision shapes)
    var space_state = get_world_3d().direct_space_state
    if space_state == null:
        print("Warning: No physics space available, using AABB only")
        return true
    
    var query = PhysicsRayQueryParameters3D.create(
        world_point + Vector3(0, 1000, 0),
        world_point - Vector3(0, 1000, 0)
    )
    
    var intersection_count = 0
    var result = space_state.intersect_ray(query)
    var max_iterations = 10  # Prevent infinite loops
    var iterations = 0
    
    # Debug: Print ray casting results for center point
    if world_point.distance_to(Vector3.ZERO) < 0.5:
        if result.is_empty():
            print("No ray intersections found - using AABB result only")
            #return true #CLAUDE - Is this correct? It might be!
        else:
            print("Ray hit: ", result.collider.name if result.has("collider") else "unknown")
    
    while result and not result.is_empty() and iterations < max_iterations:
        iterations += 1
        
        # Check if this collision is with any child of this VoxelBaker
        #CLAUDE - Added double parentage. 
        var collider = result.collider
        if collider and collider.get_parent().get_parent() == self:
            intersection_count += 1
        
        # Continue ray from intersection point
        query.from = result.position + Vector3(0, -0.01, 0)
        result = space_state.intersect_ray(query)
    
    return intersection_count % 2 == 1  # Odd = inside
