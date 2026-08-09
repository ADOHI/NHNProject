class_name SfxLibrary
extends RefCounted
## CC0 재료가 어디 있는지 (docs/design/29-sound.md §29.9).
##
## **여기가 §29.2 계약의 아래층이다.** 사건도 계약도 이 파일을 모른다.
##
## 재질마다 **강도 계단**을 둔다. 2판의 실패가 여기서 나왔다 — 파일 하나를 리샘플로
## 3배까지 늘여 무게 4를 만들었더니 "무거운 소리" 가 아니라 **"느리게 튼 소리"** 였다.
## **무거운 소리는 다른 녹음이지 느린 녹음이 아니다.**
##
## 출처와 라이선스는 `assets/audio/sfx/CREDITS.md` 에 파일 단위로 있다. 전부 CC0 다.

const ROOT := "res://assets/audio/sfx"

## 묶음 -> 강도 -> 개수. `tools/build_sfx_library.py` 가 그대로 찍어 준다.
const COUNTS := {
	"metal": {"light": 3, "medium": 3, "heavy": 3},
	"wood": {"light": 3, "medium": 3, "heavy": 3},
	"flesh": {"light": 3, "medium": 3, "heavy": 3},
	"stone": {"light": 2, "medium": 3, "heavy": 3},
	"cloth": {"medium": 5},
	"dirt": {"medium": 5},
	"low": {"medium": 5},
	"air": {"medium": 3},
	"click": {"medium": 7},
	"tone_up": {"medium": 3},
	"tone_down": {"medium": 4},
}

## 각 단이 대표하는 무게. 무게 4를 달라고 하면 heavy 를 꺼내고,
## 3.6 과 4.0 의 차이만 리샘플로 메운다 (SfxVoice.RESIDUAL_*).
const TIER_WEIGHT := {"light": 1.0, "medium": 2.2, "heavy": 3.6}

## 무게가 커지면 얹는 저역 몸통. **늘이는 게 아니라 더한다.**
const LOW_FOLDER := "low"

const MATERIAL_FOLDER := {
	SfxMaterial.Kind.METAL: "metal",
	SfxMaterial.Kind.WOOD: "wood",
	SfxMaterial.Kind.FLESH: "flesh",
	SfxMaterial.Kind.STONE: "stone",
	SfxMaterial.Kind.CLOTH: "cloth",
	SfxMaterial.Kind.DIRT: "dirt",
}

static var _paths: Dictionary = {}


## 이 요청에 쓸 파일들. **없으면 빈 배열** — 그때는 합성이 메운다.
static func paths_for(request: SfxRequest) -> PackedStringArray:
	var folder := folder_for(request)
	if folder.is_empty():
		return PackedStringArray()
	return paths_in(folder, tier_for(folder, request.weight))


## 묶음 하나의 한 단에 있는 파일들.
static func paths_in(folder: String, tier: String) -> PackedStringArray:
	var key := "%s/%s" % [folder, tier]
	if _paths.has(key):
		return _paths[key]
	var found := PackedStringArray()
	var tiers: Dictionary = COUNTS.get(folder, {})
	for index in int(tiers.get(tier, 0)):
		var path := "%s/%s/%s_%02d.wav" % [ROOT, folder, tier, index]
		if ResourceLoader.exists(path):
			found.append(path)
	_paths[key] = found
	return found


## 이 무게에 맞는 강도 단. **있는 단 중에서** 대표 무게가 가장 가까운 것을 고른다.
##
## 강도별 녹음이 없는 재질(천 · 흙)은 한 단뿐이라 항상 그 단이 나온다.
static func tier_for(folder: String, weight: float) -> String:
	var tiers: Dictionary = COUNTS.get(folder, {})
	var best := ""
	var best_distance := INF
	for tier in tiers:
		var distance: float = absf(float(TIER_WEIGHT.get(tier, 2.2)) - weight)
		if distance < best_distance:
			best_distance = distance
			best = tier
	return best


## 고른 단이 대표하는 무게. 리샘플 잔여분을 계산하는 데 쓴다.
static func tier_weight_for(folder: String, weight: float) -> float:
	var tier := tier_for(folder, weight)
	if tier.is_empty():
		return weight
	return float(TIER_WEIGHT.get(tier, 2.2))


static func folder_for(request: SfxRequest) -> String:
	match request.kind:
		SfxRequest.Kind.WHOOSH:
			# 바람은 재질과 무관하다. 공기를 가르는 소리에 "금속" 은 없다.
			return "air"
		SfxRequest.Kind.TICK:
			return "click"
		SfxRequest.Kind.TONE:
			# 올라감/내려감을 피치 조작으로 만들지 않는다. **원래 그렇게 녹음된 것**을 쓴다.
			return "tone_down" if request.bend == SfxRequest.Bend.DOWN else "tone_up"
		_:
			return MATERIAL_FOLDER.get(request.material, "")


## 저역 몸통 레이어 파일들.
static func low_paths() -> PackedStringArray:
	return paths_in(LOW_FOLDER, "medium")


static func has_material(request: SfxRequest) -> bool:
	return not paths_for(request).is_empty()


## 재료가 없는 사건들. 문서와 테스트가 구멍을 세는 데 쓴다.
static func gaps() -> Array[SfxEvent.Kind]:
	var found: Array[SfxEvent.Kind] = []
	for event in SfxEvent.all():
		if not has_material(SfxCatalog.request_for(event)):
			found.append(event)
	return found


## 실제로 디스크에 있는 파일 총 개수.
static func file_count() -> int:
	var total := 0
	for folder in COUNTS:
		for tier in COUNTS[folder]:
			total += paths_in(folder, tier).size()
	return total


static func clear_cache() -> void:
	_paths.clear()
