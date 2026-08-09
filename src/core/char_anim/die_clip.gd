class_name CharDieClip
extends CharClip
## die — **파츠가 순서대로 무게를 잃는다.**
##
## `docs/design/25-character-animation.md` §25.17.
##
## `get hit` 의 쓰러짐과 겉이 비슷한데 **정체가 다르다.**
##
## | | `get hit` | `die` |
## | --- | --- | --- |
## | 무엇이 미는가 | **밖에서 온 충격.** 여섯이 한꺼번에 밀린다 | **안에서 빠지는 힘.** 하나씩 놓는다 |
## | 순서 | 없다 — 동시에 받고 감쇠만 다르다 | **있다.** 파츠마다 놓는 시각이 다르다 |
## | 끝 | 쓰러진 자세 (일어날 수 있다) | 되돌아오지 않는다 |
##
## **「순서대로」가 이 클립의 전부다.** 여섯이 같이 무너지면 인형이 넘어지는 것이고,
## 하나씩 놓으면 힘이 빠지는 것으로 보인다. 감쇠를 다르게 하는 것(§25.12.4)과는
## 다른 축이다 — 그것은 **같이 시작해서 다르게 잦아드는 것**이고, 이것은 **시작이 다르다.**

## 파츠 하나가 놓기 시작하는 시각. **손이 먼저다** — 쥐는 힘이 가장 먼저 빠진다.
##
## 머리가 마지막인 것이 중요하다. 머리가 먼저 떨어지면 목이 부러진 것으로 보이고,
## 마지막에 천천히 떨궈야 **힘이 빠진 것**으로 읽힌다.
const RELEASE: Dictionary[CharPart.Id, float] = {
	CharPart.Id.HAND_NEAR: 0.00,
	CharPart.Id.HAND_FAR: 0.06,
	CharPart.Id.FOOT_FAR: 0.18,
	CharPart.Id.FOOT_NEAR: 0.24,
	CharPart.Id.TORSO: 0.30,
	CharPart.Id.HEAD: 0.46,
}

## 한 파츠가 다 무너지는 데 걸리는 시간.
const FALL := 0.62

## 다 무너진 자세. `(앞뒤, 상하, 회전)`.
##
## **발은 상하를 안 건드린다** — 땅에 있어야 하기 때문이다.
const DOWN: Dictionary[CharPart.Id, Vector3] = {
	CharPart.Id.HEAD: Vector3(-16.0, -46.0, 0.78),
	CharPart.Id.TORSO: Vector3(-8.0, -26.0, 0.62),
	CharPart.Id.HAND_FAR: Vector3(-18.0, -34.0, 0.50),
	CharPart.Id.HAND_NEAR: Vector3(-4.0, -38.0, 1.15),
	CharPart.Id.FOOT_FAR: Vector3(-12.0, 0.0, 0.20),
	CharPart.Id.FOOT_NEAR: Vector3(9.0, 0.0, -0.28),
}

## 놓을 때 한 번 출렁이는 폭과 잦아드는 빠르기. **되튐이 아니라 늘어짐이다.**
const SAG := 0.16
const SAG_DECAY := 5.0

## 마지막으로 힘이 다 빠지고 나서 멈춰 있는 시간. 이 여백이 「끝났다」를 만든다.
const REST_AFTER := 0.30

## 들고 있는 무기. **무기가 얹힌 상태가 전투 애니메이션의 바탕이다**(§25.11) —
## 무거운 무기는 더 길어서 쓰러질 때 검끝이 바닥에 박히기 쉽다.
var weapon := CharWeapon.new(1)


func clip_name() -> String:
	return "die (순서대로 무게를 잃는다)"


## 마지막으로 놓는 파츠가 다 무너지고, 그 뒤에 여백이 붙는다.
func loop_seconds() -> float:
	var last := 0.0
	for part: CharPart.Id in RELEASE:
		last = maxf(last, RELEASE[part])
	return last + FALL + REST_AFTER


## **루프가 아니다.** 되돌아오지 않는 유일한 동작이다.
func is_looping() -> bool:
	return false


## 그 파츠가 얼마나 무너졌는가. `0` 이 아직 버티는 것, `1` 이 다 놓은 것.
##
## 자기 차례가 오기 전에는 **정확히 0** 이다 — 그래야 「아직 버티고 있다」가 보인다.
func collapse(part: CharPart.Id, t: float) -> float:
	var since := t - RELEASE[part]
	if since <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, clampf(since / FALL, 0.0, 1.0))


## 놓는 순간의 출렁임. 목표를 **지나쳤다 돌아오는 것이 아니라** 잠깐 더 늘어졌다 앉는다.
func sag(part: CharPart.Id, t: float) -> float:
	var since := t - RELEASE[part]
	if since <= 0.0 or since >= FALL:
		return 0.0
	return exp(-SAG_DECAY * since) * sin(TAU * since / FALL)


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := clampf(t, 0.0, loop_seconds())
	for part in CharPart.COUNT:
		_apply_part(pose, part, at, features)
	# 무기는 파츠가 아니라 접지 검사가 못 본다. 검끝이 박혔으면 든 손을 들어 띄운다.
	keep_weapon_off_floor(pose, weapon)
	return pose


func _apply_part(pose: CharPose, part: CharPart.Id, t: float, f: AnimFeatures) -> void:
	var gone := collapse(part, t)
	var slack := sag(part, t) * SAG * f.delay
	var target: Vector3 = DOWN[part]
	var far := 1.0 if CharPart.is_far(part) else 0.0
	var motion := lerpf(1.0, 0.82, far * f.depth)

	pose.positions[part] += Vector2(target.x * f.arc, target.y) * gone * motion
	pose.rotations[part] = target.z * (gone + slack) * f.arc
	# 힘이 빠지면 눌린다 — 버티던 것이 안 버티는 것이라 부피가 아래로 퍼진다.
	pose.scales[part] = CharClip.volume_scale(-0.05 * gone * f.squash)

	# **발만이 아니라 여섯 다** 바닥에 닿으면 거기서 멈춘다. 무너지는 동작이라
	# 몸도 머리도 손도 결국 땅에 닿는데, 닿고 나서도 계속 내려가면 바닥을 뚫는다.
	#
	# 자세표의 값을 손으로 맞추지 않는 이유가 이것이다 — 어디서 멈추는지는 **기하가**
	# 정한다. 표는 「어느 쪽으로 무너지는가」만 말하고 「어디까지」는 바닥이 답한다.
	# **공식이 아니라 실제 트랜스폼을 잰다** — 회전과 배율이 다 반영돼야 하기 때문이다.
	pose.positions[part] += Vector2(0.0, pose.lift_to_clear_ground(part, rig))
