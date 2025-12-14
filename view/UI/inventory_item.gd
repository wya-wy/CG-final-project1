# res://view/UI/inventory_item.gd
extends TextureRect
class_name InventoryItem

# 这个格子代表的法术数据
var spell_data: Spell

func setup(spell: Spell):
	spell_data = spell
	# 这里假设你的 Spell 资源里将来会有 icon 属性
	# 目前先用 Godot 图标或者颜色代替
	# texture = spell.icon 
	texture = preload("res://icon.svg") # 临时占位图
	
	# 如果想显示法术名字作为提示
	tooltip_text = spell.spell_name

# --- 核心：Godot 拖拽逻辑 ---
# 当玩家在这个控件上按住鼠标移动时触发
func _get_drag_data(at_position: Vector2):
	if not spell_data:
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
	# 我们直接把 Spell 资源传过去
	return spell_data
