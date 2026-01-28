# res://view/UI/inventory_menu.gd
extends Control

# 预加载子场景
const SLOT_UI_SCENE = preload("res://view/UI/WeaponSlotUI.tscn")
const ITEM_UI_SCENE = preload("res://view/UI/InventoryItem.tscn")

@onready var slots_container: VBoxContainer = $HBoxContainer/SlotsContainer
@onready var inventory_container: Control = $HBoxContainer/CenterContainer

# 模拟玩家拥有的物品池（实际开发中应该从 PlayerInventory 单例读取）
var available_spells: Array[Spell] = []
var available_spell_slots: Array[SpellSlotItem] = []

func _ready():
	# --- 临时测试数据 ---
	# 加载几个法术资源放入背包
	visible = false 
	available_spells.append(load("res://viewmodel/spells/fireball.tres"))
	available_spells.append(load("res://viewmodel/spells/ice_shard.tres"))
	# 加载法术槽装备
	available_spell_slots.append(load("res://viewmodel/items/double_slot_item.tres"))
	
	# 初始化背包显示
	_init_inventory()
	
	# 初始化武器槽位显示 (假设只有一个玩家)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 稍微延迟一下，确保 Player 的 WeaponHandler 初始化完毕
		await get_tree().process_frame 
		_init_weapon_slots(player.weapon_handler)

func _init_inventory():
	# 清空
	for child in inventory_container.get_children():
		child.queue_free()
	
	# 创建垂直容器来组织不同区域
	var main_vbox = VBoxContainer.new()
	inventory_container.add_child(main_vbox)
	
	# 创建法术区域
	var spells_vbox = VBoxContainer.new()
	main_vbox.add_child(spells_vbox)
	
	var spells_label = Label.new()
	spells_label.text = "法术"
	spells_vbox.add_child(spells_label)
	
	var spells_grid = GridContainer.new()
	spells_grid.columns = 4
	spells_vbox.add_child(spells_grid)
	
	# 生成法术格子
	for spell in available_spells:
		var item_ui = ITEM_UI_SCENE.instantiate()
		spells_grid.add_child(item_ui)
		item_ui.setup(spell)
	
	# 创建法术槽区域
	var spell_slots_vbox = VBoxContainer.new()
	main_vbox.add_child(spell_slots_vbox)
	
	var spell_slots_label = Label.new()
	spell_slots_label.text = "法术槽"
	spell_slots_vbox.add_child(spell_slots_label)
	
	var spell_slots_grid = GridContainer.new()
	spell_slots_grid.columns = 4
	spell_slots_vbox.add_child(spell_slots_grid)
	
	# 生成法术槽格子
	for slot_item in available_spell_slots:
		var item_ui = ITEM_UI_SCENE.instantiate()
		spell_slots_grid.add_child(item_ui)
		item_ui.setup(slot_item)

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
		_init_inventory()
