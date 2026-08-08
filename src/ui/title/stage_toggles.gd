class_name TitleToggles
extends RefCounted
## **연출 장치를 하나씩 껐다 켠다.** 판정 도구이자 회귀 방지 장치다.
##
## 의뢰인 지시다 — *"끄고 켤 수 있게 해라. 시차 · VFX · 셰이더를 각각 토글로 두면
## 사용자가 무엇이 무엇을 만드는지 직접 가른다."*
##
## 왜 필요한가는 §21.11.9 에서 값비싸게 배웠다. 한 판에 둘을 바꾸면 **어느 쪽이
## 이겼는지 영원히 모른다.** 그림은 다시 뽑으면 되지만 연출 장치는 서로 겹쳐서
## 나중에 하나만 빼 보는 것이 더 어렵다. 그래서 **처음부터 뺄 수 있게 만든다.**
##
## 그리고 이것은 임시 도구가 아니다. 겹 열 장은 자리 표시자이고 나중에 갈린다
## (docs/design/21-title.md §21.14). 그림이 갈린 뒤에 **하나씩 꺼 보면 그 장치가
## 아직 값을 하는지 다시 잴 수 있다.**
##
## ---
##
## 여기는 순수 데이터다. 노드도 입력도 모르고 **무엇이 켜져 있는가만** 안다.
## 그래서 씬 없이 검사된다(CLAUDE.md 개발 원칙 2).

## 끌 수 있는 장치.
##
## 셋으로 가른 기준은 **무엇을 물어볼 것인가**다. 깊이를 만드는 것(시차),
## 살아 있게 만드는 것(VFX), 겹을 공기 속에 앉히는 것(색 처리)이 서로 다른 질문이다.
enum Device {
	## 겹이 깊이에 따라 다른 속도로 흐르는 것. 자동 표류도 여기 포함이다
	PARALLAX,
	## 제자리에서 도는 움직임 — 악마의 부유, 금의 맥동, 사람이 한 걸음 다가오는 것
	VFX,
	## 겹에 곱하는 색 — 원경의 공기 원근과 전경의 그늘.
	## 지금은 상수 곱하기이고 **나중에 셰이더가 된다.** 그래서 이름이 셰이더다
	SHADER,
}

## 화면에 띄우는 이름. 순서가 곧 눌러야 할 숫자 키 순서다.
const NAMES: Dictionary = {
	Device.PARALLAX: "시차",
	Device.VFX: "VFX",
	Device.SHADER: "셰이더",
}

## 숫자 키와 장치의 대응. 1 · 2 · 3 이다.
const KEYS: Dictionary = {
	KEY_1: Device.PARALLAX,
	KEY_2: Device.VFX,
	KEY_3: Device.SHADER,
}

## 안내를 접는 키. 필름을 뽑을 때는 도구가 직접 끈다.
const KEY_HINT := KEY_0

## 항목을 가르는 것. **가운뎃점(·)을 쓰면 안 된다** — SongMyung 에 U+00B7 이 없어서
## 데스크톱에서는 시스템 폰트가 대신 그려 주지만 **웹 빌드에서 두부(□)가 된다**
## (docs/conventions.md §5.1). `tools/check_glyphs.gd` 가 이것을 잡아냈다.
const _GAP := "   "

var _on: Dictionary = {}


func _init() -> void:
	for device: Device in Device.values():
		_on[device] = true


## 켜져 있나. 모르는 장치는 켜진 것으로 답한다 — **장치를 새로 만들다가
## 등록을 잊었을 때 화면이 조용히 죽는 것보다 켜져 있는 편이 낫다.**
func is_on(device: Device) -> bool:
	return bool(_on.get(device, true))


func set_on(device: Device, value: bool) -> void:
	_on[device] = value


func toggle(device: Device) -> bool:
	_on[device] = not is_on(device)
	return is_on(device)


## 누른 키가 장치를 가리키면 그것을 뒤집고 무엇을 뒤집었는지 돌려준다.
## 가리키지 않으면 -1 — 호출한 쪽이 그 키를 자기 것으로 쓸 수 있다.
func toggle_by_key(keycode: int) -> int:
	if not KEYS.has(keycode):
		return -1
	var device: Device = KEYS[keycode]
	toggle(device)
	return device


## 화면 한 귀퉁이에 띄울 한 줄. **켜짐과 꺼짐이 한눈에 갈려야 한다.**
##
## 켜진 것에 색을 주는 대신 꺼진 것에 표시를 준다 — 대개 다 켜져 있으므로
## 그때 줄이 조용해야 한다.
func hint() -> String:
	var parts: PackedStringArray = []
	var keys: Array = KEYS.keys()
	keys.sort()
	for keycode: int in keys:
		var device: Device = KEYS[keycode]
		var mark := "" if is_on(device) else " 끔"
		parts.append("%d %s%s" % [keycode - KEY_0, NAMES[device], mark])
	return _GAP.join(parts) + _GAP + _GAP + "0 안내"


## 꺼진 것이 하나라도 있나. 필름 이름에 표를 붙일 때 쓴다 —
## **판정용 필름이 무엇을 끈 상태였는지 모르면 그 필름은 증거가 아니다.**
func any_off() -> bool:
	for device: Device in Device.values():
		if not is_on(device):
			return true
	return false


## 꺼진 장치들의 이름. 파일 이름에 넣기 좋게 영문 소문자로 돌려준다.
func off_tags() -> PackedStringArray:
	var tags: PackedStringArray = []
	for device: Device in Device.values():
		if not is_on(device):
			tags.append(Device.keys()[device].to_lower())
	return tags
