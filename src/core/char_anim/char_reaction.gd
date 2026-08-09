class_name CharReaction
extends RefCounted
## **맞는 것을 「클립」이 아니라 「힘」으로 만든다.**
##
## `docs/design/25-character-animation.md` §25.27.
##
## 사용자가 물었다 — *"결국 액션이 뒤엉키잖아 때리다가 맞고 이런거.
## 이런거 별개 애니메이션 말고 절차적으로 처리할 수 있나?"*
##
## ```
## 동작 층   스윙 자세를 계속 계산한다
##    +
## 반응 층   충격을 힘으로 받아 밀어낸다                ← 이 파일
##    +
## 상태 층   무너짐 눈금이 문턱을 넘을 때만 상태가 바뀐다
## ```
##
## ## **타격은 「떨림」이 아니라 「밀림」이다**
##
## 처음에 감쇠 **진동**으로 만들었다가 **불합격했다.** 사용자가 *"때리다가 맞는게
## 안되잖아"* 라고 했다. 진동은 좌우 대칭이라 **방향이 없고**, 파츠만 떨어서
## **몸이 안 밀리고**, 스윙이 그대로 진행돼 **맞은 것 같지가 않았다.**
##
## | | 진동(틀림) | 밀림(맞음) |
## | --- | --- | --- |
## | 형태 | 좌우 대칭으로 떤다 | **한 방향으로 갔다가 돌아온다** |
## | 몸 | 파츠만 떤다 | **뿌리가 통째로 밀린다** |
## | 시간 | 그대로 진행 | **맞는 순간 멈춘다** |
##
## **그래서 감쇠 진동이 아니라 과감쇠 계단 응답이다** — 즉시 한 방향으로 가고
## 부드럽게 돌아온다. **넘어갔다 되돌아오지 않는다.** 진동은 **꼬리에만** 남는다.
##
## ## 읽히는 순서
##
## ```
## 멈춤(히트스톱)  →  밀림(방향, 몸 전체)  →  회복  →  잔진동
## ```
##
## **이 순서가 안 보이면 맞은 게 아니다.**
##
## ## 여섯이 한꺼번에 시작한다
##
## 처음에 `die` 의 **시작이 다른** 축을 가져다 썼다가 **틀렸다.**
## 그건 **무너질 때(안에서 힘이 빠지는 것)의** 축이다.
##
## `hit` 에서 이미 맞게 정리해 뒀던 것이 맞다 — **밖에서 온 충격은 여섯에 한꺼번에
## 닿는다. 시작은 같고 감쇠만 다르다.** 파츠가 제각각 튀어서 「발작」으로 보였던 것이
## 그 탓이었다.

## 밀렸다가 돌아오는 빠르기. 클수록 빨리 제자리로 온다.
##
## **파츠마다 다르다** — 머리가 가장 오래 남고 발이 가장 빨리 선다 (§25.12.4).
## 시작은 여섯이 **같다.**
const RETURN: Dictionary[CharPart.Id, float] = {
	CharPart.Id.HEAD: 3.6,
	CharPart.Id.TORSO: 5.2,
	CharPart.Id.HAND_FAR: 4.4,
	CharPart.Id.HAND_NEAR: 4.0,
	CharPart.Id.FOOT_FAR: 8.5,
	CharPart.Id.FOOT_NEAR: 8.5,
}

## **뿌리가 밀리는 거리**(px, 세기 `1` 일 때). **이게 가장 크게 읽힌다** — 파츠 진동보다 먼저다.
const ROOT_PUSH := 26.0

## 뿌리가 제자리로 돌아오는 빠르기. 파츠보다 **느리다** — 몸은 무겁다.
const ROOT_RETURN := 4.6

## 파츠가 뿌리보다 **더** 밀리는 양(px). 몸이 간 뒤에 파츠가 갈라진다.
const PART_PUSH := 9.0

## 밀린 만큼 돌아가는 각(rad).
const TWIST := 0.20

## **꼬리 진동.** 밀림이 잦아든 뒤에만 남는다 — 처음부터 떨면 「밀림」이 안 읽힌다.
const WOBBLE := 0.28
const WOBBLE_PERIOD := 0.11

## 꼬리 진동이 시작되는 시각(초). **그 전에는 순수하게 밀리기만 한다.**
const WOBBLE_AFTER := 0.09

## **히트스톱.** 맞는 순간 스윙 진행 자체가 멈춘다 (세기 `1` 일 때, 초).
##
## 이게 없으면 스윙이 계속 돌아서 **「안 맞은 것 같다」.**
const STOP_SECONDS := 0.075

## **누적 상한.** 없으면 여러 대 맞을 때 캐릭터가 발작한다.
const MAX_LOAD := 1.6

## 이 값 아래로 잦아들면 버린다. 안 버리면 목록이 무한히 는다.
const SPENT := 0.004

## 쌓인 충격들. 각각 `(시각, 세기, 방향)`.
var _impacts: Array[Vector3] = []


## 맞았다. `direction` 은 밀려나는 쪽(`-1` 이 뒤로).
func strike(at: float, power: float, direction := -1.0) -> void:
	_impacts.append(Vector3(at, maxf(power, 0.0), signf(direction) if direction != 0.0 else -1.0))


## **밀림의 세기.** `1` 에서 시작해 부드럽게 `0` 으로 돌아온다. **음수로 안 넘어간다.**
func _push(t: float, impact: Vector3, back: float) -> float:
	var age := t - impact.x
	if age < 0.0:
		return 0.0
	var fall := exp(-back * age)
	var tail := 0.0
	if age > WOBBLE_AFTER:
		# **꼬리에만** 진동이 남는다.
		tail = WOBBLE * fall * sin(TAU * (age - WOBBLE_AFTER) / WOBBLE_PERIOD)
	return impact.y * (fall + tail)


## **뿌리가 지금 얼마나 밀려 있나.** 몸 전체가 이만큼 간다.
func root_offset(t: float) -> Vector2:
	var shift := 0.0
	for impact in _impacts:
		shift += _push(t, impact, ROOT_RETURN) * impact.z
	return Vector2(ROOT_PUSH * clampf(shift, -MAX_LOAD, MAX_LOAD), 0.0)


## **히트스톱으로 멈춰 있던 시간의 합.** 재생 시각에서 이만큼 빼면 동작이 멈춘다.
##
## 맞는 순간 **스윙 진행 자체가 멈춘다** — 그래야 「맞았다」가 읽힌다.
func stalled(t: float) -> float:
	var held := 0.0
	for impact in _impacts:
		held += clampf(t - impact.x, 0.0, STOP_SECONDS * minf(impact.y, MAX_LOAD))
	return held


## 지금 얹혀 있는 충격의 총량. **상태 층이 이걸 보고 문턱을 판단한다.**
func load_at(t: float) -> float:
	var total := 0.0
	for impact in _impacts:
		total += absf(_push(t, impact, RETURN[CharPart.Id.TORSO]))
	return minf(total, MAX_LOAD)


## 다 잊는다. **상태가 바뀔 때 부른다** (§25.27.3).
func clear() -> void:
	_impacts.clear()


## 잦아든 충격을 버린다. 매 프레임 부르면 목록이 안 는다.
func forget_spent(t: float) -> void:
	var alive: Array[Vector3] = []
	for impact in _impacts:
		if absf(_push(t, impact, ROOT_RETURN)) > SPENT or t < impact.x:
			alive.append(impact)
	_impacts = alive


func is_quiet() -> bool:
	return _impacts.is_empty()


## **이미 만들어진 자세 위에 더한다.** 자세가 무엇이든 상관없다 — 그것이 이 층의 요점이다.
##
## 뿌리는 `root_offset` 이 따로 옮긴다. 여기서는 **파츠가 뿌리보다 더 가는 몫**만 얹는다.
func apply(pose: CharPose, t: float, rig: CharRig) -> void:
	if _impacts.is_empty():
		return
	for part in CharPart.COUNT:
		var push := 0.0
		for impact in _impacts:
			push += _push(t, impact, RETURN[part]) * impact.z
		push = clampf(push, -MAX_LOAD, MAX_LOAD)
		pose.positions[part] += Vector2(PART_PUSH * push, 0.0)
		pose.rotations[part] += TWIST * push
	# **더한 뒤에 다시 잰다.** 충격이 손을 팔 길이 밖으로 밀어낼 수 있다 (§25.29).
	for part in CharPart.COUNT:
		var limit := rig.reach_limit(part)
		if limit == INF or CharPart.is_foot(part):
			continue
		var socket := pose.socket_of(part, rig)
		var arm := pose.positions[part] - socket
		if arm.length() > limit:
			pose.positions[part] = socket + arm.normalized() * limit
	for part in CharPart.COUNT:
		if CharPart.is_foot(part):
			pose.positions[part] += Vector2(0.0, pose.lift_to_clear_ground(part, rig))
