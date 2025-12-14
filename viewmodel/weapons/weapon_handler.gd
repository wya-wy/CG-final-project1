extends Node2D

# 预加载投射物资源
const FIREBALL_PROJECTILE = preload("res://viewmodel/spells/fireball_projectile.tscn")

# --- 资源变量 ---
# [重要] 这是一个模版资源！不要直接修改它。
# 在编辑器里把你的 test_sword.tres 拖进去。
@export var weapon_template: Weapon 

# [重要] 这是游戏运行时实际使用的独立副本。
# 所有的动态装填、修改法术都只针对这个变量，不会影响原始文件。
var runtime_weapon: Weapon

# --- 内部变量 ---
# 记录当前轮到第几个槽位发射了
var current_slot_index: int = 0

# 获取 Hitbox 节点引用
@onready var melee_hitbox: Area2D = get_node_or_null("MeleeHitbox")

func _ready():
	# 1. 初始化武器实例
	if weapon_template:
		initialize_weapon(weapon_template)
	else:
		print("WeaponHandler: Warning - No weapon template assigned!")

	# 2. 初始化近战 Hitbox
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	else:
		print("WeaponHandler: Warning - 'MeleeHitbox' node not found.")

# --- 核心功能：初始化武器 ---
# 当你需要换武器时，也可以调用这个函数传入新的武器资源
func initialize_weapon(new_weapon_data: Weapon):
	# duplicate(true) 会深度复制资源，包括里面的数组。
	# 这样我们就有了一把属于这个玩家的、独一无二的剑。
	runtime_weapon = new_weapon_data.duplicate(true)
	current_slot_index = 0
	print("WeaponHandler: Weapon initialized -> ", runtime_weapon.weapon_name)

# --- 核心功能：动态装填法术 ---
# 供 UI、背包系统或剧情脚本调用
# slot_idx: 槽位编号 (0, 1, 2...)
# spell_data: 要放入的法术资源
func install_spell(slot_idx: int, spell_data: Spell):
	if not runtime_weapon:
		print("WeaponHandler: No runtime weapon!")
		return
	
	if slot_idx < 0 or slot_idx >= runtime_weapon.slots.size():
		print("WeaponHandler: Invalid slot index %d" % slot_idx)
		return
	
	# 获取目标槽位 (SpellSlot 实例)
	var target_slot = runtime_weapon.slots[slot_idx]
	
	# 调用槽位自己的装填逻辑
	if target_slot.has_method("equip_spell"):
		if target_slot.equip_spell(spell_data):
			print("WeaponHandler: Equipped %s into slot %d" % [spell_data.spell_name, slot_idx])
		else:
			print("WeaponHandler: Failed to equip spell (Slot full?)")
	else:
		print("WeaponHandler: Error - Slot resource does not have 'equip_spell' method.")

# --- 核心功能：攻击逻辑 ---
# 对应鼠标左键或攻击键
func attack():
	if not runtime_weapon:
		return

	if runtime_weapon.slots.is_empty():
		print("WeaponHandler: Weapon has no slots!")
		return

	# --- 新增逻辑：寻找下一个有法术的槽位 ---
	# 目的：跳过空的槽位，实现 1-1-1 的连发效果
	var found_valid_slot = false
	var checked_count = 0
	
	# 最多循环检查一圈（防止所有槽都空导致死循环）
	while checked_count < runtime_weapon.slots.size():
		var slot = runtime_weapon.slots[current_slot_index]
		
		# 检查：这个槽位里装了东西吗？
		# 注意：需要确保你的 SpellSlot 脚本里已经加了 get_equipped_spells() 函数
		if slot.has_method("get_equipped_spells") and not slot.get_equipped_spells().is_empty():
			found_valid_slot = true
			break # 找到了！这就用它，跳出循环
		
		# 没装东西 -> 索引+1，继续找下一个
		current_slot_index = (current_slot_index + 1) % runtime_weapon.slots.size()
		checked_count += 1
	
	# 如果转了一圈发现全是空的，那就直接返回，不执行攻击
	if not found_valid_slot:
		return
	# ----------------------------------------

	# 1. 获取当前找到的有效槽位
	# 注意：这里的 slots 数组里装的是 SpellSlot 资源 (如 SpellSlot 或 DoubleSlot)
	var current_slot = runtime_weapon.slots[current_slot_index]
	
	# 2. 计算蓝耗 (让槽位自己算，因为双发槽可能耗蓝更多)
	var mana_cost = 0
	if current_slot.has_method("get_total_mana_cost"):
		mana_cost = current_slot.get_total_mana_cost()
	
	# 3. 检查并消耗蓝量
	var player = get_parent() # 假设父节点是 Player
	if player.has_method("try_consume_mana"):
		# 如果蓝不够，直接返回，不执行攻击
		if not player.try_consume_mana(mana_cost, "spell"):
			# 可以加一个 "No Mana" 的 UI 提示或者音效
			return 

	# 4. 激活槽位！
	# 我们把 self (WeaponHandler) 传给槽位，这样槽位才能回调 spawn_projectile
	if current_slot.has_method("activate"):
		current_slot.activate(self, player)
	
	# 5. 只有在成功发射后，才把索引移到下一位，为下一次点击做准备
	current_slot_index = (current_slot_index + 1) % runtime_weapon.slots.size()


# --- 公共 API：生成投射物 ---
# 这个函数由 SpellSlot 资源调用，它不关心是单发还是双发，只负责造子弹
# modifiers: 一个字典，用于传递特殊效果（如穿透、伤害倍率等）
func spawn_projectile(spell_data: Spell, offset: Vector2 = Vector2.ZERO, modifiers: Dictionary = {}):
	if not spell_data:
		return

	match spell_data.effect_id:
		"fireball":
			var projectile = FIREBALL_PROJECTILE.instantiate()
			
			# 计算发射方向（鼠标方向）
			var mouse_pos = get_global_mouse_position()
			var direction = (mouse_pos - global_position).normalized()
			
			# 设置位置（加上偏移量，用于双发槽位避免重叠）
			projectile.global_position = global_position + offset
			projectile.rotation = direction.angle()
			
			# 设置速度
			# 这里最好将来把速度也放在 Spell 资源里配置
			projectile.velocity = direction * 1000 
			
			# --- 处理修改器 (Modifiers) ---
			# 如果是强化槽位传来的参数，在这里应用
			if modifiers.has("damage_multiplier"):
				projectile.damage = int(projectile.damage * modifiers["damage_multiplier"])
			
			if modifiers.has("penetration") and modifiers["penetration"] == true:
				# 假设你的子弹脚本支持穿透属性
				if "penetration_count" in projectile:
					projectile.penetration_count = 999 
				else:
					print("WeaponHandler: Projectile does not support penetration.")

			# 添加到场景
			get_tree().current_scene.add_child(projectile)

		"flame_buff":
			print("WeaponHandler: Cast Buff!")
			# 这里写 Buff 逻辑

		_:
			print("WeaponHandler: Unknown spell effect_id: ", spell_data.effect_id)

	# 发送信号（用于播放音效或UI）
	EventBus.emit_signal("player_attacked", spell_data)


# --- 辅助功能：连续发射 ---
# 供 Sequential 模式的槽位使用（如果有的话）
func cast_sequential(spells: Array[Spell], delay: float):
	for spell in spells:
		if spell:
			spawn_projectile(spell)
			# 等待
			await get_tree().create_timer(delay).timeout


# --- 近战逻辑 (保持原有逻辑) ---
func melee_attack():
	if not runtime_weapon:
		return
		
	print("WeaponHandler: Melee attack with ", runtime_weapon.weapon_name, " (Damage: ", runtime_weapon.melee_damage, ")")
	EventBus.emit_signal("player_melee_attacked")

func set_hitbox_monitoring(enabled: bool):
	if melee_hitbox:
		melee_hitbox.monitoring = enabled

func _on_melee_hitbox_body_entered(body: Node2D):
	if not runtime_weapon: return
	
	if body.has_method("take_damage"):
		print("WeaponHandler: Hit enemy ", body.name)
		body.take_damage(runtime_weapon.melee_damage)