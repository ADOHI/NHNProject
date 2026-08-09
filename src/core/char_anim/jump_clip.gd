class_name CharJumpClip
extends CharClip
## jump — **예비 · 도약 · 체공 · 착지 오버슛.**
##
## `docs/design/25-character-animation.md` §25.15.
##
## `get hit` 의 포물선을 그대로 쓴다. **다른 것은 하나뿐이다** —
## 맞는 것은 사건이 밖에서 오지만 **뛰는 것은 스스로 준비한다.** 그래서 앞에 **예비**가 붙는다.
##
## | 구간 | 하는 일 |
## | --- | --- |
## | **예비** | 웅크린다. 눌리고 낮아진다. **이것이 없으면 갑자기 떠오른다** |
## | **도약** | 펴면서 뜬다. 몸이 늘어난다 |
## | **체공** | 포물선. 꼭대기에서 가장 느리다 |
## | **착지** | 눌렸다가 **오버슛으로** 되펴진다 |
##
## §25.3.1 이 금지한 지수 접근을 여기서도 안 쓴다 — 착지의 되튐이 감쇠 진동이다.

## 웅크리는 시간. 짧으면 가볍고 길면 무겁게 뛰는 것으로 보인다.
const CROUCH := 0.16

## 떠 있는 시간.
const AIR := 0.52

## 착지 뒤 되펴지는 시간.
const LAND := 0.34

const HEIGHT := 52.0

## 웅크릴 때 내려가는 깊이와 눌리는 양.
const CROUCH_DROP := 9.0
const CROUCH_SQUASH := 0.10

## 착지 순간의 눌림. 웅크림보다 깊다 — 떨어진 것을 받아 내야 하니까.
const LAND_SQUASH := 0.14

## 착지 되튐이 잦아드는 빠르기와 흔들리는 횟수.
const LAND_DECAY := 9.0
const LAND_CYCLES := 1.5

## 뜰 때 손발이 늦게 따라 올라오는 정도. 이것이 「끌려 올라간다」를 만든다.
const HAND_TRAIL := 0.12
const FOOT_TUCK := 7.0

const HEAD_TRAIL := 0.07


func clip_name() -> String:
	return "jump (예비 • 도약 • 착지)"


func loop_seconds() -> float:
	return CROUCH + AIR + LAND


func is_looping() -> bool:
	return false


## 지면에서 뜬 높이. 포물선 — 사건 이후 흐른 시간의 닫힌 식이다.
func lift(t: float) -> float:
	var flying := t - CROUCH
	if flying <= 0.0 or flying >= AIR:
		return 0.0
	var u := flying / AIR
	return HEIGHT * 4.0 * u * (1.0 - u)


## 웅크린 정도. 예비에서 `1` 까지 갔다가 도약과 함께 0 으로 풀린다.
func crouch(t: float) -> float:
	if t < CROUCH:
		return smoothstep(0.0, 1.0, t / CROUCH)
	return 0.0


## 착지의 되튐. **감쇠 진동이라 0 을 지나쳐 되펴진다.**
func recoil(t: float) -> float:
	var landed := t - (CROUCH + AIR)
	if landed < 0.0:
		return 0.0
	var u := clampf(landed / LAND, 0.0, 1.0)
	return exp(-LAND_DECAY * landed) * (1.0 - u) * cos(TAU * LAND_CYCLES * u)


func sample(t: float, features: AnimFeatures) -> CharPose:
	var pose := CharPose.from_rig(rig)
	var at := clampf(t, 0.0, loop_seconds())
	var height := lift(at)
	var down := crouch(at)
	var bounce := recoil(at)
	# 눌림은 웅크릴 때와 착지할 때 둘 다 생긴다. 착지 쪽이 깊다.
	var press := CROUCH_SQUASH * down + LAND_SQUASH * maxf(bounce, 0.0)
	# 뜨는 동안에는 반대로 늘어난다 — 늘어남이 있어야 도약이 가벼워 보인다.
	var stretch := 0.05 * (height / HEIGHT)
	_apply_torso(pose, features, height, down, press, stretch)
	_apply_head(pose, at, features, height, down, press, stretch)
	_apply_hands(pose, at, features, height, down)
	_apply_feet(pose, features, height, press)
	return pose


func _apply_torso(
	pose: CharPose, f: AnimFeatures, height: float, down: float, press: float, stretch: float
) -> void:
	var part := CharPart.Id.TORSO
	pose.positions[part] += Vector2(0.0, height - CROUCH_DROP * down)
	pose.scales[part] = CharClip.volume_scale((stretch - press) * f.squash)


func _apply_head(
	pose: CharPose,
	t: float,
	f: AnimFeatures,
	height: float,
	down: float,
	press: float,
	stretch: float
) -> void:
	var part := CharPart.Id.HEAD
	# 머리는 늦게 따라온다 — 지연이 시각의 함수라 과거의 높이를 읽으면 그만이다.
	var late := lift(t - HEAD_TRAIL * f.delay)
	pose.positions[part] += Vector2(0.0, lerpf(height, late, f.delay) - CROUCH_DROP * 0.6 * down)
	pose.scales[part] = CharClip.volume_scale((stretch * 0.5 - press * 0.6) * f.squash)


## 손 — 뜰 때 **늦게 끌려 올라간다.** 그 지연이 도약의 무게다.
func _apply_hands(pose: CharPose, t: float, f: AnimFeatures, height: float, down: float) -> void:
	for part: CharPart.Id in [CharPart.Id.HAND_FAR, CharPart.Id.HAND_NEAR]:
		var far := 1.0 if CharPart.is_far(part) else 0.0
		var motion := lerpf(1.0, 0.78, far * f.depth)
		var late := lift(t - (HAND_TRAIL + 0.04 * far) * f.delay)
		pose.positions[part] += Vector2(0.0, lerpf(height, late, f.delay) * motion - 4.0 * down)
		pose.rotations[part] = -0.25 * (height / HEIGHT) * motion * f.arc


## 발 — 뜨면 **당겨 올린다.** 발이 그냥 딸려 올라가면 매달린 것으로 보인다.
func _apply_feet(pose: CharPose, f: AnimFeatures, height: float, press: float) -> void:
	var airborne := height / HEIGHT
	for part: CharPart.Id in [CharPart.Id.FOOT_FAR, CharPart.Id.FOOT_NEAR]:
		var far := 1.0 if CharPart.is_far(part) else 0.0
		var tuck := FOOT_TUCK * airborne * lerpf(1.0, 0.7, far * f.asymmetry)
		# **웅크린다고 발을 내리면 안 된다.** 발은 이미 지면에 있다 — 내리는 것은 몸이지
		# 발이 아니다. 처음에 웅크림만큼 발도 내렸다가 그대로 땅을 파고들었다.
		pose.positions[part] += Vector2(0.0, height + tuck)
		pose.rotations[part] = -0.30 * airborne * f.arc
		# 땅에 있을 때 회전한 만큼 되들어 올린다. **조건 없이 언제나 건다** (§25.12.3).
		pose.positions[part] += Vector2(0.0, rig.sole_drop(part, pose.rotations[part]))
		pose.scales[part] = CharClip.volume_scale(-press * 0.5 * f.squash)
