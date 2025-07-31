extends Node3D

var volume_texture: ImageTexture3D

func _ready():
    simple_voxel_test()

func simple_voxel_test():
    print("=== SIMPLE VOXEL TEST ===")
    
    # Find any MeshInstance3D in the scene
    var mesh_obj = find_mesh_in_scene(get_tree().current_scene)
    if not mesh_obj:
        print("ERROR: No MeshInstance3D found!")
        return
    
    print("Found mesh: ", mesh_obj.name, " at ", mesh_obj.global_position)
    var aabb = mesh_obj.get_aabb()
    print("Mesh AABB: ", aabb)
    
    # Create tiny 8x8x8 volume for testing
    var res = 8
    var volume_data = PackedByteArray()
    
    # Volume bounds: much larger area around the mesh for proper viewing
    var volume_min = mesh_obj.global_position + aabb.position - Vector3(5, 5, 5)
    var volume_max = mesh_obj.global_position + aabb.position + aabb.size + Vector3(5, 5, 5)
    var voxel_size = (volume_max - volume_min) / res
    
    print("Volume bounds: ", volume_min, " to ", volume_max)
    print("Voxel size: ", voxel_size)
    
    # Fill every voxel that overlaps the mesh AABB
    for z in range(res):
        for y in range(res):
            for x in range(res):
                var world_pos = volume_min + Vector3(x, y, z) * voxel_size
                var local_pos = mesh_obj.to_local(world_pos)
                
                # Simple: if point is inside mesh AABB, mark as solid
                var density = 0
                if aabb.has_point(local_pos):
                    density = 255
                    print("Voxel (", x, ",", y, ",", z, ") = SOLID at world ", world_pos)
                
                volume_data.append(density)
    
    # Create 3D texture
    volume_texture = ImageTexture3D.new()
    var images = []
    
    for z in range(res):
        var slice_data = PackedByteArray()
        for y in range(res):
            for x in range(res):
                var index = x + y * res + z * res * res
                slice_data.append(volume_data[index])
        
        var slice_image = Image.create_from_data(res, res, false, Image.FORMAT_R8, slice_data)
        images.append(slice_image)
    
    volume_texture.create(Image.FORMAT_R8, res, res, res, false, images)
    
    # Apply to shader
    var lens_material = %XRayLens.material_override
    lens_material.set_shader_parameter("volume_texture", volume_texture)
    lens_material.set_shader_parameter("volume_min", volume_min)
    lens_material.set_shader_parameter("volume_max", volume_max)
    
    print("Applied to shader - volume_min: ", volume_min, " volume_max: ", volume_max)
    print("=== VOXEL TEST COMPLETE ===")

func find_mesh_in_scene(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D and node.name.begins_with("TestPrism"):
        return node
    for child in node.get_children():
        var result = find_mesh_in_scene(child)
        if result:
            return result
    return null
