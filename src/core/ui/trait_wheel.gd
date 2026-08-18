class_name TraitWheel
extends RefCounted
## 성향 6축을 **육각형 하나**로. 노드도 그리기도 모르는 순수 계산이다.
##
## docs/design/20-ui-kit.md §20.25.3.
##
## ## 왜 막대 여섯이 아닌가
##
## 막대 여섯 줄은 §20.1 이 받은 평가 *"이건 무슨 수학 같음"* 그 자체다.
## 축이 여섯이라 육각형이 자연스럽고, 여섯이 **서로 비교되는 값**이라 한 면에 얹힌다.
## **딱지가 이름이면 육각형은 얼굴이다.**
##
## ## 규칙 셋 — 이게 이 클래스의 전부다
##
## 1. **반지름은 `|축값|` 이다.** 부호는 반지름이 아니라 **꼭짓점 이름**이 말한다
##    (「무모」인가 「신중」인가). 부호를 반지름에 섞으면 축 하나에 두 방향이 필요해지고
##    여섯 축이 열두 방향이 된다 — 그 순간 육각형이 아니다
## 2. **극 경계(`TraitDistribution.POLE_MIN`)를 점선 육각형으로 안에 하나 더 긋는다.**
##    그 선 밖으로 나간 꼭짓점이 곧 **딱지에 이름이 적히는 축**이다 (§24.17.5)
## 3. **면적이 곧 「이 사람이 얼마나 뚜렷한가」다.** 무색한 사람은 작은 육각형,
##    여섯 다 극인 1.8%(§24.16.6)는 꽉 찬 육각형 — **분포가 모양이 된다**

## 첫 축이 놓이는 각도. **똑바로 위**다 — 육각형이 기울어 있으면 「도형」이 아니라
## 「무늬」로 읽힌다.
const START_ANGLE := -PI * 0.5

## 값이 0 일 때도 남기는 최소 반지름 비율. 완전히 0 이면 꼭짓점 여섯이 한 점에 모여
## **면이 사라지고 「고장」으로 읽힌다** (§24.17.4 의 빈칸 규율과 같다).
const FLOOR_RATIO := 0.06


## 축 하나가 놓이는 각도.
static func angle_of(axis: int) -> float:
	return START_ANGLE + TAU * float(axis) / float(NpcAxis.count())


## 축 하나의 반지름 비율 0..1. **절댓값이다** (규칙 1).
static func ratio_of(value: int) -> float:
	var raw := float(absi(value)) / float(NpcAxis.MAX_VALUE)
	return maxf(clampf(raw, 0.0, 1.0), FLOOR_RATIO)


## 성향 배열이 그리는 육각형의 꼭짓점들.
static func points(traits: PackedInt32Array, center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for axis in NpcAxis.count():
		var value: int = traits[axis] if axis < traits.size() else 0
		out.append(center + Vector2.from_angle(angle_of(axis)) * radius * ratio_of(value))
	return out


## 비율이 같은 정육각형. 바깥 틀과 극 경계선이 이걸 쓴다.
static func ring(center: Vector2, radius: float, ratio: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for axis in NpcAxis.count():
		out.append(center + Vector2.from_angle(angle_of(axis)) * radius * ratio)
	return out


## 극 경계가 놓이는 비율. **점선 육각형이 여기 선다.**
static func pole_ratio() -> float:
	return float(TraitDistribution.POLE_MIN) / float(NpcAxis.MAX_VALUE)


## 꼭짓점에 적히는 이름. **부호가 여기서 말해진다** (규칙 1).
static func vertex_label(axis: int, value: int) -> String:
	return NpcAxis.pole_label(axis as NpcAxis.Kind, value)


## 이름을 놓을 자리. 꼭짓점보다 조금 밖이다.
static func label_point(axis: int, center: Vector2, radius: float, out_by: float) -> Vector2:
	return center + Vector2.from_angle(angle_of(axis)) * (radius + out_by)


## 육각형이 덮는 넓이의 비율 0..1. **「얼마나 뚜렷한가」의 수치다** (규칙 3).
##
## 정육각형 넓이 대비다 — 이웃한 두 꼭짓점이 만드는 삼각형 여섯의 합이라
## 곱의 합으로 떨어진다.
static func fullness(traits: PackedInt32Array) -> float:
	var sum := 0.0
	var axes := NpcAxis.count()
	for axis in axes:
		var here: int = traits[axis] if axis < traits.size() else 0
		var next: int = traits[(axis + 1) % axes] if (axis + 1) % axes < traits.size() else 0
		sum += ratio_of(here) * ratio_of(next)
	return clampf(sum / float(axes), 0.0, 1.0)
