extends CharacterBody2D

@export var damage = 10
@export var speed = 100.0
@export var detection_range = 400.0
@export var detection_range_y = 200.0
@export var attack_range = 70.0
@export var attack_cooldown_time = 1.5

var can_attack = true
var is_attacking = false # 新增：标记是否正在攻击动作中
var player = null

# 获取 Hitbox 引用
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

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

	# 如果正在攻击，就不移动，也不切换其他动画
	if is_attacking:
		move_and_slide()
		return

	if player:
		var direction = sign(player.global_position.x - global_position.x)
		var dist_x = abs(player.global_position.x - global_position.x)
		var dist_y = abs(player.global_position.y - global_position.y)
		
		# 让怪物朝向玩家
		if direction != 0:
			# 翻转 Hitbox 位置 (确保 Hitbox 始终位于朝向的一侧)
			if attack_hitbox:
				# abs() 确保基准是正向(右侧)，然后乘以 direction
				attack_hitbox.position.x = abs(attack_hitbox.position.x) * direction
			
			# 翻转 Sprite
			if animated_sprite:
				animated_sprite.flip_h = (direction < 0)
		
		if dist_x < attack_range and dist_y < detection_range_y:
			attack()
			velocity.x = move_toward(velocity.x, 0, speed)
		elif dist_x < detection_range and dist_y < detection_range_y:
			# 向玩家靠近
			velocity.x = direction * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
	
	# --- 动画控制 ---
	# 只有在没有攻击的时候，才由移动逻辑控制动画
	if animated_sprite and not is_attacking:
		if velocity.x != 0:
			animated_sprite.play("jump") # 移动动画
		else:
			animated_sprite.play("idle") # 待机动画
			
	move_and_slide()

func attack():
	if not can_attack:
		return

	print("Enemy Attack!")
	can_attack = false
	is_attacking = true # 锁定状态
	
	# 播放攻击动画
	if animated_sprite:
		animated_sprite.play("attack")
	
	# --- 1. 前摇：等待 10 帧 ---
	for i in range(24):
		await get_tree().physics_frame
	
	# --- 2. 判定：开启 Hitbox 并持续 5 帧 ---
	if attack_hitbox:
		attack_hitbox.monitoring = true
		
		for i in range(12):
			await get_tree().physics_frame
		
		attack_hitbox.monitoring = false
	
	# --- 3. 后摇：等待动画剩余时间 ---
	# 动画总长约 0.6s (3帧 @ 5FPS)
	# 刚才已经过了 15 帧 (60FPS) ≈ 0.25s
	# 还需要等待 0.35s
	await get_tree().create_timer(0.35).timeout
	
	is_attacking = false # 解锁状态 (恢复移动/待机动画)
	
	# --- 4. 冷却 ---
	# 剩余的冷却时间 (总冷却 1.5s - 动画耗时 0.6s = 0.9s)
	await get_tree().create_timer(attack_cooldown_time - 0.6).timeout
	can_attack = true

func _on_attack_hitbox_body_entered(body: Node2D):
	# 检查是否是玩家
	if body.name == "Player" or body.is_in_group("player") or body.has_method("take_damage"):
		print("Enemy hit player!")
		if body.has_method("take_damage"):
			body.take_damage(damage)
