extends Node2D

const RIBBON_COUNT      := 24
const POINTS_PER_RIBBON := 48
const BASE_RADIUS       := 55.0
const SPIN_SPEED        := 4
const START_ANGLE       := 0.0
const WRAP_ANGLE        := PI * 1.6
const MAX_WIDTH         := 26.0
const MIN_WIDTH_SCALE   := 0.12
const MIN_RADIUS_SCALE  := 0.6
const MAX_RADIUS_SCALE  := 1.35
const MIN_LIFETIME      := 1.5
const MAX_LIFETIME      := 4.0
const FADE_DURATION     := 0.5
const BORDER_EXTRA      := 5.0   # how many px wider the border is than the main ribbon
const SHINE_WIDTH_FRAC  := 0.0  # shine line width as a fraction of MAX_WIDTH

var _borders: Array = []   # Line2D behind main (dark outline)
var _ribbons: Array = []   # Line2D main fire ribbon
var _shines: Array = []    # Line2D on top (bright specular highlight)
var _width_curves: Array = []
var _basis_u: Array = []
var _basis_v: Array = []
var _radii: Array = []
var _ages: Array = []
var _lifetimes: Array = []
var _time := 0.0


func _ready() -> void:
	randomize()
	# Add all borders first, then mains, then shines so z-order is correct
	# across all ribbons without needing z_index.
	for i in RIBBON_COUNT:
		var lifetime := randf_range(MIN_LIFETIME, MAX_LIFETIME)
		_lifetimes.append(lifetime)
		_ages.append(randf_range(0.0, lifetime))
		_basis_u.append(Vector3.ZERO)
		_basis_v.append(Vector3.ZERO)
		_radii.append(0.0)

		var wc := _make_width_curve_preallocated()
		_width_curves.append(wc)

		var border := Line2D.new()
		border.width          = MAX_WIDTH + BORDER_EXTRA
		border.width_curve    = wc
		border.gradient       = _make_border_gradient()
		border.joint_mode     = Line2D.LINE_JOINT_ROUND
		border.begin_cap_mode = Line2D.LINE_CAP_NONE
		border.end_cap_mode   = Line2D.LINE_CAP_NONE
		_borders.append(border)

		var line := Line2D.new()
		line.width          = MAX_WIDTH
		line.width_curve    = wc
		line.gradient       = _make_fire_gradient()
		line.joint_mode     = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_NONE
		line.end_cap_mode   = Line2D.LINE_CAP_NONE
		_ribbons.append(line)

		var shine := Line2D.new()
		shine.width          = MAX_WIDTH * SHINE_WIDTH_FRAC
		shine.width_curve    = wc
		shine.gradient       = _make_shine_gradient()
		shine.joint_mode     = Line2D.LINE_JOINT_ROUND
		shine.begin_cap_mode = Line2D.LINE_CAP_NONE
		shine.end_cap_mode   = Line2D.LINE_CAP_NONE
		_shines.append(shine)

		_randomize_ribbon(i)

	for b in _borders: add_child(b)
	for r in _ribbons: add_child(r)
	for s in _shines:  add_child(s)


func _randomize_ribbon(i: int) -> void:
	var axis := _random_unit_vector()
	var ref  := Vector3(0.0, 1.0, 0.0) if abs(axis.y) < 0.9 else Vector3(1.0, 0.0, 0.0)
	var u    := axis.cross(ref).normalized()
	var v    := axis.cross(u).normalized()
	_basis_u[i] = u
	_basis_v[i] = v
	_radii[i]   = randf_range(BASE_RADIUS * MIN_RADIUS_SCALE, BASE_RADIUS * MAX_RADIUS_SCALE)


func _random_unit_vector() -> Vector3:
	var v := Vector3.ZERO
	while v.length_squared() < 0.001 or v.length_squared() > 1.0:
		v = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	return v.normalized()


func _make_fire_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.15, 0.0, 0.0, 0.0))
	g.add_point(0.25, Color(1.0, 0.25, 0.0, 0.95))
	g.add_point(0.55, Color(0.7,  0.05, 0.0, 0.6))
	g.add_point(0.80, Color(0.35, 0.0,  0.0, 0.25))
	return g


func _make_border_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.0, 0.0, 0.95))
	g.set_color(1, Color(0.15, 0.0, 0.0, 0.0))
	g.add_point(0.4, Color(0.35, 0.0, 0.0, 0.75))
	g.add_point(0.8, Color(0.2,  0.0, 0.0, 0.2))
	return g


func _make_shine_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.85, 0.85))
	g.set_color(1, Color(1.0, 0.8,  0.5,  0.0))
	g.add_point(0.2, Color(1.0, 0.92, 0.75, 0.55))
	g.add_point(0.5, Color(1.0, 0.75, 0.4,  0.18))
	return g


func _make_width_curve_preallocated() -> Curve:
	var c := Curve.new()
	for i in POINTS_PER_RIBBON:
		c.add_point(Vector2(float(i) / float(POINTS_PER_RIBBON - 1), 1.0))
	return c


func _process(delta: float) -> void:
	_time += delta
	for i in RIBBON_COUNT:
		_ages[i] += delta
		var age      := _ages[i] as float
		var lifetime := _lifetimes[i] as float

		if age >= lifetime:
			_ages[i]      = 0.0
			_lifetimes[i] = randf_range(MIN_LIFETIME, MAX_LIFETIME)
			_randomize_ribbon(i)
			age = 0.0

		var alpha := 1.0
		if age < FADE_DURATION:
			alpha = age / FADE_DURATION
		elif age > lifetime - FADE_DURATION:
			alpha = (lifetime - age) / FADE_DURATION

		var angle := _time * SPIN_SPEED + TAU * i / float(RIBBON_COUNT)
		var u0    := _basis_u[i] as Vector3
		var v0    := _basis_v[i] as Vector3
		var u     := u0 * cos(angle) + v0 * sin(angle)
		var v     := v0 * cos(angle) - u0 * sin(angle)

		var pts := PackedVector2Array()
		pts.resize(POINTS_PER_RIBBON)
		var wc := _width_curves[i] as Curve
		var r  := _radii[i] as float

		for j in POINTS_PER_RIBBON:
			var t   := float(j) / float(POINTS_PER_RIBBON - 1)
			var a   := START_ANGLE + (1.0 - t) * WRAP_ANGLE
			var pt3 := (u * cos(a) + v * sin(a)) * r
			pts[j] = Vector2(pt3.x, -pt3.y)
			var w := remap(pt3.z, -r, r, MIN_WIDTH_SCALE, 1.0)
			wc.set_point_value(j, clampf(w, MIN_WIDTH_SCALE, 1.0))
		wc.bake()

		(_borders[i] as Line2D).points    = pts
		(_borders[i] as Line2D).modulate.a = alpha
		(_ribbons[i] as Line2D).points    = pts
		(_ribbons[i] as Line2D).modulate.a = alpha
		(_shines[i]  as Line2D).points    = pts
		(_shines[i]  as Line2D).modulate.a = alpha
