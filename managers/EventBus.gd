extends Node

signal player_attacked(spell: Spell)

signal player_health_changed(current_health: int, max_health: int)

signal player_died

signal enemy_defeated(enemy_type: String)
