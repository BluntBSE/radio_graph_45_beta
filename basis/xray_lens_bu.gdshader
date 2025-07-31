shader_type spatial;

// Make the material transparent and unshaded
render_mode blend_mix, depth_draw_never, unshaded;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_linear_mipmap;
uniform float camera_near : hint_range(0.01, 10.0) = 0.1;
uniform float camera_far : hint_range(1.0, 1000.0) = 100.0;
varying vec2 screen_uv;

void vertex() {
    // Calculate screen position in vertex shader
    vec4 screen_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    screen_uv = (screen_pos.xy / screen_pos.w) * 0.5 + 0.5;
}

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, screen_uv);
    vec3 inverted_color = vec3(1.0) - screen_color.rgb;
    float depth_color = texture(DEPTH_TEXTURE, screen_uv).r;
    
    // Convert non-linear depth to linear depth
    float linear_depth = (2.0 * camera_near) / (camera_far + camera_near - depth_color * (camera_far - camera_near));
    
    // Normalize linear depth to 0-1 range
    float normalized_linear_depth = linear_depth / camera_far;
    
    // Start with the original scene colors
    ALBEDO = screen_color.rgb;
    
    // Add red tint based on distance (far objects get more red)
    ALBEDO.r += (1.0 - normalized_linear_depth);
    
    ALPHA = 1.0;
}