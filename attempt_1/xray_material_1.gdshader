shader_type spatial;

// Make the material transparent and unshaded
render_mode blend_mix, depth_draw_opaque, unshaded;

uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest;
varying vec2 screen_uv;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {

}

void fragment() {
    // Use world-space distance instead
    float distance_to_camera = length(CAMERA_POSITION_WORLD - VERTEX);
    float normalized_distance = distance_to_camera / 1.0; // Adjust divisor as needed
    ALBEDO = vec3(normalized_distance, 0.0, 0.0);
}