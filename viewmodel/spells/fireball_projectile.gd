extends Area2D

# Properties
var velocity: Vector2 = Vector2.ZERO
var damage: int = 1

# Movement
func _physics_process(delta):
	position += velocity * delta

# Collision
func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

# Cleanup
func _on_screen_exited():
	queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	pass # Replace with function body.
