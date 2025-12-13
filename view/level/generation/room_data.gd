class_name RoomData
extends Node2D

# 房间在网格中的尺寸（通常是 1x1）
@export var grid_width: int = 1
@export var grid_height: int = 1

# 房间的出口定义
@export_group("Exits")
@export var exit_top: bool = false
@export var exit_bottom: bool = false
@export var exit_left: bool = false
@export var exit_right: bool = false

# 可以在这里添加更多元数据，比如房间类型（战斗、宝箱、商店等）
@export var room_type: String = "normal"
