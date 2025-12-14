# res://view/UI/inventory_menu.gd
extends Control

# 预加载子场景
const SLOT_UI_SCENE = preload("res://view/UI/WeaponSlotUI.tscn")
const ITEM_UI_SCENE = preload("res://view/UI/InventoryItem.tscn")

@onready var slots_container: VBoxContainer = $HBoxContainer/SlotsContainer
@onready var inventory_grid: GridContainer = $HBoxContainer/CenterContainer/InventoryGrid

# 模拟玩家拥有的法术池（实际开发中应该从 PlayerInventory 单例读取）
var available_spells: Array[Spell] = []

func _ready():
	# --- 临时测试数据 ---
	# 加载几个法术资源放入背包
	visible = false 
	available_spells.append(load("res://viewmodel/spells/fireball.tres"))
	available_spells.append(load("res://viewmodel/spells/fireball.tres"))
	
	# 初始化背包显示
	_init_inventory_grid()
	
	# 初始化武器槽位显示 (假设只有一个玩家)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 稍微延迟一下，确保 Player 的 WeaponHandler 初始化完毕
		await get_tree().process_frame 
		_init_weapon_slots(player.weapon_handler)

func _init_inventory_grid():
	# 清空
	for child in inventory_grid.get_children():
		child.queue_free()
		
	# 生成格子
	for spell in available_spells:
		var item = ITEM_UI_SCENE.instantiate()
		inventory_grid.add_child(item)
		item.setup(spell)

func _init_weapon_slots(handler):
	# 清空
	for child in slots_container.get_children():
		child.queue_free()
	
	var weapon = handler.runtime_weapon
	if not weapon:
		print("UI: 玩家没有装备武器")
		return
		
	# 遍历武器的槽位数组 (Array[SpellSlot])
	for i in range(weapon.slots.size()):
		var slot_data = weapon.slots[i]
		
		# 实例化 UI
		var slot_ui = SLOT_UI_SCENE.instantiate()
		slots_container.add_child(slot_ui)
		
		# 初始化 UI，传入索引和 Handler 引用
		slot_ui.setup(i, slot_data, handler)

# --- 新增：按键开关逻辑 ---
func _input(event):
	# 这里假设你用 "Tab" 键，或者你在项目设置里定义了 "toggle_inventory" 动作
	if event.is_action_pressed("ui_focus_next"): # Godot默认 Tab 键映射是 ui_focus_next
		toggle_menu()

func toggle_menu():
	visible = !visible
	
	# 可选：打开菜单时暂停游戏，防止怪物打你
	get_tree().paused = visible
	
	# 可选：如果打开了菜单，刷新一下显示（以防数据变了）
	if visible:
		# 你可以把 _init_weapon_slots 的逻辑稍微改改，变成 refresh_ui()
		pass
