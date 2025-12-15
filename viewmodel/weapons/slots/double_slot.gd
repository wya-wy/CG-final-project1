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

	# 获取当前瞄准方向，以便计算垂直偏移
	var mouse_pos = handler.get_global_mouse_position()
	var direction = (mouse_pos - handler.global_position).normalized()
	# 计算右侧垂直向量 (旋转90度)
	var right_vector = Vector2(-direction.y, direction.x)

	# 逻辑：同时释放数组里所有的法术
	# 即使玩家只装了1个法术，这里也能正常工作
	for i in range(_equipped_spells.size()):
		var spell = _equipped_spells[i]
		
		# 计算偏移量
		# (i * 30) - 15 意味着：
		# 第0个法术偏移 -15 (左)
		# 第1个法术偏移 +15 (右)
		var offset_magnitude = (i * 30) - 15
		var offset = right_vector * offset_magnitude
		
		handler.spawn_projectile(spell, offset)
