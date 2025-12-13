extends Camera2D

# 垂直偏移量：正数表示向下偏移（让玩家看起来在屏幕上方），负数表示向上偏移（让玩家看起来在屏幕下方）
# 想要玩家在屏幕“中下部”，意味着摄像机中心要比玩家位置“高”一些，或者我们直接设置 Camera 的 offset。
# 但由于这里是代码控制 position，我们给目标位置加一个偏移量。

# 目标偏移：让摄像机中心位于玩家上方 100 像素，这样玩家就在屏幕中心下方 100 像素处。
@export var vertical_offset: float = -200.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 启用内置的位置平滑，替代之前的 lerp 代码
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# 作为子节点，摄像机会自动跟随玩家。
	# 我们只需要设置本地坐标的 Y 值来实现垂直偏移。
	position.x = 0 # 保持水平居中
	position.y = vertical_offset
