class_name RoomMark
extends RefCounted
## 방 종류를 58x30px 에서 구분하는 표시. **순수 기하뿐이라 씬 없이 검증된다.**
##
## 근거: [`07`](../../../docs/design/07-level-design.md) §7.2.9 방 종류 여섯,
## §7.8 "낮은 배율에서는 판의 **모양과 색**을 읽는다".
##
## ## 왜 색으로 안 푸는가
##
## 방 종류는 여섯이고 배율 0.40 에서 방 위젯은 **58x30px** 이다.
## 그 크기에서 색 여섯을 구분시키려면 명도까지 벌려야 하는데,
##
##   - 명도를 벌리면 **숫자와 싸운다.** 방 안에는 늘 위험도 합이 앉아 있고
##     ([`13`](../../../docs/design/13-information-design.md) §13.6 — 무료 · 정확),
##     밝은 방과 어두운 방에서 같은 숫자가 다른 대비로 읽힌다
##   - 컨셉마다 배색이 다르다. 다섯 컨셉이 각자 **색을 셋씩만** 갖고 있어서
##     역할 넷에 색 넷을 배정할 수가 없다
##
## **그래서 색 둘 + 형태 셋으로 푼다.** 색은 역할을 거들 뿐 지지 않는다.
##
## ## 가지 수를 줄인 두 수
##
## **① 빈방은 표시가 없다.** 「통로 역할」(§7.2.9)이라 판의 **바탕 상태**다.
## 여섯 중 하나가 공짜로 빠져 다섯이 된다. 모든 종류에 표시를 주면
## 판 전체가 무늬로 덮여 정작 아무것도 도드라지지 않는다.
##
## **② 보스는 새 기호가 아니라 둘을 겹쳐 찍은 것이다.**
## 「고위험 고보상」(§7.2.9)이 곧 **위협 + 보상**이므로 원자를 더할 필요가 없다.
## 기호가 늘면 외울 것이 늘지만, 겹쳐 찍기는 **읽는 법이 저절로 따라온다.**
##
## 남는 원자는 셋뿐이다.
##
## | 원자 | 뜻 | 어떻게 |
## | --- | --- | --- |
## | **쐐기** | 여기 보상이 있다 | 오른쪽 위 모서리를 채운 삼각형 |
## | **빗금 띠** | 여기 위협이 있다 | 아래 모서리를 따라 흐르는 빗금 띠 |
## | **결손** | 판의 출입구다 | 옆구리를 물어낸 자리 (실루엣이 바뀐다) |
##
## | 종류 | 쐐기 | 사선 | 결손 |
## | --- | --- | --- | --- |
## | 빈방 | | | |
## | 귀중품 | O | | |
## | 위험 | | O | |
## | **보스** | **O** | **O** | |
## | 입구 | | | 왼쪽 |
## | 탈출 | | | 오른쪽 |
##
## 결손은 **실루엣을 바꾸므로** 아무리 작아져도 남는다. 채우기와 빗금이 뭉개지는
## 크기에서도 「옆구리가 파인 방」은 보인다. 그래서 판에서 **가장 먼저 찾아야 하는
## 탈출구**(§7.2.9 — 최소 하나는 민첩 0 으로 도달 가능)가 가장 튼튼한 원자를 받는다.

enum Kind { EMPTY, TREASURE, HAZARD, BOSS, ENTRANCE, EXIT }

## 쐐기의 두 변 길이. 58x30 에서 14px 면 넓이의 약 11% 를 먹어 눈에 걸린다.
const WEDGE_LEG: float = 14.0

## 빗금 띠. **아래 모서리를 따라 흐른다.**
##
## 처음에는 왼쪽 아래 구석에 빗금 세 줄을 뒀는데 58x30 에서 **거의 안 보였고**
## 가운데 숫자와도 자리를 다퉜다. 아래 모서리를 따라 띠로 두면
##   - 폭 전체를 쓰므로 작아져도 「줄무늬가 있다」가 남는다
##   - 숫자는 복판에 있으므로 **자리가 겹치지 않는다**
##   - 쐐기(오른쪽 위 모서리)와 구역이 갈려 보스방에서 **둘이 함께 읽힌다**
## 판 높이에 대한 비율로 잡는다. 고정 px 로 두면 확대했을 때 띠 두께가 그대로라
## 빗금이 서로 겹쳐 마름모 무늬가 된다 (실제로 그랬다).
const HATCH_BAND_RATIO: float = 0.20
const HATCH_STEP_RATIO: float = 0.233
const HATCH_WIDTH: float = 2.0

## 결손의 크기. 세로로 판 높이의 3분의 1을 물어내야 실루엣이 바뀐 것으로 보인다.
const NOTCH_WIDTH: float = 7.0
const NOTCH_HEIGHT_RATIO: float = 0.34


static func has_wedge(kind: Kind) -> bool:
	return kind == Kind.TREASURE or kind == Kind.BOSS


static func has_hatch(kind: Kind) -> bool:
	return kind == Kind.HAZARD or kind == Kind.BOSS


## 0 이면 결손이 없다. -1 은 왼쪽(입구), +1 은 오른쪽(탈출).
static func notch_side(kind: Kind) -> int:
	match kind:
		Kind.ENTRANCE:
			return -1
		Kind.EXIT:
			return 1
		_:
			return 0


## 방 바탕. 결손이 있으면 그 자리를 물어낸 다각형이 된다.
##
## 표시를 위에 얹는 것이 아니라 **판의 윤곽 자체를 바꾼다.** 얹은 것은 작아지면
## 사라지지만 윤곽은 배경과 맞닿아 있어 끝까지 남는다.
static func plate_polygon(rect: Rect2, kind: Kind) -> PackedVector2Array:
	var side := notch_side(kind)
	if side == 0:
		return PackedVector2Array(
			[
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y)
			]
		)
	var bite := rect.size.y * NOTCH_HEIGHT_RATIO
	var top := rect.position.y + (rect.size.y - bite) * 0.5
	var bottom := top + bite
	if side < 0:
		var x := rect.position.x + NOTCH_WIDTH
		return PackedVector2Array(
			[
				rect.position,
				Vector2(rect.end.x, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.position.x, bottom),
				Vector2(x, bottom),
				Vector2(x, top),
				Vector2(rect.position.x, top),
			]
		)
	var x_right := rect.end.x - NOTCH_WIDTH
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, top),
			Vector2(x_right, top),
			Vector2(x_right, bottom),
			Vector2(rect.end.x, bottom),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)


## 보상 쐐기. 오른쪽 위 모서리를 채운다.
static func wedge_polygon(rect: Rect2) -> PackedVector2Array:
	var leg: float = minf(WEDGE_LEG, minf(rect.size.x, rect.size.y) * 0.55)
	return PackedVector2Array(
		[
			Vector2(rect.end.x - leg, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y + leg),
		]
	)


## 위협 빗금 띠. 아래 모서리를 따라 흐르는 45도 빗금들을 (시작, 끝) 짝으로 돌려준다.
##
## 띠 밖으로 나가는 부분은 **잘라서** 돌려준다. 삐져나온 선은 무늬가 아니라 흠으로 보인다.
static func hatch_segments(rect: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var band := rect.size.y * HATCH_BAND_RATIO
	var step := rect.size.y * HATCH_STEP_RATIO
	var top := rect.end.y - band
	var start := rect.position.x - band
	while start < rect.end.x:
		# 빗금 하나는 (start, 아래) 에서 오른쪽 위로 45도로 오른다.
		var from := Vector2(start, rect.end.y)
		var to := Vector2(start + band, top)
		# 왼쪽으로 삐져나온 만큼 시작점을 띠 안으로 끌어온다.
		if from.x < rect.position.x:
			var cut := rect.position.x - from.x
			from = Vector2(rect.position.x, rect.end.y - cut)
		# 오른쪽도 같은 방식으로 자른다.
		if to.x > rect.end.x:
			var cut := to.x - rect.end.x
			to = Vector2(rect.end.x, top + cut)
		if to.y < from.y:
			out.append(PackedVector2Array([from, to]))
		start += step
	return out


## 사람이 읽는 이름. 견본 화면과 테스트가 함께 쓴다.
static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.TREASURE:
			return "귀중품"
		Kind.HAZARD:
			return "위험"
		Kind.BOSS:
			return "보스"
		Kind.ENTRANCE:
			return "입구"
		Kind.EXIT:
			return "탈출"
		_:
			return "빈방"
