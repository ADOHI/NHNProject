class_name DisciplineMark
extends RefCounted
## 계열을 **도형 하나**로. 노드도 그리기도 모르는 순수 계산이다.
##
## docs/design/20-ui-kit.md §20.25.7.
##
## ## 왜 계열인가 — 실측이 정했다
##
## 인물관계 레인이 조우 스쿼드 여섯을 무엇으로 가를 수 있나 쟀다.
##
## | 값 | 여섯을 가르나 |
## | --- | --- |
## | **소속** | **전혀 안 갈린다** — 한 소속에서 뽑으므로 여섯이 늘 같은 번호다 |
## | **계열** | **가장 잘 갈린다** — 다섯 중 넷이 나온다 |
## | 유명세 | 가르는 게 아니라 **한 명을 도드라지게** 한다 |
## | 나이 | 16~31 로 좁게 몰린다 |
##
## **얼굴이 3000명분 안 나온다**(파이프라인이 길다). 그래서 여섯을 가르는 일이
## 곧 **계열을 그리는 일**이 된다 — 「도형과 선과 면으로만」이라는 제약이 여기서 맞는다.
##
## ## 왜 여기(`src/core/ui/`)에 있나
##
## **인물 상세와 조우 스쿼드가 같은 표를 써야 한다.** 두 화면이 계열을 다르게 그리면
## 스쿼드에서 고른 사람이 상세에서 다른 사람으로 보인다. 표는 하나다.

## 계열마다 도형의 변 수. **셋에서 일곱까지 전부 다르다** — 변 수가 다르면
## 색을 못 봐도(작게 그려도 · 겹쳐도) 갈린다.
const _SIDES := [3, 4, 5, 6, 7]

## 계열마다 도형이 도는 각도. 같은 변 수가 겹칠 때를 대비한 것이 아니라
## **정삼각형이 위를 보게** 맞추는 값이다.
const _TURNS := [-PI * 0.5, PI * 0.25, -PI * 0.5, 0.0, -PI * 0.5]

## 계열마다 면의 색. 어두운 바탕 위에서 **명도가 서로 다르게** 골랐다 —
## 색맹이어도 밝기로 갈린다. 다섯의 명도가 0.46 부터 0.84 까지 고르게 벌어져 있고
## `test_sheet_shapes.gd` 가 그 간격을 지킨다.
const _FILLS := [
	Color(0.82, 0.36, 0.32),  ## 전투 — 붉고 가장 어둡다
	Color(0.52, 0.80, 0.60),  ## 정찰 — 풀빛
	Color(0.56, 0.62, 0.94),  ## 기공 — 푸르다
	Color(0.94, 0.84, 0.50),  ## 교섭 — 노랗고 가장 밝다
	Color(0.66, 0.50, 0.82),  ## 감식 — 보랏빛
]


static func sides(kind: MemberDiscipline.Kind) -> int:
	return _SIDES[int(kind)]


static func fill(kind: MemberDiscipline.Kind) -> Color:
	return _FILLS[int(kind)]


## 계열 도형의 꼭짓점들. 반지름은 바깥 원이다.
static func points(
	kind: MemberDiscipline.Kind, center: Vector2, radius: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := sides(kind)
	var turn: float = _TURNS[int(kind)]
	for i in count:
		out.append(center + Vector2.from_angle(turn + TAU * float(i) / float(count)) * radius)
	return out


## 유명세가 만드는 **도드라짐** 0..1.
##
## 실측 — 유명세는 여섯을 **가르지 않는다.** 대부분 0 이고 한둘만 튄다.
## 그러니 **모두에게 조금씩 주면 안 된다** — 무명 다섯에 옅은 테를 두르면
## 「한 명이 유명하다」가 아니라 「여섯이 다 좀 유명하다」가 된다.
static func standout(fame: int, ceiling: int) -> float:
	if ceiling <= 0 or fame <= 0:
		return 0.0
	# 제곱해서 아래를 눌러 둔다. 유명세가 지프 분포라(§24.16.6) 선형으로 두면
	# 인구 대다수가 옅은 테를 얻는다.
	var ratio := clampf(float(fame) / float(ceiling), 0.0, 1.0)
	return ratio * ratio
