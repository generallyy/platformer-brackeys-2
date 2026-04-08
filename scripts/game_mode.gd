extends Node

const POINTS_TO_WIN := 5
const INTERMISSION_DURATION := 3.0

enum State { INACTIVE, PLAYING, INTERMISSION, GAME_OVER }

signal round_started(round_number: int)
signal round_ended(scorer_peer_id: int, scores: Dictionary)
signal game_over(winner_peer_id: int, scores: Dictionary)
signal powerups_distribute(scores: Dictionary)  # hook — connect externally when ready

var state: int = State.INACTIVE
var scores: Dictionary = {}
var round_number: int = 0
var _round_active := false

func _broadcast(new_state: int, new_scores: Dictionary, round_num: int, event_peer_id: int) -> void:
	if NetworkManager.is_active():
		_sync_round_state.rpc(new_state, new_scores, round_num, event_peer_id)
	else:
		_sync_round_state(new_state, new_scores, round_num, event_peer_id)

func start_game() -> void:
	scores.clear()
	for peer_id in get_parent().spawned_players:
		scores[peer_id] = 0
	round_number = 1
	_broadcast(State.PLAYING, scores, round_number, -1)

func goal_reached(peer_id: int) -> void:
	if not _round_active:
		return
	_round_active = false
	scores[peer_id] = scores.get(peer_id, 0) + 1
	_do_intermission(peer_id)

func _do_intermission(scorer_peer_id: int) -> void:
	_broadcast(State.INTERMISSION, scores, round_number, scorer_peer_id)
	powerups_distribute.emit(scores.duplicate())  # future powerup hook
	await get_tree().create_timer(INTERMISSION_DURATION).timeout
	if scores.get(scorer_peer_id, 0) >= POINTS_TO_WIN:
		_broadcast(State.GAME_OVER, scores, round_number, scorer_peer_id)
		return
	round_number += 1
	get_parent().respawn_all_at_spawn()
	_broadcast(State.PLAYING, scores, round_number, -1)

@rpc("authority", "call_local", "reliable")
func _sync_round_state(new_state: int, new_scores: Dictionary, round_num: int, event_peer_id: int) -> void:
	state = new_state
	scores = new_scores
	round_number = round_num
	match new_state:
		State.PLAYING:
			_round_active = true
			round_started.emit(round_num)
		State.INTERMISSION:
			round_ended.emit(event_peer_id, new_scores)
		State.GAME_OVER:
			_round_active = false
			game_over.emit(event_peer_id, new_scores)
