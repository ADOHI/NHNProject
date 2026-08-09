class_name CharSkin
extends RefCounted
## 파츠 PNG 여섯을 읽어 **리그와 그림을 한꺼번에** 만든다.
##
## `docs/design/25-character-animation.md` §25.41 이 규약이다.
##
## ## 이 파일이 지키는 세 가지
##
## * **피벗을 안 받는다.** 알파 경계상자에서 규칙으로 뽑는다 (§25.41.3)
## * **배율을 안 받는다.** **파츠마다** 리그가 아는 목표 상자에 맞춰 스스로 뽑는다
## * **자리를 안 받는다.** `CharRig.from_part_sizes()` 가 푼다 (§25.41.5)
##
## ## 배율이 여섯 벌이다 — **한 벌이었다가 바뀌었다**
##
## 처음에는 **머리 하나로 여섯의 배율을 정했다.** 「여섯이 같은 시트에서 잘렸으니
## 배율은 저절로 맞는다」가 전제였다. **배율은 맞았고 비례가 안 맞았다** —
## 실물을 재 보니 발이 리그보다 **66 %** 크고 손이 **19 %** 작았다 (§25.41.7).
##
## **같은 배율이라는 것은 「시트 안에서 서로 안 어긋난다」는 뜻일 뿐, 그 비례가
## 리그가 원하는 비례라는 뜻이 아니다.** 부츠에 굽이 있으면 발이 크게 그려진다.
##
## 그래서 **파츠마다 제 배율**을 준다. 목표는 리그가 이미 알고 있다.
##
## > **비례는 리그가 정하고 그림은 생김새를 준다.** 「크기는 그림에서」가 여기서 뒤집혔다.
## > 뒤집는 것이 맞는 이유는 **리그 치수가 클립 수식 스무 개의 전제**이기 때문이다 —
## > 그림이 비례를 정하면 그림이 바뀔 때마다 수식을 다시 잡아야 한다 (§25.40.4).
##
## ## 넓이로 맞춘다 — 세로도 가로도 아니다
##
## 파츠의 가로세로비는 **안 건드린다.** 늘리면 그림이 찌그러진다.
## 그러면 목표 상자와 한 축만 맞고 다른 축은 남는데, **어느 축을 맞출지가 문제가 된다.**
##
## | 무엇에 맞추나 | 부츠에 무슨 일이 나나 |
## | --- | --- |
## | 세로 | 굽 때문에 세로가 긴데 그걸 22 로 누르면 **발이 가늘어진다** (12 x 22) |
## | 가로 | 반대로 **발이 거대해진다** (22 x 39) |
## | **넓이** | 둘 사이. 어느 축도 특별대우 안 한다 |
##
## **넓이로 맞춘다.** 규칙 하나가 여섯에 다 걸리고, 어느 축도 안 고른다.
##
## ## 손으로 덮을 수 있다 — 그리고 덮으면 보인다
##
## 파츠 폴더에 `scales.json` 이 있으면 파츠마다 **자동 배율에 곱한다.**
##
##     { "foot_near": 0.9, "head": 1.05 }
##
## **코드에 안 박는 이유는 인물이 여덟 나이 × 남녀 둘이기 때문이다** (§25.40) —
## 굽은 노인과 5 두신 아이가 같은 값을 쓸 리가 없다. 덮은 것은 `overrides` 에 남고
## `tools/check_skin_dir.gd` 가 그것을 찍는다. **조용히 덮이면 나중에 아무도 못 찾는다.**

## 덮어쓰기 파일 이름. 없어도 된다.
const OVERRIDE_FILE := "scales.json"

## 파일 이름. **`left`/`right` 가 아니라 `near`/`far` 다** — 그 구분이 깊이를 만든다.
const FILES: Dictionary[CharPart.Id, String] = {
	CharPart.Id.HEAD: "head",
	CharPart.Id.TORSO: "torso",
	CharPart.Id.HAND_FAR: "hand_far",
	CharPart.Id.HAND_NEAR: "hand_near",
	CharPart.Id.FOOT_FAR: "foot_far",
	CharPart.Id.FOOT_NEAR: "foot_near",
}

## 뒷것이 없을 때 대신 쓸 것.
const FALLBACK: Dictionary[CharPart.Id, CharPart.Id] = {
	CharPart.Id.HAND_FAR: CharPart.Id.HAND_NEAR,
	CharPart.Id.FOOT_FAR: CharPart.Id.FOOT_NEAR,
}

## 파츠마다의 그림. 알파 경계상자로 **잘라 낸 뒤**의 것이다.
var textures: Dictionary[CharPart.Id, Texture2D] = {}

## 파츠마다의 배율 (유닛/픽셀). **여섯이 서로 다르다.**
var scales: Dictionary[CharPart.Id, float] = {}

## 사람이 덮어쓴 파츠와 그 곱. **비어 있으면 전부 자동이다.**
var overrides: Dictionary[CharPart.Id, float] = {}

## 그 그림들에서 세운 리그.
var rig: CharRig

## 왜 못 읽었나. 비어 있으면 성공이다.
var problems: PackedStringArray = PackedStringArray()


## 폴더에서 읽는다. **못 읽어도 예외를 안 던진다** — 무엇이 없는지를 `problems` 에 남긴다.
##
## 조용히 반쯤 성공하는 것이 이 저장소에서 가장 비싼 실패였다(§25.13.7).
static func load_dir(dir: String) -> CharSkin:
	var skin := CharSkin.new()
	var cropped: Dictionary[CharPart.Id, Image] = {}
	for part in CharPart.COUNT:
		var image := _read(dir, FILES[part])
		if image != null:
			cropped[part] = image
	for part in CharPart.COUNT:
		if cropped.has(part):
			continue
		if FALLBACK.has(part) and cropped.has(FALLBACK[part]):
			cropped[part] = cropped[FALLBACK[part]]
			continue
		skin.problems.append("%s 를 못 읽었고 대신 쓸 것도 없다" % FILES[part])
	if cropped.size() < CharPart.COUNT:
		return skin
	skin._read_overrides(dir)
	skin._build(cropped)
	return skin


## 알파가 있는 자리만 남겨 자른다. **여백은 무시된다** — 규약이 그렇게 적혀 있다.
static func _read(dir: String, name: String) -> Image:
	var path := "%s/%s.png" % [dir.rstrip("/"), name]
	var image: Image = null
	# **`res://` 는 임포트된 자원으로 읽는다.** 파일로 읽으면 엔진이 「내보내기에서 안
	# 된다」고 경고하고, 실제로 `.pck` 안에서는 원본 PNG 가 없어서 못 읽는다.
	# 파츠는 프로젝트 밖에서도 올 수 있으므로 두 길을 다 연다.
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			image = texture.get_image()
	elif FileAccess.file_exists(path):
		image = Image.load_from_file(path)
	if image == null:
		return null
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	return image.get_region(used)


## `scales.json` 을 읽는다. **없는 것이 정상이다** — 없으면 전부 자동이다.
##
## 못 읽거나 모양이 틀리면 `problems` 에 적는다. **조용히 무시하면 사람이 고친 값이
## 안 먹은 채로 며칠이 간다** (§25.13.5 — 도구가 요청을 조용히 무시한다).
func _read_overrides(dir: String) -> void:
	var path := "%s/%s" % [dir.rstrip("/"), OVERRIDE_FILE]
	# **두 길을 다 연다.** `.json` 은 임포트될 수도 있고 그냥 파일로 남을 수도 있는데,
	# 어느 쪽인지는 프로젝트 설정에 달렸다. 한 길만 열어 뒀다가 **덮어쓴 값이 조용히
	# 안 먹었다** — 그게 §25.13.5 그 자체다.
	var text := ""
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource := load(path) as JSON
		if resource != null:
			text = resource.get_parsed_text()
	if text.is_empty() and FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		problems.append("%s 를 못 읽었다 — 사전이 아니다" % OVERRIDE_FILE)
		return
	var by_name := {}
	for part in CharPart.COUNT:
		by_name[FILES[part]] = part
	for key: Variant in parsed:
		var name := str(key)
		if not by_name.has(name):
			problems.append("%s 에 모르는 이름이 있다: %s" % [OVERRIDE_FILE, name])
			continue
		var value: Variant = parsed[key]
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or float(value) <= 0.0:
			problems.append("%s 의 %s 가 양수가 아니다" % [OVERRIDE_FILE, name])
			continue
		overrides[by_name[name]] = float(value)


func _build(cropped: Dictionary) -> void:
	# **목표는 리그가 안다.** 여기에 숫자를 다시 적으면 두 곳이 갈린다 (§25.13.1).
	var target := CharRig.new()
	var sizes: Dictionary[CharPart.Id, Vector2] = {}
	for part in CharPart.COUNT:
		var image: Image = cropped[part]
		var pixels := Vector2(float(image.get_width()), float(image.get_height()))
		var want := target.half_sizes[part] * 2.0
		# **넓이를 맞춘다.** 가로세로비는 그림 것을 그대로 둔다.
		var scale := sqrt(want.x * want.y / (pixels.x * pixels.y))
		if overrides.has(part):
			scale *= overrides[part]
		scales[part] = scale
		sizes[part] = pixels * scale * 0.5
		textures[part] = ImageTexture.create_from_image(image)
	rig = CharRig.from_part_sizes(sizes)


## 다 읽혔나. **`problems` 를 안 보고 쓰면 반쪽 리그로 조용히 돈다.**
func is_whole() -> bool:
	return rig != null and problems.is_empty()
