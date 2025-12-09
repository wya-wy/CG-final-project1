extends CharacterBody2D

# --- 1. 节点引用 ---
# @onready 确保在 _ready() 之前获取到 WeaponHandler 节点
# ($WeaponHandler 是 Player 场景中子节点的名称)
@onready var weapon_handler = $WeaponHandler

# 新增：获取 AnimationPlayer
@onready var animation_player = $AnimationPlayer

# --- 2. 移动常量 ---
const SPEED = 300.0
const ACCELERATION = 2400.0
const FRICTION = 1200.0
const JUMP_VELOCITY = -500.0
# 土狼时间
const COYOTE_TIME_DURATION: float = 0.1
var coyote_timer: float = 0.0

# --- 3. 生命值属性 ---
@export var max_health: int = 100
var current_health: int
var is_dead: bool = false

# --- 4. 魔法值属性 ---
# 普通蓝量上限为 100
@export var max_normal_mana: int = 100
# 浓缩蓝量上限为 50
@export var max_condensed_mana: int = 50
@export var normal_mana_regen_rate: float = 10.0  # 回普通蓝速度
@export var condensed_mana_regen_rate: float = 6.0  # 回浓缩蓝速度
var normal_mana: float = 100.0
var condensed_mana: float = 50.0

# 战斗状态记录
var last_combat_time: float = -10.0
const COMBAT_COOLDOWN: float = 2.0  # 停止攻击2秒后开始回浓缩蓝

# 获取总蓝量
func get_total_mana() -> int:
	return int(normal_mana + condensed_mana)

# 发信号
func emit_mana_signal():
	EventBus.emit_signal("player_mana_changed", normal_mana, condensed_mana, max_normal_mana, max_condensed_mana)

# --- 5. 初始化 ---
func _ready():
	# 游戏开始时，满血满蓝
	current_health = max_health
	normal_mana = float(max_normal_mana)
	condensed_mana = float(max_condensed_mana)
	is_dead = false
	
	# 初始化UI
	EventBus.emit_signal("player_health_changed", current_health, max_health)
	emit_mana_signal()

# --- 6. 物理 & 输入循环 ---
func _physics_process(delta: float) -> void:
	
	# --- 自动回蓝 ---
	if not is_dead:
		var changed = false
		
		# 1. 普通蓝：一直回复，直到 max_normal_mana
		if normal_mana < max_normal_mana:
			normal_mana = move_toward(normal_mana, float(max_normal_mana), normal_mana_regen_rate * delta)
			changed = true
			
		# 2. 浓缩蓝：脱战后回复，直到 max_condensed_mana
		var time_since_combat = Time.get_ticks_msec() / 1000.0 - last_combat_time
		if time_since_combat > COMBAT_COOLDOWN:
			if condensed_mana < max_condensed_mana:
				condensed_mana = move_toward(condensed_mana, float(max_condensed_mana), condensed_mana_regen_rate * delta)
				changed = true
		
		if changed:
			emit_mana_signal()

	# --- 土狼时间 ---
	if is_on_floor():
		coyote_timer = COYOTE_TIME_DURATION
	else:
		coyote_timer -= delta

	# --- 重力 ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- 跳跃 ---
	if Input.is_action_just_pressed("jump") and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0

	# --- 左右移动 ---
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		
		# --- 视觉朝向翻转 ---
		# 1. 翻转玩家精灵 (假设节点名为 Sprite2D)
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.flip_h = (direction < 0)
			
		# 2. 翻转武器处理器 (用于调整近战 Hitbox 位置)
		# 如果向左移动，将 WeaponHandler 的 X 轴缩放设为 -1
		if weapon_handler:
			weapon_handler.scale.x = -1 if direction < 0 else 1
			
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# --- 状态优先级逻辑 ---
	# 如果正在播放攻击动画，且动画还没播完，就不要播放跑步或待机动画
	if animation_player.current_animation == "attack" and animation_player.is_playing():
		# 可以在这里选择是否允许移动，如果想攻击时定身：
		# velocity.x = 0
		pass 
	else:
		# 处理移动动画
		if velocity.y == 0:
			if direction != 0:
				animation_player.play("run")
			else:
				animation_player.play("idle")
		else:
			if velocity.y > 0:
				animation_player.play("fall")
			else:
				animation_player.play("jump")

	# --- 执行移动 ---
	move_and_slide()

	# --- 攻击输入 ---
	if Input.is_action_just_pressed("attack"):
		# 远程攻击逻辑保持不变
		weapon_handler.attack()
		update_combat_state() # 记录攻击时间

	if Input.is_action_just_pressed("melee_attack"):
		# 1. 播放动画 (动画中包含了开启 Hitbox 的逻辑)
		animation_player.play("attack")
		# 2. 通知 WeaponHandler (计算伤害数值等)
		weapon_handler.melee_attack()
		update_combat_state() # 记录攻击时间

	# --- Debug: 受伤测试 (保留) ---
	if Input.is_action_just_pressed("debug_hurt"):
		take_damage(40)

# 更新战斗状态辅助函数
func update_combat_state():
	last_combat_time = Time.get_ticks_msec() / 1000.0

# --- 6. 生命值函数 ---
			
func take_damage(amount: int):
	if is_dead:
		return # 已经死了，不再受伤

	current_health -= amount
	print("Player 受到 ", amount, " 点伤害，剩余生命: ", current_health)

	# 广播生命值变化 (用于 HUD 更新)
	EventBus.emit_signal("player_health_changed", current_health, max_health)

	# 检查死亡
	if current_health <= 0:
		player_died()


func player_died():
	# 防止重复调用
	if is_dead:
		return
		
	is_dead = true
	print("Player 死亡。")
	
	# 广播死亡事件 (用于 GameManager 切换状态)
	EventBus.emit_signal("player_died")
	
	# 停止玩家的物理处理和输入（死亡动画播放完毕后更佳）
	set_physics_process(false)

# --- 7. 魔法值函数 ---
# type: "spell" (法术) 或 "melee" (近战/强化)
func try_consume_mana(amount: int, type: String) -> bool:
	if type == "spell":
		# 法术只扣浓缩蓝
		if condensed_mana >= amount:
			condensed_mana -= amount
			normal_mana -= amount
			emit_mana_signal()
			return true
		return false
		
	elif type == "melee":
		# 近战优先扣普通，不够扣浓缩
		if normal_mana >= amount:
			normal_mana -= amount
			emit_mana_signal()
			return true
		elif normal_mana + condensed_mana >= amount:
			condensed_mana -= amount - normal_mana
			normal_mana = 0
			emit_mana_signal()
			return true
		return false
	return false

# 兼容旧接口
func has_enough_mana(amount: int) -> bool:
	return get_total_mana() >= amount

func consume_mana(amount: int):
	# 默认当作近战类型消耗
	try_consume_mana(amount, "melee")
