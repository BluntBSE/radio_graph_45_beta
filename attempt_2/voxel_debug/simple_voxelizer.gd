extends Node3D

# Simple voxel generator - no raycasting, just basic geometry detection
var voxel_size = 0.5
var grid_bounds = Vector3(10, 10, 10)  # -5 to +5 in each direction
var voxels = []

func _ready():
    generate_voxels_from_geometry()
    call_deferred("display_voxels")

func generate_voxels_from_geometry():
    print("Generating voxels...")
    
    # Find all MeshInstance3D nodes in the scene
    var mesh_objects = []
    find_mesh_instances(self, mesh_objects)
    
    print("Found ", mesh_objects.size(), " mesh objects to voxelize")
    
    # Generate voxel grid
    var steps = int(grid_bounds.x * 2 / voxel_size)
    
    for x in range(steps):
        for y in range(steps):
            for z in range(steps):
                var world_pos = Vector3(
                    -grid_bounds.x + x * voxel_size,
                    -grid_bounds.y + y * voxel_size, 
                    -grid_bounds.z + z * voxel_size
                )
                
                # Simple distance-based detection for now
                var is_inside = false
                for mesh_obj in mesh_objects:
                    var distance = world_pos.distance_to(mesh_obj.global_position)
                    if distance < 1.0:  # Simple sphere approximation
                        is_inside = true
                        break
                
                if is_inside:
                    voxels.append(world_pos)
    
    print("Generated ", voxels.size(), " voxels")

func find_mesh_instances(node: Node, mesh_list: Array):
    if node is MeshInstance3D:
        mesh_list.append(node)
    
    for child in node.get_children():
        find_mesh_instances(child, mesh_list)

func display_voxels():
    print("Displaying voxels...")
    
    # Create a simple cube mesh for each voxel
    var cube_mesh = BoxMesh.new()
    cube_mesh.size = Vector3(voxel_size, voxel_size, voxel_size)
    
    # Create a simple material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.RED
    material.emission_enabled = true
    material.emission = Color.RED * 0.3
    
    for i in range(min(voxels.size(), 1000)):  # Limit to 1000 voxels for performance
        var voxel_instance = MeshInstance3D.new()
        voxel_instance.mesh = cube_mesh
        voxel_instance.material_override = material
        add_child(voxel_instance)
        voxel_instance.global_position = voxels[i]

    
    print("Displayed ", min(voxels.size(), 1000), " voxel cubes")
