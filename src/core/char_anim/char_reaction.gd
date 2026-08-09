class_name CharReaction
extends RefCounted
## **맞는 것을 「클립」이 아니라 「힘」으로 만든다.**
##
## `docs/design/25-character-animation.md` §25.27.
##
## 사용자가 물었다 — *"결국 액션이 뒤엉키잖아 때리다가 맞고 이런거.
## 이런거 별개 애니메이션 말고 절차적으로 처리할 수 있나?"*
##
## 된다. **부품이 이미 다 있었다.**
##
## ```
## 동작 층   스윙 자세를 계속 계산한다 (맞아도 안 멈춤)
##    +
## 반응 층   충격을 힘으로 받아 감쇠 진동을 더한다      ← 이 파일
##    +
## 상태 층   무너짐 눈금이 문턱을 넘을 때만 상태가 바뀐다
## ```
##
## **`hit` 을 감쇠 진동으로 만들어 둔 것**(§25.12)이 그대로 반응 층이 되고,
## **`die` 의 「파츠마다 시작이 다른」 축**(§25.17)도 그대로 쓰인다.
## **트랜스폼이라 각도를 더하기만 하면 되므로 어떤 자세 위에도 얹힌다.**
##
## 그래서 **전환이 없다.** 때리다 맞으면 스윙이 계속 돌고 그 위에 충격이 얹힌다.

## 한 번 흔들리는 데 걸리는 시간. `hit` 과 같은 값이라 두 곳이 같은 몸으로 읽힌다.
const RING_PERIOD := 0.26

## 파츠마다 다른 감쇠. **머리가 가장 오래, 발이 가장 안 흔들린다** (§25.12.4).
const DECAY: Dictionary[CharPart.Id, float] = {
	CharPart.Id.HEAD: 3.4,
	CharPart.Id.TORSO: 6.0,
	CharPart.Id.HAND_FAR: 4.2,
	CharPart.Id.HAND_NEAR: 3.8,
	CharPart.Id.FOOT_FAR: 9.0,
	CharPart.Id.FOOT_NEAR: 9.0,
}

## 파츠마다 반응이 시작되는 시각이 다르다. **충격이 몸을 타고 올라간다.**
const LEAD: Dictionary[CharPart.Id, float] = {
	CharPart.Id.TORSO: 0.0,
	CharPart.Id.HEAD: 0.045,
	CharPart.Id.HAND_NEAR: 0.030,
	CharPart.Id.HAND_FAR: 0.030,
	CharPart.Id.FOOT_NEAR: 0.015,
	CharPart.Id.FOOT_FAR: 0.015,
}

## 세기 `1` 일 때 흔들리는 거리(px)와 각(rad).
const SHIFT := 7.0
const TWIST := 0.22

## **누적 상한.** 없으면 여러 대 맞을 때 진동이 계속 더해져 **발작한다.**
##
## 상한이 있어야 「많이 맞으면 더 크게 흔들린다」가 **어느 선에서 멈춘다.**
const MAX_LOAD := 1.6

## 충격이 이 값 아래로 잦아들면 목록에서 버린다. 안 버리면 목록이 무한히 는다.
const SPENT := 0.004

## 쌓인 충격들. 각각 `(시각, 세기, 방향)`.
var _impacts: Array[Vector3] = []


## 맞았다. `direction` 은 밀리는 쪽(`-1` 이 뒤로).
func strike(at: float, power: float, direction := -1.0) -> void:
	_impacts.append(Vector3(at, maxf(power, 0.0), signf(direction) if direction != 0.0 else -1.0))


## 지금 얹혀 있는 충격의 총량. **상태 층이 이걸 보고 문턱을 판단한다.**
func load_at(t: float) -> float:
	var total := 0.0
	for impact in _impacts:
		total += absf(_envelope(t, impact, DECAY[CharPart.Id.TORSO]))
	return minf(total, MAX_LOAD)


## 다 잊는다. **상태가 바뀔 때 부른다** — 그쪽 클립이 이미 큰 반응을 갖고 있어서
## 진동까지 남기면 **같은 사건을 두 번 세는 것**이 된다 (§25.27.3).
func clear() -> void:
	_impacts.clear()


## 잦아든 충격을 버린다. 매 프레임 부르면 목록이 안 는다.
func forget_spent(t: float) -> void:
	var alive: Array[Vector3] = []
	for impact in _impacts:
		if absf(_envelope(t, impact, DECAY[CharPart.Id.FOOT_NEAR])) > SPENT or t < impact.x:
			alive.append(impact)
	_impacts = alive


func is_quiet() -> bool:
	return _impacts.is_empty()


## **이미 만들어진 자세 위에 더한다.** 자세가 무엇이든 상관없다 — 그것이 이 층의 요점이다.
##
## 지면 규칙은 여기서 다시 본다. 더한 결과가 파고들 수 있고, **재서 올리는 방식**이라
## 무엇을 더했든 잡힌다 (§25.13.45).
func apply(pose: CharPose, t: float, rig: CharRig) -> void:
	if _impacts.is_empty():
		return
	for part in CharPart.COUNT:
		var swing := 0.0
		for impact in _impacts:
			swing += _envelope(t - LEAD[part], impact, DECAY[part]) * impact.z
		# **상한.** 없으면 여러 대 맞을 때 발작한다.
		swing = clampf(swing, -MAX_LOAD, MAX_LOAD)
		pose.positions[part] += Vector2(SHIFT * swing, 0.0)
		pose.rotations[part] += TWIST * swing
	for part in CharPart.COUNT:
		if CharPart.is_foot(part):
			pose.positions[part] += Vector2(0.0, pose.lift_to_clear_ground(part, rig))


## 충격 하나가 그 시각에 내는 흔들림. **감쇠 진동** — `swing` 의 후속과 같은 식이다.
func _envelope(t: float, impact: Vector3, decay: float) -> float:
	var age := t - impact.x
	if age < 0.0:
		return 0.0
	return impact.y * exp(-decay * age) * sin(TAU * age / RING_PERIOD)
