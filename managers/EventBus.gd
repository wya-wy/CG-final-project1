extends Node

signal player_attacked(spell: Spell)

signal player_melee_attacked

signal player_health_changed(current_health: int, max_health: int)

signal player_died

signal enemy_defeated(enemy_type: String)

signal player_mana_changed(normal_mana: int, max_normal_mana: int, condensed_mana: int, max_condensed_mana: int)
