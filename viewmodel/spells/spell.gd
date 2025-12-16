extends Resource

class_name Spell


@export var spell_name: String = "New Spell"
@export var spell_description: String = ""
@export var icon: Texture2D
@export var mana_cost: int = 10

@export var damage: int = 10
@export var cooldown_reduction: float = 0.0

@export var effect_id: String = "fireball"
