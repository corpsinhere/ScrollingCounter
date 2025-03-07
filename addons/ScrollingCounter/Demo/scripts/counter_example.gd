extends Node2D

@onready var counter = %ScrollingCounter							# Thee scrolling counter itself
@onready var point_buttons_container: VBoxContainer = %PointButtons
@onready var add_points_button: Button = %AddPointsButton			# Adds points to queue
@onready var stop_button: Button = %StopButton
@onready var pause_button: Button = %PauseButton
@onready var play_button: Button = %PlayButton
@onready var zero_out_button: Button = %ZeroOutButton
@onready var points_to_add_label: Label = %PointsToAddLabel
@onready var ball_pit_prefab: Resource = preload("res://addons/ScrollingCounter/Demo/scenes/bouncy_counter.tscn")
@onready var speed_dropdown: OptionButton = %SpeedValues
@onready var speed_mode_checkbox: CheckBox = %PointOrBolus
@onready var speed_dropdown_bolus: OptionButton = %SpeedValuesBolus	# Bolus == chunk
@onready var queue_label: RichTextLabel = %QueueLabel				# Displays point chunks in <counter.points_queue>

var default_texture_saved: Texture2D
var points_to_add: int
var is_points_to_add_positive: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_node("TabContainer").get_tab_control(1).add_child(ball_pit_prefab.instantiate())
	counter.initialize(5, null)
	setup_dropdowns()
	setup_add_points_buttons()
	add_points_button.pressed.connect(add_points)
	counter.points_added.connect(on_points_added)
	counter.count_ended.connect(on_count_ended)
	stop_button.pressed.connect(on_stop_button_pressed)
	zero_out_button.pressed.connect(counter.zero_out)
	pause_button.pressed.connect(counter.set_is_counting_paused.bind(true))
	play_button.pressed.connect(on_play_button_pressed)
	%AddDigitButton.pressed.connect(add_digit.bind(true))
	%RemoveDigitButton.pressed.connect(add_digit.bind(false))
	%TextureButton00.digit_texture_emitted.connect(on_digit_texture_emitted)
	%TextureButton01.digit_texture_emitted.connect(on_digit_texture_emitted)
	%TextureButton02.digit_texture_emitted.connect(on_digit_texture_emitted)
	counter.is_queue_paused = true
	get_tree().create_timer(1).timeout.connect(func(): counter.is_queue_paused = false)


# Ensures <counter> is ready to count when queue is not empty
func on_play_button_pressed():
	counter.set_is_counting_paused(false)
	counter.is_queue_paused = false


# As it says
func on_stop_button_pressed():
	counter.stop_counting()
	if counter.is_counting_paused:
		counter.toggle_is_counting_paused()


# Refreshes display of <counter.points_queue>
func on_points_added(a_points: int):
	queue_label.text = int_array_out(counter.points_queue)


# Rebuilds counter using current testure and new digit count
func add_digit(a_is_add: bool):
	var t_increment: int = 1 if a_is_add else -1
	var t_count: int = maxi(counter.digit_count + t_increment, 1)
	counter.initialize(t_count, counter.digit_texture)


# As it says
func setup_add_points_buttons():
	var t_buttons: Array[Button] = []
	for i_obj in point_buttons_container.get_children():
		if i_obj is Button:
			t_buttons.append(i_obj)			
	for i_button: Button in t_buttons:
		if i_button == %SignButton:
			i_button.pressed.connect(func(): is_points_to_add_positive = not is_points_to_add_positive)
			i_button.pressed.connect(refresh_points_to_add_buttons)
			continue
		var t_text: String = i_button.text
		t_text = t_text.substr(2)
		i_button.pressed.connect(update_points_to_add_label.bind(i_button))


# This dirty func returns a value derived from a_button.text
func points_to_add_by_button (a_button: Button) -> int:
	var t_text: String = a_button.text
	t_text = t_text.substr(2)
	var t_sign: int = 1 if is_points_to_add_positive else -1
	return t_sign * t_text.to_int()


# Toggles +/- text on buttons
func refresh_points_to_add_buttons():
	var t_buttons: Array[Button] = []
	for i_obj in point_buttons_container.get_children():
		if i_obj is Button:
			t_buttons.append(i_obj)			
	for i_button: Button in t_buttons:
		if i_button == null: continue
		if i_button.text == "+/-":
			continue
		var t_text: String = i_button.text
		var t_sign: String = "+" if is_points_to_add_positive else "-"
		t_text = t_text.replace("-", t_sign)
		t_text = t_text.replace("+", t_sign)
		i_button.text = t_text


# Adds points_to_add to <counter> queue 
func add_points():
	counter.display_points(points_to_add)
	refresh_points_list()
	points_to_add = 0
	points_to_add_label.text = ""


# [Messy] Updates both the points_to_add variable and also the coresponding label
func update_points_to_add_label(a_button: Button):
	points_to_add += points_to_add_by_button(a_button)
	points_to_add_label.text = str(points_to_add)


# Fires when <counter> completes counting a chunk of points
func on_count_ended():
	refresh_points_list()


# Refreshes display of <counter> queue
func refresh_points_list():
	var t_queue: Array[int] = counter.points_queue.duplicate()
	var t_current: int = counter.chunk_being_counted
	if t_current != 0:
		t_queue.push_front(t_current)
	queue_label.text = int_array_out(t_queue)


# String preresentation of array of int
# Specifically, formatted string representation of <counter> queue
func int_array_out(a_array: Array[int]) -> String:
	var t_string: String = ""
	var t_num_string: String = ""
	for i_index: int in range(a_array.size()):			
		t_num_string = "[color=BLACK]" + str(a_array[i_index]) + "[/color]"
		t_num_string = "[center]" + t_num_string + "[/center]"
		t_num_string = "[font_size=24]" + t_num_string + "[/font_size]"
		if i_index == 0:
			t_num_string = "[bgcolor=green]" + t_num_string + "[/bgcolor]"
		t_string += t_num_string
	return t_string


# As it says
func setup_dropdowns():
	speed_dropdown.get_popup().add_item("0.1")
	speed_dropdown.get_popup().add_item("1.0")
	speed_dropdown.get_popup().add_item("5")
	speed_dropdown.get_popup().add_item("7.5")
	speed_dropdown.get_popup().add_item("10")
	speed_dropdown.get_popup().add_item("100")
	speed_dropdown.get_popup().add_item("1000")
	speed_dropdown.selected = 1
	speed_dropdown.visible = true
	speed_dropdown.item_selected.connect(set_counter_speed)
	speed_dropdown_bolus.get_popup().add_item("0.01")
	speed_dropdown_bolus.get_popup().add_item("0.1")
	speed_dropdown_bolus.get_popup().add_item("1.0")
	speed_dropdown_bolus.get_popup().add_item("2")
	speed_dropdown_bolus.selected = 1
	speed_dropdown_bolus.visible = false
	speed_dropdown_bolus.item_selected.connect(set_counter_speed)
	speed_mode_checkbox.toggled.connect(on_speed_mode_checkbox_toggled)


# Note this activates ScrollingCounter.digit_texture setter which does the heavy lifting
func on_digit_texture_emitted(a_digit_texture: Texture2D):
	counter.digit_texture = a_digit_texture


# Handles user choice of speed mode
func on_speed_mode_checkbox_toggled(a_is_on: bool):
	counter.is_rate_by_chunk = a_is_on
	speed_dropdown.visible = not a_is_on
	speed_dropdown_bolus.visible = a_is_on
	set_counter_speed(0)


# Sets <counter> counting rate based on value and mode selections
func set_counter_speed(a_fake_item: int):
	var t_rate: float
	if counter.is_rate_by_point():
		t_rate = speed_dropdown.text.to_float()
		if t_rate > 0.0:
			counter.is_rate_by_chunk = false
			counter.point_rate = t_rate
	else:
		t_rate = speed_dropdown_bolus.text.to_float()
		if t_rate > 0.0:
			counter.is_rate_by_chunk = true
			counter.chunk_rate = t_rate
