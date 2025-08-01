shader_type canvas_item;

// Camera uniforms - we'll pass these from GDScript
uniform mat4 camera_transform;
uniform mat4 camera_projection;
uniform vec2 screen_size;

// Volume rendering uniforms
uniform sampler3D volume_texture : filter_nearest;
//uniform float density_multiplier : hint_range(0.1, 20.0) = 0.5;  // Higher default
uniform int max_steps : hint_range(16, 512) = 10000;
uniform float step_size : hint_range(0.005, 0.5) = 0.0078;
uniform float brightness : hint_range(0.1, 10.0) = 0.5;
uniform float absorption_coefficient : hint_range(0.1, 10.0) = 0.5;  // Beer's law absorption
uniform bool use_beers_law = false;
uniform bool debug_sphere = false;
uniform bool debug_texture_values = false;

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
        float sphere2_distance = sphere_sdf(pos, vec3(6.0, 0.0, 0.0), 2.0);

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
    }

    // Simple mapping: assume world space roughly [-2,+2] maps to texture [0,1]
    vec3 tex_coord = (pos + 2.0) / 4.0;

    // Clamp to texture bounds - looks wild if you delete this lol
    if (any(lessThan(tex_coord, vec3(0.0))) || any(greaterThan(tex_coord, vec3(1.0)))) {
        return 0.0;
    }

    return texture(volume_texture, tex_coord).r;
}



vec3 ray_march(vec3 ray_origin, vec3 ray_direction) {
    float accumulated_density = 0.0;
    float transmittance = 1.0;  // Start with full transmittance (no absorption yet)
    vec3 current_pos = ray_origin;
    float total_distance = 0.0;
    float step_size_world = step_size;

    // Volume rendering loop - conditionally apply Beer's law
    for (int i = 0; i < max_steps; i++) {
        if (total_distance > 30.0) break;

        // Sample the volume at current position
        float density = sample_volume(current_pos);

        if (density > 0.0) {
            if (use_beers_law) {
                // Beer's law: Calculate absorption for this step
                float absorption = density * absorption_coefficient * step_size_world;

                // Add light contribution weighted by current transmittance
                // This simulates light scattering towards the camera
                accumulated_density += density * step_size_world * transmittance;

                // Update transmittance using Beer's law: T = exp(-absorption)
                transmittance *= exp(-absorption);

                // Early termination if transmittance becomes negligible
                if (transmittance < 0.01) break;
            } else {
                // Simple accumulation without Beer's law absorption
                accumulated_density += density * step_size_world;
            }
        }

        // Step along the ray
        current_pos += ray_direction * step_size_world;
        total_distance += step_size_world;
    }

    // Convert to intensity
    float intensity = accumulated_density  * brightness;
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
