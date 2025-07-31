extends Camera3D

# Camera movement settings
@export var movement_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002

# Camera synchronization
@export var slave_camera: Camera3D  # Assign the SubViewport camera in the inspector

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
        
        # Sync slave camera when rotating
        sync_slave_camera()

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
    
    # Synchronize slave camera in SubViewport
    sync_slave_camera()
    
    # Update shader parameters for volume rendering
    update_voxel_display_shader()

func sync_slave_camera():
    # Copy transform from main camera to slave camera
    if slave_camera:
        slave_camera.global_transform = global_transform
        # Also copy camera properties if needed
        slave_camera.fov = fov
        slave_camera.near = near
        slave_camera.far = far

func update_voxel_display_shader():
    # Get reference to the VoxelDisplay TextureRect
    var voxel_display = get_node("%VoxelDisplay")
    if voxel_display and voxel_display.material:
        # Pass camera position 
        voxel_display.material.set_shader_parameter("camera_position", global_position)
        
        # Get the voxel baker and set the volume texture
        var voxel_baker = get_node("../SubViewport/VoxelBaker")
        if voxel_baker and voxel_baker.volume_texture:
            voxel_display.material.set_shader_parameter("volume_texture", voxel_baker.volume_texture)
        
        # Debug: Print occasionally to confirm we're reaching the TextureRect
        if int(Time.get_ticks_msec()) % 2000 < 16:  # Print every 2 seconds
            print("Camera position: ", global_position)
            if voxel_baker and voxel_baker.volume_texture:
                print("Volume texture available: ", voxel_baker.volume_texture)
            else:
                print("Volume texture missing!")
    else:
        # Debug: Print if TextureRect or material is missing
        if int(Time.get_ticks_msec()) % 1000 < 16:  # Print every second
            print("VoxelDisplay missing! Node: ", voxel_display)

# Call this function to save texture slices for debugging
func save_volume_texture_slices():
    var voxel_baker = get_node("../SubViewport/VoxelBaker")
    if not voxel_baker or not voxel_baker.volume_texture:
        print("No volume texture to save!")
        return
    
    print("Saving volume texture slices...")
    var texture3d = voxel_baker.volume_texture
    
    # Save slices at different Z levels
    var slice_indices = [32, 48, 64, 80, 96]  # Different Z slices through the 128^3 volume
    
    for i in range(slice_indices.size()):
        var z_slice = slice_indices[i]
        var slice_data = PackedByteArray()
        
        # Extract one Z slice
        for y in range(128):
            for x in range(128):
                # Sample the 3D texture at this x,y,z coordinate
                var tex_coords = Vector3(float(x)/127.0, float(y)/127.0, float(z_slice)/127.0)
                # This is tricky - we can't directly sample ImageTexture3D from script
                # Let's read from the original data if available
                pass
        
        print("Would save slice ", z_slice, " but need to implement sampling...")
    
    # Alternative: Ask voxel baker to save slices during baking
    print("Requesting voxel baker to save debug slices...")
    if voxel_baker.has_method("save_debug_slices"):
        voxel_baker.save_debug_slices()
    else:
        print("VoxelBaker doesn't have save_debug_slices method - let's add it!")

func _exit_tree():
    # Ensure mouse is visible when exiting
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
