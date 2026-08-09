class_name PersonNorms
extends RefCounted
## 인구의 **가운데 값**. 막대에 눈금을 긋는 근거다.
##
## docs/design/20-ui-kit.md §20.25.3.
##
## ## 왜 필요한가
##
## **절대값 60 은 아무 뜻이 없다.** 「이 사람이 센 놈인가」는 인구 안의 자리로만 읽힌다.
## 유명세는 더 심하다 — 대다수가 무명이라(§24.16.6) 30 이 높은 값인데 막대는 낮아 보인다.
##
## > **눈금이 없는 막대는 「크다」를 못 말한다. 「길다」만 말한다.**
##
## ## `FactionIndex` 와 같은 자리, 같은 규율
##
## 3000명을 매번 다시 세지 않게 **호출자가 한 번 만들어 들고 있는다.**
## 인구가 바뀌면(새 시드) 다시 만든다 — 안 만들면 눈금이 옛 인구를 가리킨다.

var _threat := 0
var _agility := 0
var _fame := 0


func _init(registry: PersonRegistry = null) -> void:
	if registry == null or registry.size() == 0:
		return
	var threats := PackedInt32Array()
	var agilities := PackedInt32Array()
	var fames := PackedInt32Array()
	for person in registry.size():
		threats.append(registry.threat_of(person))
		agilities.append(registry.agility_of(person))
		fames.append(registry.fame_of(person))
	_threat = _median(threats)
	_agility = _median(agilities)
	_fame = _median(fames)


## 중앙값이 있는가. 빈 인구에서는 눈금을 안 긋는다 — **0 에 눈금을 그으면 거짓말이다.**
func has_marks() -> bool:
	return _threat > 0 or _agility > 0 or _fame > 0


func threat() -> int:
	return _threat


func agility() -> int:
	return _agility


func fame() -> int:
	return _fame


## 중앙값을 막대 비율로. 눈금이 설 자리다.
func mark_of(value: int, ceiling: int) -> float:
	if ceiling <= 0:
		return SheetField.NO_BAR
	return clampf(float(value) / float(ceiling), 0.0, 1.0)


## **평균이 아니라 중앙값이다.** 유명세가 지프 분포라(§24.16.6) 평균은
## 상위 몇 명이 끌어올려 **인구 대다수보다 훨씬 위**에 선다.
static func _median(values: PackedInt32Array) -> int:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]
