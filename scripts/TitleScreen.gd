extends Control

func _ready():
		$CenterContainer/VBoxContainer/HBoxContainer/StartButton.grab_focus()  # set default button on menu open

func _input(event):
	if event.is_action_pressed("submit"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")


func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit_button_pressed():
	get_tree().quit() # Replace with function body.
	
