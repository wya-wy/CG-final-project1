extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var health_label: Label = $HealthBar/Label
@onready var mana_label: Label = $ManaBar/Label

func _ready():
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)

func _on_player_health_changed(current_health: int, max_health: int):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

func _on_player_mana_changed(current_mana: int, max_mana: int):
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana
	if mana_label:
		mana_label.text = "%d / %d" % [current_mana, max_mana]

func _on_player_died():
	if health_label:
		health_label.text = "DEAD"
