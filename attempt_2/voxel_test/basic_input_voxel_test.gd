extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


# Handle input events
func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_G:
            print("G!")
        if event.keycode == KEY_Z:
            %CollisionConfigurator.create_accurate_collision_shapes()
        if event.keycode == KEY_T:
            get_parent().start_generation()
