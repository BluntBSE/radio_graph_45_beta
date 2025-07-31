# 3D Texture Visualizer for X-Ray Rendering

This project contains tools for generating and visualizing 3D textures, specifically designed for X-ray rendering experiments.

## Files Created

### Core Generator
- `texture3d_generator.gd` - Script that procedurally generates a high-resolution 3D texture
- `texture3d_generator.tscn` - Scene to run the generator

### Visualization Tools
- `volume_viewer.tscn` - Main viewer scene with UI controls
- `volume_viewer_controller.gd` - Controller script for the viewer
- `volume_slice_shader.gdshader` - Shader for viewing 2D slices of the 3D texture
- `volume_xray_shader.gdshader` - Shader for X-ray style volume rendering

## Generated 3D Texture

The generator creates a **six-pointed cross** pattern in 3D space:
- **Resolution**: 256×256×256 pixels (high quality)
- **Pattern**: Cross in XY plane + Cross in XZ plane = Six-pointed 3D cross
- **Format**: RGBA8 with anti-aliased edges
- **File**: `six_pointed_cross_texture3d.tres`

### Cross Parameters
- **Thickness**: 16 pixels per arm
- **Length**: 80% of texture dimensions
- **Smoothing**: Distance-based anti-aliasing for clean edges

## How to Use

### Step 1: Generate the 3D Texture
1. Open Godot and load the project
2. Run the scene `texture3d_generator.tscn`
3. Wait for generation to complete (progress shown in output)
4. The 3D texture will be saved as `six_pointed_cross_texture3d.tres`

### Step 2: View and Test the Texture
1. Run the scene `volume_viewer.tscn`
2. Use the controls to examine the texture:
   - **Slice Slider**: Navigate through the volume
   - **Axis Options**: View slices along X, Y, or Z axis
   - **Mode Tabs**: Switch between slice view and X-ray view

### Step 3: Use in Your X-Ray Experiments
- Load the texture: `var texture = load("res://3d_texture_visualizer_1/six_pointed_cross_texture3d.tres")`
- Use with the provided shaders or your own volume rendering shaders
- The six-pointed cross provides clear reference points in all three dimensions

## Shader Details

### Slice Shader (`volume_slice_shader.gdshader`)
- Displays 2D cross-sections through the volume
- Adjustable slice depth and axis
- Brightness and contrast controls

### X-Ray Shader (`volume_xray_shader.gdshader`)
- Ray-marching based volume rendering
- Simulates X-ray absorption
- Configurable density, steps, and absorption coefficients

## Technical Notes

### 3D Texture Format
- Uses Godot's `ImageTexture3D` class
- Created from array of 2D Image slices
- RGBA8 format for maximum compatibility

### Performance Considerations
- 256³ texture = ~67 million voxels
- Generation takes a few seconds
- X-ray rendering is GPU intensive (adjust max_steps if needed)

### Customization
You can modify the generator parameters:
```gdscript
const TEXTURE_SIZE = 256          # Change resolution
const CROSS_THICKNESS = 16        # Change arm thickness
const CROSS_LENGTH_RATIO = 0.8    # Change cross size
```

## Next Steps for X-Ray Development

1. **Mesh to Volume**: Convert 3D meshes to volume textures
2. **Multiple Densities**: Support different material densities
3. **Lighting Models**: Add more sophisticated X-ray physics
4. **Performance**: Optimize for real-time rendering
5. **File Formats**: Support standard volume formats (DICOM, etc.)

The six-pointed cross provides an excellent test pattern because:
- It's clearly visible from any viewing angle
- Has known geometry for validation
- Contains both thick and thin features
- Provides depth cues in X-ray rendering
