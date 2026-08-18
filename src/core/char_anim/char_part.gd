class_name CharPart
extends RefCounted
## 레이맨식 캐릭터의 파츠 여섯을 가리키는 식별자.
##
## **시점은 사이드 사선이다.** 캐릭터는 `+x` 를 보고 서 있고, 카메라는 옆에서
## 조금 비스듬히 본다. 그래서 손과 발에 좌우가 아니라 **앞뒤(near · far)** 가 있다.
##
## 이 구분이 이름만의 문제가 아니다. 셋을 한꺼번에 바꾼다.
##
## * **그리는 순서** — 먼 파츠는 몸 **뒤로** 간다. 겹침이 곧 깊이다
## * **크기** — 먼 파츠가 작다 (`CharRig`)
## * **궤도** — 먼 파츠가 덜 움직이고 고주파가 깎인다 (`CharIdleClip`, `AnimFeatures.depth`)
##
## 파츠 사이에는 아무것도 없다 — 팔 · 다리 · 목이 없다.
##
## `Id` 의 순서가 곧 `CharRig` · `CharPose` 배열의 색인 순서다.

enum Id { HEAD, TORSO, HAND_FAR, HAND_NEAR, FOOT_FAR, FOOT_NEAR }

const COUNT := 6

## 화면 뒤에서 앞으로 그리는 순서.
##
## **먼 손발이 몸보다 먼저 나간다.** 이것이 사이드 사선의 핵심이다 — 정면이었을 때는
## 앞뒤가 없어서 순서가 아무 뜻도 없었다. 지금은 먼 손이 몸에 가려지는 것이
## 「저쪽에 있다」를 말하는 유일한 수단이다.
const DRAW_ORDER: Array[int] = [
	Id.FOOT_FAR, Id.HAND_FAR, Id.TORSO, Id.HEAD, Id.FOOT_NEAR, Id.HAND_NEAR
]


## 카메라에서 먼 파츠인가. 크기 · 색 · 궤도가 모두 이 판정에서 갈린다.
static func is_far(part: Id) -> bool:
	return part == Id.HAND_FAR or part == Id.FOOT_FAR


## 깊이 방향. 먼 쪽 `-1` · 가까운 쪽 `+1` · 가운데 `0`.
##
## 사이드 사선에서 이 부호는 **화면 좌우이면서 동시에 앞뒤**다. 캐릭터가 `+x` 를
## 보고 있으므로 가까운 손발이 앞(`+x`)에, 먼 손발이 뒤(`-x`)에 놓인다.
static func depth_sign(part: Id) -> float:
	match part:
		Id.HAND_FAR, Id.FOOT_FAR:
			return -1.0
		Id.HAND_NEAR, Id.FOOT_NEAR:
			return 1.0
		_:
			return 0.0


static func is_foot(part: Id) -> bool:
	return part == Id.FOOT_FAR or part == Id.FOOT_NEAR


static func part_name(part: Id) -> String:
	match part:
		Id.HEAD:
			return "머리"
		Id.TORSO:
			return "몸"
		Id.HAND_FAR:
			return "뒷손"
		Id.HAND_NEAR:
			return "앞손"
		Id.FOOT_FAR:
			return "뒷발"
		_:
			return "앞발"
