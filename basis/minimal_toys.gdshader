shader_type spatial;

// Make the material transparent and unshaded
render_mode depth_test_disabled, depth_draw_opaque, blend_premul_alpha, unshaded;

uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
varying vec2 screen_uv;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    // Pass screen coordinates to fragment shader
    screen_uv = (PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0))).xy;
    screen_uv = (screen_uv + 1.0) * 0.5;
    world_position = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    // Get the current screen UV
    vec2 uv = screen_uv;
    
    // Sample depth buffer
    float depth_center = texture(DEPTH_TEXTURE, uv).r;
    
    // Sample surrounding depths for edge detection
    vec2 texel_size = 1.0 / VIEWPORT_SIZE;

    
    vec4 base_color = texture(SCREEN_TEXTURE, uv);
    

    
    
    ALBEDO = base_color.rgb;
    ALPHA = 1.0; // Slight transparency to blend with scene
}
