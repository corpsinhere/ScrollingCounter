@tool
extends HBoxContainer
class_name ScrollingCounter

## A counter which animates as it increments. It accepts points in chunks and will wait until one chunk ##
## completes before starting on another. Speed modes: by points == constant speed; by chunk == a chunk of any size ##
## will complete in the same amount of time (determained by <chunk_rate>). If the requested speed is faster than ##
## MAX_SLOW_COUNTING_RATE, the animation will be "faked" i.e highest digit will count and the others will just spin ##

# Notes on format and terms: 
# register == number place referenced by power of 10; e.g. "6" in 567 is in register 1; i.e. 10^1
# Prefixes:
# 	a_ == func argument
# 	t_ == temp / local var
# 	i_ == iteration var
# Pointy brackets in a comment == referencing a specific variable; .e.g. <point_rate>

signal points_added(a_points: int)			# Called when points begin to be counted (or are added to <points_queue>)
signal count_started(a_points: int)			# Called when counter begins to scroll a chunk of points
signal count_ended(a_points: int)			# Called when a counter ends scrolling a chunk of points

var sign_display: Panel						# Turns red if we are displaying negative numbers
var digits: Array[DigitDisplay] = []		# Index == power of 10 
var ones_digit: DigitDisplay				# Regular-speed counting all goes through the 1s digit
var digit_count: int						# Count of displayed digits
var points: int								# Total points (includes currently scrolling chunk) 
var points_queue: Array[int]				# List of point chunks - during counting the first element is removed and then counted - repeat
var is_counting: bool						# Is counting currently ongoing?
var point_rate: float = 10.0				# Default points scrolled per second
var chunk_rate: float = 0.2					# Default point chunks scrolled per second
var is_negative: bool						# Are points currently less than zero?

# rate by chunk: A chunk of any size will take this long to count; e.g. +100, +1, +2345 will all take the same amount of time to count
# Note that chunk_rate feels a bit unintuative: it is the number of chunks per second - not the number or seconds per chunk
# rate by points: total duration = # of points * <point_rate>; e.g. +100 points will take 10x as long as +10 points  
var is_rate_by_chunk: bool
func is_rate_by_point(): return not is_rate_by_chunk
var is_queue_paused: bool							# Pauses points being loaded from the queue; counting in-progress will still complete
var is_counting_paused: bool						# Pauses all counting immediately
var is_stop_requested: bool							# Stops counting and sets display to <points>
var chunk_being_counted: int						# Size of chunk currently being counted (used for display purposes)
var default_texture_saved: Texture2D			
var is_initializing: bool							# Are we currently doing initialization?
const POSITIVE_COLOR: Color = Color.BLACK			# Colors <sign_display> to indicate <is_negative>
const NEGATIVE_COLOR: Color = Color(1.0, 0, 0, 0.56)
const MAX_SLOW_COUNTING_RATE: float = 10	# Faster rates need to use fast_counting (fake) method
const DEFAULT_TEXTURE_DIR_STRING: String = "res://addons/ScrollingCounter/number_strip.png"

@export var digit_texture: Texture2D:				# Image of digits 0 - 9 (and then 0 again)
	set(a_texture):
		digit_texture = a_texture
		if not is_initializing:
			initialize(digit_count, digit_texture)


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Display count of a_points or put in queue if currently counting
func display_points(a_points: int):
	points_queue.append(a_points)
	points_added.emit(a_points)
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Default initialization
func _ready() -> void:
	initialize(3, null)


# Does nothing if points_queue is empty or counting is ongoing
func _process(_delta):
	check_is_counting_complete()
	if not is_queue_paused and not is_counting:
		do_counting()


# As it says
func toggle_is_counting_paused():
	is_counting_paused = not is_counting_paused
	for i_digit: DigitDisplay in digits:
		i_digit.is_counting_paused = is_counting_paused


# As it says
func set_is_counting_paused(a_is_paused: bool):
	for i_digit: DigitDisplay in digits:
		i_digit.is_counting_paused = a_is_paused


# Stop counting animation and display current total; 
func stop_counting():
	is_stop_requested = true
	is_queue_paused = true
	set_is_counting_paused(false)
	for i_digit: DigitDisplay in digits:
		i_digit.stop_counting()


func unstop_counting():
	is_stop_requested = false
	for i_digit: DigitDisplay in digits:
		i_digit.is_stop_requested = false


# Rebuilds counter; if either input is missing, attempts to use defaults
func initialize(a_digit_count: int, a_digit_image: Texture2D):
	is_initializing = true
	reset()
	digit_texture = a_digit_image if a_digit_image != null else default_texture()
	if sign_display == null:
		sign_display = Panel.new()
		add_child(sign_display)
		sign_display.custom_minimum_size = Vector2(12.0, 0.0)
	digit_count = a_digit_count if a_digit_count > 0 else 3
	# Instantiate digit displays
	for i_index: int in digit_count:
		var t_digit = DigitDisplay.new()
		t_digit.initialize(digit_texture)
		t_digit.scroll_rate = point_rate
		digits.push_front(t_digit)	# Ensures digits index matches power of ten place in display
		add_child(t_digit)
	# Chain turned_over signals
	for i_index: int in  range(digits.size() - 1):
		var t_digit: DigitDisplay = digits[i_index]
		var t_next_digit: DigitDisplay = digits[i_index + 1]	#Adjacent higher register (e.g. ones -> tens)
		t_digit.turned_over.connect(t_next_digit.increment_value)
		t_digit.turned_under.connect(t_next_digit.decrement_value)
	ones_digit = digits[0]
	is_initializing = false


# Reinitializes in prep for a rebuild
func reset():
	for i_digit: DigitDisplay in digits:
		remove_child(i_digit)
		i_digit.queue_free()
	digits.resize(0)
	ones_digit = null
	points = 0
	points_queue.resize(0)
	is_counting = false
	is_negative = false
	is_queue_paused = false
	is_counting_paused = false
	is_stop_requested = false
	chunk_being_counted  = 0


# Sets points to zero
func zero_out():
	points = 0
	stop_counting()


# Count next chunk of points in points_queue
func do_counting():
	if points_queue.is_empty(): return
	if is_counting: return
	set_digit_rates(MAX_SLOW_COUNTING_RATE)
	var t_points: int = points_queue.pop_front()
	chunk_being_counted = t_points
	count_started.emit(t_points)
	if is_delta_crossing_zero(t_points):
		# Note this will split t_points at zero, add the pieces back to the queue,
		# And terminate this call to <do_counting()>
		handle_delta_crossing_zero(t_points)
		is_counting = false
		return
	var t_rate: float
	if is_rate_by_point():
		t_rate = point_rate
	else:
		t_rate = chunk_rate * t_points		# chunk/sec * points/chunk ->points/sec
	var is_fast_counting: bool = t_rate > MAX_SLOW_COUNTING_RATE
	if points == 0:
		set_sign_color(t_points > 0)
	if not is_fast_counting:
		set_digit_rates(t_rate)
		is_counting = true
		ones_digit.do_counting(t_points, is_incrementing(t_points))
		#ones_digit.counting_completed.connect(func():is_counting = false)
	else:
		do_fast_counting(t_points, t_rate)
	points += t_points


# Should counters count up (vs down)?
func is_incrementing(a_points: int) -> bool:
	if points == 0: return true
	return signi(points) == signi(a_points)

# Find lowest register that could slow-count (AKA fastest-slow-counting register) -
# ^This digit will drive higher digits
# Other, lower digits just spin
func do_fast_counting(a_points: int, a_rate: float):
	is_counting = true
	var t_fastest_slow_counting_register: int = fastest_slow_counting_register(a_rate, 0)
	if t_fastest_slow_counting_register > digits.size() - 1:
		# Essentially: if <a_points> too big -> just set all the digits to their final position without animations
		set_all_digits(points + a_points)
		is_counting = false
		return
	# Digit at t_fastest_slow_counting_register drives counting for itself and higher registers
	var t_drive_digit: DigitDisplay = digits[t_fastest_slow_counting_register]
	t_drive_digit.counting_completed.connect(do_fast_counting_completion_cascade.bind(t_fastest_slow_counting_register))
	var t_total: int = points + a_points
	var t_driving_end_digit: int = DigitMath.digit_at(t_total, t_fastest_slow_counting_register)
	var t_current_driving_digit: int = DigitMath.digit_at(points, t_fastest_slow_counting_register)
	var t_truncated_total_points: int = (points as float / pow(10, t_fastest_slow_counting_register)) as int
	var t_truncated_total: int = (t_total as float / pow(10, t_fastest_slow_counting_register)) as int
	var t_driving_points: int = t_truncated_total - t_truncated_total_points

	t_drive_digit.scroll_rate = a_rate / pow(10, t_fastest_slow_counting_register)
	t_drive_digit.do_counting(t_driving_points, is_incrementing(t_driving_points))

	for i_index: int in range(t_fastest_slow_counting_register - 1, -1, -1):
		var t_end_digit: int = DigitMath.digit_at(t_total, i_index)
		var t_rate: float = MAX_SLOW_COUNTING_RATE * pow(1.4, t_fastest_slow_counting_register - i_index)
		digits[i_index].scroll_rate = t_rate
		digits[i_index].do_fast_counting(t_end_digit, is_incrementing(a_points))


# Set all digits to match <a_points>
func set_all_digits(a_total: int):
	for i_index: int in range(digits.size()):
		var t_digit: DigitDisplay = digits[i_index]
		t_digit.set_value(DigitMath.digit_at(a_total, i_index))


#region Implementation - Here be dragons
# Does adding a_delta to <points> cross zero?
func is_delta_crossing_zero(a_delta: int) -> bool:
	if points == 0: return false
	if signi(points) == signi(a_delta): return false
	if absi(points) >= absi(a_delta):return false
	return true


# Split <a_delta> so that it no longer spans zero and put back into points_queue
# Note this means <a_delta> will be counted as two chunks
func handle_delta_crossing_zero(a_delta: int):
	# Check that a_delta will take us across zero
	if not is_delta_crossing_zero(a_delta): return
	# Split a_delta at zero
	var t_dist_to_zero: int = -1 * points
	var t_remainder: int = a_delta - t_dist_to_zero
	points_queue.push_front(t_remainder)
	points_queue.push_front(t_dist_to_zero)


# Change mode to counting completed
# Ensure all digits are no longer in fast-counting mode
func on_fast_counting_completed():
	is_counting = false
	for i_digit: DigitDisplay in digits:
		i_digit.is_fast_counting = false
	count_ended.emit()


# Fastest moving place that is slower than MAX_SLOW_COUNTING_RATE
# Digits will scroll faster as the register decreases - so fastest -> lowest
func fastest_slow_counting_register(a_rate: float, a_guess: int) -> int:
	var t_rate: float = a_rate / pow(10, a_guess)
	if t_rate <= MAX_SLOW_COUNTING_RATE:
		return a_guess
	else:
		return fastest_slow_counting_register(a_rate, a_guess + 1)


# Used to reset rates after fast-counting
func set_digit_rates(a_rate: float):
	for i_digit: DigitDisplay in digits:
		i_digit.scroll_rate = a_rate


# Recursive; called first time when fastest-slow-counting digit completes counting
# Disconnects itself from this func; connects this func to counting_completed signal of
# next-lower register, and then tells that register to stop spinning (which will also causes
# it to count to its target digit).
# If we are at the <ones_digit>, signal that fast counting is complete.
func do_fast_counting_completion_cascade(a_register: int):
	var t_digit: DigitDisplay = digits[a_register]
	var t_register: int = a_register - 1
	t_digit.counting_completed.disconnect(do_fast_counting_completion_cascade)
	if a_register == 0:
		on_fast_counting_completed()		
	else:
		t_digit = digits[t_register]
		t_digit.counting_completed.connect(do_fast_counting_completion_cascade.bind(t_register))
		t_digit.is_spinning = false	# This will cause the digit to stop spinning and slow-count to its target 


# Set is_counting to false if no digits are currently counting
func check_is_counting_complete():
	# Give digits time to propigate tunred_over signals
	await get_tree().create_timer(0.1).timeout
	for i_digit: DigitDisplay in digits:
		if i_digit.is_counting:
			return
	if is_stop_requested:
		set_all_digits(points)
		set_is_counting_paused(false)
		unstop_counting()
	if is_counting:
		is_counting = false
		chunk_being_counted = 0
		count_ended.emit()


# As it says
func set_sign_color(a_is_positive: bool):
	var t_color: Color
	if a_is_positive:
		t_color = POSITIVE_COLOR
	else:
		t_color = NEGATIVE_COLOR
	var t_stylebox: StyleBoxFlat = sign_display.get_theme_stylebox("panel").duplicate()
	t_stylebox.set("bg_color", t_color)
	sign_display.add_theme_stylebox_override("panel", t_stylebox)


# Fallback texture to use if one is not provided in <initialization()>
# Or if this node is created in the editor
# Note that if the path is broken it will not cause a problem as long as aonther texture is provided in <initializaion()>
func default_texture() -> Texture2D:
	if default_texture_saved == null:
		default_texture_saved = load(DEFAULT_TEXTURE_DIR_STRING)
	return default_texture_saved


# Shows a warning in the editor if <default_texture()> returns null
func _get_configuration_warnings():
	if digit_texture == null and default_texture() == null:
		return ["Requires a digit_texture: Texture2D"]
	else:
		return []


# On entering tree checks to see if <default_texture()> returns null
func _enter_tree() -> void:
	update_configuration_warnings()


#endregion

#region SubClasses
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Class which handles math relating to digit place
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
class DigitMath:

	# Digit at a_place; i.e. 10^a_place; e.g. a_num = 8765, a_place = 1 -> 6
	# Place like 10s place
	static func digit_at(a_num: int, a_place: int) -> int:
		var t_num: int = absi(a_num)
		var t_string: String = str(t_num)
		var t_index: int = t_string.length() - a_place -1
		if t_index < 0 or t_index >= t_string.length() : 
			return 0
		return t_string[t_index].to_int()


	# Given only positive scrolling - how many times must increment be called to go from start to end?
	static func distance(a_start_digit: int, a_end_digit: int, a_is_incrementing: bool) -> int:
		var t_start: int = absi(a_start_digit) % 10
		var t_end: int = absi(a_end_digit) % 10
		if a_is_incrementing:
			if t_end > t_start:
				return t_end - t_start
			else:
				return 10 - t_start + t_end
		else:
			if t_end > t_start:
				return 10 - t_end + t_start
			else:
				return t_start -t_end


	# Register: e.g. 10s place, 1000s place
	# Returns exponent; e.g. 1000s place -> 3
	static func max_register(a_num: int) -> int:
		var t_num: int = absi(a_num)	# In case negatives are supported
		var t_string: String = str(t_num)
		var t_length: int = t_string.length()
		return t_length - 1


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Wiget which is a scrolling single digit
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
class DigitDisplay:
	extends Control
	signal counting_completed
	signal value_incremented
	signal value_decremented
	signal turned_over
	signal turned_under
	signal counting_resumed

	var list: TextureRect
	var list_image: Texture2D:
		set(a_image):
			list_image = a_image
			list.texture = list_image
			match_texture_size()
			
	var digit_height: float #= list.texture.get_size().y / 11.0		# Digits 0-9 with an addtional 0

	const MAX_VALUE: int = 9
	const MIN_VALUE: int = 0

	var value: int							# Current value displayed
	var scroll_rate: float					# Points scrolled per second;
	var is_spinning: bool					# Are we currently spinning for effect?
	var is_fast_counting: bool				# Are we currently doing fast counting?
	var is_counting: bool					# Are we currently normal counting?
	var is_stop_requested: bool				# We should stop counting

	# Is counting paused? Emits signal if resuming
	var is_counting_paused: bool = false:
		set(a_is_counting_paused):
			is_counting_paused = a_is_counting_paused
			if not is_counting_paused:
				counting_resumed.emit()


	# Called when the node enters the scene tree for the first time.
	func initialize(a_texture: Texture2D):
		clip_contents = true
		list = TextureRect.new()
		list_image = a_texture	# Note setter does stuff
		#list.texture = a_texture
		add_child(list)
		digit_height = list.texture.get_size().y / 11.0		# Digits 0-9 with an addtional 0
		match_texture_size()
		reset()


	# Sizing <self> to match texture size
	func match_texture_size():
		var t_digits: Texture2D = list.texture
		list.size = t_digits.get_size()
		custom_minimum_size = Vector2(t_digits.get_size().x, digit_height)


	# A_value is the digit to be displayed
	# Y-position of <list>
	func y_pos_from_value(a_value: int) -> float:
		return -1 * a_value * digit_height


	# Return to min_value value (usually zero)
	func reset():
		list.position = Vector2(0.0, 0.0)


	# Set position to upper zero - reset for counting backwards
	func reset_to_top():
		list.position = Vector2(0.0, y_pos_from_value(10))


	# Display next value, or reset if at max
	func increment_value():
		is_counting = true
		value += 1
		if value == 1: reset()
		var tween = get_tree().create_tween()
		var t_end: float
		if value > MAX_VALUE:
			t_end =  y_pos_from_value(MAX_VALUE + 1)
			value = 0
		else:
			t_end =  y_pos_from_value(value)
		tween.finished.connect(on_value_incremented)
		tween.tween_property(list, "position", Vector2(0.0, t_end), pow(scroll_rate, -1))


	# Display next value, or reset if at max
	func decrement_value():
		is_counting = true
		value -= 1
		if value == -1: reset_to_top()
		var tween = get_tree().create_tween()
		var t_end: float
		if value < MIN_VALUE:
			t_end =  y_pos_from_value(MAX_VALUE)
			value = MAX_VALUE
			reset_to_top()
		else:
			t_end =  y_pos_from_value(value)
		tween.finished.connect(on_value_decremented)
		tween.tween_property(list, "position", Vector2(0.0, t_end), pow(scroll_rate, -1))


	# Tidying and singals to send after each counter decrement
	func on_value_decremented():
		if value == 9:
			if not is_fast_counting:
				turned_under.emit()
		is_counting = false
		value_decremented.emit()


	# Tidying and singals to send after each counter increment
	func on_value_incremented():
		if value == 0:
			if not is_fast_counting:
				turned_over.emit()
		is_counting = false
		value_incremented.emit()


	# Increment until done
	# Requesting a stop while paused leaves an unresolved <await counting_resumed>
	# So, when stop is called we set i_index > loop-ending value, and
	# Check if loop is ended when we return from the await
	func do_counting(a_points: int, a_is_incrementing: bool):
		is_counting = true
		for i_index: int in absi(a_points):
			if is_stop_requested:
				#i_index = absi(a_points)	# Why? See func comment
				break
			if is_counting_paused:
				await counting_resumed
				#if i_index >= absi(a_points): 
					#break
			if a_is_incrementing:
				increment_value()
				await value_incremented
			else:
				decrement_value()
				await value_decremented
		is_counting = false
		counting_completed.emit()


	# Stop counting is requested
	func stop_counting():
		is_stop_requested = true


	func do_fast_counting(a_end_digit: int, a_is_incrementing: bool):
		is_fast_counting = true
		is_spinning = true
		var t_end: int = a_end_digit % 10	# Digit we want to land on once we are done spinning
		# Wheel-spinning
		while is_spinning:	# Is_spinning gets turned off by parent counter
			if is_stop_requested:
				break
			if is_counting_paused:
				await counting_resumed
			if a_is_incrementing:
				increment_value()
				await value_incremented
			else:
				decrement_value()
				await value_decremented
		if is_stop_requested:
			is_counting = false
		else:
			goto_value(t_end, a_is_incrementing)


	# Set value to a_value and teleport to position
	func set_value(a_value: int):
		value = absi(a_value) % 10
		list.position = Vector2(0.0, y_pos_from_value(value))


	# Increment until at a_value
	func goto_value(a_value: int, a_is_incrementing: bool):
		while value != a_value:
			if a_is_incrementing:
				increment_value()
				await value_incremented
			else:
				decrement_value()
				await value_decremented
		counting_completed.emit()
#endregion
