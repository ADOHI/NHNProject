class_name SfxLibrary
extends RefCounted
## CC0 재료가 어디 있는지 (docs/design/29-sound.md §29.9).
##
## **여기가 §29.2 계약의 아래층이다.** 사건도 계약도 이 파일을 모른다 —
## 합성에서 파일로 갈아 끼울 때 바뀐 것이 여기와 SfxSample 뿐이었다.
##
## 재질 여섯 + 바람 + 딸깍. **무기 13종이 아니다** — 무게와 변주는 엔진이 계산한다 (§29.4).
## 출처와 라이선스는 `assets/audio/sfx/CREDITS.md` 에 파일 단위로 있다. 전부 CC0 다.

const ROOT := "res://assets/audio/sfx"

## 묶음별 파일 개수. `tools/build_sfx_library.py` 가 `<묶음>_00.wav` 부터 순서대로 굽는다.
##
## 개수를 여기 박아 두는 이유는 내보낸 빌드에서 `DirAccess` 로 훑는 것이
## 임포트 방식에 따라 흔들리기 때문이다. `test_sfx_library.gd` 가 실제 파일 존재를 검사한다.
const COUNTS := {
	"metal": 8,
	"wood": 8,
	"flesh": 8,
	"stone": 8,
	"cloth": 7,
	"dirt": 8,
	"air": 3,
	"click": 7,
	"tone_up": 4,
	"tone_down": 4,
}

## 재질 -> 묶음 이름. IMPACT 일 때 쓴다.
const MATERIAL_FOLDER := {
	SfxMaterial.Kind.METAL: "metal",
	SfxMaterial.Kind.WOOD: "wood",
	SfxMaterial.Kind.FLESH: "flesh",
	SfxMaterial.Kind.STONE: "stone",
	SfxMaterial.Kind.CLOTH: "cloth",
	SfxMaterial.Kind.DIRT: "dirt",
}

static var _paths: Dictionary = {}


## 이 요청에 쓸 파일들. **없으면 빈 배열** — 그때는 합성이 메운다 (§29.10).
static func paths_for(request: SfxRequest) -> PackedStringArray:
	var folder := folder_for(request)
	if folder.is_empty():
		return PackedStringArray()
	if _paths.has(folder):
		return _paths[folder]

	var found := PackedStringArray()
	for index in int(COUNTS.get(folder, 0)):
		var path := "%s/%s/%s_%02d.wav" % [ROOT, folder, folder, index]
		if ResourceLoader.exists(path):
			found.append(path)
	_paths[folder] = found
	return found


## 이 요청이 어느 묶음을 쓰는가. 빈 문자열이면 재료가 없다는 뜻이다.
static func folder_for(request: SfxRequest) -> String:
	match request.kind:
		SfxRequest.Kind.WHOOSH:
			# 바람은 재질과 무관하다. 공기를 가르는 소리에 "금속" 은 없다.
			return "air"
		SfxRequest.Kind.TICK:
			return "click"
		SfxRequest.Kind.TONE:
			# 올라감/내려감을 피치 조작으로 만들지 않는다. **원래 그렇게 녹음된 것**을 쓴다 —
			# 확인음과 오류음은 사람이 그렇게 들으라고 만든 소리다.
			return "tone_down" if request.bend == SfxRequest.Bend.DOWN else "tone_up"
		_:
			return MATERIAL_FOLDER.get(request.material, "")


## 재료가 있는가. 없으면 합성으로 간다.
static func has_material(request: SfxRequest) -> bool:
	return not paths_for(request).is_empty()


## 재료가 없는 사건들. 문서와 테스트가 구멍을 세는 데 쓴다 (§29.9.4).
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
		var request := SfxRequest.impact(SfxMaterial.Kind.METAL, 1.0)
		total += _count_folder(folder)
	return total


static func _count_folder(folder: String) -> int:
	var found := 0
	for index in int(COUNTS.get(folder, 0)):
		if ResourceLoader.exists("%s/%s/%s_%02d.wav" % [ROOT, folder, folder, index]):
			found += 1
	return found


static func clear_cache() -> void:
	_paths.clear()
