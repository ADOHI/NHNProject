class_name CharRunClip
extends CharWalkClip
## run — **디딤 비율이 0.5 아래로 내려가면 그것이 달리기다.**
##
## `docs/design/25-character-animation.md` §25.14.
##
## walk 를 상속해 **걸음새 수치만 갈아 끼운다.** 궤도 규칙은 하나도 안 바꿨다 —
## 디딘 발은 여전히 등속이고 발끝은 여전히 땅에 붙는다. 걷기와 달리기의 차이는
## **문법이 아니라 값**이라는 것이 이 클립의 주장이다.
##
## | | walk | run |
## | --- | --- | --- |
## | 디딤 비율 | `0.60` — 두 발이 겹치는 **양발 지지** | `0.38` — 둘 다 뜨는 **체공** |
## | 한 걸음 | 1.20 s | 0.72 s |
## | 보폭 | 26 | 42 |
##
## **양발 지지와 체공은 같은 눈금의 양 끝이다.** 0.5 가 경계이고, 그 하나가
## 넘어가느냐 마느냐로 두 동작이 갈린다. 그래서 값 하나가 동작의 이름을 정한다.

const RUN_STRIDE := 0.72

## **0.5 미만.** 두 발이 동시에 떠 있는 구간이 생긴다 — 그것이 달리기의 정의다.
const RUN_STANCE := 0.38

const RUN_STEP_LENGTH := 42.0
const RUN_SWING_LIFT := 13.0
const RUN_TORSO_BOB := 5.4

## 달리면 몸이 앞으로 더 기운다. 넘어지려는 것을 발이 받아 내는 것이 달리기다.
const RUN_TORSO_LEAN := 0.16

const RUN_HAND_SWING := 13.0

## 달릴 때는 뒤꿈치부터 닿지 않는다 — 발 앞쪽으로 받는다. 그래서 뒤꿈치 각을 줄인다.
const RUN_HEEL_STRIKE := 0.10
const RUN_TOE_OFF := 0.40


func _init(p_rig: CharRig) -> void:
	super(p_rig)
	stride = RUN_STRIDE
	stance = RUN_STANCE
	step_length = RUN_STEP_LENGTH
	swing_lift = RUN_SWING_LIFT
	torso_bob = RUN_TORSO_BOB
	torso_lean = RUN_TORSO_LEAN
	hand_swing = RUN_HAND_SWING
	heel_strike = RUN_HEEL_STRIKE
	toe_off = RUN_TOE_OFF


func clip_name() -> String:
	return "run (사이드 사선)"
