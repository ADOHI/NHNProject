class_name ProtoMoveTuning
extends RefCounted
## 이동 손맛을 만드는 수치 전부. 화면의 슬라이더가 이 목록을 그대로 읽어 만들어진다.
##
## 값을 코드 상수로 박지 않는 이유는 하나다. **고쳐야 바뀌는 값은 아무도 만져 보지 않는다.**
## 손맛은 남이 정해 줄 수 없으므로, 조작하는 사람이 직접 돌려 보고 자기 취향을 찾아야 한다.
## 목록에 항목을 추가하면 슬라이더도 저절로 생긴다.

## 값이 하나라도 바뀌면 알린다. 화면과 시뮬레이션이 이 신호로 다시 읽는다.
signal value_changed(key: String)

## 조절 가능한 값의 정의. 순서가 그대로 화면 순서다.
##
## hint 는 슬라이더 밑에 그대로 나가는 설명이다. 무엇을 만지는지 모르면 슬라이더는 장식이다.
const DEFS: Array[Dictionary] = [
	{
		"key": "max_speed",
		"label": "최대 속도",
		"min": 40.0,
		"max": 600.0,
		"step": 5.0,
		"value": 230.0,
		"hint": "초당 픽셀. 높이면 경쾌하고 낮추면 무겁다",
	},
	{
		"key": "acceleration",
		"label": "가속",
		"min": 200.0,
		"max": 6000.0,
		"step": 50.0,
		"value": 2600.0,
		"hint": "클릭 반응이 여기서 갈린다. 낮으면 명령이 씹힌 느낌이 난다",
	},
	{
		"key": "turn_rate",
		"label": "회전 속도",
		"min": 90.0,
		"max": 2000.0,
		"step": 10.0,
		"value": 900.0,
		"hint": "초당 각도. 진행 방향이 꺾이는 한계 속도다",
	},
	{
		"key": "arrive_radius",
		"label": "도착 반경",
		"min": 1.0,
		"max": 40.0,
		"step": 0.5,
		"value": 6.0,
		"hint": "자기 자리에 이만큼 들어오면 멈춘다. 너무 작으면 진동한다",
	},
	{
		"key": "slow_radius",
		"label": "감속 반경",
		"min": 5.0,
		"max": 200.0,
		"step": 1.0,
		"value": 52.0,
		"hint": "이 거리부터 속도를 줄인다. 없으면 목적지를 지나쳤다 되돌아온다",
	},
	{
		"key": "separation_radius",
		"label": "분리 반경",
		"min": 10.0,
		"max": 120.0,
		"step": 1.0,
		"value": 38.0,
		"hint": "이 안에 든 이웃을 밀어낸다",
	},
	{
		"key": "separation_weight",
		"label": "분리 강도",
		"min": 0.0,
		"max": 3.0,
		"step": 0.05,
		"value": 1.05,
		"hint": "0 이면 서로 통과한다. 크면 대열이 부풀고 튕긴다",
	},
	{
		"key": "side_bias",
		"label": "옆으로 비껴가기",
		"min": 0.0,
		"max": 2.0,
		"step": 0.05,
		"value": 0.85,
		"hint": "앞을 막은 상대를 옆으로 돌아간다. 0 이면 정면에서 서로 멈춘다",
	},
	{
		"key": "push_resolve",
		"label": "겹침 해소",
		"min": 0.0,
		"max": 1.0,
		"step": 0.05,
		"value": 0.7,
		"hint": "몸이 겹쳤을 때 위치를 직접 떼어 놓는 비율",
	},
	{
		"key": "formation_spacing",
		"label": "대형 간격",
		"min": 1.0,
		"max": 3.0,
		"step": 0.05,
		"value": 1.25,
		"hint": "유닛 지름의 배수. 작으면 빽빽하고 크면 넓게 퍼진다",
	},
	{
		"key": "group_sync",
		"label": "대형 유지",
		"min": 0.0,
		"max": 1.0,
		"step": 0.05,
		"value": 0.55,
		"hint": "앞선 유닛이 뒤를 기다린다. 0 이면 빠른 놈만 먼저 간다",
	},
	{
		"key": "stuck_timeout",
		"label": "포기 시간",
		"min": 0.2,
		"max": 5.0,
		"step": 0.1,
		"value": 1.1,
		"hint": "이만큼 못 나아가면 그 자리에서 멈춘다. 영원히 밀어대는 것을 막는다",
	},
]

var _values: Dictionary = {}


func _init() -> void:
	reset()


## 전부 기본값으로 되돌린다. 만지다 망가뜨렸을 때 돌아올 곳이 있어야 마음 놓고 만진다.
func reset() -> void:
	for definition in DEFS:
		_values[definition["key"]] = float(definition["value"])
	value_changed.emit("")


func get_value(key: String) -> float:
	return float(_values.get(key, 0.0))


func set_value(key: String, value: float) -> void:
	if not _values.has(key) or is_equal_approx(float(_values[key]), value):
		return
	_values[key] = value
	value_changed.emit(key)


func default_of(key: String) -> float:
	for definition in DEFS:
		if definition["key"] == key:
			return float(definition["value"])
	return 0.0


## 기본값에서 벗어난 항목 수. 화면에 그대로 보여 준다.
func changed_count() -> int:
	var count := 0
	for definition in DEFS:
		var key := String(definition["key"])
		if not is_equal_approx(get_value(key), float(definition["value"])):
			count += 1
	return count
