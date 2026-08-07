class_name SketchStage
extends RefCounted
## 세 방향을 **같은 내용으로** 비교하기 위한 재료.
##
## 방향을 셋 만들 때 가장 쉬운 실수는 각자 다른 장면을 그려 놓고 고르는 것이다.
## 그러면 무엇이 스타일 차이고 무엇이 소재 차이인지 구별되지 않는다.
## 그래서 방•통로•숫자•문장을 여기 한 벌만 두고, 방향은 **그리는 법만** 다르게 한다.

## 한 방의 자리•이름•값•상태. 상태 문자열은 RoomNode.State 와 같은 뜻이다.
const ROOMS := [
	{"id": "r_here", "pos": Vector2(250.0, 250.0), "name": "관제실", "value": "9", "state": "here"},
	{"id": "r_lift", "pos": Vector2(560.0, 168.0), "name": "화물 리프트", "value": "?", "state": "open"},
	{
		"id": "r_vault",
		"pos": Vector2(566.0, 400.0),
		"name": "봉인된 금고",
		"value": "?",
		"state": "shut"
	},
	{"id": "r_hall", "pos": Vector2(120.0, 470.0), "name": "회랑", "value": "?", "state": "open"},
	{"id": "r_altar", "pos": Vector2(860.0, 296.0), "name": "제단", "value": "?", "state": "far"},
	{"id": "r_tank", "pos": Vector2(830.0, 540.0), "name": "저수조", "value": "?", "state": "far"},
]

## [출발, 도착, 통로 상태]. live 만 지금 지나갈 수 있는 길이다.
const LINKS := [
	["r_here", "r_lift", "live"],
	["r_here", "r_hall", "live"],
	["r_here", "r_vault", "shut"],
	["r_lift", "r_altar", "dark"],
	["r_vault", "r_tank", "dark"],
	["r_altar", "r_tank", "dark"],
]

## 클로즈업으로 볼 타일 하나.
const CLOSEUP := {"name": "화물 리프트", "value": "?", "state": "open", "climb": "내림 1"}

## 계측 레이어가 말하는 것 — 사실이지만 모호하다.
const INSTRUMENT_TITLE := "인접 위험도 합"
const INSTRUMENT_VALUE := "9"
const INSTRUMENT_NOTE := "관제실 • 고도 0 • 전투력 8 • 민첩 2"

## 송출 레이어가 말하는 것 — 구체적이지만 못 믿는다.
const BROADCAST_TITLE := "금고 앞에서 셋이 붙었습니다"
const BROADCAST_BODY := "봉인된 금고, 열여덟 피해. 이 상태로 누구 만나면 끝이죠. 근처 계신 분들 서두르세요."
const BROADCAST_TAG := "속보"


## 프로젝트 폰트. 스케치는 라벨을 놓지 않고 직접 찍으므로 폰트를 손에 들고 있어야 한다.
static func font() -> Font:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	return load(path) as Font


## 방 자리를 화면 좌표로 옮긴다. 방향마다 판을 두는 자리가 다르다.
static func placed(origin: Vector2, scale_factor: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room in ROOMS:
		var copy := (room as Dictionary).duplicate()
		copy["screen"] = origin + (room["pos"] as Vector2) * scale_factor
		out.append(copy)
	return out


## id 로 자리를 찾는다. 통로를 그릴 때 쓴다.
static func screen_of(placed_rooms: Array[Dictionary], id: String) -> Vector2:
	for room in placed_rooms:
		if room["id"] == id:
			return room["screen"] as Vector2
	return Vector2.ZERO
