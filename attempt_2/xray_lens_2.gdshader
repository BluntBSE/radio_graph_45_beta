shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform sampler3D volume_texture: filter_linear;
uniform vec3 volume_min = vec3(-10.0, -10.0, -10.0);
uniform vec3 volume_max = vec3(10.0, 10.0, 10.0);
uniform int max_steps = 64;
uniform float max_distance = 100.0;
uniform float step_size = 0.1;

varying vec2 screen_uv;
varying vec3 world_position;
varying vec3 camera_position;

void vertex() {
    vec4 screen_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    screen_uv = (screen_pos.xy / screen_pos.w) * 0.5 + 0.5;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    camera_position = CAMERA_POSITION_WORLD;
}

// Convert world position to normalized texture coordinates (0-1)
vec3 world_to_texture_coords(vec3 world_pos) {
    return (world_pos - volume_min) / (volume_max - volume_min);
}

// Sample voxel density at world position
float sample_voxel_density(vec3 world_pos) {
    vec3 tex_coords = world_to_texture_coords(world_pos);

    // Check if we're outside the volume bounds
    if (any(lessThan(tex_coords, vec3(0.0))) || any(greaterThan(tex_coords, vec3(1.0)))) {
        return 0.0;
    }

    // Sample the 3D texture (R8 format, so density is in the red channel)
    return texture(volume_texture, tex_coords).r;
}

void fragment() {
    // Calculate ray direction from camera through this pixel on the quad
    vec3 ray_dir = normalize(world_position - camera_position);
    vec3 ray_pos = camera_position;

    float total_density = 0.0;
    bool hit_something = false;

    // Raymarching loop
    for (int i = 0; i < max_steps; i++) {
        // Sample voxel density at current ray position
        float density = sample_voxel_density(ray_pos);

        // If there's material at this position, accumulate density
        if (density > 0.0) {
            total_density += density * step_size;
            hit_something = true;
        }

        // Move ray forward
        ray_pos += ray_dir * step_size;

        // Stop if we've traveled too far
        if (length(ray_pos - camera_position) > max_distance) {
            break;
        }
    }

    // Visualization: white = no material, darker = more material
    if (hit_something) {
        float absorption = total_density * 0.8; // Adjust for darkness level
        //float brightness = exp(-absorption);
        float brightness = absorption;
        ALBEDO = vec3(brightness, brightness, brightness);
    } else {
        ALBEDO = vec3(1.0, 1.0, 1.0); // White background
    }

    ALPHA = 1.0;
}