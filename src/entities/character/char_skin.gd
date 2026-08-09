class_name CharSkin
extends RefCounted
## 파츠 PNG 여섯을 읽어 **리그와 그림을 한꺼번에** 만든다.
##
## `docs/design/25-character-animation.md` §25.41 이 규약이다.
##
## ## 이 파일이 지키는 세 가지
##
## * **피벗을 안 받는다.** 알파 경계상자에서 규칙으로 뽑는다 (§25.41.3)
## * **배율을 안 받는다.** 머리 조각의 세로를 `HEAD_UNITS` 로 맞추면 나머지가 따라온다
## * **자리를 안 받는다.** `CharRig.from_part_sizes()` 가 푼다 (§25.41.5)
##
## 그래서 제작 쪽에 요구하는 것이 **「여섯 장, 알파, 같은 배율」** 셋뿐이다.
##
## ## 뒷것 둘은 없어도 된다
##
## `hand_far` 가 없으면 앞손을 쓰고 **그리는 쪽이 좌우로 뒤집는다**(`CharPartSprite`).
## `foot_far` 가 없으면 앞발을 그대로 쓴다 — 옆에서 본 두 발은 둘 다 앞을 본다.

## 머리 조각의 세로를 몇 유닛으로 볼 것인가. **여섯의 배율이 이 하나에서 나온다.**
##
## 리그의 머리가 60 유닛(반크기 30)이라 그 값을 쓴다. 머리를 기준으로 잡는 이유는
## **여섯 중 가장 크고 가장 안정된 조각**이라 알파 경계상자가 덜 흔들리기 때문이다.
const HEAD_UNITS := 60.0

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
	if not cropped.has(CharPart.Id.HEAD):
		skin.problems.append("머리가 없으면 배율을 정할 수 없다")
		return skin
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


func _build(cropped: Dictionary) -> void:
	var head: Image = cropped[CharPart.Id.HEAD]
	# **배율은 머리 하나에서 나온다.** 여섯이 같은 배율로 왔다는 것이 규약의 유일한 요구다.
	var per_pixel := HEAD_UNITS / float(head.get_height())
	var sizes: Dictionary[CharPart.Id, Vector2] = {}
	for part in CharPart.COUNT:
		var image: Image = cropped[part]
		sizes[part] = (
			Vector2(float(image.get_width()), float(image.get_height())) * per_pixel * 0.5
		)
		textures[part] = ImageTexture.create_from_image(image)
	rig = CharRig.from_part_sizes(sizes)


## 다 읽혔나. **`problems` 를 안 보고 쓰면 반쪽 리그로 조용히 돈다.**
func is_whole() -> bool:
	return rig != null and problems.is_empty()
