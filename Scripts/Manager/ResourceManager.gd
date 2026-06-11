extends Node

# ==============================================================================
# 资源管理器 (ResourceManager)
# 职责：处理跨平台的动态文件加载，解决导出后 .png 变 .ctex 的坑点。
# ==============================================================================

const CHAR_IMG_DIR = "res://Assets/Images/Characters/"

var _encounter_cache: Dictionary = {}
var _sex_cache: Dictionary = {}
var _depth_map_links: Dictionary = {}

func _ready() -> void:
	_scan_character_directory()

func _scan_character_directory() -> void:
	var dir = DirAccess.open(CHAR_IMG_DIR)
	if not dir:
		push_error("[ResourceManager] 找不到角色图片目录: " + CHAR_IMG_DIR)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var all_logical_files: Array[String] = []
	
	# 🔴 兼容编辑器与打包后的双轨读取法 (参考了 LLM客户端 项目)
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".png") or file_name.ends_with(".jpg"):
				if not all_logical_files.has(file_name):
					all_logical_files.append(file_name)
			elif file_name.ends_with(".import"):
				var logical_name = file_name.replace(".import", "")
				if (logical_name.ends_with(".png") or logical_name.ends_with(".jpg")) and not all_logical_files.has(logical_name):
					all_logical_files.append(logical_name)
		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	for file in all_logical_files:
		if "_depth" in file:
			continue 
			
		var char_id = file.split("_")[0]
		var base_name_without_ext = file.get_basename() 
		var found_depth = ""
		
		for d_file in all_logical_files:
			if "_depth" in d_file and d_file.begins_with(base_name_without_ext):
				found_depth = d_file
				break
				
		if found_depth != "":
			_depth_map_links[file] = found_depth
		else:
			push_warning("[ResourceManager] 警告: 图片没有找到配对的深度图 -> " + file)
			
		if "encounter" in file:
			if not _encounter_cache.has(char_id):
				_encounter_cache[char_id] = []
			_encounter_cache[char_id].append(file)
		elif "sex_scene" in file:
			_sex_cache[char_id] = file
			
	print("[ResourceManager] 扫描完毕。遭遇图缓存: ", _encounter_cache.keys(), " | 深度图配对对数: ", _depth_map_links.size())

func get_random_encounter_art(char_id: String, exclude_file_name: String = "") -> Dictionary:
	if not _encounter_cache.has(char_id) or _encounter_cache[char_id].is_empty():
		push_error("[ResourceManager] 找不到角色的 encounter 图片: " + char_id)
		return {"base": null, "depth": null, "file_name": ""}
		
	var list = _encounter_cache[char_id]
	var available_list = []
	
	for img in list:
		if img != exclude_file_name:
			available_list.append(img)
			
	if available_list.is_empty():
		available_list = list
		
	var random_img = available_list[randi() % available_list.size()]
	var depth_img = _depth_map_links.get(random_img, "")
	
	return {
		"base": load(CHAR_IMG_DIR + random_img),
		"depth": load(CHAR_IMG_DIR + depth_img) if depth_img != "" else null,
		"file_name": random_img
	}

func get_sex_scene_art(char_id: String) -> Dictionary:
	if not _sex_cache.has(char_id):
		push_error("[ResourceManager] 找不到角色的 sex_scene 图片: " + char_id)
		return {"base": null, "depth": null, "file_name": ""}
		
	var img = _sex_cache[char_id]
	var depth_img = _depth_map_links.get(img, "")
	
	return {
		"base": load(CHAR_IMG_DIR + img),
		"depth": load(CHAR_IMG_DIR + depth_img) if depth_img != "" else null,
		"file_name": img
	}
