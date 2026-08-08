class_name CharWeapon
extends RefCounted
## 손에 따로 붙는 무기. **파츠 일곱 번째가 아니다.**
##
## [`28-combat.md`](../../../docs/design/28-combat.md) §25.7 이 확정했다 —
## *"레이맨 캐릭터의 손에 무기 스프라이트를 따로 달고, 이 역시도 스프라이트
## 애니메이션으로만."* 그래서 **무기가 얹힌 상태가 전투 애니메이션의 바탕**이다.
## 공격을 만들고 나서 무기를 붙이는 것이 아니라 그 반대다.
##
## **무기는 손 노드의 자식이다.** 손의 트랜스폼을 그대로 물려받으므로
##
## * `sample()` 은 무기의 존재를 **모른다.** 파츠는 여섯 그대로다
## * 손의 피벗이 중심이라(§25.2) **무기가 손을 축으로 돈다.** 휘두르기가 여기서 나온다
## * 손목 각도 = 손의 회전이다. 관절을 새로 만들 필요가 없다
##
## **앞손에 붙인다.** 그리는 순서의 맨 마지막이라 몸에 안 가리고, 가까운 쪽이라
## 무기가 작아 보이지 않는다 (`docs/design/25-character-animation.md` §25.9.1).
##
## 그림은 자리표시자다 — 막대 하나. 나중에 실제 무기 스프라이트로 갈아 끼운다.

## 무기를 든 손. 그리는 순서의 맨 마지막이라 무엇에도 안 가려진다.
const HOLDER := CharPart.Id.HAND_NEAR

## 손의 중심에서 자루를 잡은 자리까지. 손 반크기의 비율이다.
##
## 벙어리장갑의 **한가운데**에서 조금 앞으로 나온 자리다. 정확히 중심에 두면
## 무기가 손을 뚫고 나온 것으로 보이고, 너무 앞이면 손에서 떨어져 뜬다.
const GRIP := Vector2(0.15, -0.10)

## 자루 끝에서 날 끝까지. 캐릭터 키(141)의 약 45 % — 더 길면 SD 비례에서 흉기가 된다.
const LENGTH := 64.0

## 자루 쪽에서 잡은 지점이 전체의 몇 할인가. 이 앞쪽이 자루, 뒤쪽이 날이다.
const GRIP_ALONG := 0.18

const BLADE_HALF_WIDTH := 4.2

## 쉬는 자세에서 무기가 손에 대해 기울어 있는 각도.
##
## **손과 나란히 두면 안 된다.** 가만히 서 있을 때 검은 비스듬히 아래로 내려가 있고,
## 그 각도가 「들고 있다」를 만든다. 0 이면 손에서 수평으로 뻗어 나가 부자연스럽다.
const REST_ANGLE := -0.55


## 자루를 잡은 자리 (손의 지역 공간, `+y` 위).
static func grip_offset(rig: CharRig) -> Vector2:
	var half := rig.half_sizes[HOLDER]
	return Vector2(GRIP.x * half.x, GRIP.y * half.y)


## 날 끝이 자루에서 얼마나 떨어져 있는가 (무기 지역 공간, 회전 전).
static func tip_offset() -> Vector2:
	return Vector2(LENGTH * (1.0 - GRIP_ALONG), 0.0)


## 자루 끝(손잡이 뒤쪽 끝)이 잡은 자리에서 얼마나 떨어져 있는가.
static func butt_offset() -> Vector2:
	return Vector2(-LENGTH * GRIP_ALONG, 0.0)


## 날 끝이 **캐릭터 공간**에서 어디에 있는가 (`+y` 위).
##
## 무기가 손의 자식이라 손의 트랜스폼이 그대로 곱해진다. 그 사슬을 여기 한 곳에만
## 적어 두어야 검증과 화면이 같은 것을 본다 — **둘이 갈리면 조용히 틀린다**(§25.10.35).
##
## **검끝이 땅을 뚫는지 재는 데 쓴다.** 검은 캐릭터 밖으로 나가는 유일한 것이라
## 파츠의 접지 검사가 통째로 못 잡는다.
static func tip_position(pose: CharPose, rig: CharRig) -> Vector2:
	var local := grip_offset(rig) + tip_offset().rotated(REST_ANGLE)
	return pose.core_transform(HOLDER) * local
