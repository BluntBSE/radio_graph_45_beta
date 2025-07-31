extends Node

# Script to generate a high-resolution 3D texture with a six-pointed cross pattern
# This creates a cross in the XY plane and another cross in the XZ plane,
# forming a six-pointed cross structure in 3D space

# Texture resolution - using 256x256x256 for high quality
const TEXTURE_SIZE = 256

# Cross parameters
const CROSS_THICKNESS = 16  # Thickness of each cross arm
const CROSS_LENGTH_RATIO = 0.8  # How much of the texture the cross spans (0.0 to 1.0)

func _ready():
    generate_and_save_texture3d()

func generate_and_save_texture3d():
    print("Starting 3D texture generation...")
    
    # Create the 3D texture data array
    var texture_data = PackedByteArray()
    texture_data.resize(TEXTURE_SIZE * TEXTURE_SIZE * TEXTURE_SIZE * 4)  # RGBA format
    
    var cross_half_length = int(TEXTURE_SIZE * CROSS_LENGTH_RATIO * 0.5)
    var cross_half_thickness = CROSS_THICKNESS / 2
    var center = TEXTURE_SIZE / 2
    
    print("Generating texture data...")
    
    # Fill the texture data
    for z in range(TEXTURE_SIZE):
        for y in range(TEXTURE_SIZE):
            for x in range(TEXTURE_SIZE):
                var index = (z * TEXTURE_SIZE * TEXTURE_SIZE + y * TEXTURE_SIZE + x) * 4
                
                var is_cross_pixel = false
                var intensity = 0.0
                
                # Check if pixel is part of the cross in XY plane (extending through Z)
                var xy_cross = is_in_xy_cross(x, y, center, cross_half_length, cross_half_thickness)
                
                # Check if pixel is part of the cross in XZ plane (extending through Y)
                var xz_cross = is_in_xz_cross(x, z, center, cross_half_length, cross_half_thickness)
                
                if xy_cross or xz_cross:
                    is_cross_pixel = true
                    
                    # Calculate distance-based intensity for smooth edges
                    var xy_distance = get_cross_distance_xy(x, y, center, cross_half_length, cross_half_thickness)
                    var xz_distance = get_cross_distance_xz(x, z, center, cross_half_length, cross_half_thickness)
                    
                    # Use the minimum distance for intensity calculation
                    var min_distance = min(xy_distance, xz_distance) if (xy_cross and xz_cross) else (xy_distance if xy_cross else xz_distance)
                    intensity = 1.0 - clamp(min_distance / (cross_half_thickness * 0.5), 0.0, 1.0)
                    intensity = smoothstep(0.0, 1.0, intensity)
                
                if is_cross_pixel:
                    # White/bright pixels for the cross
                    texture_data[index] = int(255 * intensity)      # R
                    texture_data[index + 1] = int(255 * intensity)  # G
                    texture_data[index + 2] = int(255 * intensity)  # B
                    texture_data[index + 3] = int(255 * intensity)  # A
                else:
                    # Transparent/dark pixels for empty space
                    texture_data[index] = 0      # R
                    texture_data[index + 1] = 0  # G
                    texture_data[index + 2] = 0  # B
                    texture_data[index + 3] = 0  # A
        
        # Progress indicator
        if z % 32 == 0:
            print("Progress: ", int(float(z) / TEXTURE_SIZE * 100), "%")
    
    print("Creating ImageTexture3D...")
    
    # Create the 3D texture
    var image_texture_3d = ImageTexture3D.new()
    
    # Create images for each Z slice
    var images = []
    for z in range(TEXTURE_SIZE):
        var image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
        
        # Extract slice data
        var slice_data = PackedByteArray()
        slice_data.resize(TEXTURE_SIZE * TEXTURE_SIZE * 4)
        
        for y in range(TEXTURE_SIZE):
            for x in range(TEXTURE_SIZE):
                var src_index = (z * TEXTURE_SIZE * TEXTURE_SIZE + y * TEXTURE_SIZE + x) * 4
                var dst_index = (y * TEXTURE_SIZE + x) * 4
                
                slice_data[dst_index] = texture_data[src_index]
                slice_data[dst_index + 1] = texture_data[src_index + 1]
                slice_data[dst_index + 2] = texture_data[src_index + 2]
                slice_data[dst_index + 3] = texture_data[src_index + 3]
        
        image.set_data(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8, slice_data)
        images.append(image)
    
    # Create the 3D texture from images
    image_texture_3d.create(Image.FORMAT_RGBA8, TEXTURE_SIZE, TEXTURE_SIZE, TEXTURE_SIZE, false, images)
    
    print("Saving 3D texture...")
    
    # Save the texture as a resource
    var save_path = "res://3d_texture_visualizer_1/six_pointed_cross_texture3d.tres"
    var result = ResourceSaver.save(image_texture_3d, save_path)
    
    if result == OK:
        print("3D texture saved successfully to: ", save_path)
        print("Texture size: ", TEXTURE_SIZE, "x", TEXTURE_SIZE, "x", TEXTURE_SIZE)
        print("Cross thickness: ", CROSS_THICKNESS, " pixels")
        print("Cross length ratio: ", CROSS_LENGTH_RATIO * 100, "%")
    else:
        print("Error saving 3D texture: ", result)

func is_in_xy_cross(x: int, y: int, center: int, half_length: int, half_thickness: int) -> bool:
    # Horizontal bar of cross (extends in X direction)
    var horizontal = (abs(y - center) <= half_thickness and abs(x - center) <= half_length)
    
    # Vertical bar of cross (extends in Y direction)
    var vertical = (abs(x - center) <= half_thickness and abs(y - center) <= half_length)
    
    return horizontal or vertical

func is_in_xz_cross(x: int, z: int, center: int, half_length: int, half_thickness: int) -> bool:
    # Horizontal bar of cross in XZ plane (extends in X direction)
    var horizontal = (abs(z - center) <= half_thickness and abs(x - center) <= half_length)
    
    # Vertical bar of cross in XZ plane (extends in Z direction)
    var vertical = (abs(x - center) <= half_thickness and abs(z - center) <= half_length)
    
    return horizontal or vertical

func get_cross_distance_xy(x: int, y: int, center: int, half_length: int, half_thickness: int) -> float:
    # Distance to the XY cross
    var dx = abs(x - center)
    var dy = abs(y - center)
    
    # Distance to horizontal bar
    var dist_horizontal = dy if dx <= half_length else sqrt((dx - half_length) * (dx - half_length) + dy * dy)
    
    # Distance to vertical bar
    var dist_vertical = dx if dy <= half_length else sqrt(dx * dx + (dy - half_length) * (dy - half_length))
    
    return min(dist_horizontal, dist_vertical)

func get_cross_distance_xz(x: int, z: int, center: int, half_length: int, half_thickness: int) -> float:
    # Distance to the XZ cross
    var dx = abs(x - center)
    var dz = abs(z - center)
    
    # Distance to horizontal bar
    var dist_horizontal = dz if dx <= half_length else sqrt((dx - half_length) * (dx - half_length) + dz * dz)
    
    # Distance to vertical bar
    var dist_vertical = dx if dz <= half_length else sqrt(dx * dx + (dz - half_length) * (dz - half_length))
    
    return min(dist_horizontal, dist_vertical)
