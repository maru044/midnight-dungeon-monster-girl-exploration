extends Node

# ==============================================================================
# 存档管理器 (SaveManager)
# 职责：负责处理跨会话的记忆保存与读取。严格隔离不同角色的上下文数据。
# 支持多槽位存档，显示时间戳，处理新建/删除。
# ==============================================================================

const SAVES_DIR = "user://saves/"

func _ready() -> void:
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(SAVES_DIR):
		dir.make_dir_recursive(SAVES_DIR)

## 确保角色的专属文件夹存在
func _ensure_char_dir(char_id: String) -> void:
	var dir = DirAccess.open(SAVES_DIR)
	if dir and not dir.dir_exists(char_id):
		dir.make_dir(char_id)

## 检查是否曾经遭遇过该角色（只要文件夹存在就算解锁图鉴，方便作者后台建空文件夹当后门）
func has_encountered(char_id: String) -> bool:
	var dir = DirAccess.open(SAVES_DIR)
	return dir != null and dir.dir_exists(char_id)

## 检查指定角色是否有正在进行的自动存档（用于判断是否初见）
func has_save(char_id: String) -> bool:
	var path = SAVES_DIR + char_id + "/autosave.json"
	return FileAccess.file_exists(path)

## 读取角色的默认/自动存档
func load_history(char_id: String) -> Array:
	return load_slot(char_id, "autosave")

## 写入自动存档
func save_history(char_id: String, context_array: Array) -> void:
	save_slot(char_id, "autosave", context_array)

## 获取指定角色的所有存档列表
func get_all_saves(char_id: String) -> Array:
	var saves = []
	var char_dir = SAVES_DIR + char_id + "/"
	var dir = DirAccess.open(char_dir)
	if not dir: return saves
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var slot_name = file_name.replace(".json", "")
			var path = char_dir + file_name
			var modified_time = FileAccess.get_modified_time(path)
			var time_dict = Time.get_datetime_dict_from_unix_time(modified_time)
			var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [time_dict.year, time_dict.month, time_dict.day, time_dict.hour, time_dict.minute, time_dict.second]
			
			saves.append({
				"slot_name": slot_name,
				"file_name": file_name,
				"time_str": time_str,
				"timestamp": modified_time
			})
		file_name = dir.get_next()
		
	# 按时间倒序排序
	saves.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	return saves

## 保存到指定槽位
func save_slot(char_id: String, slot_name: String, context_array: Array) -> void:
	if char_id.strip_edges() == "" or context_array.is_empty() or slot_name.strip_edges() == "":
		return
		
	_ensure_char_dir(char_id)
	var path = SAVES_DIR + char_id + "/" + slot_name + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(context_array, "\t")
		file.store_string(json_string)
		file.close()
		print("[SaveManager] 存档已成功保存 -> ", path)
	else:
		push_error("[SaveManager] 无法打开或创建存档文件: " + path)

## 读取指定槽位
func load_slot(char_id: String, slot_name: String) -> Array:
	var path = SAVES_DIR + char_id + "/" + slot_name + ".json"
	if not FileAccess.file_exists(path):
		return []
		
	var content = FileAccess.get_file_as_string(path)
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK and typeof(json.data) == TYPE_ARRAY:
		return json.data
	else:
		push_error("[SaveManager] 读取存档失败，JSON 解析错误: " + path)
		return []

## 删除指定槽位
func delete_slot(char_id: String, slot_name: String) -> void:
	var path = SAVES_DIR + char_id + "/" + slot_name + ".json"
	if FileAccess.file_exists(path):
		var dir = DirAccess.open(SAVES_DIR + char_id + "/")
		if dir:
			dir.remove(slot_name + ".json")
			print("[SaveManager] 已删除存档: ", path)
