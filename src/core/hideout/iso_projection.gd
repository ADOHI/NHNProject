class_name IsoProjection
extends RefCounted
## 칸 좌표와 화면 좌표 사이의 유일한 변환 지점. **시점은 여기서만 정해진다.**
##
## ## 원근을 데이터에 굽지 않는다
##
## 아지트의 규칙(건물 발자국 · 겹침 · 통행)은 전부 정수 칸(Vector2i)으로 계산하고,
## 마름모로 접는 것은 **그릴 때뿐**이다 (docs/design/30-hideout.md §30.2).
##
## LANE-RULES §5 가 맵 파이프라인에 대해 못 박은 것과 같은 형태다 —
## "정면 텍스처 + 셰이더가 시점을 만든다. 원근을 판에 굽지 마라."
##
## 그래서 "아이소메트릭인가 쿼터뷰인가" (§30.9 ★1)가 이 파일의 값 두 개로 좁혀진다.
## 위에서 내려다보는 판으로 되돌려도 HideoutGrid 는 한 줄도 바뀌지 않는다.
##
## ## 왜 노드가 아닌가
##
## 클릭한 칸과 그려진 칸이 한 칸 어긋나는 것이 아이소에서 가장 흔한 버그다.
## 노드에 두면 눈으로만 확인하게 되고, 어긋남은 조용히 회귀한다.
## 순수 클래스로 두면 왕복(칸 -> 화면 -> 칸)을 테스트가 대신 지킨다.

## 칸 하나의 화면 가로 폭(픽셀).
const DEFAULT_TILE_WIDTH := 96.0

## 칸 하나의 화면 세로 폭(픽셀). **가로의 1/3 — 3:1 쿼터뷰다.**
##
## ## 이 값은 그림에서 나왔다 (§30.9 ★1 — 확정)
##
## 세로/가로 = sin(카메라 내려보는 각) 이다. 3:1 은 **약 19.5도**다.
##
## 처음에는 2:1(30도, 흔한 아이소)로 세웠다가 **캐릭터 그림을 보고 고쳤다.**
## 인물 그림(pp1_*)에서 읽은 것 둘이다.
##
## - **접지 그림자가 아주 납작하다.** 발밑 그림자가 고인 웅덩이가 아니라 얇은 칼날이다.
##   30도로 내려다보면 그림자가 훨씬 둥글게 보여야 한다
## - **장화의 윗면이 거의 안 보인다.** 발등과 밑창을 거의 옆에서 본다.
##   카메라가 높으면 신발 윗면이 넓게 드러난다
##
## 셋(2:1 · 3:1 · 4:1)을 같은 인물 그림과 겹쳐 놓고 골랐다. 2:1 은 인물이
## **기울어진 상 위에 세운 판때기**로 읽히고, 4:1 은 칸이 뭉개져 깊이가 안 읽힌다.
##
## **바꿀 때는 이 값 하나만 바꾼다.** 그것이 이 파일이 존재하는 이유다 (§30.2).
const DEFAULT_TILE_HEIGHT := 32.0

## **칸 한 변만큼의 높이가 화면에서 차지하는 세로 픽셀.**
##
## 바닥은 눕혀서 보지만 높이는 눕지 않는다. 그래서 세로 환산이 따로 필요하고,
## 이 값이 없으면 「2층 건물」이 몇 픽셀인지 아무도 말할 수 없다.
##
## 유도: 내려보는 각 t 에서 sin(t) = 세로/가로 = 1/3 이므로 t = 19.47도.
## 칸 한 변의 월드 길이는 화면 반폭에서 `48 x sqrt(2) = 67.88`,
## 세로는 거기에 `cos(t) = 0.9428` 이 곱해져 **정확히 64.0** 이 된다.
##
## **딱 떨어지는 것은 우연이 아니라 3:1 을 골랐기 때문이다** (§30.2.1).
## 타일 비를 바꾸면 이 값도 같이 바뀐다 — 그래서 여기 같이 둔다.
const CELL_HEIGHT_PX := 64.0

## 마름모 가로 반폭.
var half_width: float

## 마름모 세로 반폭.
var half_height: float


func _init(
	tile_width: float = DEFAULT_TILE_WIDTH, tile_height: float = DEFAULT_TILE_HEIGHT
) -> void:
	half_width = maxf(1.0, tile_width) * 0.5
	half_height = maxf(1.0, tile_height) * 0.5


func tile_width() -> float:
	return half_width * 2.0


func tile_height() -> float:
	return half_height * 2.0


## 칸의 **중심**이 놓이는 화면 좌표.
##
## 모서리가 아니라 중심을 돌려주는 이유는, 칸 위에 무엇을 놓든(건물 · 사람 · 강조)
## 기준이 중심 하나면 되기 때문이다. 모서리를 기준으로 두면 놓는 쪽마다
## 반칸씩 더하는 코드가 흩어진다.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * half_width, (cell.x + cell.y) * half_height)


## 칸 사이의 지점도 그대로 접는다. 사람이 칸 가운데가 아닌 곳에 서 있을 때 쓴다(§30.3).
func plane_to_world(plane: Vector2) -> Vector2:
	return Vector2((plane.x - plane.y) * half_width, (plane.x + plane.y) * half_height)


## 화면 좌표가 어느 칸 위인가. cell_to_world 의 역이다.
##
## 기운 좌표계에서 각 축을 따로 반올림하면 그것이 곧 마름모 하나가 된다 —
## 마름모 기하를 직접 풀 필요가 없다.
func world_to_cell(world: Vector2) -> Vector2i:
	var plane := world_to_plane(world)
	return Vector2i(roundi(plane.x), roundi(plane.y))


## 반올림하지 않은 칸 좌표. 끌어 놓는 중의 미리보기처럼 칸 사이 값이 필요할 때 쓴다.
func world_to_plane(world: Vector2) -> Vector2:
	var u := world.x / half_width
	var v := world.y / half_height
	return Vector2((u + v) * 0.5, (v - u) * 0.5)


## 칸 하나를 덮는 마름모 네 점. 위 -> 오른쪽 -> 아래 -> 왼쪽 순서다.
func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return rect_polygon(cell, Vector2i.ONE)


## 발자국이 여러 칸인 사각형을 덮는 마름모 네 점.
##
## 칸마다 마름모를 그리면 안쪽 선이 겹쳐 두껍게 보인다. 건물은 발자국 전체를
## 한 덩어리로 그린다.
func rect_polygon(origin: Vector2i, footprint: Vector2i) -> PackedVector2Array:
	var span := Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	var far := origin + span - Vector2i.ONE
	var north := cell_to_world(origin) + Vector2(0.0, -half_height)
	var east := cell_to_world(Vector2i(far.x, origin.y)) + Vector2(half_width, 0.0)
	var south := cell_to_world(far) + Vector2(0.0, half_height)
	var west := cell_to_world(Vector2i(origin.x, far.y)) + Vector2(-half_width, 0.0)
	return PackedVector2Array([north, east, south, west])


## 그리는 차례를 정하는 값. 클수록 화면 아래이고 **나중에 그려 앞을 가린다.**
##
## Godot 의 YSort 를 쓰지 않는 이유는 발자국이 큰 건물 때문이다. 원점 하나로 정렬하면
## 2x2 건물과 1x1 건물이 반쯤 겹칠 때 뒤엣것이 앞으로 나온다.
static func depth_of(cell: Vector2i) -> int:
	return cell.x + cell.y


## 발자국이 여러 칸인 것의 차례. **가장 앞선 모서리**(오른쪽 아래)를 쓴다.
static func rect_depth(origin: Vector2i, footprint: Vector2i) -> int:
	var span := Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	return depth_of(origin + span - Vector2i.ONE)


## 칸 단위 높이를 화면 픽셀로. 「2층」이 몇 픽셀인지는 여기서만 정해진다.
static func height_to_px(height_cells: float) -> float:
	return height_cells * CELL_HEIGHT_PX


## **이 높이의 건물이 바로 뒤 몇 칸을 완전히 가리는가.** 높이 상한의 근거다 (§30.10.3).
##
## 화면에서 대각선 위로 한 칸 물러나면 세로로 마름모 한 개(=`tile_height`)만큼 올라간다.
## 그래서 가려지는 칸 수는 **높이를 마름모 세로로 나눈 몫**이다.
##
## 꼭짓점 넷을 다 넣고 푼 값이라 «반쯤 가림» 이 아니라 **완전히 가림**의 개수다.
## 부분적으로 가려지는 칸은 이보다 한 칸 더 뒤까지 간다.
func hidden_cells_behind(height_px: float) -> int:
	return int(floor(height_px / (half_height * 2.0)))


## 판 전체가 화면에서 차지하는 크기. 카메라를 맞출 때 쓴다.
func board_size(cols: int, rows: int) -> Vector2:
	var wide := maxi(1, cols)
	var tall := maxi(1, rows)
	return Vector2((wide + tall) * half_width, (wide + tall) * half_height)


## 판의 한가운데. 카메라가 여기를 본다.
func board_center(cols: int, rows: int) -> Vector2:
	var wide := maxi(1, cols)
	var tall := maxi(1, rows)
	return cell_to_world(Vector2i.ZERO) + Vector2(0.0, (wide + tall - 2) * half_height * 0.5)
