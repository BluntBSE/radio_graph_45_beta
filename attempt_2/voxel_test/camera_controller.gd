extends Camera3D

# Camera movement settings
@export var movement_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002

# Camera rotation variables
var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0


func _ready():
    # Set the camera's initial rotation
    rotation_x = rotation.x
    rotation_y = rotation.y
    
func _input(event):
    # Handle mouse capture for look controls
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            if event.pressed:
                mouse_captured = true
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            else:
                mouse_captured = false
                Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    
    # Handle mouse movement for looking around
    if event is InputEventMouseMotion and mouse_captured:
        rotation_y -= event.relative.x * mouse_sensitivity
        rotation_x -= event.relative.y * mouse_sensitivity
        
        # Clamp vertical rotation to prevent camera flipping
        rotation_x = clamp(rotation_x, -PI/2, PI/2)
        
        # Apply rotation
        rotation.x = rotation_x
        rotation.y = rotation_y

func _process(delta):
    # Handle WASD movement
    var input_vector = Vector3()
    
    # Get input for WASD keys
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
        input_vector -= transform.basis.z
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
        input_vector += transform.basis.z
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
        input_vector -= transform.basis.x
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
        input_vector += transform.basis.x
    
    # Normalize input vector to prevent faster diagonal movement
    if input_vector.length() > 0:
        input_vector = input_vector.normalized()
    
    # Apply movement
    global_position += input_vector * movement_speed * delta
   

func _exit_tree():
    # Ensure mouse is visible when exiting
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
