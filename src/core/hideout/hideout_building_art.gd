class_name HideoutBuildingArt
extends RefCounted
## **건물 그림 한 장의 규격.** 캔버스 크기 · 기준점 · 높이 상한이 여기서만 정해진다.
##
## 그림이 아직 없다. 그런데 규격이 없으면 그림을 뽑고 나서 안 맞는 것을 알게 되고,
## 그때는 통째로 다시 뽑는다. **그래서 그림보다 규격이 먼저다.**
##
## 사람이 읽는 판은 `docs/design/30-hideout.md` §30.10 이고, 이 파일이 그 문서의 값을 든다.
## **둘이 갈리면 이 파일이 맞다** — 화면이 실제로 쓰는 것은 이쪽이다.
##
## ## 왜 코어에 두는가
##
## 발주서(사람이 읽는 것)와 배치 코드(기계가 쓰는 것)가 같은 숫자를 봐야 한다.
## 두 곳에 적으면 갈리고, 갈린 것은 **그림이 도착한 날**에야 드러난다.
##
## ## 기준점은 바닥 마름모의 **아래꼭짓점**이다
##
## 캐릭터 파츠 레인이 같은 것을 겪었다 — 피벗을 밑변으로 잡으니 크기가 접지에 안 샜다.
## 건물도 같다. 지붕을 높이거나 굴뚝을 얹어도 **땅에 닿는 자리가 안 움직여야** 한다.
## 가운데를 기준으로 잡으면 그림이 위로 자랄 때마다 접지가 따라 움직인다.
##
## 아래꼭짓점을 고른 두 번째 이유는 **그리는 차례와 같은 점**이기 때문이다 —
## `IsoProjection.rect_depth` 도 발자국의 앞 모서리로 순서를 정한다 (§30.2).

## 층 하나의 높이(칸).
##
## **1.5 다.** 칸 한 변을 2 m 로 보면 한 층(3 m)은 1.5 칸이다.
##
## 처음에는 1.0 으로 뒀다 — 격자에서 딱 떨어져서였지 사람 키에서 나온 값이 아니었다.
## 그러자 **1층 건물이 사람과 키가 비슷해 담으로 보였다**(§30.12.2).
## 배회에 사람을 세우고 나서야 드러난 것이다.
const STOREY_CELLS := 1.5

## **높이 상한(층).** 이보다 높은 건물은 그리지 않는다.
##
## 근거는 가림이다 — §30.10.3. 2:1 에서 1층은 뒤 **1 칸**, 2층은 **3 칸**을 가린다.
## 14 칸짜리 판(§30.9.1)에서 세 칸이면 21% 다.
##
## 3:1 이었을 때는 같은 층 높이에 2층이 **여섯 칸(43%)** 을 가렸다. 그것이 2:1 로 옮긴
## 결정적인 이유다 (§30.12.2).
const MAX_STOREYS := 2

## 그림 가장자리에 두는 여백(px). 외곽선과 글로우가 잘리지 않게 한다.
##
## 0 으로 두면 배경 제거(`birefnet-general`)가 가장자리를 한 픽셀씩 먹었을 때
## 외곽선이 끊겨 보인다. 잘라내는 쪽이 늘리는 쪽보다 싸다.
const MARGIN_PX := 8


## 이 발자국의 **바닥 마름모** 크기(px). 그림에서 땅에 닿는 부분이다.
##
## 가로 `half_width x (w+h)` · 세로 `half_height x (w+h)`.
## 타일 비가 2:1 이면 바닥 마름모도 **항상 2:1** 이다 (발자국과 무관).
static func ground_size(footprint: Vector2i) -> Vector2i:
	var span := _clamped(footprint)
	var reach := span.x + span.y
	return Vector2i(int(_half_width()) * reach, int(_half_height()) * reach)


## 그림 한 장의 캔버스 크기(px). 바닥 마름모 + 솟는 높이 + 여백.
static func canvas_size(footprint: Vector2i, storeys: int) -> Vector2i:
	var ground := ground_size(footprint)
	var lift := int(IsoProjection.height_to_px(_clamped_storeys(storeys) * STOREY_CELLS))
	return Vector2i(ground.x + MARGIN_PX * 2, ground.y + lift + MARGIN_PX * 2)


## 캔버스 안에서 **기준점이 놓이는 자리**(px, 왼쪽 위 기준).
##
## 바닥 마름모의 아래꼭짓점이다. 가로로는 `48 x w` 지점이고 **가운데가 아니다** —
## 발자국이 정사각형일 때만 가운데와 겹친다. 2x3 과 3x2 는 서로 다른 자리다.
static func pivot(footprint: Vector2i, storeys: int) -> Vector2i:
	var span := _clamped(footprint)
	var canvas := canvas_size(footprint, storeys)
	return Vector2i(MARGIN_PX + int(_half_width()) * span.x, canvas.y - MARGIN_PX)


## 캔버스 안에서 바닥 마름모의 네 점. 위 - 오른쪽 - 아래 - 왼쪽 순서다.
##
## 발주서에 깔아 줄 밑그림이 이것이다. **이 마름모 위에 건물을 세우면 맞는다.**
static func ground_polygon(footprint: Vector2i, storeys: int) -> PackedVector2Array:
	var span := _clamped(footprint)
	var anchor := pivot(footprint, storeys)
	var ground := ground_size(footprint)
	var south := Vector2(anchor)
	return PackedVector2Array(
		[
			south + Vector2(0.0, -ground.y),
			south + Vector2(_half_width() * span.y, -_half_height() * span.y),
			south,
			south + Vector2(-_half_width() * span.x, -_half_height() * span.x),
		]
	)


## 이 층수의 건물이 바로 뒤 몇 칸을 완전히 가리는가. **N 층 -> 2N 칸.**
static func hidden_cells_behind(storeys: int) -> int:
	var iso := IsoProjection.new()
	return iso.hidden_cells_behind(
		IsoProjection.height_to_px(_clamped_storeys(storeys) * STOREY_CELLS)
	)


## 마름모 반폭. **여기서만 IsoProjection 을 읽는다** — 픽셀 숫자를 이 파일에 박으면
## 비율을 바꿀 때 발주서만 혼자 낡는다.
static func _half_width() -> float:
	return IsoProjection.DEFAULT_TILE_WIDTH * 0.5


static func _half_height() -> float:
	return IsoProjection.DEFAULT_TILE_HEIGHT * 0.5


static func _clamped(footprint: Vector2i) -> Vector2i:
	return Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))


static func _clamped_storeys(storeys: int) -> int:
	return clampi(storeys, 1, MAX_STOREYS)
