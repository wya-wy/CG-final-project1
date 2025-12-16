extends CharacterBody2D

# --- 1. 节点引用 ---
# @onready 确保在 _ready() 之前获取到 WeaponHandler 节点
# ($WeaponHandler 是 Player 场景中子节点的名称)
@onready var weapon_handler = $WeaponHandler

# 新增：获取 AnimationPlayer
@onready var animation_player = $AnimationPlayer
# 新增：获取 AnimatedSprite2D
@onready var animated_sprite = $AnimatedSprite2D

# --- 2. 移动常量 ---
const SPEED = 300.0
const ACCELERATION = 2400.0
const ACCELERATION = 1500.0
const FRICTION = 1200.0
const JUMP_VELOCITY = -500.0
const JUMP_VELOCITY = -800.0
# 土狼时间
const COYOTE_TIME_DURATION: float = 0.1
var coyote_timer: float = 0.0
@@ -55,10 +55,42 @@
	condensed_mana = float(max_condensed_mana)
	is_dead = false

	# 连接动画结束信号
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 初始化UI
	EventBus.emit_signal("player_health_changed", current_health, max_health)
	emit_mana_signal()

func _on_animation_finished():
	if animated_sprite.animation == "attack":
		# 攻击动画结束，关闭 Hitbox
		if weapon_handler:
			weapon_handler.set_hitbox_monitoring(false)
		# 强制切换回 idle，防止卡在攻击状态
		animated_sprite.play("idle")
	
	elif animated_sprite.animation == "turn":
		# [关键修复] 转身动画播放完毕后，手动更新翻转状态
		animated_sprite.flip_h = not animated_sprite.flip_h
		
		# 转身结束后，根据当前状态切换动画
		if velocity.x != 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
			
	elif animated_sprite.animation == "hit":
		# 受伤动画结束，恢复待机
		animated_sprite.play("idle")
		
	elif animated_sprite.animation == "death":
		# 死亡动画播放完毕，彻底停止物理处理
		set_physics_process(false)
		# 可以在这里暂停动画，防止循环
		animated_sprite.pause()

# --- 6. 物理 & 输入循环 ---
func _physics_process(delta: float) -> void:

@@ -91,6 +123,23 @@
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
@@ -102,14 +151,36 @@

	# --- 左右移动 ---
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
	
	# [新增] 检查攻击状态
	var is_attacking = animated_sprite and animated_sprite.animation == "attack" and animated_sprite.is_playing()
	
	if is_attacking:
		# 攻击时定身：不响应移动输入，应用摩擦力
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		
	elif direction:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)

		# --- 视觉朝向翻转 ---
		# 1. 翻转玩家精灵 (假设节点名为 Sprite2D)
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.flip_h = (direction < 0)
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
@@ -120,23 +191,23 @@
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# --- 状态优先级逻辑 ---
	# 如果正在播放攻击动画，且动画还没播完，就不要播放跑步或待机动画
	if animation_player.current_animation == "attack" and animation_player.is_playing():
	# 如果正在播放攻击或转身动画，且动画还没播完，就不要播放跑步或待机动画
	if (animated_sprite.animation == "attack" or animated_sprite.animation == "turn") and animated_sprite.is_playing():
		# 可以在这里选择是否允许移动，如果想攻击时定身：
		# velocity.x = 0
		pass 
	else:
		# 处理移动动画
		if velocity.y == 0:
			if direction != 0:
				animation_player.play("run")
				animated_sprite.play("run")
			else:
				animation_player.play("idle")
				animated_sprite.play("idle")
		else:
			if velocity.y > 0:
				animation_player.play("fall")
				animated_sprite.play("fall")
			else:
				animation_player.play("jump")
				animated_sprite.play("jump")

	# --- 执行移动 ---
	move_and_slide()
@@ -148,8 +219,11 @@
		update_combat_state() # 记录攻击时间

	if Input.is_action_just_pressed("melee_attack"):
		# 1. 播放动画 (动画中包含了开启 Hitbox 的逻辑)
		animation_player.play("attack")
		# 1. 播放动画
		animated_sprite.play("attack")
		# 手动开启 Hitbox (因为 AnimatedSprite2D 无法像 AnimationPlayer 那样在轨道中开启)
		weapon_handler.set_hitbox_monitoring(true)
		
		# 2. 通知 WeaponHandler (计算伤害数值等)
		weapon_handler.melee_attack()
		update_combat_state() # 记录攻击时间
@@ -171,6 +245,20 @@
	current_health -= amount
	print("Player 受到 ", amount, " 点伤害，剩余生命: ", current_health)

	# 1. 播放受伤动画 & 进入僵直
	if animated_sprite:
		animated_sprite.play("hit")
		# 如果正在攻击，强制打断
		if weapon_handler:
			weapon_handler.set_hitbox_monitoring(false)
			
		# 2. 闪白/变色反馈 (使用 Tween)
		# 瞬间变红，然后0.2秒内变回原色
		var tween = create_tween()
		animated_sprite.modulate = Color(10, 10, 10, 1) # 尝试用 HDR 值模拟高亮闪白，如果不支持 HDR 会显示为白色/原色
		# 如果觉得太亮或没效果，可以改成 Color.RED
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

	# 广播生命值变化 (用于 HUD 更新)
	EventBus.emit_signal("player_health_changed", current_health, max_health)

@@ -187,11 +275,20 @@
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

	# 停止玩家的物理处理和输入（死亡动画播放完毕后更佳）
	set_physics_process(false)
	# 注意：我们不再立即调用 set_physics_process(false)
	# 而是让 _physics_process 继续运行以处理重力和死亡动画期间的状态
	# 直到动画播放完毕在 _on_animation_finished 中停止

# --- 7. 魔法值函数 ---
# type: "spell" (法术) 或 "melee" (近战/强化)
