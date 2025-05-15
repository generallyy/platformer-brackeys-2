extends Node

@onready var click_sound = preload("res://assets/sounds/ui_click.wav")

func play_click():
	$AudioStreamPlayer.stream = click_sound
	$AudioStreamPlayer.play()
