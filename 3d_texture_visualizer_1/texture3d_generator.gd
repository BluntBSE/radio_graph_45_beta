extends Node

# Configurable 3D texture generator for debugging volume rendering
# Supports multiple shape types for testing different scenarios

# Texture resolution - using 256x256x256 for high quality
const TEXTURE_SIZE = 256

# Shape selection
@export var shape_type: String = "six_pointed_cross"  # "six_pointed_cross", "thick_rectangles", "graduated_sphere"

# Cross parameters (for six_pointed_cross)
const CROSS_THICKNESS = 16  # Thickness of each cross arm
const CROSS_LENGTH_RATIO = 0.8  # How much of the texture the cross spans (0.0 to 1.0)

# Rectangle parameters (for thick_rectangles)
const RECT_THICKNESS = 32  # Much thicker than cross for easier debugging
const RECT_LENGTH_RATIO = 0.7

# Sphere parameters (for graduated_sphere)
const SPHERE_RADIUS_RATIO = 0.4  # Sphere radius as ratio of texture size

func _ready():
    generate_and_save_texture3d()

func generate_and_save_texture3d():
    print("Starting 3D texture generation...")
    print("Shape type: ", shape_type)
    
    # Create the 3D texture data array
    var texture_data = PackedByteArray()
    texture_data.resize(TEXTURE_SIZE * TEXTURE_SIZE * TEXTURE_SIZE * 4)  # RGBA format
    
    var center = TEXTURE_SIZE / 2
    
    print("Generating texture data...")
    
    # Fill the texture data based on shape type
    for z in range(TEXTURE_SIZE):
        for y in range(TEXTURE_SIZE):
            for x in range(TEXTURE_SIZE):
                var index = (z * TEXTURE_SIZE * TEXTURE_SIZE + y * TEXTURE_SIZE + x) * 4
                
                var intensity = 0.0
                
                match shape_type:
                    "six_pointed_cross":
                        intensity = generate_six_pointed_cross(x, y, z, center)
                    "thick_rectangles":
                        intensity = generate_thick_rectangles(x, y, z, center)
                    "graduated_sphere":
                        intensity = generate_graduated_sphere(x, y, z, center)
                    _:
                        print("Unknown shape type: ", shape_type, " - using six_pointed_cross")
                        intensity = generate_six_pointed_cross(x, y, z, center)
                
                # Apply intensity to RGBA
                texture_data[index] = int(255 * intensity)      # R
                texture_data[index + 1] = int(255 * intensity)  # G
                texture_data[index + 2] = int(255 * intensity)  # B
                texture_data[index + 3] = int(255 * intensity)  # A
        
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
    
    # Save the texture as a resource with shape-specific name
    var save_path = "res://3d_texture_visualizer_1/debug_texture3d_" + shape_type + ".tres"
    var result = ResourceSaver.save(image_texture_3d, save_path)
    
    if result == OK:
        print("3D texture saved successfully to: ", save_path)
        print("Texture size: ", TEXTURE_SIZE, "x", TEXTURE_SIZE, "x", TEXTURE_SIZE)
        print("Shape type: ", shape_type)
    else:
        print("Error saving 3D texture: ", result)

# Shape generation functions

func generate_six_pointed_cross(x: int, y: int, z: int, center: int) -> float:
    var cross_half_length = int(TEXTURE_SIZE * CROSS_LENGTH_RATIO * 0.5)
    var cross_half_thickness = CROSS_THICKNESS / 2
    
    # Check if pixel is part of the cross in XY plane (extending through Z)
    var xy_cross = is_in_xy_cross(x, y, center, cross_half_length, cross_half_thickness)
    
    # Check if pixel is part of the cross in XZ plane (extending through Y)
    var xz_cross = is_in_xz_cross(x, z, center, cross_half_length, cross_half_thickness)
    
    if xy_cross or xz_cross:
        # Calculate distance-based intensity for smooth edges
        var xy_distance = get_cross_distance_xy(x, y, center, cross_half_length, cross_half_thickness)
        var xz_distance = get_cross_distance_xz(x, z, center, cross_half_length, cross_half_thickness)
        
        # Use the minimum distance for intensity calculation
        var min_distance = min(xy_distance, xz_distance) if (xy_cross and xz_cross) else (xy_distance if xy_cross else xz_distance)
        var intensity = 1.0 - clamp(min_distance / (cross_half_thickness * 0.5), 0.0, 1.0)
        return smoothstep(0.0, 1.0, intensity)
    
    return 0.0

func generate_thick_rectangles(x: int, y: int, z: int, center: int) -> float:
    var rect_half_length = int(TEXTURE_SIZE * RECT_LENGTH_RATIO * 0.5)
    var rect_half_thickness = RECT_THICKNESS / 2
    
    # First rectangle in XY plane (extending through Z)
    var xy_rect = (abs(y - center) <= rect_half_thickness and abs(x - center) <= rect_half_length) or \
                  (abs(x - center) <= rect_half_thickness and abs(y - center) <= rect_half_length)
    
    # Second rectangle in XZ plane (extending through Y) 
    var xz_rect = (abs(z - center) <= rect_half_thickness and abs(x - center) <= rect_half_length) or \
                  (abs(x - center) <= rect_half_thickness and abs(z - center) <= rect_half_length)
    
    if xy_rect or xz_rect:
        # Solid density for thick rectangles - no anti-aliasing for clearer debugging
        return 1.0
    
    return 0.0

func generate_graduated_sphere(x: int, y: int, z: int, center: int) -> float:
    var sphere_radius = TEXTURE_SIZE * SPHERE_RADIUS_RATIO
    
    # Calculate distance from center
    var dx = float(x - center)
    var dy = float(y - center) 
    var dz = float(z - center)
    var distance_from_center = sqrt(dx*dx + dy*dy + dz*dz)
    
    if distance_from_center <= sphere_radius:
        # Graduated density - highest at center, fades to edges
        var normalized_distance = distance_from_center / sphere_radius
        return 1.0 - normalized_distance  # Linear falloff
        # Alternative: return 1.0 - (normalized_distance * normalized_distance)  # Quadratic falloff
    
    return 0.0

# Helper functions for six-pointed cross generation
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
