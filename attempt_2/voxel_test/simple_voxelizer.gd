extends Node3D

# Simple voxel generator - no raycasting, just basic geometry detection
@export var voxel_size: float = 1.0  # Larger voxels
@export var grid_bounds: Vector3 = Vector3(8, 8, 8)  # Smaller grid
var voxels: Array[Vector3] = []

func _ready():
    print("Starting voxel generation...")
    call_deferred("start_generation")

func start_generation():
    generate_voxels_from_geometry()
    display_voxels()

func generate_voxels_from_geometry():
    print("Generating voxels...")
    
    # Find all MeshInstance3D nodes in the scene
    var mesh_objects = []
    find_mesh_instances(self, mesh_objects)
    
    print("Found ", mesh_objects.size(), " mesh objects to voxelize")
    for obj in mesh_objects:
        print("Mesh object: ", obj.name, " at position: ", obj.global_position)
        if obj.mesh and obj.mesh is SphereMesh:
            var sphere = obj.mesh as SphereMesh
            print("  Sphere radius: ", sphere.radius, " height: ", sphere.height)
    
    # Generate voxel grid
    var steps = int(grid_bounds.x * 2 / voxel_size)
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
                
                # Debug some positions
                if x == 0 and y == 0 and z < 3:
                    print("Test position [", x, ",", y, ",", z, "] = ", world_pos)
                
                # Simple distance-based detection for now
                var is_inside = false
                for mesh_obj in mesh_objects:
                    var distance = world_pos.distance_to(mesh_obj.global_position)
                    # Use the sphere radius (2.0) plus a bit more
                    if distance < 2.5:  # Sphere radius + some margin
                        is_inside = true
                        if voxel_count < 10:
                            print("Voxel ", voxel_count, " at ", world_pos, " distance: ", distance, " from ", mesh_obj.global_position)
                        break
                
                if is_inside:
                    voxels.append(world_pos)
                    voxel_count += 1
    
    print("Generated ", voxels.size(), " voxels")

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
    for i in range(min(voxels.size(), 100)):  # Limit to 100 for now
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
