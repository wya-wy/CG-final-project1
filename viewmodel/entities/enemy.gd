extends CharacterBody2D

@export var damage = 10
@export var speed = 100.0
@export var detection_range = 200.0
@export var attack_range = 80.0
@export var attack_cooldown_time = 1.5

var can_attack = true
var player = null

# 获取 Hitbox 引用
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox")

func take_damage(amount):
	print("Enemy: I took %s damage!" % amount)
	queue_free()

func _ready():
	# 在 _ready() 中获取一次玩家节点
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# 初始化 Hitbox
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	else:
		print("Enemy: Warning - 'AttackHitbox' node not found.")

func _physics_process(delta):
	# 添加重力
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player:
		var direction = sign(player.global_position.x - global_position.x)
		var dist_x = abs(player.global_position.x - global_position.x)
		
		# 让怪物朝向玩家
		if direction != 0:
			# 翻转 Hitbox 位置 (确保 Hitbox 始终位于朝向的一侧)
			if attack_hitbox:
				# abs() 确保基准是正向(右侧)，然后乘以 direction
				attack_hitbox.position.x = abs(attack_hitbox.position.x) * direction
			
			# 翻转 Sprite (尝试查找常见的 Sprite 节点名称，如果你的节点名不同请修改这里)
			var sprite = get_node_or_null("Sprite2D")
			if sprite:
				sprite.flip_h = (direction < 0)
			var anim_sprite = get_node_or_null("AnimatedSprite2D")
			if anim_sprite:
				anim_sprite.flip_h = (direction < 0)
		
		if dist_x < attack_range:
			attack()
			velocity.x = move_toward(velocity.x, 0, speed)
		elif dist_x < detection_range:
			# 向玩家靠近
			velocity.x = direction * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			
	move_and_slide()

func attack():
	if not can_attack:
		return

	print("Enemy Attack!")
	can_attack = false
	
	# 开启 Hitbox
	if attack_hitbox:
		attack_hitbox.monitoring = true
		
		# 攻击判定持续时间 (0.1s)
		await get_tree().create_timer(0.1).timeout
		
		attack_hitbox.monitoring = false
	
	# 冷却时间
	await get_tree().create_timer(attack_cooldown_time).timeout
	can_attack = true

func _on_attack_hitbox_body_entered(body: Node2D):
	# 检查是否是玩家
	if body.name == "Player" or body.is_in_group("player") or body.has_method("take_damage"):
		print("Enemy hit player!")
		if body.has_method("take_damage"):
			body.take_damage(damage)
