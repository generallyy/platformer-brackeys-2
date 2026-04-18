extends Node

var points_to_win: int
const INTERMISSION_DURATION := 30.0
const FINISH_POINTS := [10, 7, 4, 2, 1]  # index 0 = 1st place
const ROUND_START_DELAY := 1.0  # matches HUD.ANNOUNCEMENT_DURATION
const KILL_POINTS := 5
const STOCKS_PER_ROUND := 3

enum State { INACTIVE, PLAYING, INTERMISSION, GAME_OVER }

signal round_started(round_number: int)
signal round_ended(finishers: Array, scores: Dictionary)
signal game_over(winner_peer_id: int, scores: Dictionary)
signal powerups_distribute(scores: Dictionary, finishers: Array)
signal scores_changed(scores: Dictionary)
signal stocks_changed(stocks: Dictionary)
signal kda_changed(kda_kills: Dictionary, kda_deaths: Dictionary, kda_damage: Dictionary)

var state: int = State.INACTIVE
var sudden_death_peers: Array = []  # non-empty only during a sudden death round
var _n_picked := 0
var _intermission_gen := 0
var scores: Dictionary = {}
var stocks: Dictionary = {}
var kda_kills: Dictionary = {}
var kda_deaths: Dictionary = {}
var kda_damage: Dictionary = {}
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

func _broadcast_scores() -> void:
	if NetworkManager.is_active():
		_sync_scores.rpc(scores)
	else:
		_sync_scores(scores)

@rpc("authority", "call_local", "reliable")
func _sync_scores(new_scores: Dictionary) -> void:
	scores = new_scores
	scores_changed.emit(scores)

func stop_game() -> void:
	_round_active = false
	state = State.INACTIVE
	kda_kills.clear()
	kda_deaths.clear()
	kda_damage.clear()
	kda_changed.emit(kda_kills, kda_deaths, kda_damage)

func register_player(peer_id: int) -> void:
	if state != State.INACTIVE and peer_id not in scores:
		scores[peer_id] = 0
		_finish_scores[peer_id] = 0
		stocks[peer_id] = STOCKS_PER_ROUND

func sync_to_peer(peer_id: int) -> void:
	_sync_round_state.rpc_id(peer_id, state, scores, round_number, -1, _finishers, _time_limit)

func start_game(time_limit: float = 60.0, win_score: int = 30) -> void:
	_time_limit = time_limit
	points_to_win = win_score
	scores.clear()
	_finish_scores.clear()
	kills.clear()
	total_kills.clear()
	stocks.clear()
	for peer_id in get_parent().spawned_players:
		scores[peer_id] = 0
		_finish_scores[peer_id] = 0
		stocks[peer_id] = STOCKS_PER_ROUND
	round_number = 1
	_finishers.clear()
	_broadcast(State.PLAYING, scores, round_number, -1)

func player_finished(peer_id: int) -> void:
	if not _round_active:
		return
	if peer_id in _finishers:
		return
	_finishers.append(peer_id)
	if sudden_death_peers.size() > 0 and peer_id in sudden_death_peers:
		_round_active = false
		_do_intermission(peer_id, _finishers.duplicate())
		return
	_check_all_done()

func _check_all_done() -> void:
	if not _round_active:
		return
	if sudden_death_peers.size() > 0:
		# During sudden death, only end the round when all tied peers are out of stocks
		for peer_id in sudden_death_peers:
			if peer_id in get_parent().spawned_players:
				if peer_id not in _finishers and stocks.get(peer_id, STOCKS_PER_ROUND) > 0:
					return
		_end_round()
		return
	for peer_id in get_parent().spawned_players:
		if peer_id not in _finishers and stocks.get(peer_id, STOCKS_PER_ROUND) > 0:
			return
	_end_round()

func _end_round() -> void:
	if not _round_active:
		return
	_round_active = false
	sudden_death_peers = []
	for i in _finishers.size():
		var pts: int = FINISH_POINTS[i] if i < FINISH_POINTS.size() else 0
		_finish_scores[_finishers[i]] = _finish_scores.get(_finishers[i], 0) + pts
	for peer_id in scores:
		_finish_scores[peer_id] = _finish_scores.get(peer_id, 0) + _compute_kill_points(peer_id)
	kills.clear()
	total_kills.clear()
	_recompute_scores()
	var winner := _find_winner()
	var tied := _find_tied_leaders() if winner == -1 else []
	_do_intermission(winner, _finishers.duplicate(), tied)

func record_kill(killer_id: int, victim_id: int) -> void:
	kda_kills[killer_id] = kda_kills.get(killer_id, 0) + 1
	kda_deaths[victim_id] = kda_deaths.get(victim_id, 0) + 1
	_broadcast_kda()
	if not _round_active:
		return
	if killer_id not in kills:
		kills[killer_id] = {}
	kills[killer_id][victim_id] = kills[killer_id].get(victim_id, 0) + 1
	total_kills[killer_id] = total_kills.get(killer_id, 0) + 1
	if victim_id in stocks and stocks[victim_id] > 0:
		stocks[victim_id] -= 1
	_broadcast_stocks()
	_check_all_done()

func record_death(victim_id: int) -> void:
	kda_deaths[victim_id] = kda_deaths.get(victim_id, 0) + 1
	_broadcast_kda()
	if not _round_active:
		return
	if victim_id in stocks and stocks[victim_id] > 0:
		stocks[victim_id] -= 1
	_broadcast_stocks()
	_check_all_done()

func can_respawn(peer_id: int) -> bool:
	if state == State.GAME_OVER or state == State.INACTIVE:
		return true
	return stocks.get(peer_id, STOCKS_PER_ROUND) > 0

func _broadcast_stocks() -> void:
	if NetworkManager.is_active():
		_sync_stocks_rpc.rpc(stocks)
	else:
		_sync_stocks_rpc(stocks)

@rpc("authority", "call_local", "reliable")
func _sync_stocks_rpc(new_stocks: Dictionary) -> void:
	stocks = new_stocks
	stocks_changed.emit(stocks)

func _broadcast_kda() -> void:
	if NetworkManager.is_active():
		_sync_kda_rpc.rpc(kda_kills, kda_deaths, kda_damage)
	else:
		_sync_kda_rpc(kda_kills, kda_deaths, kda_damage)

@rpc("authority", "call_local", "reliable")
func _sync_kda_rpc(new_kills: Dictionary, new_deaths: Dictionary, new_damage: Dictionary) -> void:
	kda_kills = new_kills
	kda_deaths = new_deaths
	kda_damage = new_damage
	kda_changed.emit(kda_kills, kda_deaths, kda_damage)

func record_damage(attacker_id: int, amount: int) -> void:
	kda_damage[attacker_id] = kda_damage.get(attacker_id, 0) + amount
	_broadcast_kda()

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
		if scores[peer_id] >= points_to_win:
			if scores[peer_id] > best_score:
				best_score = scores[peer_id]
				best_peer = peer_id
			elif scores[peer_id] == best_score:
				best_peer = -1  # tied at the top — no single winner
	return best_peer

func _find_tied_leaders() -> Array:
	var best_score := -1
	for peer_id in scores:
		if scores[peer_id] >= points_to_win and scores[peer_id] > best_score:
			best_score = scores[peer_id]
	var tied := []
	for peer_id in scores:
		if scores[peer_id] == best_score:
			tied.append(peer_id)
	return tied

signal _intermission_done

func notify_player_picked() -> void:
	if state != State.INTERMISSION:
		return
	_n_picked += 1
	if _n_picked >= get_parent().spawned_players.size():
		_n_picked = 0
		_intermission_done.emit()

func _do_intermission(winner_peer_id: int, finishers: Array, tied_peers: Array = []) -> void:
	if winner_peer_id != -1:
		_broadcast(State.GAME_OVER, scores, round_number, winner_peer_id)
		return
	_broadcast(State.INTERMISSION, scores, round_number, winner_peer_id, finishers)
	# powerups_distribute is emitted by _sync_round_state on all peers (including clients)
	_n_picked = 0
	_intermission_gen += 1
	var my_gen := _intermission_gen
	get_tree().create_timer(INTERMISSION_DURATION).timeout.connect(
		func():
			if _intermission_gen == my_gen:
				_intermission_done.emit()
	)
	await _intermission_done
	if state == State.INACTIVE:
		return  # level changed while waiting — bail out
	round_number += 1
	_finishers.clear()
	if NetworkManager.is_active():
		_sync_sudden_death.rpc(tied_peers)
	else:
		_sync_sudden_death(tied_peers)
	get_parent().respawn_all_at_spawn()
	_broadcast(State.PLAYING, scores, round_number, -1)

@rpc("authority", "call_local", "reliable")
func _sync_sudden_death(peers: Array) -> void:
	sudden_death_peers = peers

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
			for peer_id in new_scores:
				stocks[peer_id] = STOCKS_PER_ROUND
			stocks_changed.emit(stocks)
			round_started.emit(round_num)
		State.INTERMISSION:
			round_ended.emit(finishers, new_scores)
			if event_peer_id == -1:
				powerups_distribute.emit(new_scores, finishers)
		State.GAME_OVER:
			_round_active = false
			game_over.emit(event_peer_id, new_scores)
