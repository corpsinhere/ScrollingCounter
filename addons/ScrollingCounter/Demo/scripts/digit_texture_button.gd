extends Button

signal digit_texture_emitted(a_texture: Texture2D)

@export var digit_texture: Texture2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(emit_digit_texture)


func _make_custom_tooltip(_for_text: String) -> Object:
	var rect: TextureRect = TextureRect.new()
	rect.texture = digit_texture
	return rect


func emit_digit_texture():
	digit_texture_emitted.emit(digit_texture)
