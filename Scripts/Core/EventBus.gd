extends Node

# ==============================================================================
# 全局事件总线 (EventBus)
# 职责：解耦各个模块，所有跨模块的通信都通过这里以信号形式分发。
# 作为 Autoload (单例) 运行。
# ==============================================================================

# ---------------------------------------------------------
# 系统与配置状态
# ---------------------------------------------------------
signal api_key_updated(new_key: String)

## 提示词预设在外部被玩家修改并保存，触发热重载
signal presets_reloaded()

# ---------------------------------------------------------
# 游戏流程与状态机
# ---------------------------------------------------------
## 触发遭遇战 (参数：角色 ID，如 "hakuri", "hiba", "shion")
signal encounter_started(char_id: String)

## 退出遭遇战，返回主菜单
signal encounter_ended()

## 视觉阶段发生变化 (参数：1=手电筒, 2=全亮遭遇, 3=全亮色色)
signal visual_phase_changed(new_phase: int)

# ---------------------------------------------------------
# LLM 网络通信与解析
# ---------------------------------------------------------
## 玩家点击发送消息
signal player_message_sent(text: String)

## LLM 开始回复 (用于 UI 锁定和 Loading 提示)
signal llm_response_started()

## LLM 流式返回的文本块 (用于打字机效果)
signal llm_response_chunk(chunk: String)

## LLM 完整回复结束
signal llm_response_finished()

## 解析器在 <commands> 区块中捕获到了系统指令标签
## 常见 tag_name: "[开灯]", "[上床]"
signal llm_tag_detected(tag_name: String)

# ---------------------------------------------------------
# 错误与警告
# ---------------------------------------------------------
## 系统抛出错误提示 (用于 UI 弹出 Toast 提示框)
signal system_error_occurred(error_msg: String)
