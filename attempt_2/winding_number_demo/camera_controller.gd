extends Camera3D
# Free-look camera controller for inspecting voxelized meshes

@export var movement_speed: float = 5.0
@export var fast_speed_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.002

var is_capturing_mouse: bool = false

func _ready():
    # Position camera at a good starting point
    position = Vector3(0, 0, 5)
    look_at(Vector3.ZERO, Vector3.UP)

func _input(event):
    # Toggle mouse capture with right click
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if is_capturing_mouse:
                release_mouse()
            else:
                capture_mouse()
    
    # Mouse look when captured
    if event is InputEventMouseMotion and is_capturing_mouse:
        rotate_y(-event.relative.x * mouse_sensitivity)
        rotate_object_local(Vector3.RIGHT, -event.relative.y * mouse_sensitivity)
        
        # Clamp vertical rotation to prevent flipping
        var euler = transform.basis.get_euler()
        euler.x = clamp(euler.x, -PI/2 + 0.01, PI/2 - 0.01)
        transform.basis = Basis.from_euler(euler)

func _process(delta):
    if not is_capturing_mouse:
        return
    
    # Movement input
    var input_vector = Vector3()
    
    # WASD movement
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
        input_vector.z -= 1
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
        input_vector.z += 1
    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
        input_vector.x -= 1
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
        input_vector.x += 1
    
    # QE for up/down
    if Input.is_key_pressed(KEY_Q):
        input_vector.y -= 1
    if Input.is_key_pressed(KEY_E):
        input_vector.y += 1
    
    # Apply movement
    if input_vector.length() > 0:
        input_vector = input_vector.normalized()
        
        # Fast movement with shift
        var current_speed = movement_speed
        if Input.is_key_pressed(KEY_SHIFT):
            current_speed *= fast_speed_multiplier
        
        # Move relative to camera orientation
        var movement = transform.basis * input_vector * current_speed * delta
        position += movement

func capture_mouse():
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    is_capturing_mouse = true
    print("Mouse captured - WASD to move, QE for up/down, Right-click to release")

func release_mouse():
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    is_capturing_mouse = false
    print("Mouse released - Right-click to capture")

func _notification(what):
    # Release mouse when window loses focus
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        if is_capturing_mouse:
            release_mouse()
