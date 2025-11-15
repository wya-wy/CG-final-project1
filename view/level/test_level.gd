extends Node2D

func _ready():
	EventBus.player_attacked.connect(_on_player_attacked)


func _on_player_attacked(spell: Spell):
	print("--- TestLevel Listening ---")
	print("EventBus: Player uses ", spell.spell_name)
	print("-----------------------------")
