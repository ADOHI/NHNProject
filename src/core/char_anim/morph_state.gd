class_name MorphState
extends RefCounted
## 어느 한 순간의 **앵커별 변위와 부풀림.** 순수 자료다.
##
## `docs/design/31-soft-body.md` §31.3.
##
## **셰이더가 없어도 단위 테스트가 된다.** 그것이 이 클래스를 따로 둔 이유다 —
## §25.13.1 「그림과 자가 다른 것을 본다」가 이 저장소에서 네 번 났고,
## 그 다섯 번째가 날 자리가 여기다. 자가 보는 것과 화면이 보는 것이 **같은 값**이어야 한다.
##
## ## 좌표계
##
## `shifts` 는 **캐릭터 공간**(`+y` 위)의 변위다. 물리가 낸 답이 그 공간에 있고,
## 진폭 상한도 그 공간에서 재야 뜻이 맞기 때문이다 (§25.29).
##
## 그림에 넣으려면 파츠 지역으로 돌려야 한다 — `local_shift()` 가 그 일만 한다.

## **충격 한 대가 살을 미는 거리**(리그 유닛, 세기 `1` 일 때).
##
## `CharReaction.PART_PUSH` (9 px) 보다 **훨씬 작다.** 저쪽은 파츠가 통째로 밀리는 것이고
## 이쪽은 살이 파츠 안에서 어긋나는 것이다. 같은 크기면 살이 몸에서 떨어져 나간다.
const JOLT := 2.4

## 앵커별 변위 (캐릭터 공간, 리그 유닛). **상한이 걸린 뒤의 값이다.**
var shifts: PackedVector2Array = PackedVector2Array()

## 앵커별 부풀림 (`0` … `1`). 셰이더가 UV 를 중심에서 넓혀 부푼 것처럼 보이게 한다.
var bulges: PackedFloat32Array = PackedFloat32Array()

## **상한이 걸리기 전의** 변위 크기. 검사가 이것을 본다.
##
## 상한이 걸린 값으로 「상한 안에 있나」를 물으면 **늘 통과한다** — 자기가 쓴 값으로
## 자기를 검사하는 그 모양이다 (§25.13.2). 그래서 날것을 따로 남긴다.
var raw_lengths: PackedFloat32Array = PackedFloat32Array()


## 아무 데도 안 휜 상태. **정확히 0 이다** — 근사가 아니다.
static func rest(count: int) -> MorphState:
	var state := MorphState.new()
	state.shifts.resize(count)
	state.bulges.resize(count)
	state.raw_lengths.resize(count)
	return state


## **그 시각의 변위를 푼다.**
##
## 두 층이 더해진다.
##
## | 층 | 무엇 | 언제 |
## | --- | --- | --- |
## | 구동 응답 | 정상상태 — 같은 주파수, 진폭과 위상만 이동 | 루프인 클립 (idle · walk · run) |
## | 충격 응답 | `e^(-zw*t) sin(wd*t)` — 사건 이후 흐른 시간 | 맞았을 때 · 착지 (§25.27) |
##
## `drives` 는 `MorphRig.drives_for()` 가 셋업 때 뽑아 둔 것이다. **여기서 안 뽑는다** —
## 뽑으면 프레임마다 클립을 64 번 표본하게 된다.
##
## `wall` 은 **실제 시각**이다. 히트스톱 동안 동작 시각(`t`)은 멈춰 있는데 충격은 계속
## 잦아들어야 한다 — `CharPartsView` 가 이미 같은 이유로 두 시각을 갈라 들고 있다.
static func solve(
	morph: MorphRig, drives: Array[SoftDrive], t: float, reaction: CharReaction = null,
	wall := -1.0
) -> MorphState:
	var count := 0 if morph == null else morph.anchors.size()
	var state := MorphState.rest(count)
	if morph == null or morph.is_off():
		return state
	var shock_at := t if wall < 0.0 else wall
	for i in count:
		var anchor := morph.anchors[i]
		var body := anchor.body()
		var raw := Vector2.ZERO
		if i < drives.size() and drives[i] != null:
			raw += drives[i].response(body, t)
		raw += _shock(body, reaction, shock_at)
		raw *= anchor.gain * morph.strength
		state.raw_lengths[i] = raw.length()
		# **방향은 안 건드리고 거리만 줄인다** — §25.29 와 같은 손질이다.
		state.shifts[i] = raw.limit_length(anchor.limit)
		var reach := 0.0 if anchor.limit <= 0.0 else state.shifts[i].length() / anchor.limit
		state.bulges[i] = anchor.bulge * minf(reach, 1.0)
	return state


## 쌓인 충격이 살을 얼마나 밀고 있나. **몸이 간 반대쪽으로 어긋난다.**
##
## 목록을 여기서 따로 안 든다 — `CharReaction` 이 이미 들고 있고, 두 벌이면
## 하나가 잦아든 것을 버릴 때 다른 하나가 안 버려서 조용히 갈린다 (§25.27.3).
static func _shock(body: SoftBody, reaction: CharReaction, at: float) -> Vector2:
	if reaction == null:
		return Vector2.ZERO
	var along := 0.0
	for i in reaction.impact_count():
		var impact := reaction.impact_at(i)
		var age := at - impact.x
		if age <= 0.0:
			continue
		# 몸이 `z` 쪽으로 갔으므로 살은 그 반대로 남는다.
		along += -impact.z * impact.y * body.impulse(age)
	return Vector2(JOLT * along, 0.0)


## 캐릭터 공간의 변위를 **파츠 지역**으로 돌린다. 그림에 넣는 것은 이 값이다.
##
## 파츠가 돌고 눌린 만큼을 되돌려야 한다 — 안 그러면 몸이 기울었을 때
## 살이 엉뚱한 쪽으로 어긋난다.
func local_shift(index: int, part: CharPart.Id, pose: CharPose) -> Vector2:
	if index < 0 or index >= shifts.size():
		return Vector2.ZERO
	var shift := shifts[index]
	if shift.is_zero_approx():
		return Vector2.ZERO
	return pose.core_transform(part).affine_inverse().basis_xform(shift)


## 아무 앵커도 안 움직였나.
func is_rest() -> bool:
	for shift in shifts:
		if not shift.is_zero_approx():
			return false
	return true
