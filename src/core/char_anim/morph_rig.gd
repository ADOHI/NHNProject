class_name MorphRig
extends RefCounted
## 인물 한 벌의 **앵커 목록과 세기.** 순수 자료다.
##
## `docs/design/31-soft-body.md` §31.2 · §31.4.
##
## ## 세기는 **인물마다의 자료값**이다
##
## 인물이 나이 띠 여덟 × 남녀 둘이다 (§25.40). 여든 살과 여덟 살이 같은 값을 쓸 리가 없고,
## **아예 안 흔들려야 하는 인물**도 있다. 그래서 `strength` 가 자료다.
##
## > **`strength = 0` 이면 완전히 꺼진다.** 변위가 근사가 아니라 **정확히** `Vector2.ZERO` 이고,
## > 그리는 쪽은 셰이더 재질을 **아예 안 붙인다** — 붙여 놓고 0 을 넣는 것과 다르다.
## > 안 붙어야 지금과 **같은 경로**로 그려지고, 그래야 픽셀이 같다 (§31.5.3).
##
## ## 값을 **리그 비율로** 적는다
##
## 앵커 자리를 절대 px 로 박으면 §25.40.2 가 열거한 그 사고가 난다 — 리그만 바꿨는데
## 상수가 안 따라와서 **테스트는 통과하는데 화면이 틀린** 것. 그래서 `default_for()` 가
## **파츠 반크기에 대한 비율**로 푼다. 리그가 커지면 앵커도 같이 커진다.

## 가슴 앵커의 이름. 테스트와 로그가 이 이름으로 찾는다.
const CHEST := "가슴"

## 머리카락 앵커의 이름.
const HAIR := "머리카락"

## **변위 상한** — 파츠 반크기(짧은 축)에 대한 비율 (§25.29 · §31.4).
##
## 「과장은 각도로, 거리로 하면 몸이 분해된다」의 이 층 판이다.
## 살이 몸에서 이보다 더 떨어지면 **붙어 있는 것으로 안 읽힌다.**
const LIMIT_RATIO := 0.12

## 세기. `0` 이면 완전히 꺼진다.
var strength := 0.0

## 앵커들. 파츠 하나에 여럿 붙어도 된다 — 셰이더가 받는 상한은 그리는 쪽이 정한다.
var anchors: Array[MorphAnchor] = []


## 아무 데도 안 붙는 빈 것. **기본값이다** — 안 켜면 지금 화면 그대로다.
static func none() -> MorphRig:
	return MorphRig.new()


## 가슴과 머리카락 앵커 한 벌. **자리를 파츠 반크기의 비율로 푼다.**
##
## | | 어디 | 왜 그 자리인가 |
## | --- | --- | --- |
## | 가슴 | 몸통 위쪽 앞 | 반평면이 **밑단을 잘라 낸다** — 치마가 같이 출렁이면 몸이 물러진다 |
## | 머리카락 | 머리 뒤위 | 반평면이 **얼굴을 잘라 낸다** (§31.2.3) |
##
## **머리카락이 가슴보다 느리고 덜 멎는다.** 그래야 둘이 한 몸으로 안 보인다.
static func default_for(rig: CharRig, p_strength := 1.0) -> MorphRig:
	var morph := MorphRig.new()
	morph.strength = p_strength
	morph.anchors = [_chest(rig), _hair(rig)]
	return morph


static func _chest(rig: CharRig) -> MorphAnchor:
	var half := rig.half_sizes[CharPart.Id.TORSO]
	var anchor := MorphAnchor.new(CHEST, CharPart.Id.TORSO)
	anchor.centre = Vector2(0.34 * half.x, 1.44 * half.y)
	anchor.radius = Vector2(0.64 * half.x, 0.42 * half.y)
	# 위쪽만. 밑단이 출렁이면 A 라인이 무너진다 (§25.2.2 의 원피스 윤곽).
	anchor.mask_normal = Vector2(0.0, 1.0)
	anchor.mask_offset = 1.05 * half.y
	anchor.mask_feather = 0.24 * half.y
	anchor.hz = 5.0
	anchor.damping = 0.30
	anchor.gain = 1.0
	anchor.bulge = 0.35
	anchor.limit = LIMIT_RATIO * minf(half.x, half.y)
	return anchor


static func _hair(rig: CharRig) -> MorphAnchor:
	var half := rig.half_sizes[CharPart.Id.HEAD]
	var anchor := MorphAnchor.new(HAIR, CharPart.Id.HEAD)
	anchor.centre = Vector2(-0.27 * half.x, 1.47 * half.y)
	anchor.radius = Vector2(0.80 * half.x, 0.60 * half.y)
	# **뒤위쪽만.** 법선을 비스듬히 눕혀 정수리와 뒤통수를 같이 잡고 얼굴을 뺀다.
	anchor.mask_normal = Vector2(-0.5, 0.866)
	anchor.mask_offset = 1.00 * half.y
	anchor.mask_feather = 0.23 * half.y
	# 가슴보다 **느리고 덜 멎는다.** 머리카락이 더 오래 흔들려야 둘이 갈린다.
	anchor.hz = 3.2
	anchor.damping = 0.22
	anchor.gain = 1.15
	anchor.bulge = 0.22
	anchor.limit = LIMIT_RATIO * minf(half.x, half.y)
	return anchor


## 아무것도 안 하나. **켜졌는지 묻는 자리가 하나여야 한다.**
func is_off() -> bool:
	return strength <= 0.0 or anchors.is_empty()


## 그 파츠에 붙은 앵커들의 **색인**. 그리는 쪽이 파츠마다 uniform 을 채울 때 쓴다.
func indices_of(part: CharPart.Id) -> PackedInt32Array:
	var out := PackedInt32Array()
	if is_off():
		return out
	for i in anchors.size():
		if anchors[i].part == part:
			out.append(i)
	return out


func index_of(anchor_name: String) -> int:
	for i in anchors.size():
		if anchors[i].anchor_name == anchor_name:
			return i
	return -1


## 앵커마다 **그 클립이 그 점을 어떻게 흔드는지** 뽑는다. **셋업 때 한 번 돈다.**
##
## 프레임마다 부르면 안 된다 — 한 앵커당 클립을 64 번 표본한다 (§31.1.3).
func drives_for(clip: CharClip, features: AnimFeatures) -> Array[SoftDrive]:
	var out: Array[SoftDrive] = []
	for anchor in anchors:
		out.append(SoftDrive.from_clip(clip, anchor.part, anchor.centre, features))
	return out


func copy() -> MorphRig:
	var out := MorphRig.new()
	out.strength = strength
	for anchor in anchors:
		out.anchors.append(anchor.copy())
	return out
