# res://viewmodel/weapons/slots/spell_slot.gd
extends Resource
class_name SpellSlot

# 基础属性
@export var slot_name: String = "基础槽"
@export var capacity: int = 1 # 这个槽能装几个法术？

# 运行时存储：这里存放玩家动态塞进去的 Spell 资源
# 不要在编辑器里填这个，这是给游戏运行中用的
var _equipped_spells: Array[Spell] = []

# --- 运行时操作 API ---

# 尝试装填法术
func equip_spell(spell: Spell) -> bool:
	if _equipped_spells.size() >= capacity:
		print("槽位已满！")
		return false
	
	_equipped_spells.append(spell)
	return true

# 清空槽位
func clear_slot():
	_equipped_spells.clear()

# 获取所需蓝耗
func get_total_mana_cost() -> int:
	var total = 0
	for s in _equipped_spells:
		if s: total += s.mana_cost
	return total

# 激活逻辑（子类可以重写这个函数来实现特殊效果）
func activate(handler: Node2D, player: CharacterBody2D):
	if _equipped_spells.is_empty():
		print("空槽位，无法释放")
		return
	
	# 默认行为：只释放第一个
	handler.spawn_projectile(_equipped_spells[0])

func get_equipped_spells() -> Array[Spell]:
	return _equipped_spells
