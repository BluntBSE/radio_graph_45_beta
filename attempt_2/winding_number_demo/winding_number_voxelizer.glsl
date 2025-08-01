#[compute]
#version 450

// Workgroup size - process voxels in 8x8x8 chunks
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Output texture3D
layout(set = 0, binding = 0, r8) uniform restrict writeonly image3D voxel_texture;

// Input buffers
layout(set = 0, binding = 1, std430) restrict readonly buffer VertexBuffer {
    vec3 vertices[];
};

layout(set = 0, binding = 2, std430) restrict readonly buffer IndexBuffer {
    uint indices[];
};

// Uniforms
layout(set = 0, binding = 3, std140) uniform VoxelParams {
    vec3 aabb_min;
    float padding1;
    vec3 aabb_size;
    float padding2;
    uint resolution;
    uint triangle_count;
    uint padding3;
    uint padding4;
};

// Calculate solid angle subtended by triangle from point
float calculate_solid_angle(vec3 point, vec3 v0, vec3 v1, vec3 v2) {
    // Translate triangle vertices relative to point
    vec3 a = v0 - point;
    vec3 b = v1 - point;
    vec3 c = v2 - point;
    
    // Get lengths
    float len_a = length(a);
    float len_b = length(b);
    float len_c = length(c);
    
    // Avoid degenerate cases
    if (len_a < 1e-6 || len_b < 1e-6 || len_c < 1e-6) {
        return 0.0;
    }
    
    // Normalize vectors
    a = a / len_a;
    b = b / len_b;
    c = c / len_c;
    
    // Calculate solid angle using L'Huilier's theorem
    float numerator = dot(a, cross(b, c));
    float denominator = 1.0 + dot(a, b) + dot(b, c) + dot(c, a);
    
    if (abs(denominator) < 1e-6) {
        return 0.0;
    }
    
    return 2.0 * atan(abs(numerator), denominator) * sign(numerator);
}

// Test if point is inside mesh using winding number
bool point_inside_mesh(vec3 point) {
    float winding_number = 0.0;
    
    // Sum solid angles from all triangles
    for (uint i = 0; i < triangle_count; i++) {
        uint base = i * 3;
        vec3 v0 = vertices[indices[base]];
        vec3 v1 = vertices[indices[base + 1]];
        vec3 v2 = vertices[indices[base + 2]];
        
        float solid_angle = calculate_solid_angle(point, v0, v1, v2);
        winding_number += solid_angle;
    }
    
    // Normalize by 4π (total solid angle of sphere)
    winding_number /= (4.0 * 3.14159265);
    
    // Point is inside if winding number magnitude > 0.5
    return abs(winding_number) > 0.5;
}

void main() {
    uvec3 voxel_coord = gl_GlobalInvocationID;
    
    // Bounds check
    if (any(greaterThanEqual(voxel_coord, uvec3(resolution)))) {
        return;
    }
    
    // Convert voxel coordinate to world position
    vec3 world_pos = aabb_min + (vec3(voxel_coord) + 0.5) / float(resolution) * aabb_size;
    
    // Test if point is inside mesh
    bool inside = point_inside_mesh(world_pos);
    
    // Write result
    imageStore(voxel_texture, ivec3(voxel_coord), vec4(inside ? 1.0 : 0.0));
}
