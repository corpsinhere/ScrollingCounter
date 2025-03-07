extends Node2D

@export var ball: RigidBody2D
@onready var counter: ScrollingCounter = $BounceCounter
@onready var point_label: RichTextLabel = $PointLabel


var offset: Vector2
var last_bounce: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	counter.initialize(3, null)
	counter.is_rate_by_chunk = false
	counter.chunk_rate = 0.5
	counter.point_rate = 3.0
	offset = ball.get_node("CollisionShape2D").shape.get_rect().size
	offset = Vector2(offset.x / 2.0, offset.y)
	point_label.position = Vector2(75, -6)
	ball.body_exited.connect(on_bounce)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position = ball.position - offset


func bounce_gap() -> float:
	var t_delta: float = Time.get_ticks_msec() - last_bounce
	last_bounce = Time.get_ticks_msec()
	return t_delta


func on_bounce(a_node: Node):
	if bounce_gap() > 2000:
		var t_points: int = 1 if not a_node is RigidBody2D else -2
		counter.display_points(t_points)
		flash_points(t_points)
	if ball.linear_velocity.length() < 150.0:
		ball.apply_central_impulse(1.0 * ball.linear_velocity)


func flash_points(a_points: int):
	point_label.visible = true
	var t_text: String = str(a_points)
	t_text = "[font_size=20]" + t_text + "[/font_size]"
	if a_points >= 0:
		t_text = "[color=green][b]" + "+" + t_text + "[/b][/color]"
	else:
		t_text = "[color=red][b]" + t_text + "[/b][/color]"
	point_label.text = t_text
	get_tree().create_timer(1.5).timeout.connect(point_label.set_visible.bind(false))
	
	
