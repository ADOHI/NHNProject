class_name HideoutBuilding
extends RefCounted
## 아지트에 놓인 건물 한 채. 발자국과 놓인 자리를 든다.
##
## ## 시설을 새로 정의하지 않는다
##
## 건물의 종류는 Facility.Kind 를 그대로 쓴다. 아지트 화면이 시설 종류를 따로 들면
## 같은 이름이 두 곳에 살게 되고, 그때부터 둘은 조용히 갈라진다
## (LANE-RULES §2 — "같은 이름을 단 두 값이 다른 자로 잰 것일 수 있다").
##
## 방향은 한쪽뿐이다: **hideout 은 guild 를 안다. guild 는 hideout 을 모른다.**
## §22.5 가 gate 와 guild 사이에 세운 것과 같은 규칙이다.
##
## ## 발자국은 사각형뿐이다
##
## L 자나 계단 모양을 허용하면 겹침 검사가 정수 비교로 안 끝나고,
## 마름모 한 덩어리로 그릴 수도 없다(IsoProjection.rect_polygon).
## 사각형이 아닌 건물이 필요해지면 그때 두 곳을 같이 고친다.

## 시설이 아닌 건물(장식 · 통로 등)의 종류 값. Facility.Kind 밖의 값을 쓴다.
##
## Facility.Kind 에 NONE 을 넣지 않는 이유는 FacilityAssignment.facility_of 와 같다 —
## "시설이 아님" 은 시설의 한 종류가 아니고, enum 에 넣으면 시설을 훑는 모든 자리에서
## 그것을 걸러야 한다.
const NOT_A_FACILITY := -1

## 시설별 발자국. **잠정이다** — §30.9 ★3 이 건물 종류를 열어 두었다.
##
## 여기 한 곳에 두는 이유는, 처음에 화면의 시작 배치표에 크기를 적어 두었더니
## 「짓기」가 생기는 순간 같은 값이 두 곳에 살게 되었기 때문이다.
## 크기가 갈리면 미리보기와 실제 건물이 다른 크기가 된다.
##
## 셋이 다 다른 모양인 것은 일부러다 — 정사각형만 있으면 회전도 방향도 눈에 안 들어오고,
## 겹침 검사가 정사각형에서만 맞는 것을 못 잡는다.
const _FOOTPRINTS: Array[Vector2i] = [
	Vector2i(2, 2),  ## 공방
	Vector2i(2, 3),  ## 정보실
	Vector2i(3, 2),  ## 접선처
]

## 판 안에서 이 건물을 가리키는 이름. 격자의 점유표가 이 값을 든다.
var id: String

## Facility.Kind 또는 NOT_A_FACILITY.
var facility_kind: int

## 몇 칸을 차지하는가. 최소 1x1.
var footprint: Vector2i

## 발자국의 **왼쪽 위**(칸 좌표가 가장 작은) 모서리.
var origin: Vector2i


func _init(
	building_id: String,
	kind: int = NOT_A_FACILITY,
	size: Vector2i = Vector2i.ONE,
	at: Vector2i = Vector2i.ZERO
) -> void:
	id = building_id
	facility_kind = kind
	footprint = Vector2i(maxi(1, size.x), maxi(1, size.y))
	origin = at


static func footprint_for(facility_kind: int) -> Vector2i:
	if facility_kind < 0 or facility_kind >= _FOOTPRINTS.size():
		return Vector2i.ONE
	return _FOOTPRINTS[facility_kind]


func is_facility() -> bool:
	return facility_kind != NOT_A_FACILITY


## 화면에 그대로 나가는 이름. 화면이 문자열을 짓지 않는다 (conventions.md §3.1).
func label() -> String:
	if not is_facility():
		return "빈 건물"
	return Facility.label(facility_kind)


## 화면에 붙는 한 줄 설명. 시설이 아니면 비어 있다.
func note() -> String:
	if not is_facility():
		return ""
	return Facility.note(facility_kind)


## 이 건물이 덮는 칸 전부.
func cells() -> Array[Vector2i]:
	var covered: Array[Vector2i] = []
	for offset_y in footprint.y:
		for offset_x in footprint.x:
			covered.append(origin + Vector2i(offset_x, offset_y))
	return covered


func covers(cell: Vector2i) -> bool:
	var local := cell - origin
	return local.x >= 0 and local.y >= 0 and local.x < footprint.x and local.y < footprint.y


## 그리는 차례. 큰 값이 나중에 그려져 앞을 가린다 (IsoProjection.rect_depth).
func depth() -> int:
	return IsoProjection.rect_depth(origin, footprint)


## 사람이 이 건물로 들어갈 때 서는 칸. 발자국 바로 아래(화면 앞쪽)다.
##
## 발자국 안에 세우면 건물에 가려 보이지 않는다. ②(끌어 넣기)가 이 자리를 쓴다.
func entrance_cell() -> Vector2i:
	return origin + Vector2i(footprint.x - 1, footprint.y)
