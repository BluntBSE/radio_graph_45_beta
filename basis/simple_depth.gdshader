shader_type spatial;

// Make the material transparent and unshaded
render_mode blend_mix, depth_draw_opaque, unshaded;
uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_linear_mipmap;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;

varying vec2 screen_uv;

void vertex() {
    // Calculate screen position in vertex shader
    vec4 screen_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    screen_uv = (screen_pos.xy / screen_pos.w) * 0.5 + 0.5;
}

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, screen_uv);
    float depth = texture(DEPTH_TEXTURE, screen_uv).r;
    //vec3 inverted_color = vec3(1.0) - screen_color.rgb;

    ALBEDO = vec3(depth, depth, depth);
    ALPHA = 1.0;
}