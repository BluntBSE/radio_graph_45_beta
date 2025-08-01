shader_type canvas_item;

// Camera uniforms - we'll pass these from GDScript
uniform mat4 camera_transform;
uniform mat4 camera_projection;
uniform vec2 screen_size;

// Volume rendering uniforms
uniform sampler3D volume_texture : filter_linear;
uniform float density_multiplier : hint_range(0.1, 20.0) = 0.5;  // Higher default
uniform int max_steps : hint_range(16, 512) = 128;
uniform float step_size : hint_range(0.005, 0.5) = 0.05;  // Bigger steps = more accumulation
uniform float brightness : hint_range(0.1, 10.0) = 0.5;  // Much brighter default
uniform bool debug_sphere = true;

varying vec2 screen_uv;

void vertex() {
    screen_uv = UV;
}

// Debug SDF sphere
float sphere_sdf(vec3 point, vec3 center, float radius) {
    return length(point - center) - radius;
}

float sample_volume(vec3 pos) {
    if (debug_sphere) {
        // First sphere at origin
        float sphere1_distance = sphere_sdf(pos, vec3(0.0, 0.0, 0.0), 2.0);

        // Second sphere offset to create partial overlap
        float sphere2_distance = sphere_sdf(pos, vec3(1.5, 0.0, 0.0), 2.0);

        float density = 0.0;

        // Additive density - each sphere contributes independently
        if (sphere1_distance < 0.0) {
            density += 1.0; // First sphere contributes density
        }

        if (sphere2_distance < 0.0) {
            density += 1.0; // Second sphere contributes density
        }

        // In overlap region, density will be 2.0 (brighter)
        // In single sphere regions, density will be 1.0 (normal)
        // Outside both spheres, density will be 0.0 (dark)
        return density;
    }    // Convert from local space [-1,1] to texture space [0,1]
    vec3 tex_coord = pos * 0.5 + 0.5;

    // Ensure position is in [0,1] range
    if (any(lessThan(tex_coord, vec3(0.0))) || any(greaterThan(tex_coord, vec3(1.0)))) {
        return 0.0;
    }

    return texture(volume_texture, tex_coord).r;
}

bool ray_box_intersection(vec3 ray_origin, vec3 ray_dir, out float t_near, out float t_far) {
    // Box bounds in local space
    vec3 box_min = vec3(-1.0);
    vec3 box_max = vec3(1.0);

    vec3 inv_dir = 1.0 / ray_dir;
    vec3 t1 = (box_min - ray_origin) * inv_dir;
    vec3 t2 = (box_max - ray_origin) * inv_dir;

    vec3 t_min = min(t1, t2);
    vec3 t_max = max(t1, t2);

    t_near = max(max(t_min.x, t_min.y), t_min.z);
    t_far = min(min(t_max.x, t_max.y), t_max.z);

    return t_far > 0.0 && t_near < t_far;
}

vec3 ray_march(vec3 ray_origin, vec3 ray_direction) {
    float accumulated_density = 0.0;
    vec3 current_pos = ray_origin;
    float total_distance = 0.0;
    float step_size_world = step_size; // Use step size directly in world space

    // March for a reasonable distance - your reference used 30.0
    for (int i = 0; i < max_steps; i++) {
        if (total_distance > 30.0) break;

        // Sample the volume at current position
        float density = sample_volume(current_pos);

        if (density > 0.0) {
            // Accumulate density like your reference shader
            accumulated_density += density * step_size_world;
        }

        // Step along the ray
        current_pos += ray_direction * step_size_world;
        total_distance += step_size_world;
    }

    // Convert to intensity - matching your reference approach
    float intensity = accumulated_density * density_multiplier * brightness;
    return vec3(intensity);
}void fragment() {
    // Convert screen UV to normalized device coordinates
    vec2 ndc = (screen_uv * 2.0) - 1.0;

    // Get the inverse projection matrix to properly calculate ray direction
    mat4 inv_projection = inverse(camera_projection);

    // Transform NDC to view space - using the same method as your reference shader
    vec4 view_pos = inv_projection * vec4(ndc, -1.0, 1.0);
    view_pos /= view_pos.w;

    // Calculate ray direction in world space - normalize first, then transform
    vec3 ray_direction = normalize((camera_transform * vec4(normalize(view_pos.xyz), 0.0)).xyz);
    vec3 ray_origin = camera_transform[3].xyz; // Camera position from transform matrix

    // Transform ray to local space (volume is centered at origin, size 2x2x2)
    // Your reference shader worked in world space, but we need local space
    vec3 local_ray_origin = ray_origin;
    vec3 local_ray_direction = ray_direction;

    vec3 color = ray_march(local_ray_origin, local_ray_direction);
    COLOR = vec4(color, 1.0);
}
