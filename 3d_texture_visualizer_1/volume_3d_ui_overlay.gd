extends Control

@onready var instructions_label = $VBoxContainer/Instructions
@onready var parameters_container = $VBoxContainer/Parameters

# Reference to the main 3D viewer
var viewer_3d: Node3D

func _ready():
    setup_ui()

func setup_ui():
    # Make the overlay non-blocking for mouse input to the 3D scene
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # Setup parameter controls
    setup_parameter_controls()

func show_instructions():
    if instructions_label:
        instructions_label.text = """3D Volume Viewer Controls:
        
• Right-click + drag: Look around
• WASD: Move camera
• Q/E: Move up/down  
• Mouse wheel: Zoom in/out
• ESC: Release mouse"""

func setup_parameter_controls():
    # Add some runtime parameter controls
    if not viewer_3d:
        return
        
    # This would add sliders for real-time parameter adjustment
    # Implementation depends on specific needs
