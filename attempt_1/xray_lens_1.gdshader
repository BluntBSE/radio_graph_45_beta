shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform sampler3D volume_texture: filter_linear;
uniform vec3 volume_min = vec3(0, 0, 0);
uniform vec3 volume_max = vec3(1, 1, 1);

varying vec2 screen_uv;
varying vec3 world_position;
varying vec3 camera_position;

void vertex() {
    vec4 screen_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
    screen_uv = (screen_pos.xy / screen_pos.w) * 0.5 + 0.5;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    camera_position = CAMERA_POSITION_WORLD;
}

void fragment() {
    // Raymarching from camera through lens
    vec3 ray_dir = normalize(world_position - camera_position);
    float total_density = 0.0;
    
    // Calculate proper step size based on volume bounds
    float max_distance = length(volume_max - volume_min);
    float step_size = max_distance / 32.0; // 32 steps through the entire volume
    
    // March through space in world coordinates
    for (int i = 0; i < 32; i++) {
        vec3 sample_pos = camera_position + ray_dir * float(i) * step_size;
        
        // Convert world position to volume texture coordinates (0-1)
        vec3 tex_coords = (sample_pos - volume_min) / (volume_max - volume_min);
        
        // Skip if outside volume bounds
        if (any(lessThan(tex_coords, vec3(0.0))) || any(greaterThan(tex_coords, vec3(1.0)))) {
            continue;
        }
        
        // Sample volume and accumulate density
        float density = texture(volume_texture, tex_coords).r;
        total_density += density;
    }
    
    // Pure absorption visualization
    float absorption = total_density * 0.1; // Adjust this to control absorption strength
    float brightness = exp(-absorption); // More density = darker
    
    // Show only absorption: white = no material, black = dense material
    ALBEDO = vec3(brightness, brightness, brightness);
    ALPHA = 1.0;
}