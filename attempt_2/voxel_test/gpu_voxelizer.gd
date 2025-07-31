extends Node3D

# GPU-based mesh voxelization - much more reliable than raycasting
@export var voxel_resolution: int = 64
@export var mesh_to_voxelize: Mesh

func voxelize_mesh_to_texture3d(mesh: Mesh, resolution: int) -> ImageTexture3D:
    # Get mesh bounds
    var aabb = mesh.get_aabb()
    var bounds_size = aabb.size
    var bounds_center = aabb.get_center()
    
    print("Mesh bounds: ", aabb)
    print("Bounds size: ", bounds_size)
    
    # Create 3D image data
    var image_data = PackedByteArray()
    image_data.resize(resolution * resolution * resolution)
    
    # Get mesh arrays
    var arrays = mesh.surface_get_arrays(0)
    var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
    var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
    
    print("Mesh has ", vertices.size(), " vertices and ", indices.size() / 3, " triangles")
    
    # Voxelize using triangle rasterization
    for x in range(resolution):
        for y in range(resolution):
            for z in range(resolution):
                # Convert voxel coordinates to world space
                var voxel_pos = Vector3(
                    (float(x) / resolution - 0.5) * bounds_size.x + bounds_center.x,
                    (float(y) / resolution - 0.5) * bounds_size.y + bounds_center.y,
                    (float(z) / resolution - 0.5) * bounds_size.z + bounds_center.z
                )
                
                # Test if this voxel is inside the mesh using winding number
                var is_inside = point_inside_mesh_winding_number(voxel_pos, vertices, indices)
                
                # Set voxel value
                var voxel_index = x + y * resolution + z * resolution * resolution
                image_data[voxel_index] = 255 if is_inside else 0
    
    # Create Image3D
    var image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_R8, image_data)
    var texture3d = ImageTexture3D.new()
    texture3d.create_from_images([image])  # Single slice for now
    
    return texture3d

# Winding number algorithm - much more reliable than raycasting
func point_inside_mesh_winding_number(point: Vector3, vertices: PackedVector3Array, indices: PackedInt32Array) -> bool:
    var winding_number = 0.0
    
    # Process each triangle
    for i in range(0, indices.size(), 3):
        var v0 = vertices[indices[i]]
        var v1 = vertices[indices[i + 1]]
        var v2 = vertices[indices[i + 2]]
        
        # Calculate solid angle subtended by triangle
        var solid_angle = calculate_solid_angle(point, v0, v1, v2)
        winding_number += solid_angle
    
    # Point is inside if winding number is non-zero
    return abs(winding_number) > 0.1  # Small threshold for numerical stability

func calculate_solid_angle(point: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
    # Translate triangle to point origin
    var a = v0 - point
    var b = v1 - point
    var c = v2 - point
    
    # Calculate solid angle using formula
    var cross_ab = a.cross(b)
    var cross_bc = b.cross(c)
    var cross_ca = c.cross(a)
    
    var len_a = a.length()
    var len_b = b.length()
    var len_c = c.length()
    
    if len_a < 0.001 or len_b < 0.001 or len_c < 0.001:
        return 0.0
    
    var numerator = a.dot(cross_bc)
    var denominator = len_a * len_b * len_c + a.dot(b) * len_c + b.dot(c) * len_a + c.dot(a) * len_b
    
    if abs(denominator) < 0.001:
        return 0.0
    
    return 2.0 * atan2(numerator, denominator)

func _ready():
    if mesh_to_voxelize:
        var texture3d = voxelize_mesh_to_texture3d(mesh_to_voxelize, voxel_resolution)
        print("Created Texture3D with resolution: ", voxel_resolution)
