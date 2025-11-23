extends CharacterBody2D

# --- 1. 节点引用 ---
# @onready 确保在 _ready() 之前获取到 WeaponHandler 节点
# ($WeaponHandler 是 Player 场景中子节点的名称)
@onready var weapon_handler = $WeaponHandler

# 新增：获取 AnimationPlayer
@onready var animation_player = $AnimationPlayer

# --- 2. 移动常量 ---
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# --- 3. 生命值属性 ---
@export var max_health: int = 100
var current_health: int
var is_dead: bool = false

# --- 4. 初始化 ---
func _ready():
	# 游戏开始时，满血
	current_health = max_health
	is_dead = false

# --- 5. 物理 & 输入循环 ---
func _physics_process(delta: float) -> void:
	
	# --- 重力 ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- 跳跃 ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- 左右移动 ---
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		
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
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# --- 状态优先级逻辑 ---
	# 如果正在播放攻击动画，且动画还没播完，就不要播放跑步或待机动画
	if animation_player.current_animation == "Attack" and animation_player.is_playing():
		# 可以在这里选择是否允许移动，如果想攻击时定身：
		# velocity.x = 0
		pass 
	else:
		# 处理移动动画
		if velocity.x != 0:
			animation_player.play("run")
		else:
			animation_player.play("idle")

	# --- 执行移动 ---
	move_and_slide()

	# --- 攻击输入 ---
	if Input.is_action_just_pressed("attack"):
		# 远程攻击逻辑保持不变
		weapon_handler.attack()

	if Input.is_action_just_pressed("melee_attack"):
		# 1. 播放动画 (动画中包含了开启 Hitbox 的逻辑)
		animation_player.play("attack")
		# 2. 通知 WeaponHandler (计算伤害数值等)
		weapon_handler.melee_attack()

	# --- Debug: 受伤测试 (保留) ---
	if Input.is_action_just_pressed("debug_hurt"):
		take_damage(40)

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
