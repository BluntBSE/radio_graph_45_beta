shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;

uniform sampler3D volume_texture: filter_linear;
uniform vec3 volume_min = vec3(-10.0, -10.0, -10.0);
uniform vec3 volume_max = vec3(10.0, 10.0, 10.0);
uniform int max_steps = 50;
uniform float step_size = 0.4;

varying vec2 screen_uv;
varying vec3 world_position;
varying vec3 camera_position;

void vertex() {
    vec4 screen_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    screen_uv = (screen_pos.xy / screen_pos.w) * 0.5 + 0.5;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    camera_position = CAMERA_POSITION_WORLD;
}

vec3 world_to_texture_coords(vec3 world_pos) {
    return (world_pos - volume_min) / (volume_max - volume_min);
}

float sample_voxel_density(vec3 world_pos) {
    vec3 tex_coords = world_to_texture_coords(world_pos);

    if (any(lessThan(tex_coords, vec3(0.0))) || any(greaterThan(tex_coords, vec3(1.0)))) {
        return 0.0;
    }

    return texture(volume_texture, tex_coords).r;
}

void fragment() {
    vec3 ray_dir = normalize(world_position - camera_position);
    vec3 ray_pos = camera_position;

    // DEBUG: Show camera position relative to volume
    vec3 cam_tex_coords = world_to_texture_coords(camera_position);

    if (screen_uv.x < 0.1 && screen_uv.y < 0.1) {
        // Top-left corner: show camera position info
        if (any(lessThan(cam_tex_coords, vec3(0.0))) || any(greaterThan(cam_tex_coords, vec3(1.0)))) {
            ALBEDO = vec3(1.0, 0.0, 0.0); // Red: camera outside volume
        } else {
            ALBEDO = vec3(0.0, 1.0, 0.0); // Green: camera inside volume
        }
        ALPHA = 1.0;
    }

    // Try to find ANY density along the ray
    float max_density_found = 0.0;
    int steps_with_density = 0;

    for (int i = 0; i < max_steps; i++) {
        float density = sample_voxel_density(ray_pos);

        if (density > 0.0) {
            max_density_found = max(max_density_found, density);
            steps_with_density++;
        }

        ray_pos += ray_dir * step_size;
    }

    // Show results
    if (steps_with_density > 0) {
        // Found density! Show it as blue intensity
        ALBEDO = vec3(0.0, 0.0, max_density_found);
    } else {
        // No density found - show as white
        ALBEDO = vec3(1.0, 1.0, 1.0);
    }

    ALPHA = 1.0;
}