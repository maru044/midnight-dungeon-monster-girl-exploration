extends TextureRect
class_name VisualController

# ==============================================================================
# 视觉控制器 (VisualController)
# 职责：挂载在主立绘节点上，结合 2.5D Shader 实现鼠标视差跟随，
# 并监听全局事件，实现“手电筒 -> 全亮 -> 色色”三阶段的无缝切换。
# ==============================================================================

@export var smooth_speed: float = 5.0

# 内部平滑变量
var _local_smoothed_offset: Vector2 = Vector2.ZERO
var _smoothed_mouse_uv: Vector2 = Vector2(0.5, 0.5)
var _current_file_name: String = ""

func _ready() -> void:
	# 监听游戏阶段生命周期
	EventBus.encounter_started.connect(_on_encounter_started)
	EventBus.visual_phase_changed.connect(_on_visual_phase_changed)

func _process(delta: float) -> void:
	# ---------------------------------------------------------
	# 1. 计算 2.5D 视差偏移 (Parallax Offset)
	# ---------------------------------------------------------
	var viewport = get_viewport()
	if not viewport: return
	
	var viewport_size = viewport.get_visible_rect().size
	var center = viewport_size / 2.0
	var mouse_pos = viewport.get_mouse_position()
	
	# 将鼠标坐标映射到 [-1.0, 1.0] 的偏移向量
	var target_offset = (mouse_pos - center) / center
	target_offset.x = clamp(target_offset.x, -1.0, 1.0)
	target_offset.y = clamp(target_offset.y, -1.0, 1.0)
	
	# 平滑逼近
	_local_smoothed_offset = _local_smoothed_offset.lerp(target_offset, delta * smooth_speed)

	# ---------------------------------------------------------
	# 2. 计算手电筒中心 UV (Mouse UV)
	# ---------------------------------------------------------
	var local_mouse = get_local_mouse_position()
	var rect_size = get_rect().size
	var target_uv = Vector2(0.5, 0.5)
	
	if rect_size.x > 0 and rect_size.y > 0:
		target_uv = local_mouse / rect_size
		target_uv.x = clamp(target_uv.x, 0.0, 1.0)
		target_uv.y = clamp(target_uv.y, 0.0, 1.0)
		
	# 手电筒跟随速度略快于视差，增加灵动感
	_smoothed_mouse_uv = _smoothed_mouse_uv.lerp(target_uv, delta * smooth_speed * 1.5) 

	# ---------------------------------------------------------
	# 3. 注入 Shader 材质参数
	# ---------------------------------------------------------
	if material and material is ShaderMaterial:
		material.set_shader_parameter("mouse_offset", _local_smoothed_offset)
		material.set_shader_parameter("mouse_uv", _smoothed_mouse_uv)

## ---------------------------------------------------------
## 核心逻辑：视觉阶段流转控制
## ---------------------------------------------------------

func _on_encounter_started(char_id: String) -> void:
	# 初始遭遇：加载随机的 encounter 图片和深度图
	var art = ResourceManager.get_random_encounter_art(char_id)
	_apply_art(art)
	# 默认强制进入阶段 1 (手电筒模式) 已经在 GameManager 中触发，
	# 稍后会通过 _on_visual_phase_changed 同步过来。

func _on_visual_phase_changed(phase: int) -> void:
	# 根据 GameManager 定义的 VisualPhase 枚举执行切换
	if phase == 1: # PHASE_1_FLASHLIGHT
		_set_effect_mode(1)
		
	elif phase == 2: # PHASE_2_NORMAL
		_set_effect_mode(0)
		# 【需求更新】：切阶段 2 时重 roll 遭遇图以展现揭开全貌的视觉冲击感
		var art = ResourceManager.get_random_encounter_art(GameManager.current_char_id, _current_file_name)
		_apply_art(art)
		
	elif phase == 3: # PHASE_3_SEX
		_set_effect_mode(0)
		# 只有在阶段 3 时，需要瞬间切换为色色图底图
		var art = ResourceManager.get_sex_scene_art(GameManager.current_char_id)
		_apply_art(art)

## 辅助函数：替换底图与深度图
func _apply_art(art_dict: Dictionary) -> void:
	if art_dict.has("file_name"):
		_current_file_name = art_dict["file_name"]
		
	if art_dict.has("base") and art_dict["base"]:
		texture = art_dict["base"]
	
	if material and material is ShaderMaterial:
		if art_dict.has("depth") and art_dict["depth"]:
			material.set_shader_parameter("depth_map", art_dict["depth"])

## 辅助函数：开关 Shader 的手电筒效果 (0=全亮视差, 1=手电筒视差)
func _set_effect_mode(mode: int) -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("effect_mode", mode)
