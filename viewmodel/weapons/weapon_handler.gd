extends Node2D

const FIREBALL_PROJECTILE = preload("res://viewmodel/spells/fireball_projectile.tscn")

@export var equipped_weapon: Weapon

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

	match spell_data.effect_id:

		"fireball":
			print("WeaponHandler: FIREBALL")

			var projectile = FIREBALL_PROJECTILE.instantiate()
			projectile.velocity = Vector2(500, 0)

			# (重点) get_parent() 是 Player, get_parent().get_parent() 是 TestLevel
			# 我们需要一个更好的方法来访问“世界”
			# 暂时先这样，之后再优化
			get_parent().get_parent().add_child(projectile)
			projectile.global_position = get_parent().global_position

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
	# TODO: 在这里实现近战伤害判定 (例如检测 Area2D 或 RayCast2D)
	
	EventBus.emit_signal("player_melee_attacked")
