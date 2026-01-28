# res://view/UI/inventory_item.gd
extends TextureRect
class_name InventoryItem

# 这个格子代表的数据
var item_data: Variant

func setup(item: Variant):
	item_data = item
	
	# 处理不同类型的数据
	if item is Spell:
		var spell = item as Spell
		if spell.icon:
			texture = spell.icon
		else:
			texture = preload("res://icon.svg") # 临时占位图
		# 如果想显示法术名字作为提示
		tooltip_text = spell.spell_name
	elif item is SpellSlotItem:
		var slot_item = item as SpellSlotItem
		if slot_item.icon:
			texture = slot_item.icon
		else:
			texture = preload("res://icon.svg") # 临时占位图
		# 如果想显示法术槽名字作为提示
		tooltip_text = slot_item.slot_name

# --- 核心：Godot 拖拽逻辑 ---
# 当玩家在这个控件上按住鼠标移动时触发
func _get_drag_data(at_position: Vector2):
	if not item_data:
		return null
		
	# 1. 创建拖拽预览（跟随后标的小图标）
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40) # 预览图稍微小一点
	preview.modulate.a = 0.8 # 半透明
	
	# 必须把预览设在一个 Control 节点下才能生效
	var control = Control.new()
	control.add_child(preview)
	# 调整预览中心点到鼠标位置
	preview.position = -0.5 * preview.size
	
	set_drag_preview(control)
	
	# 2. 返回“数据”
	# 这个数据会被传递给 _can_drop_data 和 _drop_data
	return item_data
