extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $Label
@onready var mana_bar_total: ProgressBar = $ManaBarTotal
@onready var mana_bar_condensed: ProgressBar = $ManaBarCondensed
@onready var mana_label: Label = $ManaLabel

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

func _on_player_mana_changed(normal: float, condensed: float, max_normal: int, max_condensed: int):
	if mana_bar_total:
		mana_bar_total.max_value = max_normal
		mana_bar_total.value = normal # 这里显示的是总长度

	if mana_bar_condensed:
		# 虽然浓缩蓝的真实上限比max_normal小，但为了让它在UI上看起来只占普通蓝的一部分长，
		# 我们把它的 UI max_value 设为和普通蓝一样。
		mana_bar_condensed.max_value = max_normal
		mana_bar_condensed.value = condensed

	if mana_label:
		mana_label.text = "N:%d + C:%d" % [int(normal), int(condensed)]

func _on_player_died():
	if health_label:
		health_label.text = "DEAD"
