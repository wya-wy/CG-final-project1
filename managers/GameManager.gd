extends Node

enum GameState {
	LOADING,
	IN_HUB,
	IN_GAME,
	PAUSED
}
var current_state: GameState = GameState.LOADING

func _ready():
	EventBus.player_died.connect(_on_player_died)
	# !!! initialized: begin with IN_GAME for test !!!
	change_state(GameState.IN_GAME)

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

	# (未来的逻辑：在这里重置玩家状态，结算货币等)
