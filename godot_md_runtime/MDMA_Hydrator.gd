class_name MDMAHydrator
extends Node

signal mdma_button_pressed(option_id: String, payload: Dictionary)

@export var ui_container: Control
var _vfs_ref: MDVFS
var _regex: RegEx

func _ready() -> void:
	_regex = RegEx.new()
	if _regex.compile("```mdma-button\\s*([\\s\\S]*?)\\s*```") != OK:
		push_error("[MDMA] regex fail")

func setup_hydrator(vfs: MDVFS) -> void:
	_vfs_ref = vfs

func hydrate_markdown_ui(md_content: String) -> void:
	if ui_container == null or _regex == null or not _regex.is_valid():
		push_error("[MDMA] container/regex missing")
		return
	for c: Node in ui_container.get_children():
		c.queue_free()
	for rm: RegExMatch in _regex.search_all(md_content):
		var raw: String = rm.get_string(1).strip_edges()
		var parser: JSON = JSON.new()
		if parser.parse(raw) != OK:
			push_error("[MDMA] JSON fail: %s" % parser.get_error_message())
			continue
		if typeof(parser.get_data()) != TYPE_DICTIONARY:
			continue
		_create_runtime_button(parser.get_data())

func _create_runtime_button(button_data: Dictionary) -> void:
	var btn: Button = Button.new()
	btn.text = str(button_data.get("text", "option"))
	btn.name = "MDMA_Btn_%s" % str(button_data.get("id", "unknown"))
	btn.custom_minimum_size = Vector2(200, 45)
	var oid: String = str(button_data.get("id", ""))
	var domain: String = str(button_data.get("domain", "global"))
	var effects: Dictionary = button_data.get("effects", {})
	btn.pressed.connect(_on_mdma_button_clicked.bind(oid, domain, effects))
	ui_container.call_deferred("add_child", btn)

func _on_mdma_button_clicked(option_id: String, domain: String, effects: Dictionary) -> void:
	if _vfs_ref == null:
		push_error("[MDMA] VFS missing")
		return
	var pre: int = _vfs_ref.current_state.public_sentiment
	if effects.has("public_sentiment"):
		_vfs_ref.current_state.public_sentiment += int(effects["public_sentiment"])
	if effects.has("foreign_reserves"):
		_vfs_ref.current_state.foreign_reserves += int(effects["foreign_reserves"])
	if effects.has("bankruptcy_rate"):
		_vfs_ref.current_state.bankruptcy_rate += int(effects["bankruptcy_rate"])
	if effects.has("sanity_level"):
		_vfs_ref.current_state.sanity_level += int(effects["sanity_level"])
	if effects.has("body_scale"):
		_vfs_ref.current_state.body_scale += int(effects["body_scale"])
	if effects.has("vocabulary_grade"):
		_vfs_ref.current_state.vocabulary_grade += int(effects["vocabulary_grade"])
	var rule: String = _vfs_ref.evaluate_edge(pre, _vfs_ref.current_state.public_sentiment, domain)
	var artifact: Dictionary = _vfs_ref.save_artifact_node("SCENE_CURRENT", domain, option_id)
	artifact["rule_evaluation"] = rule
	artifact["space_desc"] = _vfs_ref.describe_space()
	artifact["gameover"] = _vfs_ref.is_gameover()
	mdma_button_pressed.emit(option_id, artifact)
