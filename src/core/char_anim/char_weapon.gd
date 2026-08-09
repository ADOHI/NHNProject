class_name CharWeapon
extends RefCounted
## 손에 따로 붙는 무기. **파츠 일곱 번째가 아니라 든 손의 자식이다.**
##
## [`28-combat.md`](../../../docs/design/28-combat.md) §25.7 이 확정했다 —
## *"레이맨 캐릭터의 손에 무기 스프라이트를 따로 달고, 이 역시도 스프라이트
## 애니메이션으로만."* 그래서 **무기가 얹힌 상태가 전투 애니메이션의 바탕**이다.
##
## **무기는 손 노드의 자식이다.** 손의 트랜스폼을 그대로 물려받으므로
##
## * `sample()` 은 무기의 존재를 **모른다.** 파츠는 여섯 그대로다
## * 손의 피벗이 중심이라(§25.2) **무기가 손을 축으로 돈다**
## * 손목 각도 = 손의 회전이다. 관절을 새로 만들 필요가 없다
##
## ## 부피가 곧 무게이고, 무게가 동작을 정한다
##
## 전투 레인이 실측했다 — **아이템 부피가 한 방의 무게다.** 4 칸은 4 타로 적을 띄우고
## 1 칸은 열 몇 타가 필요하다. **그런데 화면에서 둘이 같은 속도로 같은 궤적을 그리면
## 화면이 전투 규칙을 부정한다.**
##
## 그래서 **칸 수 하나만 넣으면 나머지가 전부 계산으로 나온다.** 넷을 손으로 따로
## 만들지 않는다 (`docs/design/25-character-animation.md` §25.16).

## 칸 수의 범위. [`28-combat.md`](../../../docs/design/28-combat.md) 의 아이템 부피다.
const MIN_CELLS := 1
const MAX_CELLS := 4

## 1 칸짜리의 길이. 캐릭터 키(141)의 37 % 다.
const BASE_LENGTH := 52.0

## 길이가 칸 수를 따라 자라는 지수. **1 보다 훨씬 작다** — 4 칸이 4 배 길지는 않다.
## 부피가 늘면 길이보다 **두께와 밀도**로 더 간다.
const LENGTH_EXPONENT := 0.30

## 무기를 든 손. 그리는 순서의 맨 마지막이라 무엇에도 안 가려진다.
const HOLDER := CharPart.Id.HAND_NEAR

## 손의 중심에서 자루를 잡은 자리까지. 손 반크기의 비율이다.
const GRIP := Vector2(0.15, -0.10)

## 자루 쪽에서 잡은 지점이 전체의 몇 할인가. 이 앞쪽이 자루, 뒤쪽이 날이다.
const GRIP_ALONG := 0.18

## 날 두께의 기준. 무거울수록 두꺼워진다 — **길이보다 두께가 무게를 말한다.**
const BASE_HALF_WIDTH := 3.4

## 쉬는 자세에서 무기가 손에 대해 기울어 있는 각도의 **희망값**.
##
## 실제 각도는 `rest_angle()` 이 정한다 — 긴 무기는 이 각도로 내리면 바닥에 박힌다.
const REST_ANGLE_WISH := -0.55

## 검끝이 바닥에서 최소한 이만큼은 떠 있어야 한다. 자세를 기하로 푸는 기준선이다.
const TIP_CLEARANCE := 4.0

## **히트스톱.** 닿는 순간 멈춰 있는 시간. **무거운 것은 멈춤이 길다.**
##
## 25 fps 로 1 칸 약 1 프레임, 4 칸 약 4.5 프레임이다. 처음에 0.02…0.125 로 두었더니
## 1 칸이 반 프레임도 안 되어 **아무 일도 안 일어났다.**
const HITSTOP_BASE := 0.045
const HITSTOP_PER_CELL := 0.045

## 칸 수. 1 … 4.
var cells: int


func _init(p_cells := 1) -> void:
	cells = clampi(p_cells, MIN_CELLS, MAX_CELLS)


## 자루 끝에서 날 끝까지.
func length() -> float:
	return BASE_LENGTH * pow(float(cells), LENGTH_EXPONENT)


func blade_half_width() -> float:
	return BASE_HALF_WIDTH * pow(float(cells), 0.42)


## 1 칸짜리에 대한 **관성 모멘트**의 비. `I ∝ 질량 × 길이²` 이고 질량은 칸 수다.
##
## **이 값 하나가 동작 전부를 정한다.** 예비 · 타격 · 회복이 다 여기서 나온다.
func inertia_ratio() -> float:
	var reach := length() / BASE_LENGTH
	return float(cells) * reach * reach


## 휘두르는 데 걸리는 시간의 배수.
##
## 같은 힘으로 돌리면 각가속도가 `1/I` 이므로 같은 각을 지나는 시간이 `sqrt(I)` 에 비례한다.
## **1 칸과 4 칸이 3 배 차이 난다** — 전투 레인의 「4 타 대 열 몇 타」와 방향이 맞는다.
func time_scale() -> float:
	return sqrt(inertia_ratio())


## 히트스톱. 무거울수록 길다.
##
## **전투가 이 값으로 때린 쪽과 맞은 쪽을 같이 멈춰야 한다** — 휘두르는 쪽 혼자
## 멈추는 것은 절반이고, 타격감은 둘이 동시에 설 때 난다 (§25.19.2).
func hitstop_seconds() -> float:
	return HITSTOP_BASE + HITSTOP_PER_CELL * float(cells - MIN_CELLS)


## 몸이 무기에 끌려가는 정도 (`0` … `1`). 무거우면 상체가 따라간다.
func drag() -> float:
	return float(cells - MIN_CELLS) / float(MAX_CELLS - MIN_CELLS)


## 자루를 잡은 자리 (손의 지역 공간, `+y` 위).
func grip_offset(rig: CharRig) -> Vector2:
	var half := rig.half_sizes[HOLDER]
	return Vector2(GRIP.x * half.x, GRIP.y * half.y)


func tip_offset() -> Vector2:
	return Vector2(length() * (1.0 - GRIP_ALONG), 0.0)


func butt_offset() -> Vector2:
	return Vector2(-length() * GRIP_ALONG, 0.0)


## 쉬는 자세에서 무기가 실제로 기우는 각도. **길이가 자세를 정한다.**
##
## 희망값(`−0.55`)으로 내리면 긴 무기는 바닥에 박힌다. 그래서 기하로 푼 안전한 각도와
## 견주어 **덜 가파른 쪽**을 쓴다. 손으로 네 번 맞추지 않는다.
func rest_angle(rig: CharRig) -> float:
	return maxf(REST_ANGLE_WISH, safe_angle(rig.rest_positions[HOLDER].y))


## 손이 `hand_y` 에 있을 때 검끝이 바닥에 안 닿는 **가장 가파른** 각도 (음수).
##
## `sin(각) = (손 높이 − 여유) / 길이` 를 뒤집은 것뿐이다. 손이 낮거나 무기가 길면
## 각이 얕아진다 — **그것이 「긴 무기는 아래로 못 내린다」의 정체다.**
func safe_angle(hand_y: float) -> float:
	var reach := length() * (1.0 - GRIP_ALONG)
	if reach <= 0.0:
		return 0.0
	return -asin(clampf((hand_y - TIP_CLEARANCE) / reach, 0.0, 1.0))


## 날 끝이 **캐릭터 공간**에서 어디에 있는가 (`+y` 위).
##
## 무기가 손의 자식이라 손의 트랜스폼이 그대로 곱해진다. 그 사슬을 여기 한 곳에만
## 적어 두어야 검증과 화면이 같은 것을 본다 — **둘이 갈리면 조용히 틀린다**(§25.13.1).
func tip_position(pose: CharPose, rig: CharRig) -> Vector2:
	var local := grip_offset(rig) + tip_offset().rotated(rest_angle(rig))
	return pose.core_transform(HOLDER) * local
