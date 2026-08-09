class_name HideoutPalette
extends RefCounted
## 아지트 화면이 쓰는 색 전부. **도형만 그리는 임시 화면의 색이다.**
##
## src/ui/style/(UiTokens) 도 src/ui/kit/(KitTokens) 도 끌어 쓰지 않는다.
## 둘 다 아직 방향이 정해지지 않은 실험이고, 이름이 갈리면 이 화면이 같이 깨진다.
## 그때 고쳐야 할 것은 조형이 아니라 배선인데 배선까지 멈춘다
## (docs/design/22-guild-base.md §22.8.7 이 같은 판단을 이미 내렸다).
##
## 조형이 정해지면 이 파일 하나를 갈아 끼운다.

const BACKDROP := Color(0.07, 0.08, 0.11)

## 바닥 마름모.
const FLOOR_FILL := Color(0.15, 0.17, 0.21)
const FLOOR_FILL_ALT := Color(0.13, 0.15, 0.19)
const FLOOR_LINE := Color(0.27, 0.31, 0.39)
const BOARD_EDGE := Color(0.40, 0.44, 0.54)

## 마우스가 올라간 칸.
const HOVER_FILL := Color(0.35, 0.55, 0.75, 0.45)
const HOVER_LINE := Color(0.62, 0.82, 1.0)

## 놓을 수 없는 자리.
const BLOCKED_FILL := Color(0.70, 0.28, 0.30, 0.40)
const BLOCKED_LINE := Color(0.95, 0.45, 0.45)

## 건물 세 면. 지붕이 가장 밝고 왼쪽 벽이 가장 어둡다 — 빛이 오른쪽 위에서 온다고 본다.
const ROOF := Color(0.52, 0.56, 0.66)
const WALL_LEFT := Color(0.26, 0.28, 0.35)
const WALL_RIGHT := Color(0.34, 0.37, 0.45)
const BUILDING_EDGE := Color(0.72, 0.76, 0.86)

## 시설별 지붕 색조. Facility.Kind 순서다(공방 · 정보실 · 접선처).
##
## 그림이 오면 통째로 버린다. 지금은 **어느 건물이 어느 시설인지 눈으로 갈리는 것**만 한다.
const FACILITY_ROOFS: Array[Color] = [
	Color(0.72, 0.50, 0.34),
	Color(0.36, 0.56, 0.72),
	Color(0.50, 0.44, 0.68),
]

const TEXT := Color(0.88, 0.91, 0.96)
const TEXT_DIM := Color(0.62, 0.66, 0.74)


## 이 건물의 지붕 색. 시설이 아니면 기본 지붕색이다.
static func roof_of(facility_kind: int) -> Color:
	if facility_kind < 0 or facility_kind >= FACILITY_ROOFS.size():
		return ROOF
	return FACILITY_ROOFS[facility_kind]
