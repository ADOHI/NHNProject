class_name MorphAnchor
extends RefCounted
## 파츠 그림에서 **휘는 자리 하나.** 순수 자료다 — 셰이더도 노드도 모른다.
##
## `docs/design/31-soft-body.md` §31.2.
##
## 가슴은 몸통에, 머리카락은 머리에 붙는다. **둘이 같은 장치를 쓴다** —
## 파츠를 안 늘리고(§25.32) 트랜스폼도 안 건드린다. 휘는 것은 **그림뿐**이다.
##
## ## 좌표계
##
## 중심 · 반경 · 마스크가 전부 **파츠 지역 좌표**(`+y` 위, 리그 유닛)다.
## `CharRig.local_centers` 와 같은 공간이라 사람이 검산할 수 있고,
## **그림 벌이 바뀌어도 안 바뀐다** — 리그가 크기를 목표 상자에 맞추기 때문이다 (§25.41.8).
##
## UV 로 옮기는 것은 그리는 쪽(`CharPartSprite`)이 한다. 그림이 왼쪽을 보므로
## 그 자리에서 좌우가 한 번 뒤집힌다 (§25.41.9).
##
## ## ★ 얼굴을 뭉개지 마라 — **마스크가 자료여야 하는 이유**
##
## 머리 앵커의 감쇠 반경이 얼굴까지 닿으면 **이목구비가 녹는다.** 반경만으로는 못 막는다 —
## 머리카락은 정수리와 뒤통수에 있고 얼굴은 그 아래 앞쪽이라 **거리로는 안 갈리고
## 방향으로 갈린다.**
##
## 그래서 **반평면 게이트**를 자료로 둔다: `dot(p, mask_normal) >= mask_offset` 인 쪽만 휜다.
## 타원 감쇠와 **곱해지므로** 둘 중 하나만 걸려도 0 이다.
##
## > 자료라서 **검사가 되고**(테스트가 얼굴 자리의 가중치가 0 임을 단언한다),
## > **그림이 바뀌어도 코드가 안 바뀐다.** §25.13.1 의 다섯 번째를 여기서 막는다.

## 사람이 읽는 이름. 로그와 테스트 실패 문구에만 쓴다.
var anchor_name := ""

## 어느 파츠의 그림에 붙나.
var part := CharPart.Id.TORSO

## 파츠 지역 좌표에서의 중심 (`+y` 위).
var centre := Vector2.ZERO

## 타원 감쇠의 반경. 이 밖은 0 이다.
var radius := Vector2(10.0, 10.0)

## 반평면 게이트의 법선. **단위 벡터로 둔다.** `Vector2.ZERO` 면 게이트가 없다.
var mask_normal := Vector2.ZERO

## 반평면의 자리. `dot(p, mask_normal) >= mask_offset` 인 쪽이 휜다.
var mask_offset := 0.0

## 반평면 경계가 무뎌지는 폭(리그 유닛). 0 이면 칼로 자른 것처럼 갈린다.
var mask_feather := 4.0

## 물리가 낸 변위에 곱하는 값. 앵커마다 다르게 반응하게 한다.
var gain := 1.0

## 이 앵커의 고유 진동수(Hz). 머리카락이 가슴보다 낮다 — 더 오래 흔들린다.
var hz := 4.0

## 이 앵커의 감쇠비.
var damping := 0.35

## 변위가 클 때 얼마나 부푸나. `0` 이면 미끄러지기만 하고 안 부푼다.
var bulge := 0.35

## 변위 상한(리그 유닛). **파츠 반크기의 12 %** 로 잡는다 (§25.29).
var limit := 2.0


func _init(p_name := "", p_part := CharPart.Id.TORSO) -> void:
	anchor_name = p_name
	part = p_part


## 이 앵커의 진동자. **매번 새로 만든다** — 값 두 개짜리라 들고 있을 이유가 없다.
func body() -> SoftBody:
	return SoftBody.new(hz, damping)


## 파츠 지역 좌표의 한 점이 **얼마나 휘나** (`0` … `1`).
##
## 타원 감쇠와 반평면 게이트의 **곱**이다. 둘 중 하나만 0 이어도 0 이다.
func weight_at(point: Vector2) -> float:
	return falloff_at(point) * mask_at(point)


## 타원 감쇠만. 중심에서 `1`, 반경 밖에서 `0`.
func falloff_at(point: Vector2) -> float:
	var rx := maxf(radius.x, 0.001)
	var ry := maxf(radius.y, 0.001)
	var offset := point - centre
	var distance := Vector2(offset.x / rx, offset.y / ry).length()
	return 1.0 - smoothstep(0.0, 1.0, distance)


## 반평면 게이트만. 게이트가 없으면 늘 `1`.
func mask_at(point: Vector2) -> float:
	if mask_normal.is_zero_approx():
		return 1.0
	var along := mask_normal.normalized().dot(point)
	var feather := maxf(mask_feather, 0.001)
	return smoothstep(mask_offset - feather, mask_offset + feather, along)


func copy() -> MorphAnchor:
	var out := MorphAnchor.new(anchor_name, part)
	out.centre = centre
	out.radius = radius
	out.mask_normal = mask_normal
	out.mask_offset = mask_offset
	out.mask_feather = mask_feather
	out.gain = gain
	out.hz = hz
	out.damping = damping
	out.bulge = bulge
	out.limit = limit
	return out
