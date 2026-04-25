class_name EightBallLogic

const DEFAULT_IDLE_MESSAGE := "Challenge another player to an 8-ball match."

const TABLE_SIZE := Vector2(980.0, 560.0)
const PLAYFIELD_RECT := Rect2(Vector2(118.0, 118.0), Vector2(744.0, 324.0))
const BALL_RADIUS := 11.5
const POCKET_RADIUS := 28.0
const STEP_DELTA := 1.0 / 60.0
const MAX_SIMULATION_STEPS := 900
const SAMPLE_INTERVAL := 2
const MIN_SHOT_SPEED := 240.0
const MAX_SHOT_SPEED := 1220.0
const STOP_SPEED := 8.0
const BALL_RESTITUTION := 0.985
const RAIL_RESTITUTION := 0.94
const FRICTION := 0.991
const CUE_BALL_START := Vector2(PLAYFIELD_RECT.position.x + PLAYFIELD_RECT.size.x * 0.23, PLAYFIELD_RECT.position.y + PLAYFIELD_RECT.size.y * 0.5)
const RACK_APEX := Vector2(PLAYFIELD_RECT.position.x + PLAYFIELD_RECT.size.x * 0.76, PLAYFIELD_RECT.position.y + PLAYFIELD_RECT.size.y * 0.5)
const POCKET_POSITIONS := [
	Vector2(PLAYFIELD_RECT.position.x, PLAYFIELD_RECT.position.y),
	Vector2(PLAYFIELD_RECT.position.x + PLAYFIELD_RECT.size.x * 0.5, PLAYFIELD_RECT.position.y - 4.0),
	Vector2(PLAYFIELD_RECT.end.x, PLAYFIELD_RECT.position.y),
	Vector2(PLAYFIELD_RECT.position.x, PLAYFIELD_RECT.end.y),
	Vector2(PLAYFIELD_RECT.position.x + PLAYFIELD_RECT.size.x * 0.5, PLAYFIELD_RECT.end.y + 4.0),
	Vector2(PLAYFIELD_RECT.end.x, PLAYFIELD_RECT.end.y),
]
const RACK_ROWS := [
	[1],
	[9, 2],
	[10, 8, 3],
	[11, 4, 12, 5],
	[13, 6, 14, 7, 15],
]


static func create_idle_session(message: String = DEFAULT_IDLE_MESSAGE) -> Dictionary:
	return {
		"phase": "idle",
		"challenger_id": 0,
		"opponent_id": 0,
		"current_turn": 0,
		"breaker_id": 0,
		"winner_id": 0,
		"assignments": {},
		"balls": _make_rack_balls(),
		"message": message,
		"animation_id": 0,
		"animation_frames": [],
		"last_shooter_id": 0,
		"pocketed_last": [],
	}


static func create_invite_session(challenger_id: int, opponent_id: int) -> Dictionary:
	var session := create_idle_session()
	session["phase"] = "invite"
	session["challenger_id"] = challenger_id
	session["opponent_id"] = opponent_id
	session["message"] = "Challenge pending."
	return session


static func create_match_session(challenger_id: int, opponent_id: int) -> Dictionary:
	var session := create_idle_session("Break and clear the table.")
	session["phase"] = "active"
	session["challenger_id"] = challenger_id
	session["opponent_id"] = opponent_id
	session["current_turn"] = challenger_id
	session["breaker_id"] = challenger_id
	session["balls"] = _make_rack_balls()
	return session


static func is_participant(session: Dictionary, peer_id: int) -> bool:
	return peer_id != 0 and (int(session.get("challenger_id", 0)) == peer_id or int(session.get("opponent_id", 0)) == peer_id)


static func other_participant(session: Dictionary, peer_id: int) -> int:
	var challenger_id := int(session.get("challenger_id", 0))
	var opponent_id := int(session.get("opponent_id", 0))
	if challenger_id == peer_id:
		return opponent_id
	if opponent_id == peer_id:
		return challenger_id
	return 0


static func assignment_for(session: Dictionary, peer_id: int) -> String:
	var assignments: Dictionary = session.get("assignments", {})
	return String(assignments.get(peer_id, ""))


static func is_shot_allowed(session: Dictionary, peer_id: int) -> bool:
	return String(session.get("phase", "")) == "active" and int(session.get("current_turn", 0)) == peer_id


static func apply_shot(session: Dictionary, shooter_id: int, angle: float, power: float, animation_id: int) -> Dictionary:
	if not is_shot_allowed(session, shooter_id):
		return session

	var next: Dictionary = session.duplicate(true)
	var sim_balls := _make_sim_balls(next.get("balls", []))
	var cue_ball: Dictionary = _get_sim_ball(sim_balls, 0)
	if cue_ball.is_empty():
		return session

	cue_ball["pocketed"] = false
	cue_ball["pos"] = _clamp_inside_table(cue_ball.get("pos", CUE_BALL_START))
	cue_ball["vel"] = Vector2.from_angle(angle) * lerpf(MIN_SHOT_SPEED, MAX_SHOT_SPEED, clampf(power, 0.0, 1.0))

	var pocketed_this_turn: Array = []
	var frames: Array = [_snapshot_sim_balls(sim_balls)]
	var steps_without_motion := 0

	for step in range(MAX_SIMULATION_STEPS):
		_move_balls(sim_balls)
		_resolve_ball_collisions(sim_balls)
		_resolve_rail_collisions(sim_balls)
		_collect_pocketed(sim_balls, pocketed_this_turn)
		var moving := _apply_friction(sim_balls)
		if step % SAMPLE_INTERVAL == 0:
			frames.append(_snapshot_sim_balls(sim_balls))
		if moving:
			steps_without_motion = 0
		else:
			steps_without_motion += 1
			if steps_without_motion >= 4:
				break

	frames.append(_snapshot_sim_balls(sim_balls))

	next["balls"] = _to_state_balls(sim_balls)
	next["animation_id"] = animation_id
	next["animation_frames"] = frames
	next["last_shooter_id"] = shooter_id
	next["pocketed_last"] = pocketed_this_turn.duplicate()

	var assignments: Dictionary = next.get("assignments", {})
	var opponent_id := other_participant(next, shooter_id)
	var shooter_group := String(assignments.get(shooter_id, ""))
	var solids_pocketed: Array = []
	var stripes_pocketed: Array = []
	for ball_id in pocketed_this_turn:
		if is_solid(int(ball_id)):
			solids_pocketed.append(int(ball_id))
		elif is_stripe(int(ball_id)):
			stripes_pocketed.append(int(ball_id))
	var cue_scratched := pocketed_this_turn.has(0)
	var eight_pocketed := pocketed_this_turn.has(8)

	if shooter_group.is_empty():
		if not solids_pocketed.is_empty() and stripes_pocketed.is_empty():
			assignments[shooter_id] = "solids"
			assignments[opponent_id] = "stripes"
		elif not stripes_pocketed.is_empty() and solids_pocketed.is_empty():
			assignments[shooter_id] = "stripes"
			assignments[opponent_id] = "solids"
		next["assignments"] = assignments
		shooter_group = String(assignments.get(shooter_id, ""))

	if cue_scratched:
		_respot_cue_ball(next.get("balls", []))

	if eight_pocketed:
		var shooter_cleared := not shooter_group.is_empty() and remaining_group_balls(next.get("balls", []), shooter_group) == 0
		next["phase"] = "finished"
		next["winner_id"] = opponent_id if cue_scratched or not shooter_cleared else shooter_id
		next["current_turn"] = 0
		next["message"] = "The 8-ball drops."
		return next

	var turn_continues := false
	if cue_scratched:
		turn_continues = false
	elif shooter_group.is_empty():
		turn_continues = not solids_pocketed.is_empty() or not stripes_pocketed.is_empty()
	elif shooter_group == "solids":
		turn_continues = not solids_pocketed.is_empty()
	else:
		turn_continues = not stripes_pocketed.is_empty()

	next["current_turn"] = shooter_id if turn_continues else opponent_id
	next["message"] = "Scratch. Turn passes." if cue_scratched else ("Shot made. Keep shooting." if turn_continues else "Turn passes.")
	return next


static func remaining_group_balls(balls: Array, group_name: String) -> int:
	var remaining := 0
	for ball in balls:
		if bool(ball.get("pocketed", false)):
			continue
		var ball_id := int(ball.get("id", -1))
		if group_name == "solids" and is_solid(ball_id):
			remaining += 1
		elif group_name == "stripes" and is_stripe(ball_id):
			remaining += 1
	return remaining


static func is_solid(ball_id: int) -> bool:
	return ball_id >= 1 and ball_id <= 7


static func is_stripe(ball_id: int) -> bool:
	return ball_id >= 9 and ball_id <= 15


static func ball_color(ball_id: int) -> Color:
	match ball_id:
		0:
			return Color(0.97, 0.97, 0.95)
		1, 9:
			return Color(0.98, 0.82, 0.20)
		2, 10:
			return Color(0.18, 0.42, 0.88)
		3, 11:
			return Color(0.79, 0.16, 0.18)
		4, 12:
			return Color(0.44, 0.24, 0.74)
		5, 13:
			return Color(0.96, 0.48, 0.12)
		6, 14:
			return Color(0.12, 0.56, 0.24)
		7, 15:
			return Color(0.55, 0.12, 0.15)
		8:
			return Color(0.08, 0.09, 0.12)
		_:
			return Color(0.75, 0.75, 0.75)


static func _make_rack_balls() -> Array:
	var balls: Array = [{
		"id": 0,
		"pos": CUE_BALL_START,
		"pocketed": false,
	}]
	var row_spacing := BALL_RADIUS * 1.82
	var column_spacing := BALL_RADIUS * 2.06
	for row_index in range(RACK_ROWS.size()):
		var row: Array = RACK_ROWS[row_index]
		var x := RACK_APEX.x + column_spacing * row_index
		var start_y := RACK_APEX.y - row_spacing * row.size() * 0.5 + row_spacing * 0.5
		for ball_index in range(row.size()):
			balls.append({
				"id": int(row[ball_index]),
				"pos": Vector2(x, start_y + row_spacing * ball_index),
				"pocketed": false,
			})
	return balls


static func _make_sim_balls(state_balls: Array) -> Array:
	var sim_balls: Array = []
	for ball in state_balls:
		sim_balls.append({
			"id": int(ball.get("id", -1)),
			"pos": Vector2(ball.get("pos", Vector2.ZERO)),
			"vel": Vector2.ZERO,
			"pocketed": bool(ball.get("pocketed", false)),
		})
	return sim_balls


static func _to_state_balls(sim_balls: Array) -> Array:
	var result: Array = []
	for ball in sim_balls:
		result.append({
			"id": int(ball.get("id", -1)),
			"pos": Vector2(ball.get("pos", Vector2.ZERO)),
			"pocketed": bool(ball.get("pocketed", false)),
		})
	return result


static func _snapshot_sim_balls(sim_balls: Array) -> Array:
	var frame: Array = []
	for ball in sim_balls:
		frame.append({
			"id": int(ball.get("id", -1)),
			"pos": Vector2(ball.get("pos", Vector2.ZERO)),
			"pocketed": bool(ball.get("pocketed", false)),
		})
	return frame


static func _get_sim_ball(sim_balls: Array, ball_id: int) -> Dictionary:
	for ball in sim_balls:
		if int(ball.get("id", -1)) == ball_id:
			return ball
	return {}


static func _move_balls(sim_balls: Array) -> void:
	for ball in sim_balls:
		if bool(ball.get("pocketed", false)):
			continue
		ball["pos"] = Vector2(ball.get("pos", Vector2.ZERO)) + Vector2(ball.get("vel", Vector2.ZERO)) * STEP_DELTA


static func _resolve_rail_collisions(sim_balls: Array) -> void:
	var min_x := PLAYFIELD_RECT.position.x + BALL_RADIUS
	var max_x := PLAYFIELD_RECT.end.x - BALL_RADIUS
	var min_y := PLAYFIELD_RECT.position.y + BALL_RADIUS
	var max_y := PLAYFIELD_RECT.end.y - BALL_RADIUS
	for ball in sim_balls:
		if bool(ball.get("pocketed", false)):
			continue
		var pos := Vector2(ball.get("pos", Vector2.ZERO))
		var vel := Vector2(ball.get("vel", Vector2.ZERO))
		if pos.x < min_x:
			pos.x = min_x
			vel.x = absf(vel.x) * RAIL_RESTITUTION
		elif pos.x > max_x:
			pos.x = max_x
			vel.x = -absf(vel.x) * RAIL_RESTITUTION
		if pos.y < min_y:
			pos.y = min_y
			vel.y = absf(vel.y) * RAIL_RESTITUTION
		elif pos.y > max_y:
			pos.y = max_y
			vel.y = -absf(vel.y) * RAIL_RESTITUTION
		ball["pos"] = pos
		ball["vel"] = vel


static func _resolve_ball_collisions(sim_balls: Array) -> void:
	var min_distance := BALL_RADIUS * 2.0
	for i in range(sim_balls.size()):
		var a: Dictionary = sim_balls[i]
		if bool(a.get("pocketed", false)):
			continue
		for j in range(i + 1, sim_balls.size()):
			var b: Dictionary = sim_balls[j]
			if bool(b.get("pocketed", false)):
				continue
			var delta := Vector2(b.get("pos", Vector2.ZERO)) - Vector2(a.get("pos", Vector2.ZERO))
			var distance := delta.length()
			if distance <= 0.0001 or distance >= min_distance:
				continue
			var normal := delta / distance
			var tangent := Vector2(-normal.y, normal.x)
			var overlap := min_distance - distance
			a["pos"] = Vector2(a.get("pos", Vector2.ZERO)) - normal * (overlap * 0.5)
			b["pos"] = Vector2(b.get("pos", Vector2.ZERO)) + normal * (overlap * 0.5)
			var a_velocity := Vector2(a.get("vel", Vector2.ZERO))
			var b_velocity := Vector2(b.get("vel", Vector2.ZERO))
			var a_normal := normal * a_velocity.dot(normal)
			var b_normal := normal * b_velocity.dot(normal)
			var a_tangent := tangent * a_velocity.dot(tangent)
			var b_tangent := tangent * b_velocity.dot(tangent)
			a["vel"] = (b_normal + a_tangent) * BALL_RESTITUTION
			b["vel"] = (a_normal + b_tangent) * BALL_RESTITUTION


static func _collect_pocketed(sim_balls: Array, pocketed_ids: Array) -> void:
	for ball in sim_balls:
		if bool(ball.get("pocketed", false)):
			continue
		var pos := Vector2(ball.get("pos", Vector2.ZERO))
		for pocket_pos in POCKET_POSITIONS:
			if pos.distance_to(pocket_pos) <= POCKET_RADIUS:
				ball["pocketed"] = true
				ball["vel"] = Vector2.ZERO
				ball["pos"] = pocket_pos
				var ball_id := int(ball.get("id", -1))
				if not pocketed_ids.has(ball_id):
					pocketed_ids.append(ball_id)
				break


static func _apply_friction(sim_balls: Array) -> bool:
	var any_moving := false
	for ball in sim_balls:
		if bool(ball.get("pocketed", false)):
			continue
		var velocity := Vector2(ball.get("vel", Vector2.ZERO)) * FRICTION
		if velocity.length() < STOP_SPEED:
			velocity = Vector2.ZERO
		else:
			any_moving = true
		ball["vel"] = velocity
	return any_moving


static func _respot_cue_ball(state_balls: Array) -> void:
	for ball in state_balls:
		if int(ball.get("id", -1)) == 0:
			ball["pocketed"] = false
			ball["pos"] = CUE_BALL_START
			return


static func _clamp_inside_table(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, PLAYFIELD_RECT.position.x + BALL_RADIUS, PLAYFIELD_RECT.end.x - BALL_RADIUS),
		clampf(pos.y, PLAYFIELD_RECT.position.y + BALL_RADIUS, PLAYFIELD_RECT.end.y - BALL_RADIUS)
	)
