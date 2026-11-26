extends Camera3D
class_name MinimapCameraBounds

## Full-map minimap camera. The camera stays inside the playable city footprint
## and scales its orthographic frustum so it never renders beyond that footprint.
@export var world_bounds_xz := Vector2(154.0, 154.0)
@export var map_center_xz := Vector2.ZERO
@export var camera_height := 155.0
@export var edge_padding := 0.0

func _ready() -> void:
    projection = Camera3D.PROJECTION_ORTHOGONAL
    keep_aspect = Camera3D.KEEP_HEIGHT
    rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    _fit_to_map()
    get_viewport().size_changed.connect(_fit_to_map)

func _fit_to_map() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var aspect := viewport_size.x / viewport_size.y
    var map_width := maxf(world_bounds_xz.x - edge_padding * 2.0, 1.0)
    var map_depth := maxf(world_bounds_xz.y - edge_padding * 2.0, 1.0)
    # Camera3D.size is the visible vertical span with KEEP_HEIGHT. Fit the
    # wider dimension too, so the complete city remains visible without void.
    size = minf(map_depth, map_width / maxf(aspect, 0.01))
    global_position = Vector3(map_center_xz.x, camera_height, map_center_xz.y)
