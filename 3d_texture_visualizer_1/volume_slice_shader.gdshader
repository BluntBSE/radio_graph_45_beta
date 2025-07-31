shader_type canvas_item;

uniform sampler3D volume_texture : filter_linear;
uniform float slice_depth : hint_range(0.0, 1.0) = 0.5;
uniform int slice_axis : hint_range(0, 2) = 2; // 0=X, 1=Y, 2=Z
uniform float brightness : hint_range(0.1, 3.0) = 1.0;
uniform float contrast : hint_range(0.1, 3.0) = 1.0;

void fragment() {
    vec2 uv = UV;
    vec3 sample_pos;
    
    // Select which axis to slice along
    if (slice_axis == 0) {
        // X-axis slice
        sample_pos = vec3(slice_depth, uv.x, uv.y);
    } else if (slice_axis == 1) {
        // Y-axis slice
        sample_pos = vec3(uv.x, slice_depth, uv.y);
    } else {
        // Z-axis slice (default)
        sample_pos = vec3(uv.x, uv.y, slice_depth);
    }
    
    // Sample the 3D texture
    float density = texture(volume_texture, sample_pos).r;
    
    // Apply brightness and contrast
    density = (density - 0.5) * contrast + 0.5;
    density *= brightness;
    density = clamp(density, 0.0, 1.0);
    
    COLOR = vec4(vec3(density), 1.0);
}
