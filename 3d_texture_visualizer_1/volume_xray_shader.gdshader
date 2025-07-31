shader_type canvas_item;

uniform sampler3D volume_texture : filter_linear;
uniform float slice_depth : hint_range(0.0, 1.0) = 0.5;
uniform float density_multiplier : hint_range(0.1, 5.0) = 1.0;
uniform int max_steps : hint_range(8, 256) = 128;
uniform float step_size : hint_range(0.001, 0.1) = 0.01;

// X-ray style rendering parameters
uniform float absorption_coefficient : hint_range(0.1, 10.0) = 2.0;
uniform vec3 light_direction : hint_range(-1.0, 1.0) = vec3(0.0, 0.0, 1.0);
uniform float ambient_intensity : hint_range(0.0, 1.0) = 0.2;

vec3 get_ray_direction(vec2 uv) {
    // Convert UV to NDC
    vec2 ndc = uv * 2.0 - 1.0;
    
    // Simple orthographic projection for now
    return normalize(vec3(0.0, 0.0, -1.0));
}

vec3 get_ray_origin(vec2 uv) {
    // Convert UV to world space
    vec2 ndc = uv * 2.0 - 1.0;
    return vec3(ndc.x, ndc.y, 1.0);
}

float sample_volume(vec3 pos) {
    // Ensure position is in [0,1] range
    if (any(lessThan(pos, vec3(0.0))) || any(greaterThan(pos, vec3(1.0)))) {
        return 0.0;
    }
    
    return texture(volume_texture, pos).r;
}

void fragment() {
    vec2 uv = UV;
    
    // Ray setup
    vec3 ray_origin = get_ray_origin(uv);
    vec3 ray_dir = get_ray_direction(uv);
    
    // Transform ray to texture space [0,1]
    ray_origin = ray_origin * 0.5 + 0.5;
    
    // Ray marching
    float accumulated_density = 0.0;
    float accumulated_transparency = 1.0;
    vec3 current_pos = ray_origin;
    
    for (int i = 0; i < max_steps; i++) {
        // Sample the volume
        float density = sample_volume(current_pos);
        
        if (density > 0.0) {
            // X-ray style absorption
            float absorption = density * absorption_coefficient * step_size;
            accumulated_transparency *= exp(-absorption);
            accumulated_density += density * step_size;
        }
        
        // Step along the ray
        current_pos += ray_dir * step_size;
        
        // Early exit if we've left the volume or transparency is very low
        if (any(lessThan(current_pos, vec3(0.0))) || 
            any(greaterThan(current_pos, vec3(1.0))) ||
            accumulated_transparency < 0.01) {
            break;
        }
    }
    
    // X-ray style output - inverted transparency gives X-ray effect
    float x_ray_intensity = 1.0 - accumulated_transparency;
    x_ray_intensity = clamp(x_ray_intensity * density_multiplier, 0.0, 1.0);
    
    COLOR = vec4(vec3(x_ray_intensity), 1.0);
}
