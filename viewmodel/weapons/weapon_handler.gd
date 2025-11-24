extends Node2D

const FIREBALL_PROJECTILE = preload("res://viewmodel/spells/fireball_projectile.tscn")

@export var equipped_weapon: Weapon

# 获取 Hitbox 节点引用
# 使用 get_node_or_null 防止节点未创建时报错
@onready var melee_hitbox: Area2D = get_node_or_null("MeleeHitbox")

func _ready():
	if melee_hitbox:
		# 确保初始状态下 Hitbox 是关闭的
		melee_hitbox.monitoring = false
		# 连接碰撞信号
		melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	else:
		print("WeaponHandler: Warning - 'MeleeHitbox' node not found. Please add an Area2D named 'MeleeHitbox' as a child of WeaponHandler.")

func attack():
	if not equipped_weapon:
		print("WeaponHandler: no weapon equipped!")
		return

	if equipped_weapon.spell_slots.is_empty():
		print("WeaponHandler: weapon has no spell slots!")
		return

	var spell_data: Spell = equipped_weapon.spell_slots[0]
	if not spell_data:
		print("WeaponHandler: spell slot is empty!")
		return

	# --- 检查蓝量 ---
	var player = get_parent() # 假设 WeaponHandler 是 Player 的直接子节点
	if player.has_method("has_enough_mana"):
		if not player.has_enough_mana(spell_data.mana_cost):
			print("WeaponHandler: Not enough mana!")
			return
		
		# 消耗蓝量
		player.consume_mana(spell_data.mana_cost)

	match spell_data.effect_id:

		"fireball":
			print("WeaponHandler: FIREBALL")

			var projectile = FIREBALL_PROJECTILE.instantiate()
			
			# 计算朝向鼠标的方向
			var direction = (get_global_mouse_position() - global_position).normalized()
			projectile.velocity = direction * 1000
			projectile.rotation = direction.angle()

			# (重点) get_parent() 是 Player, get_parent().get_parent() 是 TestLevel
			# 我们需要一个更好的方法来访问“世界”
			# 暂时先这样，之后再优化
			get_parent().get_parent().add_child(projectile)
			projectile.global_position = global_position

		"flame_buff":
			print("WeaponHandler: Fireball with Flame Buff!")
			# (未来的逻辑：get_parent().apply_buff("fire_damage"))

		_:
			print("WeaponHandler: Unknown spell. effect_id: ", spell_data.effect_id)

	EventBus.emit_signal("player_attacked", spell_data)


func melee_attack():
	if not equipped_weapon:
		print("WeaponHandler: no weapon equipped!")
		return
		
	print("WeaponHandler: Melee attack with ", equipped_weapon.weapon_name, " (Damage: ", equipped_weapon.melee_damage, ")")
	
	# 开启 Hitbox 进行伤害判定
	if melee_hitbox:
		melee_hitbox.monitoring = true
		
		# 模拟攻击持续时间（例如 0.1 秒）
		# 注意：更好的做法是使用 AnimationPlayer 的 "Call Method" 轨道来精确控制开启和关闭
		await get_tree().create_timer(0.1).timeout
		
		melee_hitbox.monitoring = false
	
	EventBus.emit_signal("player_melee_attacked")

func _on_melee_hitbox_body_entered(body: Node2D):
	# 检查碰撞体是否是敌人（是否有 take_damage 方法）
	if body.has_method("take_damage"):
		print("WeaponHandler: Hit enemy ", body.name)
		body.take_damage(equipped_weapon.melee_damage)
