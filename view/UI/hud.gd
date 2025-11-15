extends CanvasLayer

@onready var health_label: Label = $Label

func _ready():
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_died.connect(_on_player_died)

func _on_player_health_changed(current_health: int, max_health: int):
	health_label.text = "Health: %d / %d" % [current_health, max_health]

func _on_player_died():
	health_label.text = "Player Died"
