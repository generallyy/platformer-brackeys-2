extends Area2D

func _on_body_entered(body):
	if body.name == "Player":
		#print("You died.")	it's kinda funny but eh whatever
		body.die() 		# now we can have the player die properly
