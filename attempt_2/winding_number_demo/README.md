# Winding Number Voxelization Demo

This folder demonstrates the **winding number algorithm** for converting meshes to Texture3D - a mathematically robust alternative to physics-based raycasting.

## Why Winding Number?

The winding number algorithm provides **100% reliable** point-in-mesh testing without the problems that plagued our raycasting approach:

- ✅ **No physics engine dependency** - Pure mathematical calculation
- ✅ **Perfect accuracy** - Never fails on complex mesh topology
- ✅ **Handles any closed mesh** - Works with skulls, complex models, etc.
- ✅ **No collision shape requirements** - Works directly with mesh vertices
- ✅ **Deterministic results** - Same input always gives same output

## How It Works

The winding number algorithm calculates how many times a mesh "winds around" a test point:

1. **For each triangle** in the mesh, calculate the solid angle it subtends from the test point
2. **Sum all solid angles** to get the total winding number
3. **If |winding_number| > 0.5**, the point is inside the mesh

This is mathematically equivalent to casting infinite rays in all directions and counting intersections.

## Files

- `winding_number_voxelizer.gd` - Main voxelization script with winding number implementation
- `winding_demo.tscn` - Demo scene with test objects
- `demo_controller.gd` - Interactive controls for testing different meshes
- `README.md` - This file

## Usage

1. **Open** `winding_demo.tscn` in Godot
2. **Run** the scene - it will automatically voxelize the test sphere
3. **Press keys** to interact:
   - `Space` - Re-voxelize current mesh
   - `T` - Toggle debug cube visualization
   - `1` - Switch to sphere test object
   - `2` - Switch to box test object
   - `+/-` - Increase/decrease voxel resolution

## Integration with Your Skull Project

To use this with your skull mesh:

```gdscript
# Create the voxelizer
var voxelizer = preload("res://winding_number_demo/winding_number_voxelizer.gd").new()

# Set your skull mesh
voxelizer.target_mesh_instance = your_skull_mesh_instance
voxelizer.voxel_resolution = 64  # Or whatever resolution you need

# Generate the Texture3D
add_child(voxelizer)  # Add to scene tree
voxelizer.start_voxelization()

# Get the result
var skull_texture3d = voxelizer.get_texture3d()
```

## Performance Notes

- **CPU-based** - Slower than GPU approaches but more reliable
- **Scales with resolution³** - Double resolution = 8x more work
- **Recommended starting resolution**: 32-64 for skulls
- **Can be optimized** with spatial acceleration structures if needed

## Mathematical Foundation

The winding number W(p) for point p is:

```
W(p) = (1/4π) * Σ Ω(p, triangle_i)
```

Where Ω(p, triangle) is the solid angle subtended by the triangle from point p.

For a closed mesh:
- W(p) = ±1 if p is inside
- W(p) = 0 if p is outside

This method is used in computational geometry, 3D printing, medical imaging, and anywhere robust point-in-mesh testing is critical.
