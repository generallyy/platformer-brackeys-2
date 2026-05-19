extends Node

enum State { INACTIVE, PLAYING, GAME_OVER }

const FLAG_SCORE := 10
const ROUND_START_DELAY := 1.0
const SCORE_ANNOUNCE_DELAY := 1.0
const POWERUP_PHASE_DURATION := 45.0

var state: int = State.INACTIVE
var _round_active := false
var _time_limit: float = 60.0
var _time_remaining: float = 0.0
var _start_delay: float = 0.0
var points_to_win: int = 50
var infinite_lives: bool = true
var lives_per_player: int = 3
var _n_picked := 0
var _powerup_gen := 0
var _scoring_locked := false
var _round_number := 1

var team_scores: Dictionary = {}
var lives: Dictionary = {}
var kda_kills: Dictionary = {}
var kda_deaths: Dictionary = {}
var kda_damage: Dictionary = {}
var kda_damage_taken: Dictionary = {}

signal player_scored(peer_id: int)
signal powerups_distribute(scores: Dictionary, finishers: Array)
signal round_started(round_number: int)
signal _powerup_done
signal game_over(winner_team_id: int)
signal team_scores_changed(team_scores: Dictionary)
signal lives_changed(lives: Dictionary)
signal kda_changed(kda_kills: Dictionary, kda_deaths: Dictionary, kda_damage: Dictionary, kda_damage_taken: Dictionary)

func _process(delta: float) -> void:
	if not _round_active:
		return
	if _start_delay > 0.0:
		_start_delay -= delta
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		if multiplayer.is_server():
			_time_over()

func _time_over() -> void:
	var winner := -1
	if team_scores.get(1, 0) > team_scores.get(2, 0):
		winner = 1
	elif team_scores.get(2, 0) > team_scores.get(1, 0):
		winner = 2
	_end_game(winner)

func start_game(time_limit: float = 60.0, win_score: int = 50) -> void:
	_time_limit = time_limit
	points_to_win = win_score
	team_scores = {1: 0, 2: 0}
	lives.clear()
	kda_kills.clear()
	kda_deaths.clear()
	kda_damage.clear()
	kda_damage_taken.clear()
	_assign_teamless_players()
	get_parent().respawn_all_at_spawn()
	if not infinite_lives:
		for peer_id in get_parent().spawned_players:
			lives[peer_id] = lives_per_player
	_broadcast_state(State.PLAYING)

func _assign_teamless_players() -> void:
	var main := get_parent()
	var team_counts := {1: 0, 2: 0}
	for peer_id in main.spawned_players:
		var tid: int = main.player_teams.get(peer_id, 0)
		if tid in team_counts:
			team_counts[tid] += 1
	var teamless: Array = []
	for peer_id in main.spawned_players:
		if main.player_teams.get(peer_id, 0) == 0:
			teamless.append(peer_id)
	teamless.shuffle()
	for peer_id in teamless:
		var tid := 1 if team_counts[1] <= team_counts[2] else 2
		main.request_team_change(peer_id, tid)
		team_counts[tid] += 1

func stop_game() -> void:
	_round_active = false
	_round_number = 1
	state = State.INACTIVE
	team_scores.clear()
	lives.clear()
	kda_kills.clear()
	kda_deaths.clear()
	kda_damage.clear()
	kda_damage_taken.clear()
	kda_changed.emit(kda_kills, kda_deaths, kda_damage, kda_damage_taken)

func can_respawn(peer_id: int) -> bool:
	if state == State.INACTIVE or state == State.GAME_OVER:
		return true
	if infinite_lives:
		return true
	return lives.get(peer_id, lives_per_player) > 0

func player_finished(_peer_id: int) -> void:
	pass

func flag_crossed(peer_id: int, flag_team_id: int) -> void:
	if not _round_active or _scoring_locked:
		return
	var player_team: int = get_parent().player_teams.get(peer_id, 0)
	if player_team == 0 or player_team == flag_team_id:
		return
	_scoring_locked = true
	team_scores[player_team] = team_scores.get(player_team, 0) + FLAG_SCORE
	_broadcast_team_scores()
	_sync_player_scored.rpc(peer_id)
	await get_tree().create_timer(SCORE_ANNOUNCE_DELAY).timeout
	if not _round_active:
		_scoring_locked = false
		return
	if team_scores[player_team] >= points_to_win:
		_end_game(player_team)
		return
	_n_picked = 0
	_powerup_gen += 1
	var my_gen := _powerup_gen
	_sync_powerup_phase.rpc({}, [])
	get_tree().create_timer(POWERUP_PHASE_DURATION).timeout.connect(
		func():
			if _powerup_gen == my_gen:
				skip_powerups()
	)
	await _powerup_done
	if not _round_active:
		_scoring_locked = false
		return
	_round_number += 1
	get_parent().respawn_all_at_spawn()
	_sync_round_started.rpc(_round_number)
	_scoring_locked = false

func notify_player_picked() -> void:
	_n_picked += 1
	if _n_picked >= get_parent().spawned_players.size():
		_n_picked = 0
		_powerup_done.emit()

func skip_powerups() -> void:
	_powerup_done.emit()

@rpc("authority", "call_local", "reliable")
func _sync_round_started(round_number: int) -> void:
	round_started.emit(round_number)

@rpc("authority", "call_local", "reliable")
func _sync_player_scored(peer_id: int) -> void:
	player_scored.emit(peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_powerup_phase(scores: Dictionary, finishers: Array) -> void:
	powerups_distribute.emit(scores, finishers)

func _end_game(winner_team_id: int) -> void:
	if not _round_active:
		return
	_round_active = false
	_broadcast_game_over(winner_team_id)

func record_kill(killer_id: int, victim_id: int) -> void:
	kda_kills[killer_id] = kda_kills.get(killer_id, 0) + 1
	kda_deaths[victim_id] = kda_deaths.get(victim_id, 0) + 1
	_broadcast_kda()
	if not _round_active or infinite_lives:
		return
	if victim_id in lives:
		lives[victim_id] = max(lives[victim_id] - 1, 0)
	_broadcast_lives()

func record_death(victim_id: int) -> void:
	kda_deaths[victim_id] = kda_deaths.get(victim_id, 0) + 1
	_broadcast_kda()
	if not _round_active or infinite_lives:
		return
	if victim_id in lives:
		lives[victim_id] = max(lives[victim_id] - 1, 0)
	_broadcast_lives()

func record_damage(attacker_id: int, amount: int) -> void:
	kda_damage[attacker_id] = kda_damage.get(attacker_id, 0) + amount
	_broadcast_kda()

func record_damage_taken(victim_id: int, amount: int) -> void:
	kda_damage_taken[victim_id] = kda_damage_taken.get(victim_id, 0) + amount
	_broadcast_kda()

func register_player(peer_id: int) -> void:
	if state != State.INACTIVE and peer_id not in lives:
		if not infinite_lives:
			lives[peer_id] = lives_per_player
			_broadcast_lives()

func sync_to_peer(peer_id: int) -> void:
	_sync_state.rpc_id(peer_id, state, team_scores, _time_limit, lives, infinite_lives, lives_per_player, points_to_win)

func _broadcast_state(new_state: int) -> void:
	_sync_state.rpc(new_state, team_scores, _time_limit, lives, infinite_lives, lives_per_player, points_to_win)

func _broadcast_team_scores() -> void:
	_sync_team_scores.rpc(team_scores)

func _broadcast_lives() -> void:
	_sync_lives.rpc(lives)

func _broadcast_kda() -> void:
	_sync_kda.rpc(kda_kills, kda_deaths, kda_damage, kda_damage_taken)

func _broadcast_game_over(winner_team_id: int) -> void:
	_sync_game_over.rpc(winner_team_id)

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int, new_team_scores: Dictionary, time_limit: float, new_lives: Dictionary, inf_lives: bool, lives_pp: int, win_score: int) -> void:
	state = new_state
	team_scores = new_team_scores
	_time_limit = time_limit
	lives = new_lives
	infinite_lives = inf_lives
	lives_per_player = lives_pp
	points_to_win = win_score
	if new_state == State.PLAYING:
		_round_active = true
		_time_remaining = time_limit
		_start_delay = ROUND_START_DELAY
		round_started.emit(1)
		team_scores_changed.emit(team_scores)
		lives_changed.emit(lives)

@rpc("authority", "call_local", "reliable")
func _sync_team_scores(new_scores: Dictionary) -> void:
	team_scores = new_scores
	team_scores_changed.emit(team_scores)

@rpc("authority", "call_local", "reliable")
func _sync_lives(new_lives: Dictionary) -> void:
	lives = new_lives
	lives_changed.emit(lives)

@rpc("authority", "call_local", "reliable")
func _sync_kda(new_kills: Dictionary, new_deaths: Dictionary, new_damage: Dictionary, new_damage_taken: Dictionary) -> void:
	kda_kills = new_kills
	kda_deaths = new_deaths
	kda_damage = new_damage
	kda_damage_taken = new_damage_taken
	kda_changed.emit(kda_kills, kda_deaths, kda_damage, kda_damage_taken)

@rpc("authority", "call_local", "reliable")
func _sync_game_over(winner_team_id: int) -> void:
	_round_active = false
	state = State.GAME_OVER
	game_over.emit(winner_team_id)
