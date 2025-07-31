shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform vec3 sphere_center = vec3(0.0, 0.0, -2.0);
uniform float sphere_radius = 1.0;
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

// SDF for a sphere - returns distance to surface
float sdf_sphere(vec3 pos, vec3 center, float radius) {
    return length(pos - center) - radius;
}

void fragment() {
    // Calculate ray direction from camera through this pixel on the quad
    vec3 ray_dir = normalize(world_position - camera_position);
    vec3 ray_pos = camera_position;

    float total_density = 0.0;
    bool hit_something = false;

    // Raymarching loop
    for (int i = 0; i < max_steps; i++) {
        // ===== REPLACE THIS SECTION WITH VOXEL SAMPLING =====
        // Currently using SDF sphere distance
        float dist = sdf_sphere(ray_pos, sphere_center, sphere_radius);

        // If we're inside the sphere (distance < 0), accumulate density
        if (dist < 0.0) {
            // Convert distance to density (closer to center = higher density)
            float density = 1.0 - (abs(dist) / sphere_radius);
            total_density += density * step_size;
            hit_something = true;
        }
        // ===== END REPLACE SECTION =====

        // Move ray forward
        ray_pos += ray_dir * step_size;

        // Stop if we've traveled too far
        if (length(ray_pos - camera_position) > max_distance) {
            break;
        }
    }

    // Visualization: white = no material, darker = more material
    if (hit_something) {
        float absorption = total_density * 0.95; // Adjust for darkness level
        float brightness = exp(-absorption);
        ALBEDO = vec3(brightness, brightness, brightness);
    } else {
        ALBEDO = vec3(1.0, 1.0, 1.0); // White background
    }

    ALPHA = 1.0;
}