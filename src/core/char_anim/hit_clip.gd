class_name CharHitClip
extends CharClip
## get hit — **경직 · 띄우기 · 바닥 쓰러짐.** §28.5 가 확정한 셋이 한 클립에 들어간다.
##
## `docs/design/25-character-animation.md` §25.12.
##
## **구조를 새로 짤 것이 하나도 없었다.** 휘두르기의 감쇠 진동을 그대로 쓰고
## **파츠마다 감쇠만 다르게** 준다 — 머리가 가장 오래 흔들리고 발이 가장 안 흔들린다.
## §25.3.1 이 처음부터 「사건 이후 흐른 시간의 함수」로 짜 두라고 한 값이 여기서 나온다.
##
## | 구간 | 하는 일 |
## | --- | --- |
## | **경직** | 맞은 자세로 **완전히 멈춘다.** 이 정지가 타격의 무게다 |
## | **띄우기** | 포물선으로 뜨고 뒤로 밀린다 |
## | **바닥 쓰러짐** | 떨어져 한 번 튀고 주저앉는다 |
##
## **`plant` 축은 여기서 아무 상관이 없다** — 그것은 walk 의 디딤 등속만 관장한다.
## 띄우기가 지면 규칙과 부딪히지도 않는다. 지면 규칙은 **파고드는 것만 금지하고
## 뜨는 것은 허용**하기 때문이다 (§25.12.1).

## 어디까지 무너지나. **구간을 자를 뿐 수식을 하나도 안 바꾼다** —
## 전부 「사건 이후 흐른 시간의 함수」라(§25.3.1) 앞부분만 쓰는 것이 그냥 된다.
enum Depth { STUN, LAUNCH, FALL }

## **무너짐 눈금** — 전투 레인이 §28.5 를 확정했다. **저쪽이 정한 값이고 여기가 받는다.**
##
## | 넘으면 | 어디까지 |
## | --- | --- |
## | **30** | 경직만 |
## | **60** | 띄우기까지 |
## | **100** | 쓰러짐까지 |
##
## **문턱만으로는 못 정했다는 것이 저쪽의 발견이다** — 감쇠가 초당 20 이면 1 칸은
## 한 방의 29 %, 4 칸은 7 % 만 남아서 **아홉 타가 다섯 타와 같은 데서 만난다.**
## *"문턱은 그 폭을 나눌 뿐 폭을 만들지 못한다."* 그래서 저쪽이 **감쇠를 10 으로** 옮겼다.
const STUN_AT := 30.0
const LAUNCH_AT := 60.0
const FALL_AT := 100.0

## 얕은 눈금이 **제자리로 돌아오는 데** 쓰는 끝자락의 비율.
##
## **「앞부분만 재생」은 반만 맞았다**(§25.12.6). 밀려난 채로 끝나면 다음 동작이
## 그 차이만큼 튄다 — 쓰러짐만 안 돌아온다. 그것 하나가 **상태로 남는 것**이기 때문이다.
const HOME_TAIL := 0.45

## 경직. 맞은 자세로 멈춰 있는 시간. **짧아야 한다** — 길면 정지가 아니라 고장으로 보인다.
const FREEZE := 0.09

## 띄워져 있는 시간과 한 번 튀는 시간.
const FLIGHT := 0.34
const BOUNCE := 0.18

## 주저앉아 자리 잡는 시간.
const SETTLE := 0.55

const LAUNCH_HEIGHT := 26.0

## 튈 때 올라가는 높이의 비율. 1 에 가까우면 공이 되고 0 이면 철퍼덕 떨어진다.
const BOUNCE_RATIO := 0.28

## 뒤로 밀리는 거리. 캐릭터는 `+x` 를 보고 있으므로 **`-x` 로** 밀린다.
const KNOCKBACK := 34.0

## 맞은 순간의 자세. `(앞뒤, 상하, 회전)` — `WeaponGuard.POSES` 와 같은 방식이다.
##
## **뒤로 젖혀지는 것이 양수 회전이다.** 피벗이 밑면이라 위쪽이 `-x` 로 가려면
## 반시계로 돌아야 한다.
const RECOIL: Dictionary[CharPart.Id, Vector3] = {
	CharPart.Id.HEAD: Vector3(-7.0, 1.0, 0.42),
	CharPart.Id.TORSO: Vector3(-4.0, 0.0, 0.24),
	CharPart.Id.HAND_FAR: Vector3(-6.0, 3.0, 0.30),
	CharPart.Id.HAND_NEAR: Vector3(-9.0, 4.0, 0.55),
	CharPart.Id.FOOT_FAR: Vector3(1.0, 0.0, 0.0),
	CharPart.Id.FOOT_NEAR: Vector3(2.0, 0.0, -0.10),
}

## 다 끝나고 주저앉은 자세. **발은 상하를 안 건드린다** — 땅에 있어야 하기 때문이다.
const SLUMP: Dictionary[CharPart.Id, Vector3] = {
	CharPart.Id.HEAD: Vector3(-12.0, -34.0, 0.60),
	CharPart.Id.TORSO: Vector3(-6.0, -20.0, 0.50),
	CharPart.Id.HAND_FAR: Vector3(-14.0, -26.0, 0.40),
	CharPart.Id.HAND_NEAR: Vector3(-10.0, -30.0, 0.90),
	CharPart.Id.FOOT_FAR: Vector3(-9.0, 0.0, 0.16),
	CharPart.Id.FOOT_NEAR: Vector3(6.0, 0.0, -0.22),
}

## 파츠마다 **다른 감쇠**. 이것이 「관절 없는데 살로 보이는」 것의 정체다.
##
## 머리가 가장 오래 흔들리고(목이 무거우니까) 발이 가장 안 흔들린다(땅에 있으니까).
## 같은 감쇠를 주면 여섯이 한 덩어리로 떨려 인형이 된다.
const RING_DECAY: Dictionary[CharPart.Id, float] = {
	CharPart.Id.HEAD: 3.4,
	CharPart.Id.TORSO: 6.0,
	CharPart.Id.HAND_FAR: 4.2,
	CharPart.Id.HAND_NEAR: 3.8,
	CharPart.Id.FOOT_FAR: 9.0,
	CharPart.Id.FOOT_NEAR: 9.0,
}

## 흔들리는 폭 (px) 과 회전 폭 (rad), 한 번 흔들리는 데 걸리는 시간.
const RING_SHIFT := 3.6
const RING_TWIST := 0.16
const RING_PERIOD := 0.26

## 맞는 순간의 눌림. 몸이 한 번 찌그러졌다 펴진다.
const IMPACT_SQUASH := 0.075

## 맞은 자세가 풀리는 데 걸리는 시간. **경직만 맞았을 때 이만큼 더 보여 준다** —
## 경직에서 딱 끊으면 젖혀진 자세 그대로 다음 동작이 시작되어 툭 튄다.
const RECOIL_RELEASE := FLIGHT * 0.8

## 들고 있는 무기. **무기가 얹힌 상태가 전투 애니메이션의 바탕이다**(§25.11) —
## 무거운 무기는 더 길어서 쓰러질 때 검끝이 바닥에 박히기 쉽다.
var weapon := CharWeapon.new(1)

## 어디까지 무너지나. **전투가 준 눈금에서 나온다** — 여기서 만들지 않는다 (§25.18.2).
var depth := Depth.FALL


## 눈금을 구간으로 옮긴다. **문턱은 저쪽 것이고 구간은 이쪽 것이다.**
static func depth_for(stagger: float) -> Depth:
	if stagger >= FALL_AT:
		return Depth.FALL
	if stagger >= LAUNCH_AT:
		return Depth.LAUNCH
	return Depth.STUN


func clip_name() -> String:
	# 가운뎃점(U+00B7)이 아니라 불릿(U+2022)이다. **SongMyung 에 U+00B7 이 없어서**
	# 웹 빌드에서 두부가 된다 - 화면에 나가는 문자열이므로 글리프 검사가 잡았다.
	return "get hit (경직 • 띄우기 • 쓰러짐)"


func loop_seconds() -> float:
	match depth:
		Depth.STUN:
			return FREEZE + RECOIL_RELEASE
		Depth.LAUNCH:
			return FREEZE + FLIGHT + BOUNCE
		_:
			return FREEZE + FLIGHT + BOUNCE + SETTLE


## **얕은 눈금은 제자리로 돌아온다.** `1` 에서 시작해 끝자락에서 `0` 이 된다.
##
## 쓰러짐만 `1` 로 남는다 — 되돌아오지 않는 것이 쓰러짐의 정의다 (§25.17).
func homing(t: float) -> float:
	if depth == Depth.FALL:
		return 1.0
	var span := loop_seconds()
	var tail := span * HOME_TAIL
	if tail <= 0.0 or t <= span - tail:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (t - (span - tail)) / tail)


## **루프가 아니다.** 쓰러진 자세에 멈춰 선다 — 일어나기는 별개의 동작이다.
func is_looping() -> bool:
	return false


## 지면에서 뜬 높이. **포물선이다** — 사건 이후 흐른 시간의 함수라 그냥 닫힌 식이다.
##
## 경직 동안에는 0 이다. 맞은 자리에서 **멈춰 있어야** 정지가 보인다.
func lift(t: float) -> float:
	# **경직만 맞으면 안 뜬다.** 30 을 넘고 60 을 못 넘긴 것이 그 눈금이다.
	if depth == Depth.STUN:
		return 0.0
	var flying := t - FREEZE
	if flying <= 0.0:
		return 0.0
	if flying < FLIGHT:
		return _hop(flying / FLIGHT, LAUNCH_HEIGHT)
	var bouncing := flying - FLIGHT
	if bouncing < BOUNCE:
		return _hop(bouncing / BOUNCE, LAUNCH_HEIGHT * BOUNCE_RATIO)
	return 0.0


## 뒤로 밀린 거리 (음수). 끝에서 속도가 0 이 되어 **미끄러지다 멈춘다.**
func drift(t: float) -> float:
	if depth == Depth.STUN:
		return 0.0
	var flying := t - FREEZE
	if flying <= 0.0:
		return 0.0
	var span := FLIGHT + BOUNCE
	# **밀린 채로 끝나면 다음 동작이 그만큼 튄다.** 쓰러짐만 밀린 자리에 남는다.
	var push := -KNOCKBACK * smoothstep(0.0, 1.0, clampf(flying / span, 0.0, 1.0))
	return push * homing(t)


## 주저앉은 자세로 얼마나 갔는가. 땅에 닿고 나서야 오른다.
func slump(t: float) -> float:
	# **쓰러지는 것은 100 을 넘었을 때뿐이다.** 띄우기까지는 떴다가 서 있는 것으로 끝난다.
	if depth != Depth.FALL:
		return 0.0
	var landing := t - (FREEZE + FLIGHT)
	if landing <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, clampf(landing / (BOUNCE + SETTLE), 0.0, 1.0))


## 맞은 자세가 남아 있는 정도. 경직 동안 **정확히 1** 이고 그 뒤로 빠르게 풀린다.
func recoil(t: float) -> float:
	if t < FREEZE:
		return 1.0
	return maxf(0.0, 1.0 - (t - FREEZE) / RECOIL_RELEASE)


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := clampf(t, 0.0, loop_seconds())
	var height := lift(at)
	var back := drift(at)
	var down := slump(at)
	var snap := recoil(at)
	for part in CharPart.COUNT:
		_apply_part(pose, part, at, features, height, back, down, snap)
	# 무기는 파츠가 아니라 접지 검사가 못 본다. 검끝이 박혔으면 든 손을 들어 띄운다.
	keep_weapon_off_floor(pose, weapon)
	rein_in_limbs(pose)
	return pose


func _apply_part(
	pose: CharPose,
	part: CharPart.Id,
	t: float,
	f: AnimFeatures,
	height: float,
	back: float,
	down: float,
	snap: float
) -> void:
	var hit: Vector3 = RECOIL[part]
	var rest: Vector3 = SLUMP[part]
	var far := 1.0 if CharPart.is_far(part) else 0.0
	# 먼 파츠가 덜 움직인다 — idle · walk 와 같은 깊이 규칙이다.
	var motion := lerpf(1.0, 0.78, far * f.depth)
	# 파츠마다 감쇠가 다르다. **여기가 「살로 보이는」 지점이다.**
	var wobble := _ring(t, RING_DECAY[part]) * f.delay * motion

	var shift := Vector2(hit.x, hit.y) * snap + Vector2(rest.x, rest.y) * down
	pose.positions[part] += (
		Vector2(shift.x * f.arc + back * motion, shift.y + height)
		+ Vector2(RING_SHIFT * wobble * f.arc, 0.0)
	)
	pose.rotations[part] = (hit.z * snap + rest.z * down) * f.arc + RING_TWIST * wobble

	# 발은 회전한 만큼 되들어 올린다 (idle · walk 와 같은 규칙).
	#
	# **떠 있을 때만 빼는 조건을 달았다가 걸렸다.** 뜬 높이가 0 을 갓 벗어난 프레임에서
	# 보정이 툭 꺼져 발이 0.22 만큼 파고들었다. 보정은 회전에서 나오는 값이지 높이와
	# 무관하므로 **언제나 건다** — 조건을 다는 것 자체가 불연속을 만든다.
	if CharPart.is_foot(part):
		pose.positions[part] += Vector2(0.0, pose.lift_to_clear_ground(part, rig))

	if part == CharPart.Id.TORSO:
		pose.scales[part] = CharClip.volume_scale(-IMPACT_SQUASH * snap * f.squash)


## 포물선 한 번. `u` 가 0 과 1 에서 정확히 0 이라 구간이 매끄럽게 이어진다.
func _hop(u: float, peak: float) -> float:
	return peak * 4.0 * u * (1.0 - u)


## 감쇠 진동. 휘두르기의 후속과 **같은 식**이다 — 새로 짤 것이 없었다.
func _ring(t: float, decay: float) -> float:
	var since := t - FREEZE
	if since <= 0.0:
		return 0.0
	return exp(-decay * since) * sin(TAU * since / RING_PERIOD)
