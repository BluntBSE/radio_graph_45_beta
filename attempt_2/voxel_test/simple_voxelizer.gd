extends Node3D

# Simple voxel generator - no raycasting, just basic geometry detection
@export var voxel_size: float = 1.0  # Larger voxels
@export var grid_bounds: Vector3 = Vector3(8, 8, 8)  # Smaller grid
var voxels: Array[Vector3] = []
var mesh_objects = []

func _ready():
    pass
    #call_deferred("start_generation")
    #%CollisionConfigurator.collisions_generated.connect(start_generation)

func start_generation():
    #test_single_point()
    test_and_create_voxel_at_point()
    #generate_voxels_from_geometry()
    #display_voxels()

func generate_voxels_from_geometry():
    print("Generating voxels...")
    
    # Find all MeshInstance3D nodes in the scene

    find_mesh_instances(self, mesh_objects)
    
    print("Found ", mesh_objects.size(), " mesh objects to voxelize")
    for obj in mesh_objects:
        print("Mesh object: ", obj.name, " at position: ", obj.global_position)

    
    # Generate voxel grid
    var steps = int(grid_bounds.x * 2 / voxel_size) #Why X2?
    print("Grid steps: ", steps, " (", steps*steps*steps, " total voxels to test)")
    print("Grid bounds: ", -grid_bounds, " to ", grid_bounds)
    print("Voxel size: ", voxel_size)
    
    var voxel_count = 0
    for x in range(steps):
        for y in range(steps):
            for z in range(steps):
                var world_pos = Vector3(
                    -grid_bounds.x + x * voxel_size + voxel_size * 0.5,
                    -grid_bounds.y + y * voxel_size + voxel_size * 0.5,
                    -grid_bounds.z + z * voxel_size + voxel_size * 0.5
                )
                

                # Test if point is inside mesh using ray-casting
                var is_inside = point_inside_concave_mesh(world_pos)

    
                if is_inside:
                    print("Got something inside!?")
                    voxels.append(world_pos)
                    voxel_count += 1
    
    print("Generated ", voxels.size(), " voxels")

func point_inside_concave_mesh(world_pos: Vector3) -> bool:
    # Cast a ray from the test point outward and count intersections
    # This implements the "ray casting algorithm" for point-in-polygon testing
    # Odd number of intersections = inside, even number = outside
    var ray_direction = Vector3(1, 0, 0)  # Direction to cast
    var ray_start = world_pos
    var ray_end = world_pos + ray_direction * 100.0  # Far distance
    var margin = 0.001  # Small offset to avoid hitting the same surface twice
    
    var space_state = get_world_3d().direct_space_state
    var intersection_count = 0
    var current_start = ray_start
    
    # Keep casting rays until we reach the end or no more intersections
    while current_start.distance_to(ray_end) > margin:
        var query = PhysicsRayQueryParameters3D.create(current_start, ray_end)
        var result = space_state.intersect_ray(query)
        
        if result.is_empty():
            # No more intersections, we're done
            break
        
        # We found an intersection
        intersection_count += 1
        var hit_point = result["position"]
        
        # Debug output
        print("Intersection ", intersection_count, " at: ", hit_point)
        
        # Set up next raycast starting just past this intersection
        current_start = hit_point + ray_direction * margin
        
        # Safety check to prevent infinite loops
        if intersection_count > 100:  # Reasonable limit
            print("Warning: Too many intersections, breaking")
            break
    
    
    
    # Count how many surfaces we hit
    return (intersection_count % 2) == 1  # Odd = inside

func find_mesh_instances(node: Node, mesh_list: Array):
    if node is MeshInstance3D and node.name != "VoxelCube":  # Skip our own voxel cubes
        mesh_list.append(node)
    
    for child in node.get_children():
        find_mesh_instances(child, mesh_list)

func display_voxels():
    print("Displaying voxels...")
    
    if voxels.size() == 0:
        print("ERROR: No voxels to display!")
        return
    
    # Create a simple cube mesh for each voxel
    var cube_mesh = BoxMesh.new()
    cube_mesh.size = Vector3(voxel_size * 0.9, voxel_size * 0.9, voxel_size * 0.9)  # Slightly smaller to see gaps
    
    # Create different colored materials
    var materials = []
    var colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA]
    for color in colors:
        var material = StandardMaterial3D.new()
        material.albedo_color = color
        material.emission_enabled = true
        material.emission = color * 0.3
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        materials.append(material)
    
    var displayed = 0
    for i in range(min(voxels.size(), 30000)):  # Limit to 100 for now
        var voxel_instance = MeshInstance3D.new()
        voxel_instance.name = "VoxelCube"  # Name them so we can skip them in mesh detection
        voxel_instance.mesh = cube_mesh
        # Use different colors for different voxels
        voxel_instance.material_override = materials[i % materials.size()]
        add_child(voxel_instance)
        voxel_instance.global_position = voxels[i]
        displayed += 1
        
        # Debug all positions
        print("Displaying voxel ", i, " at position: ", voxels[i])
    
    print("Displayed ", displayed, " voxel cubes")


# Add this function to create debug spheres
func create_debug_sphere(position: Vector3, color: Color, size: float = 0.1) -> MeshInstance3D:
    var sphere_mesh = SphereMesh.new()
    sphere_mesh.radius = size
    sphere_mesh.height = size * 2
    
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color * 0.8
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    
    var sphere_instance = MeshInstance3D.new()
    sphere_instance.name = "DebugSphere"
    sphere_instance.mesh = sphere_mesh
    sphere_instance.material_override = material
    sphere_instance.global_position = position
    
    add_child(sphere_instance)
    return sphere_instance



# Add this test function
func test_single_point():
    print("=== Testing single point raycast from origin ===")
    var test_pos = Vector3(0.0,0.5,0.0)
    
    # Create debug sphere at test point
    create_debug_sphere(test_pos, Color.GREEN, 0.01)
    
    # Perform the raycast
    var ray_direction = Vector3(1, 0, 0)
    var ray_start = test_pos
    var ray_end = test_pos + ray_direction * 5.0
    var margin = 0.001
    create_debug_sphere(ray_end, Color.RED, 0.05)
    
    # Create debug sphere at ray end


# Add this function to test the specific point and create a voxel if inside
# Add this function to test the specific point and create a voxel if inside
func test_and_create_voxel_at_point():
    print("=== Testing point and creating voxel if inside ===")
    var test_pos = Vector3(0.0, 0.5, 0.0)  # Same position as your green sphere
    
    # Just raycast from test_pos to the right 5 units, print the collision
    print("=== Simple raycast debug ===")
    var ray_end = test_pos
    create_debug_sphere(ray_end, Color.GREEN, 0.05)
    var ray_start = test_pos + Vector3(5.0, 0, 0)
    create_debug_sphere(ray_start, Color.RED, 0.05)
    var debug_query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    debug_query.collision_mask = 0xFFFFFFFF  # Hit all collision layers
    debug_query.collide_with_areas = false
    debug_query.collide_with_bodies = true
    #debug_query.hit_from_inside = true
    #debug_query.hit_back_faces = true
    
    var space_state = get_world_3d().direct_space_state
    var debug_result = space_state.intersect_ray(debug_query)
    
    if debug_result.is_empty():
        print("DEBUG: No collision detected from ", ray_start, " to ", ray_end)
        print("This means either:")
        print("  1. No collision shapes in the scene")
        print("  2. Collision shapes are on wrong layer") 
        print("  3. Ray missed the collision shape")
    else:
        print("DEBUG: Hit detected!")
        print("  Hit position: ", debug_result["position"])
        print("  Hit object: ", debug_result.get("collider", "Unknown"))
        if debug_result.has("collider"):
            var hit_obj = debug_result["collider"]
            print("  Object class: ", hit_obj.get_class())
            print("  Object name: ", hit_obj.name)
        
        # Create a blue sphere at the hit point
        create_debug_sphere(debug_result["position"], Color.BLUE, 0.03)
    
    print("=== End simple raycast debug ===")
    
    # Test if point is inside using our ray-casting function
    var is_inside = point_inside_concave_mesh(test_pos)
    
    print("Point ", test_pos, " is inside mesh: ", is_inside)
    
    if is_inside:
        print("Creating voxel at inside point!")
        
        # Add to voxels array
        voxels.append(test_pos)
        
        # Create and display the voxel immediately
        var cube_mesh = BoxMesh.new()
        cube_mesh.size = Vector3(voxel_size * 0.9, voxel_size * 0.9, voxel_size * 0.9)
        
        var material = StandardMaterial3D.new()
        material.albedo_color = Color.CYAN
        material.emission_enabled = true
        material.emission = Color.CYAN * 0.3
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        
        var voxel_instance = MeshInstance3D.new()
        voxel_instance.name = "TestVoxelCube"
        voxel_instance.mesh = cube_mesh
        voxel_instance.material_override = material
        voxel_instance.global_position = test_pos
        
        add_child(voxel_instance)
        
        print("Voxel created and displayed at: ", test_pos)
    else:
        print("Point is outside - no voxel created")
    
    return is_inside
