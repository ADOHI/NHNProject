class_name CharPart
extends RefCounted
## 레이맨식 캐릭터의 파츠 여섯을 가리키는 식별자.
##
## 파츠 사이에는 아무것도 없다 — 팔 · 다리 · 목이 없다. 손발이 공중에 떠 있다.
## 왜 정확히 여섯인지는 `docs/design/25-character-animation.md` §25.1.1 에 있다.
##
## `Id` 의 순서가 곧 `CharRig` · `CharPose` 배열의 색인 순서다. 순서를 바꾸면
## 리그의 치수와 포즈가 서로 어긋나므로, 바꿀 때는 양쪽을 같이 봐야 한다.

enum Id { HEAD, TORSO, HAND_L, HAND_R, FOOT_L, FOOT_R }

const COUNT := 6

## 화면 뒤에서 앞으로 그리는 순서.
##
## 손을 몸보다 앞에 두는 이유는 겹칠 때 손이 이겨야 하기 때문이다 — 호흡으로
## 손이 몸 쪽으로 밀려 들어오는 순간에 손이 몸에 먹히면 파츠가 사라진 것으로 보인다.
const DRAW_ORDER: Array[int] = [Id.FOOT_L, Id.FOOT_R, Id.TORSO, Id.HAND_L, Id.HAND_R, Id.HEAD]


## 파츠가 몸의 중심에서 어느 쪽으로 벌어져 있는가. 왼쪽 `-1` · 오른쪽 `+1` · 가운데 `0`.
##
## 애니메이션 수식이 "바깥으로 벌어진다" 를 좌우 구분 없이 한 줄로 쓸 수 있게 하는 값이다.
static func outward_sign(part: Id) -> float:
	match part:
		Id.HAND_L, Id.FOOT_L:
			return -1.0
		Id.HAND_R, Id.FOOT_R:
			return 1.0
		_:
			return 0.0


## 좌우 한 쌍 중 오른쪽인가. 비대칭을 오른쪽에만 얹기 위한 판정이다.
static func is_right(part: Id) -> bool:
	return part == Id.HAND_R or part == Id.FOOT_R


static func part_name(part: Id) -> String:
	match part:
		Id.HEAD:
			return "머리"
		Id.TORSO:
			return "몸"
		Id.HAND_L:
			return "왼손"
		Id.HAND_R:
			return "오른손"
		Id.FOOT_L:
			return "왼발"
		_:
			return "오른발"
