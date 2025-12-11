# res://viewmodel/weapons/slots/double_slot.gd
extends SpellSlot
class_name DoubleSlot

func _init():
	slot_name = "双重槽"
	capacity = 2 # 关键：设置容量为2

# 重写激活逻辑
func activate(handler: Node2D, player: CharacterBody2D):
	if _equipped_spells.is_empty():
		return

	# 逻辑：同时释放数组里所有的法术
	# 即使玩家只装了1个法术，这里也能正常工作
	for i in range(_equipped_spells.size()):
		var spell = _equipped_spells[i]
		
		# 加大位置偏移
		# var offset = Vector2(0, (i * 30) - 15) # 纵向排开
		
		handler.spawn_projectile(spell)
		# handler.spawn_projectile(spell, offset)
