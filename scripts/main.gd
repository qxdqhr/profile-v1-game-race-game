extends Node2D
## Stage-C: start menu, pause, D-pad, obstacle types, spawn spacing, high score.

const W := 360.0
const H := 640.0
const LANES := 4
const CAR_W := 34.0
const CAR_H := 50.0
const OBS_W := 38.0
const OBS_H := 38.0
const COIN_R := 11.0
const MIN_Y := 48.0
const MAX_Y := 520.0
const VERT_STEP := 10.0
const BASE_SPEED := 200.0
const MAX_SPEED := 420.0
const SPEED_UP_EVERY := 12.0
const SPEED_UP_RATE := 22.0
const SPAWN_BASE := 1.8
const SPAWN_MIN := 0.9
const COIN_EVERY := 3.0
const MIN_SPAWN_DIST := 150.0
const LANE_COOLDOWN_MS := 200
const COIN_SCORE := 1
const HIT_SHRINK := 0.72

@onready var _car: ColorRect = $Car
@onready var _hud: Label = $UI/HUD
@onready var _menu: ColorRect = $UI/Menu
@onready var _start_btn: Button = $UI/Menu/VBox/Start
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry
@onready var _to_menu: Button = $UI/Overlay/VBox/ToMenu
@onready var _pause_ov: ColorRect = $UI/Pause
@onready var _resume: Button = $UI/Pause/VBox/Resume
@onready var _pause_retry: Button = $UI/Pause/VBox/Retry
@onready var _pause_menu: Button = $UI/Pause/VBox/ToMenu
@onready var _pause_btn: Button = $UI/PauseBtn
@onready var _obstacles: Node2D = $Obstacles
@onready var _coins: Node2D = $Coins
@onready var _lanes_vis: Node2D = $Lanes
@onready var _scroll: Node2D = $ScrollMarks
@onready var _btn_left: Button = $UI/Controls/Left
@onready var _btn_right: Button = $UI/Controls/Right
@onready var _btn_up: Button = $UI/Controls/Up
@onready var _btn_down: Button = $UI/Controls/Down
@onready var _bounds: Node2D = $Bounds

var _lane: int = 1
var _car_y: float = MAX_Y
var _speed: float = BASE_SPEED
var _spawn_iv: float = SPAWN_BASE
var _spawn_cd: float = 0.0
var _coin_cd: float = 1.0
var _score: int = 0
var _score_acc: float = 0.0
var _speed_timer: float = 0.0
var _scroll_y: float = 0.0
var _alive: bool = false
var _paused: bool = false
var _in_menu: bool = true
var _last_lane_msec: int = 0
var _rng := RandomNumberGenerator.new()
var _lane_xs: Array[float] = []

func _ready() -> void:
	_rng.randomize()
	_start_btn.pressed.connect(_begin_game)
	_retry.pressed.connect(_restart_play)
	_to_menu.pressed.connect(_show_menu)
	_resume.pressed.connect(_toggle_pause)
	_pause_retry.pressed.connect(_restart_play)
	_pause_menu.pressed.connect(_show_menu)
	_pause_btn.pressed.connect(_toggle_pause)
	_btn_left.pressed.connect(func() -> void: _steer("left"))
	_btn_right.pressed.connect(func() -> void: _steer("right"))
	_btn_up.pressed.connect(func() -> void: _steer("up"))
	_btn_down.pressed.connect(func() -> void: _steer("down"))
	_build_lanes()
	_build_bounds()
	_show_menu()

func _build_lanes() -> void:
	for c in _lanes_vis.get_children():
		c.queue_free()
	_lane_xs.clear()
	var spacing := W / float(LANES + 1)
	for i in LANES:
		_lane_xs.append(spacing * float(i + 1))
	for x in _lane_xs:
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.14)
		line.size = Vector2(2, MAX_Y - MIN_Y)
		line.position = Vector2(x - 1, MIN_Y)
		_lanes_vis.add_child(line)

func _build_bounds() -> void:
	for c in _bounds.get_children():
		c.queue_free()
	var top := ColorRect.new()
	top.color = Color(1, 1, 1, 0.35)
	top.size = Vector2(W, 2)
	top.position = Vector2(0, MIN_Y)
	_bounds.add_child(top)
	var bot := ColorRect.new()
	bot.color = Color(1, 1, 1, 0.35)
	bot.size = Vector2(W, 2)
	bot.position = Vector2(0, MAX_Y)
	_bounds.add_child(bot)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.28)
	panel.size = Vector2(W, H - MAX_Y)
	panel.position = Vector2(0, MAX_Y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bounds.add_child(panel)

func _show_menu() -> void:
	_alive = false
	_paused = false
	_in_menu = true
	_clear_world()
	_menu.visible = true
	_overlay.visible = false
	_pause_ov.visible = false
	_pause_btn.visible = false
	$UI/Controls.visible = false
	_car.visible = false
	_hud.text = "最高分 %d" % SaveData.high_score

func _begin_game() -> void:
	_in_menu = false
	_menu.visible = false
	_pause_btn.visible = true
	$UI/Controls.visible = true
	_car.visible = true
	_restart_play()

func _restart_play() -> void:
	_clear_world()
	_lane = 1
	_car_y = MAX_Y
	_speed = BASE_SPEED
	_spawn_iv = SPAWN_BASE
	_spawn_cd = 0.6
	_coin_cd = 1.2
	_score = 0
	_score_acc = 0.0
	_speed_timer = 0.0
	_scroll_y = 0.0
	_alive = true
	_paused = false
	_in_menu = false
	_overlay.visible = false
	_pause_ov.visible = false
	_menu.visible = false
	_pause_btn.visible = true
	$UI/Controls.visible = true
	_car.visible = true
	_place_car()
	_rebuild_scroll()
	_update_hud()

func _clear_world() -> void:
	for c in _obstacles.get_children():
		c.queue_free()
	for c in _coins.get_children():
		c.queue_free()
	for c in _scroll.get_children():
		c.queue_free()

func _lane_x(i: int) -> float:
	return _lane_xs[clampi(i, 0, LANES - 1)]

func _place_car() -> void:
	_car.size = Vector2(CAR_W, CAR_H)
	_car.position = Vector2(_lane_x(_lane) - CAR_W * 0.5, _car_y - CAR_H * 0.5)
	_car.color = Color(0.30, 0.78, 0.48)

func _update_hud() -> void:
	var mult := _speed / BASE_SPEED
	_hud.text = "得分 %d  最高 %d\n速度 %.1fx" % [_score, SaveData.high_score, mult]

func _toggle_pause() -> void:
	if _in_menu or not _alive:
		return
	_paused = not _paused
	_pause_ov.visible = _paused

func _steer(dir: String) -> void:
	if not _alive or _paused or _in_menu:
		return
	match dir:
		"up":
			_car_y = maxf(MIN_Y + CAR_H * 0.5, _car_y - VERT_STEP)
		"down":
			_car_y = minf(MAX_Y - CAR_H * 0.5, _car_y + VERT_STEP)
		"left":
			if not _can_lane_move():
				return
			_lane = maxi(0, _lane - 1)
			_last_lane_msec = Time.get_ticks_msec()
		"right":
			if not _can_lane_move():
				return
			_lane = mini(LANES - 1, _lane + 1)
			_last_lane_msec = Time.get_ticks_msec()
	_place_car()

func _can_lane_move() -> bool:
	return Time.get_ticks_msec() - _last_lane_msec >= LANE_COOLDOWN_MS

func _process(delta: float) -> void:
	if not _alive or _paused or _in_menu:
		return
	_score_acc += delta * (_speed / BASE_SPEED)
	if _score_acc >= 1.0:
		_score += int(_score_acc)
		_score_acc -= float(int(_score_acc))
		_update_hud()
	_speed_timer += delta
	if _speed_timer >= SPEED_UP_EVERY:
		_speed_timer = 0.0
		_speed = minf(MAX_SPEED, _speed + SPEED_UP_RATE)
		_spawn_iv = maxf(SPAWN_MIN, _spawn_iv - 0.1)
		_update_hud()
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_obstacle()
		_spawn_cd = _spawn_iv
	_coin_cd -= delta
	if _coin_cd <= 0.0:
		_spawn_coin()
		_coin_cd = COIN_EVERY
	_scroll_y += _speed * delta
	_rebuild_scroll()
	_move_entities(delta)
	_check_collisions()

func _rebuild_scroll() -> void:
	for c in _scroll.get_children():
		c.queue_free()
	var gap := 48.0
	var offset := fmod(_scroll_y, gap)
	var y := MIN_Y - offset
	while y < MAX_Y:
		var mark := ColorRect.new()
		mark.color = Color(1, 1, 1, 0.08)
		mark.size = Vector2(W - 40.0, 10.0)
		mark.position = Vector2(20.0, y)
		_scroll.add_child(mark)
		y += gap

func _spawn_ok(lane: int, y: float) -> bool:
	for c in _obstacles.get_children():
		var r := c as ColorRect
		if int(r.get_meta("lane")) == lane and absf(r.position.y - y) < MIN_SPAWN_DIST:
			return false
	for c in _coins.get_children():
		var p := c as Polygon2D
		if bool(p.get_meta("collected", false)):
			continue
		if int(p.get_meta("lane")) == lane and absf(p.position.y - y) < MIN_SPAWN_DIST:
			return false
	return true

func _spawn_obstacle() -> void:
	for _i in 10:
		var lane := _rng.randi_range(0, LANES - 1)
		var y := -OBS_H
		if not _spawn_ok(lane, y):
			continue
		var kind: int = _rng.randi_range(0, 2) ## 0 rock 1 cone 2 barrier
		var rect := ColorRect.new()
		rect.size = Vector2(OBS_W, OBS_H)
		match kind:
			0:
				rect.color = Color(0.55, 0.52, 0.48)
			1:
				rect.color = Color(0.95, 0.55, 0.15)
				rect.size = Vector2(OBS_W * 0.7, OBS_H)
			_:
				rect.color = Color(0.85, 0.28, 0.28)
				rect.size = Vector2(OBS_W, OBS_H * 0.55)
		rect.position = Vector2(_lane_x(lane) - rect.size.x * 0.5, y)
		rect.set_meta("lane", lane)
		_obstacles.add_child(rect)
		return

func _spawn_coin() -> void:
	for _i in 10:
		var lane := _rng.randi_range(0, LANES - 1)
		var y := -COIN_R
		if not _spawn_ok(lane, y):
			continue
		var poly := Polygon2D.new()
		poly.color = Color(1.0, 0.84, 0.2)
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			pts.append(Vector2(cos(a), sin(a)) * COIN_R)
		poly.polygon = pts
		poly.position = Vector2(_lane_x(lane), y)
		poly.set_meta("lane", lane)
		poly.set_meta("collected", false)
		_coins.add_child(poly)
		return

func _move_entities(delta: float) -> void:
	var dy := _speed * delta
	for c in _obstacles.get_children():
		var r := c as ColorRect
		r.position.y += dy
		if r.position.y > H:
			r.queue_free()
	for c in _coins.get_children():
		var p := c as Polygon2D
		if bool(p.get_meta("collected", false)):
			continue
		p.position.y += dy
		if p.position.y > H:
			p.queue_free()

func _hit_rect(base: Rect2) -> Rect2:
	var shrink := (1.0 - HIT_SHRINK) * 0.5
	return Rect2(
		base.position + base.size * shrink,
		base.size * HIT_SHRINK
	)

func _check_collisions() -> void:
	var car_rect := _hit_rect(Rect2(_car.position, _car.size))
	for c in _obstacles.get_children():
		var r := c as ColorRect
		if car_rect.intersects(_hit_rect(Rect2(r.position, r.size))):
			_game_over()
			return
	for c in _coins.get_children():
		var p := c as Polygon2D
		if bool(p.get_meta("collected", false)):
			continue
		var coin_rect := Rect2(p.position - Vector2(COIN_R, COIN_R), Vector2(COIN_R * 2, COIN_R * 2))
		if car_rect.intersects(coin_rect):
			p.set_meta("collected", true)
			p.queue_free()
			_score += COIN_SCORE
			_update_hud()

func _game_over() -> void:
	_alive = false
	_paused = false
	_pause_ov.visible = false
	var best: int = SaveData.record(_score)
	_over_msg.text = "撞车！\n得分 %d\n最高 %d" % [_score, best]
	_overlay.visible = true
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _in_menu:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				_toggle_pause()
				return
			KEY_ESCAPE:
				if _paused or not _alive:
					_show_menu()
				return
			KEY_R:
				if _paused or not _alive:
					_restart_play()
				return
	if not _alive or _paused:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_steer("left")
			KEY_RIGHT, KEY_D:
				_steer("right")
			KEY_UP, KEY_W:
				_steer("up")
			KEY_DOWN, KEY_S:
				_steer("down")
