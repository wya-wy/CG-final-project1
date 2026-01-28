# res://view/UI/weapon_slot_ui.gd
extends PanelContainer
class_name WeaponSlotUI

@onready var icons_container: HBoxContainer = $IconsContainer
@onready var slot_name_label: Label = $SlotNameLabel

# 记录自己对应的是武器上的第几个槽
var slot_index: int = -1
var weapon_handler_ref: Node2D # 对 WeaponHandler 的引用
var current_slot_data: SpellSlot # 对应的资源数据

func setup(index: int, slot_data: SpellSlot, handler: Node2D):
	slot_index = index
	current_slot_data = slot_data
	weapon_handler_ref = handler
	
	slot_name_label.text = slot_data.slot_name
	refresh_visuals()

# 刷新显示：看看槽里现在装了什么
func refresh_visuals():
	# 清空旧图标
	for child in icons_container.get_children():
		child.queue_free()
	
	# 既然是运行时，我们要读取 _equipped_spells
	# (注意：我们在 SpellSlot 脚本里加过 get_equipped_spells() 函数)
	var spells = current_slot_data.get_equipped_spells()
	
	for spell in spells:
		var icon = TextureRect.new()
		if spell.icon:
			icon.texture = spell.icon
		else:
			icon.texture = preload("res://icon.svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(40, 40)
		icons_container.add_child(icon)

# --- 核心：Godot 放置逻辑 ---

# 1. 检查能不能放：当鼠标拖着东西悬停在上方时每帧调用
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# 检查数据是不是 Spell 类型
	if data is Spell:
		# 还可以检查容量是否满了
		if current_slot_data.get_equipped_spells().size() < current_slot_data.capacity:
			return true
	# 检查数据是不是 SpellSlotItem 类型
	elif data is SpellSlotItem:
		# 法术槽装备总是可以替换
		return true
	return false

# 2. 执行放置：当鼠标松开时调用
func _drop_data(at_position: Vector2, data: Variant):
	if not weapon_handler_ref: return
	
	if data is Spell:
		var spell = data as Spell
		print("UI: 试图将 ", spell.spell_name, " 放入槽位 ", slot_index)
		# 调用我们之前写好的 WeaponHandler 接口！
		weapon_handler_ref.install_spell(slot_index, spell)
		# 刷新 UI 显示
		refresh_visuals()
	elif data is SpellSlotItem:
		var slot_item = data as SpellSlotItem
		print("UI: 试图将 ", slot_item.slot_name, " 替换槽位 ", slot_index)
		# 执行槽位替换
		replace_slot(slot_item)

# 替换槽位
func replace_slot(slot_item: SpellSlotItem):
	# 调用 WeaponHandler 的替换方法
	if weapon_handler_ref.has_method("replace_slot"):
		var success = weapon_handler_ref.replace_slot(slot_index, slot_item)
		if success:
			# 更新本地引用
			current_slot_data = weapon_handler_ref.runtime_weapon.slots[slot_index]
			slot_name_label.text = current_slot_data.slot_name
			refresh_visuals()
			print("UI: 槽位替换成功！")
		else:
			print("UI: 槽位替换失败！")

# --- 处理鼠标点击 ---
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# 检测右键点击 (MOUSE_BUTTON_RIGHT = 2)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_click()

func _on_right_click():
	if not current_slot_data: return
	
	print("UI: 右键点击，清空槽位 ", slot_index)
	
	# 1. 清空数据
	current_slot_data.clear_slot()
	
	# 2. 刷新界面
	refresh_visuals()
