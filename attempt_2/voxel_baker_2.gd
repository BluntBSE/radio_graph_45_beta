extends Node3D
class_name VoxelBaker2

# Volume settings
var volume_resolution: int = 128
var volume_min: Vector3 = Vector3(-10, -10, -10)
var volume_max: Vector3 = Vector3(10, 10, 10)
var volume_texture: ImageTexture3D
var volume_data: PackedByteArray  # Make this a class variable for debug access

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
        print("Object '", obj.name, "' rotation: ", obj.rotation_degrees)
        print("Object '", obj.name, "' scale: ", obj.scale)
        if obj.mesh:
            print("Object '", obj.name, "' mesh type: ", obj.mesh.get_class())
    print("Volume bounds: ", volume_min, " to ", volume_max)
    
    # Create volume data
    volume_data = PackedByteArray()  # Use the class variable
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
    
    # Auto-save debug slices
    save_debug_slices()

func save_debug_slices():
    print("Saving debug slices of volume data...")
    
    # Save Z slices (looking down from above)
    var z_slice_indices = [32, 48, 64, 80, 96]
    for z_slice in z_slice_indices:
        var slice_data = PackedByteArray()
        
        for y in range(volume_resolution):
            for x in range(volume_resolution):
                var index = x + y * volume_resolution + z_slice * volume_resolution * volume_resolution
                if index < volume_data.size():
                    var density = volume_data[index]
                    slice_data.append(density)  # R
                    slice_data.append(density)  # G  
                    slice_data.append(density)  # B
                else:
                    slice_data.append(0)
                    slice_data.append(0)
                    slice_data.append(0)
        
        var slice_image = Image.create_from_data(volume_resolution, volume_resolution, false, Image.FORMAT_RGB8, slice_data)
        var filename = "res://volume_slice_Z" + str(z_slice) + ".png"
        slice_image.save_png(filename)
        print("Saved Z-slice ", z_slice, " to ", filename)
    
    # Save Y slices (side view, looking along Y axis)
    var y_slice_indices = [32, 48, 64, 80, 96]
    for y_slice in y_slice_indices:
        var slice_data = PackedByteArray()
        
        for z in range(volume_resolution):
            for x in range(volume_resolution):
                var index = x + y_slice * volume_resolution + z * volume_resolution * volume_resolution
                if index < volume_data.size():
                    var density = volume_data[index]
                    slice_data.append(density)  # R
                    slice_data.append(density)  # G  
                    slice_data.append(density)  # B
                else:
                    slice_data.append(0)
                    slice_data.append(0)
                    slice_data.append(0)
        
        var slice_image = Image.create_from_data(volume_resolution, volume_resolution, false, Image.FORMAT_RGB8, slice_data)
        var filename = "res://volume_slice_Y" + str(y_slice) + ".png"
        slice_image.save_png(filename)
        print("Saved Y-slice ", y_slice, " to ", filename)
    
    print("Debug slices saved! Z-slices = top view, Y-slices = side view")
func point_inside_mesh(mesh_instance: MeshInstance3D, world_point: Vector3) -> bool:
    var space_state = get_world_3d().direct_space_state
    if space_state == null:
        print("DEBUG: No physics space available")
        return false
    
    # Cast ray from high above straight down - simple and universal approach
    var ray_start = Vector3(world_point.x, volume_max.y + 5.0, world_point.z)  # Start above
    var ray_end = Vector3(world_point.x, volume_min.y - 5.0, world_point.z)    # End below
    
    var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
    query.collide_with_areas = false
    
    var result = space_state.intersect_ray(query)
    
    # Debug for center point
    if world_point.distance_to(Vector3.ZERO) < 0.5:
        print("DEBUG: Vertical ray from ", ray_start, " to ", ray_end)
        print("DEBUG: Test point at: ", world_point)
        if result and not result.is_empty():
            print("DEBUG: Ray hit at ", result.position, " collider: ", result.collider.name if result.collider else "none")
        else:
            print("DEBUG: Ray missed - no collision")
    
    # If we hit something, check if our test point is below the hit
    if result and not result.is_empty():
        var collider = result.collider
        # Check if this hit belongs to one of our mesh objects
        if collider and collider.get_parent() and collider.get_parent().get_parent() == self:
            # If the hit is above our test point, we're inside
            if result.position.y > world_point.y:
                if world_point.distance_to(Vector3.ZERO) < 0.5:
                    print("DEBUG: SUCCESS - Hit at Y=", result.position.y, " test point at Y=", world_point.y, " -> INSIDE!")
                return true
    
    if world_point.distance_to(Vector3.ZERO) < 0.5:
        print("DEBUG: Point is outside mesh")
    return false
