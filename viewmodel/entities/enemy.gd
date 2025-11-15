extends CharacterBody2D

func take_damage(amount):
	print("Enemy: I took %s damage!" % amount)
	queue_free()
