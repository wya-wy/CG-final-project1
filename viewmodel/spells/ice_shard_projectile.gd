extends Area2D

# 属性
var velocity: Vector2 = Vector2.ZERO
var damage: int = 15
var slow_percent: float = 0.5 # 50% 减速
var slow_duration: float = 2.0 # 持续 2 秒

func _physics_process(delta):
	position += velocity * delta

# 碰撞逻辑
func _on_body_entered(body):
	# 造成伤害
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# 施加减速
	if body.has_method("apply_slow"):
		body.apply_slow(slow_percent, slow_duration)
		
	queue_free() # 命中后销毁

func _on_screen_exited():
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
