extends Control

# References to UI elements
@onready var slice_viewer = $VBoxContainer/ViewerContainer/SliceViewer
@onready var xray_viewer = $VBoxContainer/ViewerContainer/XRayViewer
@onready var slice_slider = $VBoxContainer/Controls/SliceControls/SliceSlider
@onready var axis_options = $VBoxContainer/Controls/SliceControls/AxisOptions
@onready var mode_tabs = $VBoxContainer/Controls/ModeControls/ModeTabs

# 3D Texture reference
var volume_texture: ImageTexture3D

func _ready():
    setup_ui()
    load_volume_texture()

func setup_ui():
    # Setup slice slider
    slice_slider.min_value = 0.0
    slice_slider.max_value = 1.0
    slice_slider.step = 0.01
    slice_slider.value = 0.5
    slice_slider.value_changed.connect(_on_slice_changed)
    
    # Setup axis options
    axis_options.add_item("X Axis")
    axis_options.add_item("Y Axis") 
    axis_options.add_item("Z Axis")
    axis_options.selected = 2
    axis_options.item_selected.connect(_on_axis_changed)
    
    # Setup mode tabs
    mode_tabs.add_tab("Slice View")
    mode_tabs.add_tab("X-Ray View")
    mode_tabs.tab_changed.connect(_on_mode_changed)
    
    # Initial mode
    _on_mode_changed(0)

func load_volume_texture():
    var texture_path = "res://3d_texture_visualizer_1/six_pointed_cross_texture3d.tres"
    
    if ResourceLoader.exists(texture_path):
        volume_texture = load(texture_path)
        if volume_texture:
            print("Successfully loaded 3D texture")
            update_shader_texture()
        else:
            print("Failed to load 3D texture from: ", texture_path)
    else:
        print("3D texture file not found at: ", texture_path)
        print("Please run the texture3d_generator.tscn scene first to create the texture")

func update_shader_texture():
    if not volume_texture:
        return
        
    # Update slice viewer material
    var slice_material = slice_viewer.material as ShaderMaterial
    if slice_material and slice_material.shader:
        slice_material.set_shader_parameter("volume_texture", volume_texture)
        slice_material.set_shader_parameter("slice_depth", slice_slider.value)
        slice_material.set_shader_parameter("slice_axis", axis_options.selected)
    
    # Update X-ray viewer material
    var xray_material = xray_viewer.material as ShaderMaterial
    if xray_material and xray_material.shader:
        xray_material.set_shader_parameter("volume_texture", volume_texture)

func _on_slice_changed(value: float):
    if slice_viewer.material and slice_viewer.material is ShaderMaterial:
        slice_viewer.material.set_shader_parameter("slice_depth", value)

func _on_axis_changed(index: int):
    if slice_viewer.material and slice_viewer.material is ShaderMaterial:
        slice_viewer.material.set_shader_parameter("slice_axis", index)

func _on_mode_changed(tab_index: int):
    match tab_index:
        0: # Slice View
            slice_viewer.visible = true
            xray_viewer.visible = false
        1: # X-Ray View
            slice_viewer.visible = false
            xray_viewer.visible = true
