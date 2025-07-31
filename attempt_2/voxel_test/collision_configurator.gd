extends Node3D
class_name CollisionConfigurator
var meshes_to_configure = []
var colliders_to_configure = []
signal collisions_generated

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    meshes_to_configure = get_tree().get_nodes_in_group("realistic_collider")
    for mesh_instance in meshes_to_configure:
        var collider: CollisionShape3D = mesh_instance.get_child(0).get_child(0)
        # Static body inbetween the two layers
        colliders_to_configure.append(collider)
    create_accurate_collision_shape(%SkullCollisionShape, %b_skull.mesh)


func create_accurate_collision_shapes():
    for i in meshes_to_configure.size():
        create_accurate_collision_shape(colliders_to_configure[i],meshes_to_configure[i].mesh)
    collisions_generated.emit()

func create_accurate_collision_shape(collision_shape: CollisionShape3D, mesh: Mesh) -> bool:
    print("I got ", collision_shape.name, "and ", mesh)
    if mesh == null:
        print("ERROR: No mesh provided")
        return false
    
    if collision_shape == null:
        print("ERROR: No collision shape provided")
        return false
    
    # Create a ConcavePolygonShape3D for perfect accuracy
    var shape = ConcavePolygonShape3D.new()
    
    # Get all the vertices from the mesh
    var surface_arrays = mesh.surface_get_arrays(0)
    var vertices = surface_arrays[Mesh.ARRAY_VERTEX]
    
    if vertices == null or vertices.size() == 0:
        print("ERROR: Mesh has no vertices")
        return false
    
    # ConcavePolygonShape3D needs triangulated faces as a flat array
    var faces = PackedVector3Array()
    
    # If the mesh has indices, use them to build triangles
    var indices = surface_arrays[Mesh.ARRAY_INDEX]
    if indices != null and indices.size() > 0:
        # Mesh has indices - build triangles from them
        for i in range(0, indices.size(), 3):
            if i + 2 < indices.size():
                faces.append(vertices[indices[i]])
                faces.append(vertices[indices[i + 1]])
                faces.append(vertices[indices[i + 2]])
    else:
        # No indices - vertices are already in triangle order
        faces = vertices
    
    # Set the faces on the collision shape
    shape.set_faces(faces)
    
    # FIXED: Actually assign the shape to the CollisionShape3D
    collision_shape.shape = shape
    
    print("Created collision shape with ", faces.size() / 3, " triangles")
    return true
