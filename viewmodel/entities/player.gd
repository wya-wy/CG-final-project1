extends CharacterBody2D

# --- 1. 节点引用 ---
# @onready 确保在 _ready() 之前获取到 WeaponHandler 节点
# ($WeaponHandler 是 Player 场景中子节点的名称)
@onready var weapon_handler = $WeaponHandler

# 新增：获取 AnimatedSprite2D
@onready var animated_sprite = $AnimatedSprite2D

# --- 2. 移动常量 ---
const SPEED = 300.0
const ACCELERATION = 1500.0
const FRICTION = 1200.0
const JUMP_VELOCITY = -800.0
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
@export var normal_mana_regen_rate: float = 20.0  # 回普通蓝速度
@export var condensed_mana_regen_rate: float = 6.0  # 回浓缩蓝速度
var normal_mana: float = 100.0
var condensed_mana: float = 50.0

# 战斗状态记录
var last_combat_time: float = -10.0
const COMBAT_COOLDOWN: float = 2.0  # 停止攻击2秒后开始回浓缩蓝

@export_category("Debug")
@export var debug_infinite_air_jump: bool = false

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
	
	# 连接动画结束信号
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 初始化UI
	EventBus.emit_signal("player_health_changed", current_health, max_health)
	emit_mana_signal()

func _on_animation_finished():
	# 连击系统接管了 attack 和 attack2 的结束逻辑，这里不再处理
	# 除非被打断导致状态不一致，这里可以作为保底
	
	if animated_sprite.animation == "turn":
		# [关键修复] 转身动画播放完毕后，手动更新翻转状态
		animated_sprite.flip_h = not animated_sprite.flip_h
		
		# 转身结束后，根据当前状态切换动画
		if velocity.x != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
			
	elif animated_sprite.animation == "hit":
		# 受伤动画结束，恢复待机
		# 确保重置攻击状态
		attack_state = 0
		animated_sprite.play("idle")
		
	elif animated_sprite.animation == "death":
		# 死亡动画播放完毕，彻底停止物理处理
		set_physics_process(false)
		# 可以在这里暂停动画，防止循环
		animated_sprite.pause()

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

	# [新增] 死亡状态检查
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		move_and_slide()
		return

	# [新增] 检查受伤僵直状态
	# 如果正在播放 hit 动画，则处于僵直状态
	var is_hurt = animated_sprite and animated_sprite.animation == "hit" and animated_sprite.is_playing()
	
	if is_hurt:
		# 僵直时：无法移动、无法跳跃、无法攻击
		# 仅保留重力和摩擦力
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		move_and_slide()
		return # 直接返回，跳过后续所有输入处理

	# --- 跳跃 ---
	if Input.is_action_just_pressed("jump"):
		var can_jump := coyote_timer > 0
		if debug_infinite_air_jump and OS.is_debug_build():
			can_jump = true
		if can_jump:
			velocity.y = JUMP_VELOCITY
			coyote_timer = 0.0

	# --- 左右移动 ---
	var direction := Input.get_axis("move_left", "move_right")
	
	# [新增] 检查攻击状态
	var is_attacking = animated_sprite and (animated_sprite.animation == "attack" or animated_sprite.animation == "attack2") and animated_sprite.is_playing()
	
	if is_attacking:
		# 攻击时定身：不响应移动输入，应用摩擦力
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		
	elif direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
		
		# --- 视觉朝向翻转 ---
		# 1. 翻转玩家精灵
		if animated_sprite:
			# 检测转身：如果在地面上，且输入方向与当前速度方向相反 (急停转身)
			if is_on_floor() and direction != 0:
				# 判断当前速度方向是否与输入相反
				# 注意：velocity.x 刚刚被 move_toward 更新过
				var is_moving_oppositely = (velocity.x > 0 and direction < 0) or (velocity.x < 0 and direction > 0)
				
				# 只有当确实在移动（速度足够大）且方向相反时才播放转身动画
				# 如果速度为0或很小，视为原地转身，直接翻转不播放动画
				if is_moving_oppositely and abs(velocity.x) > 20:
					if animated_sprite.animation != "turn":
						animated_sprite.play("turn")
			
			# [修改] 只有在不播放转身动画时才更新翻转状态
			# 防止转身动画被镜像，导致看起来方向反了
			if animated_sprite.animation != "turn":
				animated_sprite.flip_h = (direction < 0)
			
		# 2. 翻转武器处理器 (用于调整近战 Hitbox 位置)
		# 如果向左移动，将 WeaponHandler 的 X 轴缩放设为 -1
		if weapon_handler:
			weapon_handler.scale.x = -1 if direction < 0 else 1
			
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# --- 状态优先级逻辑 (修改后) ---
	# 如果正在播放 [攻击] 或 [转身] 或 [斩击] 动画，且动画还没播完...
	# 务必把 "slash" (或者你用的 "attack2") 加到这个判断里！
	if (animated_sprite.animation == "attack" or animated_sprite.animation == "turn" or animated_sprite.animation == "attack2") and animated_sprite.is_playing():
		pass # 正在做重要动作，什么都别做，保持当前动画
	else:
		# 只有没在攻击时，才允许切换跑步/待机
		if velocity.y == 0:
			if direction != 0:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idle")
		else:
			if velocity.y > 0:
				animated_sprite.play("fall")
			else:
				animated_sprite.play("jump")

	# --- 执行移动 ---
	move_and_slide()

	# --- 远程攻击输入 ---
	if Input.is_action_just_pressed("attack"):
		# 远程攻击逻辑保持不变
		weapon_handler.attack()
		update_combat_state() # 记录攻击时间

	# --- 左键逻辑 (连击系统) ---
	if Input.is_action_just_pressed("melee_attack"):
		if attack_state == 0:
			# 起手：第一段攻击
			perform_attack_1()
		elif attack_state == 1 and is_in_combo_window:
			# 连击缓冲
			queued_combo = true
			print("Combo queued!")

	# --- V键逻辑：强制斩击 ---
	if Input.is_action_pressed("slash_attack"):
		# 直接尝试执行，不需要额外逻辑，因为 try_execute_slash_attack 内部已经处理了蓝量和CD
		if attempt_slash_imbue():
			if animated_sprite: animated_sprite.play("attack2")
			perform_slash_logic()
		else:
			# 可选：如果按V但没蓝或CD中，这里可以加提示
			pass

	# --- Debug: 受伤测试 (保留) ---
	if Input.is_action_just_pressed("debug_hurt"):
		take_damage(40)

# 更新战斗状态辅助函数
func update_combat_state():
	last_combat_time = Time.get_ticks_msec() / 1000.0

# --- 连击系统变量 ---
var attack_state: int = 0 # 0: None, 1: Attack1, 2: Attack2
var is_in_combo_window: bool = false
var queued_combo: bool = false

# --- 连击第一段：普攻 ---
func perform_attack_1():
	attack_state = 1
	is_in_combo_window = false
	queued_combo = false
	update_combat_state()
	
	# 尝试附魔 (第一段也享受附魔)
	if attempt_slash_imbue():
		print("连击1：强化斩击！")
	else:
		print("连击1：普通斩击 (无附魔)")
	
	# 播放普攻
	if animated_sprite:
		animated_sprite.play("attack")
	
	# 延迟 1 帧 (15fps) = 0.067s 开启判定
	await get_tree().create_timer(0.067).timeout
	if attack_state != 1: return # 防止被打断后依然开启判定
	
	# 开启 MeleeHitbox 判定
	weapon_handler.set_hitbox_monitoring(true)
	
	# 开启连击窗口 (从判定框出现开始即可连击)
	is_in_combo_window = true
	
	# 判定框持续 2 帧 (15fps) = 0.133s
	await get_tree().create_timer(0.133).timeout
	weapon_handler.set_hitbox_monitoring(false)
	
	# 再等待剩余动画时间 (凑够约 0.4s 总时长)
	# 目前已过 0.067 + 0.133 = 0.2s
	# 再等 0.2s
	await get_tree().create_timer(0.2).timeout
	if attack_state != 1: return
	
	is_in_combo_window = false
	
	if queued_combo:
		perform_attack_2()
	else:
		# 结束攻击
		attack_state = 0
		if animated_sprite: animated_sprite.play("idle")

# --- 连击第二段：强化斩击 ---
func perform_attack_2():
	attack_state = 2
	queued_combo = false
	update_combat_state()
	
	# 尝试附魔
	if attempt_slash_imbue():
		print("连击：强化斩击！")
	else:
		print("连击：普通斩击 (无附魔)")
	
	# 无论是否附魔，都播放 attack2 动作
	if animated_sprite:
		animated_sprite.play("attack2")
	
	# 开启判定框 (注意：如果没有附魔，weapon_handler 里只会造成基础伤害)
	# 延迟 2 帧 (15fps) = 0.133s
	perform_slash_logic(0.133)
	
	# 等待动画结束 (假设也是 0.4s)
	await get_tree().create_timer(0.4).timeout
	if attack_state != 2: return
	
	# 连击结束
	attack_state = 0
	if animated_sprite: animated_sprite.play("idle")

# --- 辅助函数：手动控制判定时机 ---
func perform_slash_logic(delay: float = 0.0):
	if delay > 0:
		await get_tree().create_timer(delay).timeout

	# 立即开启判定框
	print("DEBUG: 开启斩击判定框 (Delay: ", delay, ")")
	weapon_handler.set_slash_hitbox_monitoring(true)
	
	# 等待一小段时间 (例如 0.1秒) 后关闭
	# 这能保证判定框存在足够的时间来检测碰撞，但又不会一直开着
	await get_tree().create_timer(0.1).timeout
	
	# 关闭判定框
	print("DEBUG: 关闭斩击判定框")
	weapon_handler.set_slash_hitbox_monitoring(false)

# --- 辅助函数：尝试附魔 (纯逻辑) ---
func attempt_slash_imbue() -> bool:
	# 1. 第一关：问武器"冷却好了吗？"
	# 注意：连击本身有间隔，这里可以放宽冷却检查，或者保留以防止V键滥用
	if not weapon_handler.can_slash():
		return false 
	
	# 2. 第二关：尝试扣费
	var cost = weapon_handler.get_next_spell_cost()
	if cost == -1: return false # 无可用法术
	
	if not try_consume_mana(cost, "melee"):
		return false # 没蓝
		
	# 3. 执行附魔
	weapon_handler.execute_slash()
	return true

# --- 旧函数保留但改名 (为了兼容性，或者直接删除) ---
func try_execute_slash_attack() -> bool:
	if attempt_slash_imbue():
		if animated_sprite: animated_sprite.play("attack2")
		perform_slash_logic()
		return true
	return false
		
	# C. 开启判定框
	perform_slash_logic()
	
	return true # 告诉调用者：斩击成功执行了！

# --- 6. 生命值函数 ---
			
func take_damage(amount: int):
	if is_dead:
		return # 已经死了，不再受伤

	current_health -= amount
	print("Player 受到 ", amount, " 点伤害，剩余生命: ", current_health)

	# 1. 播放受伤动画 & 进入僵直
	if animated_sprite:
		animated_sprite.play("hit")
		# 如果正在攻击，强制打断
		if weapon_handler:
			weapon_handler.set_hitbox_monitoring(false)
			weapon_handler.set_slash_hitbox_monitoring(false)
		
		# 重置连击状态
		attack_state = 0
		is_in_combo_window = false
		queued_combo = false
			
		# 2. 闪白/变色反馈 (使用 Tween)
		# 瞬间变红，然后0.2秒内变回原色
		var tween = create_tween()
		animated_sprite.modulate = Color(10, 10, 10, 1) # 尝试用 HDR 值模拟高亮闪白，如果不支持 HDR 会显示为白色/原色
		# 如果觉得太亮或没效果，可以改成 Color.RED
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

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
	
	# 确保关闭攻击判定
	if weapon_handler:
		weapon_handler.set_hitbox_monitoring(false)
	
	# 播放死亡动画
	if animated_sprite:
		animated_sprite.play("death")
	
	# 广播死亡事件 (用于 GameManager 切换状态)
	EventBus.emit_signal("player_died")
	
	# 注意：我们不再立即调用 set_physics_process(false)
	# 而是让 _physics_process 继续运行以处理重力和死亡动画期间的状态
	# 直到动画播放完毕在 _on_animation_finished 中停止

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
