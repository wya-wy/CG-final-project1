extends Node

enum GameState {
	LOADING,
	IN_HUB,
	IN_GAME,
	PAUSED
}
var current_state: GameState = GameState.LOADING
var normal_mana: int = 100
var max_normal_mana: int = 100
var condensed_mana: int = 0
var max_condensed_mana: int = 100

var mana_recover_rate := 10 # 每秒恢复速度
var is_attacking := false 
func _ready():
	EventBus.player_died.connect(_on_player_died)
	# !!! initialized: begin with IN_GAME for test !!!
	change_state(GameState.IN_GAME)
set_process(true) # 开启 _process


func _process(delta):
	# 蓝量恢复逻辑
	if current_state == GameState.IN_GAME:
		if is_attacking:
			normal_mana = min(normal_mana + mana_recover_rate * delta, max_normal_mana)
			# 浓缩蓝量不增加
		else:
			normal_mana = min(normal_mana + mana_recover_rate * delta, max_normal_mana)
			condensed_mana = min(condensed_mana + mana_recover_rate * delta, max_condensed_mana)
		_emit_mana_changed()

func _emit_mana_changed():
	# 向 HUD 发送包含普通蓝和浓缩蓝量的事件
	EventBus.player_mana_changed.emit(normal_mana, max_normal_mana, condensed_mana, max_condensed_mana)

func consume_for_strong_slash(amount):
	# 强化斩击优先消耗普通蓝量
	if normal_mana >= amount:
		normal_mana -= amount
	elif condensed_mana >= amount:
		condensed_mana -= amount
	else:
		# 蓝量不足
		pass
	_emit_mana_changed()

func consume_for_spell(amount):
	# 法术消耗浓缩蓝量，同时表现为普通蓝量一起减少
	if condensed_mana >= amount:
		condensed_mana -= amount
		normal_mana = max(normal_mana - amount, 0)
		_emit_mana_changed()
	else:
		# 蓝量不足
		pass

func change_state(new_state: GameState):
	print("Game State changes from ", GameState.keys()[current_state], " to ", GameState.keys()[new_state])
	current_state = new_state

	match new_state:
		GameState.IN_GAME:
			# future: how to load level (load game)
			pass
		GameState.IN_HUB:
			# future: out-game development system
			pass
		GameState.PAUSED:
			# pause game
			get_tree().paused = true
		GameState.LOADING:
			pass

	if new_state != GameState.PAUSED:
		get_tree().paused = false


# --- 事件监听函数 ---

func _on_player_died():
	print("GameManager: Player died.")
	# 玩家死亡后，我们切换到“局外”（罪渊）状态
	change_state(GameState.IN_HUB)
normal_mana = max_normal_mana
	condensed_mana = 0
	_emit_mana_changed()
	# (未来的逻辑：在这里重置玩家状态，结算货币等)
