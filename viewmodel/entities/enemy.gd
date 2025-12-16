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

# 减速相关变量
var speed_modifier: float = 1.0 # 1.0 代表正常速度，0.5 代表一半速度
var slow_timer: Timer		   # 用来计时的闹钟

# 血量设置
@export var max_health: int = 30
var current_health: int

# 颜色
var damage_tween: Tween

# 获取 Hitbox 引用
@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func die():
	print("Enemy Died!")
	queue_free()

func take_damage(amount):
	current_health -= amount
	print("Enemy: Took %s damage. Current HP: %s" % [amount, current_health])
	
	# 受击反馈
	if animated_sprite:
		# 1. 瞬间变红
		animated_sprite.modulate = Color.RED 
		
		# [修改] 2. 创建动画前，先清除上一个可能还在跑的动画
		if damage_tween:
			damage_tween.kill()
		damage_tween = create_tween()
		
		# 3. 计算恢复颜色
		var target_color = Color.WHITE
		if not slow_timer.is_stopped(): 
			target_color = Color(0.5, 0.5, 1.5) # 减速中恢复为蓝色
		
		# 4. 执行变色
		damage_tween.tween_property(animated_sprite, "modulate", target_color, 0.2)
	
	if current_health <= 0:
		die()

# 供外部调用的减速接口
# percent: 减速百分比 (例如 0.5 表示减速 50%)
# duration: 持续时间 (秒)
func apply_slow(percent: float, duration: float):
	speed_modifier = 1.0 - percent 
	slow_timer.start(duration)

	# [修改] 颜色逻辑
	if animated_sprite:
		# 检查：如果此时有一个正在运行的受伤动画（damage_tween），
		# 说明我们刚刚在 take_damage 里错误地把目标设为了白色。
		if damage_tween and damage_tween.is_valid():
			# 我们不直接设颜色，而是修改动画的目标
			# 杀掉旧的“变白”动画
			damage_tween.kill()
			# 创建一个新的“变蓝”动画（从当前的红色平滑过渡到蓝色）
			damage_tween = create_tween()
			damage_tween.tween_property(animated_sprite, "modulate", Color(0.5, 0.5, 1.5), 0.2)
		else:
			# 如果没有受伤动画在跑，直接变蓝即可
			animated_sprite.modulate = Color(0.5, 0.5, 1.5)

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

	# 初始化血量
	current_health = max_health

	# 初始化减速计时器
	slow_timer = Timer.new()
	slow_timer.one_shot = true # 只响一次，不循环
	add_child(slow_timer)

	# 当计时结束时，执行这个函数：恢复速度、恢复颜色
	slow_timer.timeout.connect(func(): 
		speed_modifier = 1.0
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE 
	)

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
		var current_speed = speed * speed_modifier
		
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
			velocity.x = move_toward(velocity.x, 0, current_speed)
		elif dist_x < detection_range and dist_y < detection_range_y:
			# 向玩家靠近
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
	
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
