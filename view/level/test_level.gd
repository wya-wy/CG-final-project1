extends Node2D

func _ready():
	$LevelGenerator.level_generated.connect(_on_level_generated)
	$LevelGenerator.generate_level()

	EventBus.player_attacked.connect(_on_player_attacked)
	
	# --- 模拟：游戏开始时，NPC 给了玩家一个火球术装在第一个槽 ---
	var player = $Player
	var fireball = load("res://viewmodel/spells/fireball.tres")
	
	# 延迟一点点确保 Player _ready 执行完毕
	await get_tree().create_timer(0.1).timeout
	
	print("--- 模拟 NPC 初始化玩家武器 ---")
	# 清空槽位（如果需要）
	# 装填火球到第0个槽（假设是普通槽）
	player.weapon_handler.install_spell(0, fireball)
	
	# 模拟：给第1个槽（假设是双发槽）装两个火球
	player.weapon_handler.install_spell(1, fireball)
	player.weapon_handler.install_spell(1, fireball)

func _on_player_attacked(spell: Spell):
	print("--- TestLevel Listening ---")
	print("EventBus: Player uses ", spell.spell_name)
	print("-----------------------------")

func _on_level_generated(start_pos: Vector2):
	# 将玩家移动到起点
	$Player.position = start_pos + Vector2(960, 540) # 假设居中，或者读取 SpawnPoint
	
	# 重置摄像机限制（如果需要）
	# $Player/Camera2D.reset_smoothing()
