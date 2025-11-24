extends CanvasLayer

@onready var health_label: Label = $Label
# 请在 HUD 场景中添加一个新的 Label 节点，并将其命名为 "ManaLabel"
@onready var mana_label: Label = $ManaLabel

func _ready():
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)

func _on_player_health_changed(current_health: int, max_health: int):
	health_label.text = "Health: %d / %d" % [current_health, max_health]

func _on_player_mana_changed(current_mana: int, max_mana: int):
	if mana_label:
		mana_label.text = "Mana: %d / %d" % [current_mana, max_mana]

func _on_player_died():
	health_label.text = "Player Died"
