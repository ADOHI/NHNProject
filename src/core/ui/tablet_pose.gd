class_name TabletPose
extends RefCounted
## **손에 든 기기로 읽히게 하는 계산.** 순수 계산이다.
##
## ## 정면 평면이면 그냥 게임 UI 다
##
## 이 화면은 조우 중에 **꺼내 든 태블릿**이다. 정면으로 반듯하게 놓이면 그건 기기가
## 아니라 게임의 HUD 다. **살짝 기울고 원근이 있어야** 손에 든 물건이 된다.
##
## 기울임을 **어파인(기울기 변환)으로 하면 안 된다.** 어파인은 마주 보는 두 변을
## 평행하게 유지하므로 **멀어지는 쪽이 안 좁아진다** — 눈에는 「비뚤어진 평면」이지
## 「누워 있는 판」이 아니다. 그래서 **네 귀퉁이를 직접 놓고 사영 변환**을 쓴다.
##
## ## 텍스처를 격자로 나눠 붙인다
##
## 캔버스 그리기는 삼각형 안에서 UV 를 **어파인으로** 보간한다. 사각형 하나로 붙이면
## 대각선을 경계로 그림이 접힌다. **판을 잘게 나누면** 칸마다의 어파인 오차가 눈에
## 안 보이는 크기로 줄어든다 — `CELLS` 가 그 잘게 나누는 수다.

## 격자 칸 수. 16x12 면 1280x720 짜리 판에서 칸 하나가 80x60 px 이고 그 안의 오차는
## 1px 아래다. 더 잘게 나눠도 눈에 달라지는 것이 없고 호출만 늘어난다.
const CELLS := Vector2i(16, 12)

## 기기 테두리 두께(px). **절대값이다** — 테두리는 기기의 성질이지 화면의 성질이 아니다.
const BEZEL: float = 26.0

## 미끄러짐이 잦아드는 빠르기(1/초). 클수록 빨리 선다.
##
## **관성이 없으면 즉시 PC 로 읽힌다.** 손을 뗐는데 그 자리에 서면 그건 마우스다.
const DRAG: float = 3.4

## 이보다 느려지면 선 것으로 본다(칸/초).
const CREEP: float = 0.04


## 기울어 누운 화면의 네 귀퉁이. 차례는 왼위 · 오른위 · 오른아래 · 왼아래다.
##
## `lean` 은 좌우로 돌린 정도(-1..1), `tip` 은 위로 눕힌 정도(0..1)다.
## **위가 좁고 아래가 넓다** — 아래쪽이 손에 가깝기 때문이다. 반대로 하면 벽에 걸린
## 화면이 되고 「들고 있다」가 사라진다.
static func quad(screen: Vector2, lean: float, tip: float) -> PackedVector2Array:
	var mid := screen * 0.5
	# 위쪽 변이 좁아지는 정도. 원근의 몸통이다.
	var far := 1.0 - 0.16 * tip
	var near := 1.0 + 0.05 * tip
	# 좌우로 돌리면 **한쪽 변이 짧아진다.** 두 변을 같이 줄이면 그냥 작아진다.
	var left := 1.0 - 0.20 * maxf(lean, 0.0)
	var right := 1.0 - 0.20 * maxf(-lean, 0.0)
	var rise := screen.y * 0.045 * tip
	return PackedVector2Array(
		[
			mid + Vector2(-mid.x * far * left, -mid.y * left + rise),
			mid + Vector2(mid.x * far * right, -mid.y * right + rise),
			mid + Vector2(mid.x * near * right, mid.y * right + rise),
			mid + Vector2(-mid.x * near * left, mid.y * left + rise),
		]
	)


## 단위 정사각형의 한 점을 네 귀퉁이가 만드는 사각형으로 옮긴다.
##
## 사영 변환이라 **가운데가 한쪽으로 쏠린다** — 그것이 원근이다. 어파인이면
## 가운데가 늘 가운데에 있고, 그래서 어파인으로는 누운 판이 안 된다.
static func project(corners: PackedVector2Array, uv: Vector2) -> Vector2:
	var m := _mapping(corners)
	var w: float = m[6] * uv.x + m[7] * uv.y + 1.0
	if absf(w) < 0.00001:
		w = 0.00001
	return Vector2((m[0] * uv.x + m[1] * uv.y + m[2]) / w, (m[3] * uv.x + m[4] * uv.y + m[5]) / w)


## 텍스처를 붙일 격자 칸 하나. `cell` 은 칸의 가로세로 번호다.
##
## 네 점과 네 UV 를 함께 낸다 — 그리는 쪽은 그대로 `draw_primitive` 에 넘기면 된다.
static func patch(corners: PackedVector2Array, cell: Vector2i) -> Array:
	var step := Vector2(1.0 / float(CELLS.x), 1.0 / float(CELLS.y))
	var uv := Vector2(float(cell.x) * step.x, float(cell.y) * step.y)
	var uvs := PackedVector2Array(
		[uv, uv + Vector2(step.x, 0.0), uv + step, uv + Vector2(0.0, step.y)]
	)
	var points := PackedVector2Array()
	for each in uvs:
		points.append(project(corners, each))
	return [points, uvs]


## 기기 테두리. 화면 사각형을 바깥으로 밀어 낸 사각형이다.
##
## **테두리가 보여야 「기기」다.** 화면만 있으면 그것은 창이지 물건이 아니다.
static func bezel(corners: PackedVector2Array, thick: float) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for point in corners:
		mid += point
	mid /= float(corners.size())
	var out := PackedVector2Array()
	for point in corners:
		var away := (point - mid).normalized()
		out.append(point + away * thick)
	return out


## 표면에 비스듬히 스치는 빛. `phase` 0..1 이 판을 가로지른다.
##
## **판의 좌표로 만들고 사영으로 옮긴다.** 화면 좌표에서 곧은 띠를 그리면 판이
## 기울어도 빛만 안 기울어서 유리 위가 아니라 화면 앞 유리에 붙은 것으로 보인다.
static func sheen(corners: PackedVector2Array, phase: float, width: float) -> PackedVector2Array:
	var head := clampf(phase, 0.0, 1.0) * (1.0 + width * 2.0) - width
	var out := PackedVector2Array()
	# 위 변에서 아래 변으로 비스듬히 내려가는 띠다. 세로면 화면 닦은 자국이 된다.
	out.append(project(corners, Vector2(clampf(head, 0.0, 1.0), 0.0)))
	out.append(project(corners, Vector2(clampf(head + width, 0.0, 1.0), 0.0)))
	out.append(project(corners, Vector2(clampf(head + width - 0.42, 0.0, 1.0), 1.0)))
	out.append(project(corners, Vector2(clampf(head - 0.42, 0.0, 1.0), 1.0)))
	return out


## 손을 뗀 뒤 `t` 초 동안 미끄러진 거리(칸).
##
## 지수로 잦아든다 — **일정하게 감속하면 멈추는 순간이 딱 끊겨** 브레이크로 읽힌다.
static func glide(speed: float, t: float, drag := DRAG) -> float:
	return speed / drag * (1.0 - exp(-drag * maxf(t, 0.0)))


## 영원히 미끄러졌을 때의 총 거리(칸). 어디에 설지를 미리 아는 값이다.
static func reach(speed: float, drag := DRAG) -> float:
	return speed / drag


## 미끄러짐이 끝나는 데 걸리는 시간(초).
static func stop_time(speed: float, drag := DRAG) -> float:
	if absf(speed) <= CREEP:
		return 0.0
	return log(absf(speed) / CREEP) / drag


## **관성과 칸이 어떻게 어울리나.**
##
## 미끄러진 만큼 지나간 뒤 **가장 가까운 칸에 붙는다.** 칸을 무시하고 아무 데나 서면
## 「고른 인물이 가운데」가 깨지고, 칸에서 딱 끊으면 관성이 없는 것과 같다.
##
## > **미끄러지는 것은 연속이고 서는 곳은 이산이다.**
static func lands_on(from: float, speed: float, drag := DRAG) -> float:
	return roundf(from + reach(speed, drag))


## 끝에서 더 당겼을 때 실제로 늘어나는 양. **당길수록 덜 늘어난다.**
##
## `over` 가 커져도 `span` 을 넘지 않는다 — 고무줄이 끊기지 않는 이유다.
## 이것이 없으면 끝에서 그냥 멈춰서 화면이 고장난 것으로 보인다.
static func rubber(over: float, span: float) -> float:
	var pull := absf(over)
	var give := span * pull / (span + pull)
	return give if over >= 0.0 else -give


## 단위 정사각형 → 사각형 사영 변환의 계수 여덟(a b c d e f g h).
##
## 마주 보는 두 변이 평행하면 g=h=0 이 되어 저절로 어파인으로 떨어진다 —
## 따로 갈라 적을 필요가 없다.
static func _mapping(corners: PackedVector2Array) -> PackedFloat32Array:
	var p0 := corners[0]
	var p1 := corners[1]
	var p2 := corners[2]
	var p3 := corners[3]
	var sx := p0.x - p1.x + p2.x - p3.x
	var sy := p0.y - p1.y + p2.y - p3.y
	if absf(sx) < 0.000001 and absf(sy) < 0.000001:
		return PackedFloat32Array(
			[p1.x - p0.x, p3.x - p0.x, p0.x, p1.y - p0.y, p3.y - p0.y, p0.y, 0.0, 0.0]
		)
	var dx1 := p1.x - p2.x
	var dy1 := p1.y - p2.y
	var dx2 := p3.x - p2.x
	var dy2 := p3.y - p2.y
	var den := dx1 * dy2 - dx2 * dy1
	if absf(den) < 0.000001:
		den = 0.000001
	var g := (sx * dy2 - dx2 * sy) / den
	var h := (dx1 * sy - sx * dy1) / den
	return PackedFloat32Array(
		[
			p1.x - p0.x + g * p1.x,
			p3.x - p0.x + h * p3.x,
			p0.x,
			p1.y - p0.y + g * p1.y,
			p3.y - p0.y + h * p3.y,
			p0.y,
			g,
			h,
		]
	)
