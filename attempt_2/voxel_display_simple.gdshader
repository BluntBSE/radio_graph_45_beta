shader_type canvas_item;

uniform sampler3D volume_texture : hint_default_white;
uniform vec3 camera_position = vec3(0.0, 0.0, 5.0);
uniform vec3 volume_min = vec3(-10.0, -10.0, -10.0);
uniform vec3 volume_max = vec3(10.0, 10.0, 10.0);

vec3 world_to_texture_coords(vec3 world_pos) {
    return (world_pos - volume_min) / (volume_max - volume_min);
}

void fragment() {
    // Test 2: Sample the volume texture at camera position
    vec3 tex_coords = world_to_texture_coords(camera_position);
    float density = texture(volume_texture, tex_coords).r;
    
    // Show density as brightness, but keep some UV gradient for reference
    COLOR = vec4(UV.x * 0.3, UV.y * 0.3, density, 1.0);
    
    // If you see blue areas, the volume texture has data
    // Red/green areas show the UV is still working
}
