extends CharacterBody2D

func take_damage(amount):
	print("Enemy: I took %s damage!" % amount)
	queue_free()

var player = null
@export var speed = 100.0
@export var detection_range = 200.0
@export var attack_range = 40.0

func _ready():
	# 在 _ready() 中获取一次玩家节点
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta):
	# 添加重力
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player:
		var dist_x = abs(player.global_position.x - global_position.x)
		
		if dist_x < attack_range:
			attack()
			velocity.x = move_toward(velocity.x, 0, speed)
		elif dist_x < detection_range:
			# 向玩家靠近
			var direction = sign(player.global_position.x - global_position.x)
			velocity.x = direction * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			
	move_and_slide()

func attack():
	print("Enemy Attack!")
