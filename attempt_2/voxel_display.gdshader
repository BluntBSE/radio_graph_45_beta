shader_type canvas_item;

uniform sampler3D volume_texture: filter_linear;
uniform vec3 volume_min = vec3(-10.0, -10.0, -10.0);
uniform vec3 volume_max = vec3(10.0, 10.0, 10.0);
uniform vec3 camera_position;
uniform mat4 camera_transform;
uniform mat4 camera_projection;
uniform int max_steps = 100;
uniform float step_size = 0.2;

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
    // Convert screen UV to normalized device coordinates
    vec2 ndc = (UV * 2.0) - 1.0;

    // Calculate ray direction from camera through this pixel
    vec4 ray_clip = vec4(ndc, -1.0, 1.0);
    vec4 ray_eye = inverse(camera_projection) * ray_clip;
    ray_eye = vec4(ray_eye.xy, -1.0, 0.0);
    vec3 ray_world = (inverse(camera_transform) * ray_eye).xyz;
    vec3 ray_dir = normalize(ray_world);

    // Start raymarching from camera
    vec3 ray_pos = camera_position;
    float total_density = 0.0;

    for (int i = 0; i < max_steps; i++) {
        float density = sample_voxel_density(ray_pos);

        if (density > 0.0) {
            total_density += density * step_size;
        }

        ray_pos += ray_dir * step_size;

        // Stop if outside volume bounds
        vec3 tex_coords = world_to_texture_coords(ray_pos);
        if (any(greaterThan(tex_coords, vec3(1.1))) || any(lessThan(tex_coords, vec3(-0.1)))) {
            break;
        }
    }

    // Convert to brightness
    if (total_density > 0.0) {
        float brightness = 1.0 - exp(-total_density * 3.0);
        COLOR = vec4(vec3(brightness), 1.0);
    } else {
        // Show red tint to debug - if you see red, no voxel data is being found
        COLOR = vec4(0.1, 0.0, 0.0, 1.0); // Dark red background for debugging
    }
}