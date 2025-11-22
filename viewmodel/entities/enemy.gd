extends CharacterBody2D

func take_damage(amount):
	print("Enemy: I took %s damage!" % amount)
	queue_free()

var player = null
var speed = 50.0 # 你可以随意调整速度
func _ready():
	# 在 _ready() 中获取一次玩家节点
	# (这比每帧都获取要高效得多)
	player = get_tree().get_nodes_in_group("player")[0]
func _physics_process(delta):
	if player:
		# 1. 计算朝向玩家的方向
		var direction = (player.global_position - global_position).normalized()
		
		# 2. 设置速度
		velocity = direction * speed
		
		# 3. 移动
		move_and_slide()
