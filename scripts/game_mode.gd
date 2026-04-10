extends Node

const POINTS_TO_WIN := 30
const INTERMISSION_DURATION := 1.25
const FINISH_POINTS := [10, 7, 4, 2, 1]  # index 0 = 1st place
const ROUND_START_DELAY := 1.0  # matches HUD.ANNOUNCEMENT_DURATION
const KILL_POINTS := 5

enum State { INACTIVE, PLAYING, INTERMISSION, GAME_OVER }

signal round_started(round_number: int)
signal round_ended(finishers: Array, scores: Dictionary)
signal game_over(winner_peer_id: int, scores: Dictionary)
signal powerups_distribute(scores: Dictionary)

var state: int = State.INACTIVE
var scores: Dictionary = {}
var round_number: int = 0
var _round_active := false
var _finishers: Array = []
var _time_limit: float = 60.0
var _time_remaining: float = 0.0
var _start_delay: float = 0.0
# kills[killer_id][victim_id] = raw kill count for this game
var kills: Dictionary = {}
# total kills per player for this game (not synced to clients, server-only)
var total_kills: Dictionary = {}
# accumulated finish points separate from kill points so we can recompute at any time
var _finish_scores: Dictionary = {}

func _process(delta: float) -> void:
	if not _round_active:
		return
	if _start_delay > 0.0:
		_start_delay -= delta
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		if not NetworkManager.is_active() or multiplayer.is_server():
			_end_round()

func _broadcast(new_state: int, new_scores: Dictionary, round_num: int, event_peer_id: int, finishers: Array = []) -> void:
	if NetworkManager.is_active():
		_sync_round_state.rpc(new_state, new_scores, round_num, event_peer_id, finishers, _time_limit)
	else:
		_sync_round_state(new_state, new_scores, round_num, event_peer_id, finishers, _time_limit)

func stop_game() -> void:
	_round_active = false
	state = State.INACTIVE

func register_player(peer_id: int) -> void:
	if state != State.INACTIVE and peer_id not in scores:
		scores[peer_id] = 0
		_finish_scores[peer_id] = 0

func sync_to_peer(peer_id: int) -> void:
	_sync_round_state.rpc_id(peer_id, state, scores, round_number, -1, _finishers, _time_limit)

func start_game(time_limit: float = 60.0) -> void:
	_time_limit = time_limit
	scores.clear()
	_finish_scores.clear()
	kills.clear()
	total_kills.clear()
	for peer_id in get_parent().spawned_players:
		scores[peer_id] = 0
		_finish_scores[peer_id] = 0
	round_number = 1
	_finishers.clear()
	_broadcast(State.PLAYING, scores, round_number, -1)

func player_finished(peer_id: int) -> void:
	if not _round_active:
		return
	if peer_id in _finishers:
		return
	_finishers.append(peer_id)
	if _finishers.size() >= get_parent().spawned_players.size():
		_end_round()

func _end_round() -> void:
	if not _round_active:
		return
	_round_active = false
	for i in _finishers.size():
		var pts: int = FINISH_POINTS[i] if i < FINISH_POINTS.size() else 0
		_finish_scores[_finishers[i]] = _finish_scores.get(_finishers[i], 0) + pts
	_recompute_scores()
	var winner := _find_winner()
	_do_intermission(winner, _finishers.duplicate())

func record_kill(killer_id: int, victim_id: int) -> void:
	if not _round_active:
		return
	if killer_id not in kills:
		kills[killer_id] = {}
	kills[killer_id][victim_id] = kills[killer_id].get(victim_id, 0) + 1
	total_kills[killer_id] = total_kills.get(killer_id, 0) + 1
	_recompute_scores()
	if _find_winner() != -1:
		_end_round()
	else:
		_broadcast(state, scores, round_number, -1)

func _compute_kill_points(peer_id: int) -> int:
	var pts := 0
	for victim_id in kills.get(peer_id, {}):
		var i_killed_them: int = kills[peer_id][victim_id]
		var they_killed_me: int = kills.get(victim_id, {}).get(peer_id, 0)
		pts += max(0, i_killed_them - they_killed_me) * KILL_POINTS
	return pts

func _recompute_scores() -> void:
	for peer_id in scores:
		scores[peer_id] = _finish_scores.get(peer_id, 0) + _compute_kill_points(peer_id)

func _find_winner() -> int:
	var best_peer := -1
	var best_score := -1
	for peer_id in scores:
		if scores[peer_id] >= POINTS_TO_WIN and scores[peer_id] > best_score:
			best_score = scores[peer_id]
			best_peer = peer_id
	return best_peer

func _do_intermission(winner_peer_id: int, finishers: Array) -> void:
	_broadcast(State.INTERMISSION, scores, round_number, winner_peer_id, finishers)
	powerups_distribute.emit(scores.duplicate())
	await get_tree().create_timer(INTERMISSION_DURATION).timeout
	if state == State.INACTIVE:
		return  # level changed while waiting — bail out
	if winner_peer_id != -1:
		_broadcast(State.GAME_OVER, scores, round_number, winner_peer_id)
		return
	round_number += 1
	_finishers.clear()
	get_parent().respawn_all_at_spawn()
	_broadcast(State.PLAYING, scores, round_number, -1)

@rpc("authority", "call_local", "reliable")
func _sync_round_state(new_state: int, new_scores: Dictionary, round_num: int, event_peer_id: int, finishers: Array = [], time_limit: float = 60.0) -> void:
	state = new_state
	scores = new_scores
	round_number = round_num
	_finishers = finishers
	match new_state:
		State.PLAYING:
			_round_active = true
			_time_limit = time_limit
			_time_remaining = time_limit
			_start_delay = ROUND_START_DELAY
			round_started.emit(round_num)
		State.INTERMISSION:
			round_ended.emit(finishers, new_scores)
		State.GAME_OVER:
			_round_active = false
			game_over.emit(event_peer_id, new_scores)
