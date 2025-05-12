extends CanvasLayer

func _ready():
	visible = false  # hide pause menu on start
	
		# Connect all buttons to handle mouse focus
	for button in get_node("CenterContainer/VBoxContainer").get_children():
		if button is Button:
			button.mouse_entered.connect(func():
				button.grab_focus()
			)

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
	if event.is_action_pressed("submit"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")

func pause_game():
	get_tree().paused = true
	visible = true
	$CenterContainer/VBoxContainer/Resume.grab_focus()  # set default button on menu open


func resume_game():
	visible = false
	get_tree().paused = false

func _on_resume_pressed():
	resume_game()


func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()



func _on_title_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")


func _on_quit_pressed():
	get_tree().quit()
