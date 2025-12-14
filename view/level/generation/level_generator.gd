class_name LevelGenerator
extends Node

@export_category("Generation Settings")
@export var grid_width: int = 0
@export var grid_height: int = 0
@export var cell_size: Vector2 = Vector2(1920, 1080) # 你的房间像素大小
@export var max_rooms: int = 15
@export var min_rooms: int = 8

@export_category("Loop Generation")
@export var loop_probability: float = 0.4
@export var min_loop_gap: int = 3
@export var max_loop_gap: int = 8

@export_category("Room Pools")
@export var treasure_room: PackedScene
# 必须包含各种连接类型的房间。
@export var room_scenes: Array[PackedScene]
@export var start_room: PackedScene
@export var end_room: PackedScene

# 内部网格数据：Vector2i -> Dictionary
# Dictionary 包含: { "type": "normal", "exits": [Vector2i.UP, ...] }
var grid: Dictionary = {}
var rng = RandomNumberGenerator.new()

# 缓存房间数据：Key (String "U_D_L_R") -> Array[PackedScene]
var room_cache: Dictionary = {}

signal level_generated(start_position: Vector2)

func _ready():
	rng.randomize()
	_build_room_cache()

func _build_room_cache():
	print("Building room cache...")
	for scene in room_scenes:
		var temp = scene.instantiate()
		if temp is RoomData:
			var key = _get_exit_key(temp.exit_top, temp.exit_bottom, temp.exit_left, temp.exit_right)
			if not room_cache.has(key):
				room_cache[key] = []
			room_cache[key].append(scene)
		else:
			push_warning("Scene in room_scenes does not have RoomData script attached: " + scene.resource_path)
		temp.free()
	print("Room cache built: ", room_cache.keys())

func _get_exit_key(up: bool, down: bool, left: bool, right: bool) -> String:
	return str(int(up)) + "_" + str(int(down)) + "_" + str(int(left)) + "_" + str(int(right))

func generate_level():
	# 1. 清理旧关卡
	for child in get_children():
		child.queue_free()
	grid.clear()
	
	# 2. 生成布局 (Layout)
	_generate_layout()
	
	# 3. 实例化房间 (Instantiate)
	_instantiate_rooms()

func _generate_layout():
	var current_pos = Vector2i(int(grid_width / 2), int(grid_height / 2))
	grid[current_pos] = { "type": "start", "exits": [] }
	
	# --- 第一步：生成主路径 (Main Path) ---
	var walker_pos = current_pos
	var main_path = [current_pos]
	
	# 强制第一步向右 (Force Right)
	# 这样保证起点房间（只有右出口）一定能接上
	var first_dir = Vector2i.RIGHT
	var first_new_pos = walker_pos + first_dir
	
	if _is_in_bounds(first_new_pos):
		grid[first_new_pos] = { "type": "normal", "exits": [] }
		_connect_rooms(walker_pos, first_new_pos, first_dir)
		walker_pos = first_new_pos
		main_path.append(first_new_pos)
	else:
		push_error("Grid is too small or start pos is at edge, cannot go RIGHT!")
	
	# 继续随机游走
	var attempts = 0
	while main_path.size() < min_rooms and attempts < 100:
		attempts += 1
		var dir = _get_random_direction()
		var new_pos = walker_pos + dir
		
		if _is_in_bounds(new_pos):
			if not grid.has(new_pos):
				grid[new_pos] = { "type": "normal", "exits": [] }
				_connect_rooms(walker_pos, new_pos, dir)
				walker_pos = new_pos
				main_path.append(new_pos)
			else:
				# 如果撞到自己，有概率重置位置到路径上的某一点，或者继续走
				# 这里简单处理：如果撞到，就从当前撞到的位置继续尝试
				walker_pos = new_pos
	
	# 标记终点
	var end_pos = main_path.back()
	grid[end_pos]["type"] = "end"
	print("Main path generated. Length: ", main_path.size())
	
	# --- 第二步：生成回环 (Loops) ---
	# 遍历主路径，尝试在相隔一定距离的两个节点之间建立“捷径”或“绕路”
	# 修复：跳过起点(index 0)和终点(index size-1)，防止改变它们的固定连接数
	# 范围从 1 开始，到 size - 1 结束（不包含终点）
	for i in range(1, main_path.size() - 1):
		if rng.randf() < loop_probability:
			var gap = rng.randi_range(min_loop_gap, max_loop_gap)
			var target_idx = i + gap
			
			# 确保目标点也不是终点
			if target_idx < main_path.size() - 1:
				var start_node = main_path[i]
				var end_node = main_path[target_idx]
				_try_generate_loop(start_node, end_node)

func _try_generate_loop(start_pos: Vector2i, end_pos: Vector2i):
	# 使用 BFS 寻找一条不经过现有房间（除了起点和终点）的路径
	var path = _find_path_bfs(start_pos, end_pos)
	
	if path.size() > 1:
		print("Generating loop from ", start_pos, " to ", end_pos, " length: ", path.size())
		# 沿着路径创建房间并连接
		for i in range(path.size() - 1):
			var curr = path[i]
			var next = path[i+1]
			var dir = next - curr
			
			# 确保当前点有数据（起点肯定有，中间点是刚生成的）
			if not grid.has(curr):
				grid[curr] = { "type": "normal", "exits": [] }
			
			# 确保下一点有数据（如果是终点肯定有，如果是中间点则新建）
			if not grid.has(next):
				grid[next] = { "type": "normal", "exits": [] }
			
			_connect_rooms(curr, next, dir)

func _find_path_bfs(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	var queue = []
	queue.append([start_pos])
	
	var visited = { start_pos: true }
	
	# 限制搜索深度和迭代次数，防止卡死
	var max_depth = 15
	var iterations = 0
	var max_iterations = 300
	
	while queue.size() > 0:
		iterations += 1
		if iterations > max_iterations:
			break
			
		var current_path = queue.pop_front()
		var current_node = current_path.back()
		
		if current_path.size() > max_depth:
			continue
		
		var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		directions.shuffle() # 随机打乱方向，产生随机形状的回路
		
		for dir in directions:
			var next_pos = current_node + dir
			
			# 如果找到了终点
			if next_pos == end_pos:
				return current_path + [next_pos]
			
			# 检查是否可行：在边界内，且不是现有的房间（避免穿过主路其他部分）
			if _is_in_bounds(next_pos) and not grid.has(next_pos) and not visited.has(next_pos):
				visited[next_pos] = true
				var new_path = current_path.duplicate()
				new_path.append(next_pos)
				queue.append(new_path)
	
	return []

func _get_random_direction() -> Vector2i:
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	return directions[rng.randi() % directions.size()]

func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

func _connect_rooms(pos1: Vector2i, pos2: Vector2i, direction: Vector2i):
	# pos1 -> pos2 是 direction
	if not grid[pos1]["exits"].has(direction):
		grid[pos1]["exits"].append(direction)
	
	# pos2 -> pos1 是 -direction
	if not grid[pos2]["exits"].has(-direction):
		grid[pos2]["exits"].append(-direction)

func _instantiate_rooms():
	for pos in grid:
		var room_data = grid[pos]
		var room_instance: Node2D = null
		
		# 尝试实例化特殊房间，但必须检查出口匹配
		if room_data["type"] == "start" and start_room:
			var temp = start_room.instantiate()
			if _check_exits_match(temp, room_data["exits"]):
				room_instance = temp
			else:
				push_warning("Start room exits mismatch! Required: " + str(room_data["exits"]) + ". Falling back to generic room.")
				temp.free()
				
		elif room_data["type"] == "end" and end_room:
			var temp = end_room.instantiate()
			# 即使是终点，如果逻辑上有多条路连进来，而预制体只有一个口，也会出问题
			if _check_exits_match(temp, room_data["exits"]):
				room_instance = temp
			else:
				push_warning("End room exits mismatch! Required: " + str(room_data["exits"]) + ". Falling back to generic room.")
				temp.free()
				
		elif room_data["type"] == "treasure" and treasure_room:
			var temp = treasure_room.instantiate()
			if _check_exits_match(temp, room_data["exits"]):
				room_instance = temp
			else:
				temp.free()
		
		# 如果特殊房间不匹配或未定义，或者本来就是普通房间，则查找匹配的房间
		if room_instance == null:
			room_instance = _find_matching_room(room_data["exits"])
		
		if room_instance:
			add_child(room_instance)
			# 计算世界坐标
			room_instance.position = Vector2(pos.x * cell_size.x, pos.y * cell_size.y)
			
			# 调试显示类型
			if room_instance.has_node("Label"): # 假设你有个Label用于调试
				room_instance.get_node("Label").text = room_data["type"]
		else:
			# 打印出具体缺少的出口组合，方便你查漏补缺
			var missing_exits_str = ""
			if room_data["exits"].has(Vector2i.UP): missing_exits_str += "UP "
			if room_data["exits"].has(Vector2i.DOWN): missing_exits_str += "DOWN "
			if room_data["exits"].has(Vector2i.LEFT): missing_exits_str += "LEFT "
			if room_data["exits"].has(Vector2i.RIGHT): missing_exits_str += "RIGHT "
			
			push_error("MISSING ROOM TYPE! Need exits: [" + missing_exits_str + "] at " + str(pos))

	# 找到起点房间的位置 (移到循环外)
	for pos in grid:
		if grid[pos]["type"] == "start":
			var start_world_pos = Vector2(pos.x * cell_size.x, pos.y * cell_size.y)
			# 假设起点房间中心就是出生点，或者你可以加个偏移量
			# 更好的做法是在 StartRoom 场景里放一个 Marker2D 叫 "SpawnPoint"
			emit_signal("level_generated", start_world_pos)
			break

func _find_matching_room(required_exits: Array) -> Node2D:
	var need_up = required_exits.has(Vector2i.UP)
	var need_down = required_exits.has(Vector2i.DOWN)
	var need_left = required_exits.has(Vector2i.LEFT)
	var need_right = required_exits.has(Vector2i.RIGHT)
	
	var key = _get_exit_key(need_up, need_down, need_left, need_right)
	
	if room_cache.has(key):
		var candidates = room_cache[key]
		if candidates.size() > 0:
			return candidates[rng.randi() % candidates.size()].instantiate()
	
	return null

func _check_exits_match(room_instance: Node2D, required_exits: Array) -> bool:
	var room_data = room_instance
	if not room_data is RoomData:
		room_data = room_instance.get_node_or_null("RoomData")
		if not room_data: return false

	var room_has_up = room_data.exit_top
	var room_has_down = room_data.exit_bottom
	var room_has_left = room_data.exit_left
	var room_has_right = room_data.exit_right
	
	var need_up = required_exits.has(Vector2i.UP)
	var need_down = required_exits.has(Vector2i.DOWN)
	var need_left = required_exits.has(Vector2i.LEFT)
	var need_right = required_exits.has(Vector2i.RIGHT)
	
	return room_has_up == need_up and \
		   room_has_down == need_down and \
		   room_has_left == need_left and \
		   room_has_right == need_right
