class_name CharRig
extends RefCounted
## 파츠 여섯의 피벗과 치수. **사이드 사선** 기준이다.
##
## 캐릭터는 `+x` 를 보고 서 있다. 왼쪽을 보게 하려면 `CharPartsView` 의 `scale.x` 를
## 뒤집으면 된다 — 트랜스폼만 쓰므로 그것으로 끝이고, 앞뒤 관계도 그대로 유지된다.
##
## **피벗을 어디에 두는가가 연기의 절반이다.** 파츠별 근거는
## `docs/design/25-character-animation.md` §25.2.
##
## 좌표계: **`+y` 가 위**, 원점은 **앞발이 땅에 닿는 자리**. Godot 은 `+y` 가 아래이므로
## 변환이 필요하고, 그 변환은 `CharPose.canvas_transform()` 한 곳에만 있다.
##
## 스프라이트로 갈아 끼울 때 바뀌는 파일이 이것과 `char_part_shape.gd` 둘뿐이다.

## 서 있는 자세는 **앞발이 앞, 뒷발이 뒤**다. 나란히 세우면 정면 자세가 되어
## 옆에서 본 것으로 안 읽힌다. 이 어긋남 자체가 시점을 말한다.
const FOOT_NEAR_POS := Vector2(8.0, 0.0)
const FOOT_NEAR_HALF := Vector2(11.0, 11.0)

## 뒷발은 **뒤로 밀리고 위로 올라간다.** 바닥이 멀어지면 접지점이 화면에서 위로 간다.
## 그래서 뒷발의 지면은 `y = 0` 이 아니라 자기 자리의 높이다.
const FOOT_FAR_POS := Vector2(-13.0, 5.0)
const FOOT_FAR_HALF := Vector2(9.5, 9.5)

## 몸은 두 발 사이. 옆으로 돌아섰으므로 정면보다 좁다 (반너비 20 에서 17 로).
const TORSO_POS := Vector2(-2.0, 34.0)
const TORSO_HALF := Vector2(17.0, 21.0)

## 원피스 실루엣의 한쪽 윤곽. `x` 는 반너비의 비율, `y` 는 **밑단(0)에서 깃(1)까지**
## 몸 전체 높이의 비율이다. `CharPartShape` 이 이것을 좌우로 닫아 폴리곤을 만든다.
##
## **그림이 아니라 치수라서 리그가 갖는다.** 손이 몸에 겹치는지는 반드시
## **그 손의 높이에서** 재야 하는데, 이 표가 도형 파일에만 있으면 검증이 잴 수 있는
## 것은 `TORSO_HALF.x`(최대 반너비)뿐이다. 그러면 **밑단의 폭으로 어깨 옆을 판정한다.**
##
## 실제로 그렇게 한 번 틀렸다 — 앞손이 화면에서는 멀쩡히 떠 있는데 테스트만
## 「몸에 겹친다」고 우겼다. 밑단이 어깨보다 1.5 배 넓기 때문이다.
const TORSO_PROFILE: Array[Vector2] = [
	Vector2(0.00, 0.00),
	Vector2(0.50, 0.01),
	Vector2(0.84, 0.04),
	Vector2(1.00, 0.10),
	Vector2(0.97, 0.18),
	Vector2(0.88, 0.28),
	Vector2(0.77, 0.40),
	Vector2(0.68, 0.50),
	Vector2(0.63, 0.58),
	Vector2(0.62, 0.66),
	Vector2(0.66, 0.74),
	Vector2(0.68, 0.82),
	Vector2(0.62, 0.90),
	Vector2(0.44, 0.97),
	Vector2(0.00, 1.02),
]

## 앞손은 앞 · 아래 · 크게. 몸에서 떨어져 떠 있는 것이 보여야 한다 — 레이맨의 표시다.
const HAND_NEAR_POS := Vector2(25.0, 52.0)
const HAND_NEAR_HALF := Vector2(11.0, 11.0)

## 뒷손은 뒤 · 위 · 작게. **몸에 겹친다** — 겹쳐서 가려져야 뒤에 있는 것이 된다.
##
## 겹침을 **손 높이에서** 재야 한다. 처음에 밑단의 최대 반너비로 계산해 −24 로 뒀더니,
## 정작 손이 있는 높이에서는 치마가 잘록해 2 만큼 떠 있었다 — 가려지는 데가 없어
## 깊이 단서가 통째로 사라졌다.
const HAND_FAR_POS := Vector2(-18.0, 58.0)
const HAND_FAR_HALF := Vector2(9.5, 9.5)

## 머리는 몸보다 조금 앞. 옆에서 보면 머리가 어깨 위에 얹혀 살짝 앞으로 나온다.
## 몸의 윗면(76)보다 5 위 — **이 5 가 목이다.**
const HEAD_POS := Vector2(1.0, 81.0)
const HEAD_HALF := Vector2(30.0, 30.0)

## 파츠의 피벗 위치 (쉬는 자세, 캐릭터 공간).
var rest_positions: PackedVector2Array

## 그려지는 덩어리의 중심이 피벗에서 얼마나 떨어져 있는가 (파츠 지역 공간, `+y` 위).
var local_centers: PackedVector2Array

## 그려지는 덩어리의 반크기. 접지 판정과 실루엣 계산에 쓴다.
var half_sizes: PackedVector2Array


func _init() -> void:
	rest_positions = PackedVector2Array(
		[HEAD_POS, TORSO_POS, HAND_FAR_POS, HAND_NEAR_POS, FOOT_FAR_POS, FOOT_NEAR_POS]
	)
	half_sizes = PackedVector2Array(
		[HEAD_HALF, TORSO_HALF, HAND_FAR_HALF, HAND_NEAR_HALF, FOOT_FAR_HALF, FOOT_NEAR_HALF]
	)
	# 머리 · 몸 · 발은 피벗이 밑면이라 중심이 반높이만큼 위에 있다. 손은 피벗이 중심이다.
	local_centers = PackedVector2Array(
		[
			Vector2(0.0, HEAD_HALF.y),
			Vector2(0.0, TORSO_HALF.y),
			Vector2.ZERO,
			Vector2.ZERO,
			Vector2(0.0, FOOT_FAR_HALF.y),
			Vector2(0.0, FOOT_NEAR_HALF.y),
		]
	)


## 정수리까지의 키. 화면에 맞춰 배율을 정할 때 쓴다.
##
## 상수로 두지 않는 이유는 리그 치수를 두 곳에 적으면 도구가 옛 수치로 거짓말하기 때문이다.
func total_height() -> float:
	return rest_positions[CharPart.Id.HEAD].y + half_sizes[CharPart.Id.HEAD].y * 2.0


## 손 바깥 끝에서 끝까지의 폭.
func total_width() -> float:
	var near_edge := rest_positions[CharPart.Id.HAND_NEAR].x + half_sizes[CharPart.Id.HAND_NEAR].x
	var far_edge := rest_positions[CharPart.Id.HAND_FAR].x - half_sizes[CharPart.Id.HAND_FAR].x
	return near_edge - far_edge


## 이 파츠가 딛는 바닥의 높이.
##
## **발마다 다르다.** 사이드 사선에서는 바닥이 멀어지며 화면 위로 물러나므로
## 뒷발의 접지면이 앞발보다 높다. 이걸 하나로 두면 뒷발이 땅에 파묻히거나 떠 있다.
func ground_y(part: CharPart.Id) -> float:
	if CharPart.is_foot(part):
		return rest_positions[part].y
	return 0.0


## 그 높이에서 몸이 얼마나 넓은가 (캐릭터 공간의 `y`, 반너비).
##
## **A 라인이라 높이마다 다르다.** 밑단이 가장 넓고 어깨가 가장 좁다.
## 손이 몸에 겹치는지 · 떠 있는지는 이 값으로 재야 한다 (`TORSO_PROFILE` 참고).
## 몸 밖의 높이를 물으면 가장 가까운 끝의 폭을 돌려준다.
func torso_half_width_at(char_y: float) -> float:
	var part := CharPart.Id.TORSO
	var span := half_sizes[part].y * 2.0
	var at := (char_y - rest_positions[part].y) / span
	var ratio := _profile_width_at(TORSO_PROFILE, at)
	return ratio * half_sizes[part].x


## 몸의 앞면(`+x` 쪽) · 뒷면(`-x` 쪽)이 그 높이에서 어디인가. 겹침 판정의 기준선이다.
func torso_front_at(char_y: float) -> float:
	return rest_positions[CharPart.Id.TORSO].x + torso_half_width_at(char_y)


func torso_back_at(char_y: float) -> float:
	return rest_positions[CharPart.Id.TORSO].x - torso_half_width_at(char_y)


## 파츠 지역 공간에서의 밑면 한가운데. 접지 판정의 기준점이다.
##
## 피벗이 밑면인 파츠는 이 값이 원점이라, **눌려도(`sy < 1`) 밑면이 안 움직인다.**
func local_bottom(part: CharPart.Id) -> Vector2:
	return local_centers[part] - Vector2(0.0, half_sizes[part].y)


## 파츠 지역 공간에서의 **발끝**(앞쪽 밑 모서리).
##
## 뒤꿈치를 드는 동작이 이 점을 축으로 돈다. 피벗은 밑면 한가운데에 고정되어 있으므로
## 회전만 시키면 발끝이 땅을 파고든다 — `CharIdleClip` 이 그만큼 들어 올려 보정한다.
func local_toe(part: CharPart.Id) -> Vector2:
	return local_bottom(part) + Vector2(half_sizes[part].x, 0.0)


## 윤곽표를 높이 `at` 에서 선형 보간한다. 표의 `y` 는 오름차순이다.
func _profile_width_at(profile: Array[Vector2], at: float) -> float:
	if at <= profile[0].y:
		return profile[0].x
	for i in range(1, profile.size()):
		var top := profile[i]
		if at > top.y:
			continue
		var low := profile[i - 1]
		var reach := top.y - low.y
		if is_zero_approx(reach):
			return top.x
		return lerpf(low.x, top.x, (at - low.y) / reach)
	return profile[profile.size() - 1].x
