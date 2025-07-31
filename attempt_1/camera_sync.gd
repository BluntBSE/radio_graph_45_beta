extends Camera3D

# Reference to the high-res camera in the SubViewport
@onready var hi_res_camera: Camera3D = get_node("../../SubViewport/HighResCamera")

func _ready():
	# Sync initial camera properties
	sync_camera_properties()

func _process(delta):
	# Continuously sync the high-res camera with this camera
	sync_camera_properties()

func sync_camera_properties():
	if hi_res_camera:
		# Copy transform
		hi_res_camera.global_transform = global_transform
		
		# Copy camera settings
		hi_res_camera.fov = fov
		hi_res_camera.near = near
		hi_res_camera.far = far
		hi_res_camera.projection = projection
