class_name PlateState
extends RefCounted
## 한 프레임에 판 하나가 어떤 꼴인지. **컨셉이 다르면 이 값들이 다르게 채워질 뿐이다.**
##
## 컨셉마다 렌더러를 따로 만들지 않는 이유가 있다. 넷을 나란히 놓고 견주려면
## 판의 **생김새**가 아니라 **움직임**만 달라야 하는데, 렌더러가 다르면
## 무엇 때문에 달라 보이는지 알 수 없게 된다.
##
## 그래서 채널은 여기 고정이고, 컨셉은 `src/core/ui/motion/*` 에서 이 채널을
## **얼마나 세게 미느냐**로만 갈린다.

## 판의 자리. 원래 자리에서 얼마나 밀렸는가.
var offset: Vector2 = Vector2.ZERO

## 눌리고 늘어난 정도. (1,1) 이 원래 크기다.
var scale: Vector2 = Vector2.ONE

## 기울이기(라디안). 사각형이 평행사변형이 된다.
var skew: float = 0.0

var rotation: float = 0.0

## 판 · 강세 · 글자. 컨셉마다 배색이 다르므로 색도 모션이 정한다.
var body: Color = Color.BLACK
var accent: Color = Color.WHITE
var ink: Color = Color.WHITE

## 강세 막대의 길이 (판 폭에 대한 비율).
var bar: float = 0.0

## 판을 벤 자리들. 판 복판을 원점으로 한 좌표이고, 비어 있으면 안 갈라진다.
var cuts: Array[Vector2] = []

## 벤 선의 법선. 조각은 이 선을 **따라** 미끄러진다 — 가로지르는 것이 아니라.
var cut_normal: Vector2 = Vector2(0.26, -0.97)

## 조각마다 밀린 거리. `cuts` 보다 하나 많은 것이 정상이다.
var piece_slide: Array[Vector2] = []

## 조각마다 틀어진 각. 평행이동만 하면 잘린 조각이 아니라 미끄러진 판이다.
var piece_spin: Array[float] = []

## 충격 고리. 0 이면 없고 1 이면 막 터진 것이다.
var shock: float = 0.0

## 색이 뒤집힌 정도. 1 이면 판과 강세가 자리를 바꾼다.
var invert: float = 0.0

## 글자만 따로 미는 값. 판과 함께 움직이면 아무 일도 없었던 것이 된다.
var ink_offset: Vector2 = Vector2.ZERO

var ink_scale: float = 1.0

## 뒤에 남는 잔상들. 각각 `{offset, color, scale, skew, rotation}`.
var ghosts: Array[Dictionary] = []


## 색을 뒤집는다. 눌림에서 밝아지거나 어두워지는 것은 웹 버튼이고,
## **통째로 뒤집히는 것**은 도장이 찍힌 것이다.
func apply_invert() -> void:
	if invert <= 0.001:
		return
	var new_body := body.lerp(accent, invert)
	var new_accent := accent.lerp(body, invert)
	ink = ink.lerp(body, invert)
	body = new_body
	accent = new_accent


func add_ghost(
	at: Vector2, color: Color, ghost_scale: Vector2 = Vector2.ONE, ghost_skew: float = 0.0
) -> void:
	ghosts.append({"offset": at, "color": color, "scale": ghost_scale, "skew": ghost_skew})
