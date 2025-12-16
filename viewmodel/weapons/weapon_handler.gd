extends Node2D

# --- 预加载投射物资源 ---
const FIREBALL_PROJECTILE = preload("res://viewmodel/spells/fireball_projectile.tscn")
# [新增] 从旧代码中找回了冰锥术的预加载
const ICE_SHARD_PROJECTILE = preload("res://viewmodel/spells/ice_shard_projectile.tscn")

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
# 攻击间隔控制 (斩击用)
var last_slash_time: float = -10.0 # 初始值设负数确保开局可用
var slash_cooldown: float = 0.15   # 0.15秒攻击间隔

# --- 获取 Hitbox 节点引用 ---
@onready var melee_hitbox: Area2D = get_node_or_null("MeleeHitbox")
# [重要] 斩击判定框
@onready var slash_hitbox: Area2D = get_node_or_null("SlashHitbox")

func _ready():
	# 1. 初始化武器实例
	if weapon_template:
		initialize_weapon(weapon_template)
	else:
		print("WeaponHandler: Warning - No weapon template assigned!")

	# 2. 初始化近战 Hitbox (普通攻击)
	if melee_hitbox:
		melee_hitbox.monitoring = false
		if not melee_hitbox.body_entered.is_connected(_on_melee_hitbox_body_entered):
			melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	else:
		print("WeaponHandler: Warning - 'MeleeHitbox' node not found.")
		
	# 3. 初始化 SlashHitbox (斩击)
	if slash_hitbox:
		# 确保开始是关闭的
		slash_hitbox.monitoring = false
		
		# 修正层级 (代码强制修正，防止编辑器漏选)
		slash_hitbox.collision_layer = 0   # 自身不阻挡
		# 确保包含了敌人的层级 (假设敌人是 Layer 3, value=4)
		# 如果你不确定，可以临时设为 7 (1+2+4) 或 255 测试
		# slash_hitbox.collision_mask = 4 
		
		# 连接碰撞信号 (确保只连一次)
		if not slash_hitbox.body_entered.is_connected(_on_slash_hitbox_body_entered):
			slash_hitbox.body_entered.connect(_on_slash_hitbox_body_entered)
	else:
		print("Error: 未找到 SlashHitbox! 请在编辑器中创建并命名为 SlashHitbox。")

# --- 物理帧更新：斩击调试逻辑 --- 
func _physics_process(delta): 
	# 仅在斩击判定框开启时检测，用于Debug为何打不到怪
	if slash_hitbox and slash_hitbox.monitoring: 
		# 这是一个强力函数，直接获取当前重叠的所有物体 
		var bodies = slash_hitbox.get_overlapping_bodies() 
		
		if bodies.size() > 0: 
			# print("DEBUG: 物理引擎检测到了重叠物体! 数量: ", bodies.size()) 
			for b in bodies: 
				pass
				# print(" - 重叠物体: ", b.name, " | 层级: ", b.collision_layer) 
		else: 
			# 如果这一行疯狂打印，说明红框虽然看见了，但物理上它是空的 
			# print("DEBUG: 判定框开启中，但没有检测到任何物体...") 
			pass

# --- 核心功能：初始化武器 ---
func initialize_weapon(new_weapon_data: Weapon):
	runtime_weapon = new_weapon_data.duplicate(true)
	current_slot_index = 0
	print("WeaponHandler: Weapon initialized -> ", runtime_weapon.weapon_name)

# --- 核心功能：动态装填法术 ---
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

# --- 核心功能：远程攻击逻辑 (右键) ---
func attack():
	if not runtime_weapon:
		return

	if runtime_weapon.slots.is_empty():
		print("WeaponHandler: Weapon has no slots!")
		return

	# --- 寻找下一个有法术的槽位 ---
	var found_valid_slot = false
	var checked_count = 0
	
	while checked_count < runtime_weapon.slots.size():
		var slot = runtime_weapon.slots[current_slot_index]
		
		if slot.has_method("get_equipped_spells") and not slot.get_equipped_spells().is_empty():
			found_valid_slot = true
			break 
		
		current_slot_index = (current_slot_index + 1) % runtime_weapon.slots.size()
		checked_count += 1
	
	if not found_valid_slot:
		return

	# 1. 获取当前槽位
	var current_slot = runtime_weapon.slots[current_slot_index]
	
	# 2. 计算蓝耗
	var mana_cost = 0
	if current_slot.has_method("get_total_mana_cost"):
		mana_cost = current_slot.get_total_mana_cost()
	
	# 3. 检查并消耗蓝量 (法术类型)
	var player = get_parent()
	if player.has_method("try_consume_mana"):
		if not player.try_consume_mana(mana_cost, "spell"):
			return 

	# 4. 激活槽位
	if current_slot.has_method("activate"):
		current_slot.activate(self, player)
	
	# 5. 移到下一位
	current_slot_index = (current_slot_index + 1) % runtime_weapon.slots.size()


# --- 公共 API：生成投射物 (合并了火球和冰锥) ---
func spawn_projectile(spell_data: Spell, offset: Vector2 = Vector2.ZERO, modifiers: Dictionary = {}):
	if not spell_data:
		return

	match spell_data.effect_id:
		"fireball":
			var projectile = FIREBALL_PROJECTILE.instantiate()
			var mouse_pos = get_global_mouse_position()
			var direction = (mouse_pos - global_position).normalized()
			
			projectile.global_position = global_position + offset
			projectile.rotation = direction.angle()
			projectile.velocity = direction * 1000 
			
			# 应用修改器
			if modifiers.has("damage_multiplier"):
				projectile.damage = int(projectile.damage * modifiers["damage_multiplier"])
			
			if modifiers.has("penetration") and modifiers["penetration"] == true:
				if "penetration_count" in projectile:
					projectile.penetration_count = 999 

			get_tree().current_scene.add_child(projectile)

		"flame_buff":
			print("WeaponHandler: Cast Buff!")
			# 这里写 Buff 逻辑

		"ice_shard":
			# [新增] 冰锥术逻辑
			var projectile = ICE_SHARD_PROJECTILE.instantiate()

			var mouse_pos = get_global_mouse_position()
			var direction = (mouse_pos - global_position).normalized()

			projectile.global_position = global_position + offset
			projectile.rotation = direction.angle()

			# 冰锥速度快
			projectile.velocity = direction * 1500 
			
			# 设置基础伤害
			if "damage" in projectile:
				projectile.damage = spell_data.damage if "damage" in spell_data else 10

			# 应用修改器
			if modifiers.has("damage_multiplier"):
				projectile.damage = int(projectile.damage * modifiers["damage_multiplier"])

			get_tree().current_scene.add_child(projectile)

		_:
			print("WeaponHandler: Unknown spell effect_id: ", spell_data.effect_id)

	# 发送信号
	EventBus.emit_signal("player_attacked", spell_data)


# --- 辅助功能：连续发射 ---
func cast_sequential(spells: Array[Spell], delay: float):
	for spell in spells:
		if spell:
			spawn_projectile(spell)
			await get_tree().create_timer(delay).timeout


# --- 近战逻辑 (普通攻击) ---
func melee_attack():
	if not runtime_weapon:
		return
		
	print("WeaponHandler: Melee attack with ", runtime_weapon.weapon_name)
	EventBus.emit_signal("player_melee_attacked")

# --- 斩击逻辑 (左键强力攻击) ---
func slash_attack():
	if not runtime_weapon:
		return
		
	# 1. 检查攻击间隔
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_slash_time < slash_cooldown:
		return
	last_slash_time = current_time
		
	# 2. 检查并消耗蓝量
	# 注意：蓝量数值检查已经在 Player.gd 的输入逻辑中完成
	# 这里只负责实际扣除
	var player = get_parent()
	if player and player.has_method("try_consume_mana"):
		player.try_consume_mana(5, "melee")
		
	# 3. 动画与判定
	# 动画播放由 Player.gd 控制
	# Hitbox 开启由动画轨道调用 set_slash_hitbox_monitoring 控制
	print("WeaponHandler: Slash attack executed")
	
	EventBus.emit_signal("player_slash_attacked")

# --- Hitbox 控制函数 ---

# 普攻 Hitbox 控制
func set_hitbox_monitoring(enabled: bool):
	if melee_hitbox:
		melee_hitbox.monitoring = enabled

# 斩击 Hitbox 控制 (由动画调用)
func set_slash_hitbox_monitoring(enabled: bool):
	if slash_hitbox:
		slash_hitbox.monitoring = enabled
		# 为了解决速度太快物理引擎检测不到的问题，
		# 可以在开启时强制开启一小段时间，不完全依赖动画的关闭指令
		if enabled:
			print("Slash Hitbox 开启!")

# --- 碰撞回调 ---

# 普攻命中
func _on_melee_hitbox_body_entered(body: Node2D):
	if not runtime_weapon: return
	
	if body.has_method("take_damage"):
		print("WeaponHandler: Hit enemy ", body.name)
		body.take_damage(runtime_weapon.melee_damage)

# 斩击命中
func _on_slash_hitbox_body_entered(body: Node2D):
	# 【重要】防止误伤自己
	if body == get_parent() or body.is_in_group("player"):
		return

	print("WeaponHandler: Slash hitbox collided with ", body.name)
	
	# 扣血逻辑
	if body.has_method("take_damage"):
		var damage = 15
		# 暴击逻辑 (30% 几率双倍)
		if randf() < 0.3:
			damage *= 2
			print(">>> 暴击! <<<")
			
		body.take_damage(damage)
