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
		"hint": "서 있는 유닛을 늘 같은 쪽으로 돌아간다. 마주 오는 상대는 아래 양보가 맡는다",
	},
	{
		"key": "yield_strength",
		"label": "양보",
		"min": 0.0,
		"max": 1.0,
		"step": 0.05,
		"value": 0.7,
		"hint": "목적지에 가까운 쪽에 길을 낸다. 0 이면 서로 밀어대며 제자리에서 떤다",
	},
	{
		"key": "steer_smooth",
		"label": "조향 평활",
		"min": 0.0,
		"max": 0.5,
		"step": 0.01,
		"value": 0.12,
		"hint": "초. 흐름장이 칸마다 튀는 것을 다듬는다. 0 이면 좁은 곳에서 좌우로 떤다",
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
		"key": "push_cap",
		"label": "겹침 해소 상한",
		"min": 0.05,
		"max": 1.0,
		"step": 0.05,
		"value": 0.5,
		"hint": "한 프레임에 밀어내는 거리를 몸 반지름의 이 배수로 묶는다. 크면 튕긴다",
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
]
## `포기 시간` 이 여기 있었다. 걷어낸 이유는 그 값이 **오판을 시간으로 덮는 장치**였기 때문이다.
##
## 포기한 유닛에게 다시 명령하면 가는 일이 있었다. 실제로는 막히지 않았는데 막혔다고
## 결론 낸 것이다. 그 상태에서 시간을 늘리면 굼떠지고 줄이면 일찍 포기하니 어느 쪽으로
## 돌려도 나아지지 않는다. 조절해서 답이 나오지 않는 값은 슬라이더로 둘 이유가 없다.
##
## 대신 `unit_field.gd` 의 `_update_states` 가 상태로 묻는다.

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
