class_name MDVFS
extends RefCounted

# Two-Nodes 상태: 기존 3종 + 앨리스 확장 3종
class GlobalState:
	var foreign_reserves: int = 400:
		set(v): foreign_reserves = clampi(v, 0, 999)
	var bankruptcy_rate: int = 10:
		set(v): bankruptcy_rate = clampi(v, 0, 100)
	var public_sentiment: int = 50:
		set(v): public_sentiment = clampi(v, 0, 100)
	# --- 앨리스 확장 ---
	var sanity_level: int = 70:
		set(v): sanity_level = clampi(v, 0, 100)
	var body_scale: int = 100: # 100=정상 체격(%), 작아질수록 축소
		set(v): body_scale = clampi(v, 10, 200)
	var vocabulary_grade: int = 2: # 1~6
		set(v): vocabulary_grade = clampi(v, 1, 6)
	func to_dict() -> Dictionary:
		return {
			"foreign_reserves": foreign_reserves, "bankruptcy_rate": bankruptcy_rate,
			"public_sentiment": public_sentiment, "sanity_level": sanity_level,
			"body_scale": body_scale, "vocabulary_grade": vocabulary_grade,
		}

var current_state: GlobalState
var active_explicit_rules: Array[String] = []

func _init() -> void:
	current_state = GlobalState.new()

func evaluate_edge(input_sentiment: int, output_sentiment: int, domain: String = "alice") -> String:
	var d: String = domain.strip_edges()
	if d.is_empty():
		d = "alice"
	# C(QA): 게임오버 우선 판정 (sanity 양극단)
	var go: String = check_gameover(d)
	if go != "":
		return go
	if output_sentiment < 30:
		var rule: String = "FOR domain=%s WHEN public_sentiment < 30 LIMIT max_negative_effect TO -5" % d
		if not active_explicit_rules.has(rule):
			active_explicit_rules.append(rule)
			push_warning("[MD_VFS] rule: %s" % rule)
		return rule
	return "SYSTEM_STABLE"

func evaluate_edge_full(input_sentiment: int, output_sentiment: int, domain: String = "alice") -> Dictionary:
	var rule: String = evaluate_edge(input_sentiment, output_sentiment, domain)
	return {"delta": output_sentiment - input_sentiment, "rule": rule, "needs_patch": rule != "SYSTEM_STABLE"}

# C(QA): sanity 0/100 게임오버 방어. 발동 시 규칙 등록 후 문자열 반환, 아니면 ""
func check_gameover(domain: String = "alice") -> String:
	var s: int = current_state.sanity_level
	if s <= 0:
		var r0: String = "FOR domain=%s WHEN sanity_level <= 0 TRIGGER ending_mad_tea_bust" % domain
		if not active_explicit_rules.has(r0):
			active_explicit_rules.append(r0)
			push_error("[MD_VFS] GAMEOVER sanity=0")
		return r0
	if s >= 100:
		var r1: String = "FOR domain=%s WHEN sanity_level >= 100 TRIGGER ending_too_sane_exit" % domain
		if not active_explicit_rules.has(r1):
			active_explicit_rules.append(r1)
			push_error("[MD_VFS] GAMEOVER sanity=100")
		return r1
	return ""

func is_gameover() -> bool:
	return current_state.sanity_level <= 0 or current_state.sanity_level >= 100

# A(아키텍트): body_scale → 공간 묘사 엣지. 렌더 텍스트에 이어붙이는 한 줄 반환
func describe_space() -> String:
	var b: int = current_state.body_scale
	if b < 50:
		return "천장이 아득하고, 문은 우표만 해 보인다. (body_scale=%d)" % b
	if b <= 150:
		return "방과 문이 평소 크기로 보인다. (body_scale=%d)" % b
	return "몸이 커서 복도가 비좁다. 문고리가 손가락만 해 보인다. (body_scale=%d)" % b

func save_artifact_node(scene_id: String, domain: String, selected_option: String) -> Dictionary:
	return {"scene_id": str(scene_id), "domain": str(domain),
		"global_state": current_state.to_dict(), "selected_option": str(selected_option)}
