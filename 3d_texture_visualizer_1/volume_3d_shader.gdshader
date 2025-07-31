shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, depth_test_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler3D volume_texture : filter_linear;
uniform float density_multiplier : hint_range(0.1, 5.0) = 1.0;
uniform int max_steps : hint_range(16, 512) = 128;
uniform float step_size : hint_range(0.005, 0.1) = 0.01;
uniform float absorption_coefficient : hint_range(0.1, 10.0) = 2.0;
uniform float brightness : hint_range(0.1, 3.0) = 1.0;

// Volume bounds in local space (-1 to 1)
varying vec3 world_position;
varying vec3 local_position;

void vertex() {
    world_position = VERTEX;
    local_position = VERTEX;
    POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

vec3 get_ray_direction(vec3 camera_pos, vec3 world_pos) {
    return normalize(world_pos - camera_pos);
}

float sample_volume(vec3 pos) {
    // Convert from local space [-1,1] to texture space [0,1]
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

void fragment() {
    // Get camera position in world space
    vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
    
    // Transform camera position to local space
    vec3 local_camera_pos = (inverse(MODEL_MATRIX) * vec4(camera_pos, 1.0)).xyz;
    
    // Ray direction from camera to current fragment
    vec3 ray_dir = normalize(local_position - local_camera_pos);
    
    // Find intersection with volume bounds
    float t_near, t_far;
    if (!ray_box_intersection(local_camera_pos, ray_dir, t_near, t_far)) {
        discard;
    }
    
    // Start ray marching from entry point
    float t_start = max(t_near, 0.0);
    vec3 ray_start = local_camera_pos + ray_dir * t_start;
    
    // Ray marching
    float accumulated_density = 0.0;
    float accumulated_transparency = 1.0;
    vec3 current_pos = ray_start;
    float t = t_start;
    
    for (int i = 0; i < max_steps; i++) {
        if (t > t_far) break;
        
        // Sample the volume
        float density = sample_volume(current_pos);
        
        if (density > 0.0) {
            // Accumulate density and transparency
            float absorption = density * absorption_coefficient * step_size;
            accumulated_transparency *= exp(-absorption);
            accumulated_density += density * step_size;
            
            // Early exit if transparency is very low
            if (accumulated_transparency < 0.01) {
                break;
            }
        }
        
        // Step along the ray
        t += step_size;
        current_pos = local_camera_pos + ray_dir * t;
    }
    
    // Calculate final color based on accumulated density
    float final_intensity = 1.0 - accumulated_transparency;
    final_intensity = clamp(final_intensity * density_multiplier * brightness, 0.0, 1.0);
    
    // Output color - white for the volume, transparent background
    ALBEDO = vec3(final_intensity);
    ALPHA = final_intensity;
}
