class_name LedgerForm
extends RefCounted
## **글이 많은 화면 전용 형태.** 노드에 의존하지 않는 순수 계산이다.
##
## ## 왜 `PopupForm` 으로는 안 되나
##
## 인물 상세를 팝업 형태 넷에 얹었더니 넷 다 무너졌다
## (docs/design/20-ui-kit.md §20.13). 그중 하나만이 **형태의 성질**이었다 —
## 「벌어지는 널」만 글줄이 이음매에 네 번 잘렸다. 널이 세로로 갈라져 있어서
## 이음매가 글줄을 가로지른다. 「어긋난 띠 셋」은 조각이 셋인데 한 번도 안 잘렸다.
## 띠가 가로라 이음매가 줄과 줄 **사이로** 지나간다.
##
## > **가로쓰기 화면에서 세로 이음매는 낱말을 자르고, 가로 이음매는 줄 사이에 숨는다.**
##
## 이 파일은 그 한 줄을 형태로 만든 것이다. 여섯 다 **글이 앉는 자리 안에 세로
## 이음매가 없다.** 세로로 자를 자유를 버린 대신 다른 축을 벌렸다 — 층의 어긋남 ·
## 계단 · 여백의 파편 · 겹침 · 화면 끝 물림 · 두루마리.
##
## ## 이음매를 형태가 정하지 않는다 — **자료가 정한다**
##
## `bands()` 가 `cuts` 를 받는다. 칸과 칸 사이 빈틈의 y 좌표고, **호출자가 글을 실제로
## 앉혀 보고 잰 값**이다. 형태가 「3등분」처럼 미리 정하면 내용이 한 줄만 바뀌어도
## 이음매가 글줄 위로 올라앉는다. `PopupForm.pieces()` 가 `size` 만 받은 것이
## 「벌어지는 널」이 잘린 근본 원인이다.
##
## ## 세로 이음매가 아예 금지는 아니다 — **글 오른쪽 끝 바깥에서는 된다**
##
## 「층계」가 그 자리다. 층마다 오른쪽 변의 위치가 다르고 그 사이에 세로 변(디딤의
## 챌판)이 생기는데, 그 x 가 **그 층 글이 닿은 끝보다 오른쪽**이라 낱말을 못 자른다.
## 그래서 `bands()` 가 `reach` 도 받는다 — 층마다 글이 실제로 닿은 폭이다.
## **글이 계단을 만든다.**

enum Kind {
	## 칸 경계에서만 가로로 자르고 층마다 좌우로 다르게 민다. 「어긋난 띠 셋」의 일반화 —
	## 조각 수가 형태가 아니라 **내용**에서 나온다.
	STRATA,
	## 한 판인데 오른쪽 변이 계단이다. 디딤의 깊이가 그 층 글의 폭에서 나온다.
	TERRACE,
	## 복판은 통판이고 **조각은 여백에서만 논다.** 글이 앉는 자리는 한 번도 안 갈라진다.
	RIM,
	## 판이 여러 겹 겹친다. 뒷장이 위아래와 오른쪽으로 삐져나오고 **앞장만 글을 든다.**
	SHEAF,
	## 화면 왼쪽 끝에 물려 있다. 붙은 변은 각지고 **반대쪽 변에서만** 형태가 논다.
	DOCK,
	## 머리띠 | 창 | 발띠. 창은 절대 안 갈라진다 — 안에서 글이 흘러야 하기 때문이다.
	SCROLL,
}

## 화면에 그대로 나가는 이름. SongMyung 에 있는 글자만 쓴다.
const NAMES := ["층진 띠", "층계", "테만 부순다", "겹친 장", "끝에 붙은 판", "두루마리"]

## 층이 몇 개까지 갈라지는가. 더 늘리면 띠가 얇아져 「줄무늬」가 되고 그건 배제 목록이다.
const MAX_BANDS: int = 5

## 「층계」만 층이 더 많아도 된다. **이음매가 안 보이기 때문이다** — 층끼리 딱 붙어
## 있어서 판 안에는 경계가 없고, 층 수는 오른쪽 변의 **디딤 수**로만 드러난다.
## 층이 둘뿐이면 계단이 아니라 그냥 튀어나온 판이다.
const TERRACE_BANDS: int = 8

## 계단의 디딤 격자(px). **절대값이다** — 계단은 손이 짚는 크기지 판의 크기가 아니다
## (§20.12).
const TREAD: float = 12.0

## 이어지는 게 없을 때 변이 헐어 있는 정도(px). **성한 끝이다.**
const FRAY_CALM: float = 2.5

## 그쪽으로 글이 더 있을 때 변이 헐어 있는 정도(px).
##
## **절대값이다** — 헐어 있음은 종이의 성질이지 판의 성질이 아니다(§20.12).
const FRAY_TORN: float = 17.0

## 겹인쇄 어긋남(px). §20.11.3 에서 잠근 값 — 면적이 커져도 안 커진다.
const MISPRINT := Vector2(5.0, -4.0)

## 겹친 장이 뒤로 몇 겹인가.
const SHEAF_DEPTH: int = 3

## 글이 시작되는 높이(px). **제목 아래가 또 제목이라 여기가 좁으면 둘이 겹친다** —
## §20.13.3 이 넷 다 걸린 자리다. `PopupForm.title_at()` 은 팝업 하나만 보고 정한
## 값이라 그대로 가져오면 안 됐다.
const TOP: float = 58.0

## 손이 닿았을 때 층의 어긋남이 몇 배가 되는가.
##
## **글 상자가 이 값을 알아야 한다.** 테스트가 잡은 자리다 — 처음에 글 상자를
## 평상시 어긋남만 보고 물렸더니 손이 닿는 순간 글 왼쪽이 판 밖으로 나갔다.
## 정지 화면으로는 멀쩡했다.
const HOVER_GAIN: float = 0.85

## 두루마리의 머리띠 · 발띠 높이(px). **절대값이다** — 손잡이라서 창이 길어져도 안 자란다.
const SCROLL_HEAD: float = 54.0
const SCROLL_FOOT: float = 34.0


static func label(kind: Kind) -> String:
	return NAMES[int(kind)]


static func count() -> int:
	return NAMES.size()


## 이 형태가 층을 몇 개까지 받는가.
static func max_bands(kind: Kind) -> int:
	return TERRACE_BANDS if kind == Kind.TERRACE else MAX_BANDS


## 글이 앉아도 되는 사각형. **여기 안에는 세로 이음매가 없다는 것이 이 파일의 계약이다.**
static func text_box(kind: Kind, size: Vector2) -> Rect2:
	var w := size.x
	var h := size.y
	match kind:
		Kind.STRATA:
			# 층이 좌우로 밀리므로 **가장 많이 민 층도 글을 덮도록** 안쪽으로 물린다.
			# 평상시가 아니라 **손이 닿았을 때의 최대치**로 물려야 한다.
			var pad := _sway_max(size) + 8.0
			return Rect2(pad, TOP, w - pad * 2.0, h - TOP - 14.0)
		Kind.TERRACE:
			# 오른쪽은 계단이 쓴다. 글은 거기까지 안 간다.
			return Rect2(22.0, TOP, w - 150.0, h - TOP - 14.0)
		Kind.RIM:
			var margin := w * 0.105
			return Rect2(margin, TOP, w - margin * 2.0, h - TOP - 14.0)
		Kind.SHEAF:
			# 뒷장이 오른쪽과 아래로 삐져나오므로 앞장이 그만큼 좁다.
			return Rect2(
				26.0, TOP, w - 26.0 - 34.0 - _sheaf_step(size) * float(SHEAF_DEPTH), h - TOP - 30.0
			)
		Kind.DOCK:
			# 왼쪽 등뼈가 굵다. 붙은 변이라 굵어도 액자가 안 된다.
			return Rect2(34.0, TOP, w - 34.0 - 76.0, h - TOP - 14.0)
		_:
			var win := window(kind, size)
			return Rect2(win.position + Vector2(14.0, 10.0), win.size - Vector2(28.0, 20.0))


## 제목이 앉는 자리. 팝업과 같은 이유로 왼쪽 위 고정이다 — 가운데로 가면 문서가 된다.
##
## **팝업 값(`PopupForm.title_at`)을 그대로 쓰면 안 된다.** 팝업은 제목 아래가 본문
## 두 줄이라 안 겹쳤지만 상세 화면은 **제목 바로 아래가 또 제목**이다(§20.13.3).
## 그래서 제목은 글 상자보다 **위**에 있고 글 상자가 그만큼 내려와 있다.
static func title_at(kind: Kind, size: Vector2) -> Vector2:
	match kind:
		Kind.DOCK:
			return Vector2(34.0, 27.0)
		Kind.SCROLL:
			return Vector2(28.0, 32.0)
		Kind.RIM:
			return Vector2(size.x * 0.105, 27.0)
		_:
			return Vector2(26.0, 27.0)


## 글이 흐르는 창. 두루마리만 갖는다 — 나머지는 빈 사각형이다.
##
## **스크롤은 조각난 형태와 정면으로 싸운다.** 판이 갈라져 있는데 안에서 글이 흐르면
## 어느 줄이 어느 조각에 앉을지 미리 모른다. 그래서 「이음매를 자료가 정한다」가
## 성립하지 않는다 — 자료가 움직이기 때문이다. 창을 가진 형태만 그 싸움을 피한다.
static func window(kind: Kind, size: Vector2) -> Rect2:
	if kind != Kind.SCROLL:
		return Rect2()
	return Rect2(16.0, SCROLL_HEAD, size.x - 32.0, size.y - SCROLL_HEAD - SCROLL_FOOT)


## 판을 이루는 층들. `cuts` 는 **호출자가 글을 앉혀 보고 잰** 칸 사이 빈틈의 y 좌표다.
##
## `reach` 는 층마다 글이 닿은 오른쪽 끝(x, 카드 좌표). 계단만 쓴다. 비워도 된다.
static func bands(
	kind: Kind,
	size: Vector2,
	cuts: PackedFloat32Array,
	reach: PackedFloat32Array,
	event: Vector3,
	reading := Vector2.ZERO
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var w := size.x
	var h := size.y
	var edge := edges(kind, size, cuts)
	match kind:
		Kind.STRATA:
			for i in edge.size() - 1:
				var dx := band_shift(kind, i, edge.size() - 1, size, event)
				out.append(
					_poly([dx, edge[i], w + dx, edge[i], w + dx, edge[i + 1], dx, edge[i + 1]])
				)
		Kind.TERRACE:
			var box := text_box(kind, size)
			var rights := PackedFloat32Array()
			for i in edge.size() - 1:
				rights.append(_tread(box, reach, i, size, event))
			out.append(_staircase(edge, rights))
		Kind.RIM:
			# 한 장이다. **복판을 가르지 않는 것이 이 형태의 전부다.**
			# 위아래 변만 가로로 물어낸다 — 가로 이음매라 줄 사이로 지나간다.
			#
			# **찢긴 깊이가 「그쪽으로 글이 이어진다」는 뜻이다**(§20.17).
			var torn := fray(kind, reading)
			var bite := torn.x + 4.0 * event.x
			var bite_low := torn.y + 4.0 * event.x
			out.append(
				_poly(
					[
						0.0,
						bite,
						w * 0.28,
						0.0,
						w * 0.63,
						bite * 0.6,
						w,
						0.0,
						w,
						h - bite_low,
						w * 0.55,
						h,
						w * 0.21,
						h - bite_low * 0.7,
						0.0,
						h
					]
				)
			)
		Kind.SHEAF:
			var step := _sheaf_step(size) * (1.0 + 0.55 * event.x - 0.8 * event.y)
			# **읽은 장은 위로 넘어가고 안 읽은 장은 아래에 남는다.** 종이 뭉치를
			# 읽는 방식 그대로다 — 남은 두께가 곧 「얼마나 남았나」다.
			var turned := reading.x * float(SHEAF_DEPTH) if reading.y > 0.5 else 0.0
			for back in range(SHEAF_DEPTH, 0, -1):
				var d := step * float(back)
				if float(back) <= turned:
					out.append(
						_poly(
							[
								d * 0.3,
								-d * 0.62,
								w,
								-d * 0.62,
								w,
								h - d * 0.62,
								d * 0.3,
								h - d * 0.62
							]
						)
					)
				else:
					out.append(_poly([d, d * 0.30, w, d * 0.30, w, h + d * 0.30, d, h + d * 0.30]))
			out.append(
				_poly(
					[
						0.0,
						0.0,
						w - step * float(SHEAF_DEPTH),
						0.0,
						w - step * float(SHEAF_DEPTH),
						h,
						0.0,
						h
					]
				)
			)
		Kind.DOCK:
			var juts := PackedFloat32Array()
			for i in edge.size() - 1:
				juts.append(_jut(i, size, event))
			out.append(_staircase(edge, juts))
		Kind.SCROLL:
			var win := window(kind, size)
			out.append(_poly([0.0, 0.0, w, 0.0, w, win.position.y, 0.0, win.position.y]))
			out.append(
				_poly([0.0, win.position.y, w, win.position.y, w, win.end.y, 0.0, win.end.y])
			)
			out.append(_poly([0.0, win.end.y, w, win.end.y, w, h, 0.0, h]))
	return out


## 층 `index` 가 좌우로 어긋난 거리. **어긋난 거리는 비율이다**(§20.12 — 판의 성질).
##
## 손이 닿으면 벌어지고 **눌리면 모인다.** 같은 축의 양끝이라 두 사건이 갈린다(§20.10).
static func band_shift(kind: Kind, index: int, count: int, size: Vector2, event: Vector3) -> float:
	if kind != Kind.STRATA or count <= 0:
		return 0.0
	# 황금비 켜기. 해시를 쓰면 이웃끼리 값이 몰린다(§20.6.10 ③).
	var turn := fposmod(0.31 + float(index) * 0.6180339887, 1.0)
	var base := _sway(size) * (turn * 2.0 - 1.0)
	return base * (1.0 + HOVER_GAIN * event.x) * (1.0 - 0.95 * event.y)


## 여백에서만 노는 파편들. **글이 앉는 자리에는 하나도 안 들어간다.**
##
## §20.9.4 가 남긴 것을 형태로 옮긴 것이다 — 화려함은 밀도 대비에서 나오고,
## 골고루 뿌리면 죽는다. 그래서 파편은 **왼쪽 여백 한 자리**에만 몰려 있다.
static func shards(
	kind: Kind, size: Vector2, event: Vector3, reading := Vector2.ZERO
) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if kind != Kind.RIM:
		return out
	var box := text_box(kind, size)
	var lane := box.position.x - 6.0
	for i in 7:
		var turn := fposmod(0.17 + float(i) * 0.6180339887, 1.0)
		var top := box.position.y + box.size.y * (0.06 + 0.13 * float(i))
		# **지나간 파편이 더 길게 뻗는다.** 색만 바꾸면 흑백으로 뽑았을 때 사라진다 —
		# 자리 표시는 길이로도 읽혀야 한다.
		var past := reading.y > 0.5 and float(i) / 6.0 <= reading.x
		var wide := lane * (0.30 + 0.62 * turn) * (1.35 if past else 0.78)
		var tall := 5.0 + 13.0 * turn
		var push := (0.6 + turn) * 9.0 * (event.x - event.y)
		var left := lane - wide - push
		out.append(
			_poly(
				[left, top, left + wide, top - 2.0, left + wide, top + tall, left, top + tall - 3.0]
			)
		)
	return out


## 이 형태가 **어디까지 읽었는지를 형태로 말할 수 있는가.**
##
## `seam_shows()` 로 갈린 「이음매를 자료가 먹는 형태」와 **정확히 반대 집합**이다.
## 실루엣이 이미 내용에 잡아먹힌 형태는 자리를 말할 채널이 남아 있지 않다 —
## 같은 변에 두 가지 뜻을 얹으면 둘 다 안 읽힌다.
##
## > **형태가 자리를 말하면 스크롤바가 필요 없다.** 에셋 없이 기능을 얻는다.
static func tells_position(kind: Kind) -> bool:
	return kind == Kind.RIM or kind == Kind.SHEAF or kind == Kind.SCROLL


## 위아래 변이 얼마나 헐었나(px). `reading` 은 `(읽은 비율 0..1, 흐를 수 있는가 0/1)`.
##
## > **끝이 성하면 끝이고, 끝이 헐면 이어진다.**
##
## 위가 반듯하면 그게 글의 처음이라는 뜻이고, 위가 찢겨 있으면 위로 더 있다는 뜻이다.
## 스크롤바처럼 **덧붙인 부품이 아니라 판의 실루엣 자체**라 「도형과 선 면으로만」에서
## 값이 난다. 모따기를 실루엣에서 잘라낸 것과 같은 판단이다(`PaneDeck`).
## `size` 를 안 받는다 — **헐어 있는 정도는 절대값이라 판 크기와 무관하다**(§20.12).
static func fray(kind: Kind, reading: Vector2) -> Vector2:
	if not tells_position(kind) or reading.y <= 0.5:
		return Vector2(FRAY_CALM, FRAY_CALM)
	var read := clampf(reading.x, 0.0, 1.0)
	return Vector2(
		FRAY_CALM + (FRAY_TORN - FRAY_CALM) * read,
		FRAY_CALM + (FRAY_TORN - FRAY_CALM) * (1.0 - read)
	)


## 같은 윤곽을 강세색으로 한 번 더 어긋나게 찍는가. **가장 값싸고 가장 세다**(§20.9.3).
static func overprints(kind: Kind) -> bool:
	return kind == Kind.STRATA or kind == Kind.SHEAF


## 층 경계가 **글이 앉는 자리 안에서 눈에 보이는가.**
##
## 「층진 띠」만 참이다 — 층이 좌우로 어긋나므로 경계가 판을 가로질러 드러난다.
## 「층계」와 「끝에 붙은 판」은 층끼리 딱 붙어 있어서 판 안에는 아무 경계도 없고
## **오른쪽 변의 위치만** 층마다 다르다. 그 변은 글보다 오른쪽이라 낱말을 못 자른다.
##
## 이 구분이 층 수를 가른다. 보이는 이음매는 **두 열의 빈틈이 겹치는 자리**에만
## 설 수 있어서 인물 상세에서 둘밖에 안 나온다. 안 보이는 이음매는 아무 데나 설 수
## 있어서 계단이 여덟 칸까지 나온다. **같은 「가로로 나눈다」인데 자유도가 네 배 다르다.**
static func seam_shows(kind: Kind) -> bool:
	return kind == Kind.STRATA


## 눈금을 두르는가. 「끝에 붙은 판」의 등뼈만 두른다.
static func ruled(kind: Kind) -> bool:
	return kind == Kind.DOCK


## 층 `index` 가 열림에서 **어디에서 날아오는가.** 형태마다 달라야 여섯이 갈린다.
static func entry(kind: Kind, index: int, count: int, size: Vector2) -> Vector2:
	var middle := float(count - 1) * 0.5
	var side := signf(float(index) - middle + 0.001)
	match kind:
		Kind.STRATA:
			# 층이 좌우에서 와 붙는다. 가로 이음매라 세로로 오면 이음매가 안 보인다.
			return Vector2(side * size.x * 0.55, 0.0)
		Kind.TERRACE:
			return Vector2(-size.x * 0.30, 0.0)
		Kind.RIM:
			return Vector2(0.0, -size.y * 0.18)
		Kind.SHEAF:
			return Vector2(size.x * 0.10, size.y * 0.16)
		Kind.DOCK:
			# 붙은 변에서 밀려 나온다. 화면 끝이 낸 것으로 읽혀야 한다.
			return Vector2(-size.x * 0.42, 0.0)
		_:
			# 두루마리는 **세로로 펼쳐진다.** 머리띠가 먼저 서고 창이 자란다.
			return Vector2(0.0, side * size.y * 0.40)


## 열림에서 층이 커졌다 제 크기로 오는 배율.
static func entry_scale(kind: Kind) -> float:
	match kind:
		Kind.RIM:
			return 1.10
		Kind.SHEAF:
			return 0.90
		_:
			return 1.0


## 층 경계 y. 맨 위 · `cuts` · 맨 아래를 이어 붙인 것이다.
##
## `cuts` 가 비면 층이 하나뿐이다 — **자를 자리가 없으면 안 자른다.** 형태를 지키려고
## 아무 데나 자르면 그 순간 글줄이 잘린다.
static func edges(kind: Kind, size: Vector2, cuts: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0])
	if kind == Kind.STRATA or kind == Kind.TERRACE or kind == Kind.DOCK:
		var taken := 0
		for y in cuts:
			if y <= out[out.size() - 1] + 12.0 or y >= size.y - 12.0:
				continue
			if taken >= max_bands(kind) - 1:
				break
			out.append(y)
			taken += 1
	out.append(size.y)
	return out


## 층마다 오른쪽 변이 어디인가. 계단에 표를 찍을 때 쓴다.
##
## **실루엣이 한 장이라 그리는 쪽이 이걸 다시 셀 방법이 없다** — 다각형의 경계상자는
## 가장 깊은 디딤 하나만 알려준다. 처음에 경계상자로 표를 찍었더니 표 일곱이 전부
## 판 밖 같은 자리에 떠 있었다.
static func step_rights(
	kind: Kind, size: Vector2, cuts: PackedFloat32Array, reach: PackedFloat32Array, event: Vector3
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var edge := edges(kind, size, cuts)
	match kind:
		Kind.TERRACE:
			var box := text_box(kind, size)
			for i in edge.size() - 1:
				out.append(_tread(box, reach, i, size, event))
		Kind.DOCK:
			for i in edge.size() - 1:
				out.append(_jut(i, size, event))
	return out


## 높이 `y` 에서 판의 **왼쪽과 오른쪽 변**이 어디인가. `Vector2(왼쪽, 오른쪽)`.
##
## **오른쪽만 재면 「층진 띠」의 흔들림이 안 잡힌다.** 처음에 그렇게 만들었더니
## 층이 좌우로 밀리는 형태가 흔들림 0 으로 나왔다 — 그 형태의 실루엣은 **왼쪽 변**이
## 층마다 다른 것인데 재는 자가 오른쪽만 보고 있었다.
##
## > **§20.13.1 이 세 번째로 나왔다. 새로 만든 자에도 같은 병이 있었다.**
static func edge_at(
	kind: Kind,
	size: Vector2,
	cuts: PackedFloat32Array,
	reach: PackedFloat32Array,
	event: Vector3,
	y: float
) -> Vector2:
	var edge := edges(kind, size, cuts)
	if kind == Kind.STRATA:
		for i in edge.size() - 1:
			if y >= edge[i] and y < edge[i + 1]:
				var dx := band_shift(kind, i, edge.size() - 1, size, event)
				return Vector2(dx, size.x + dx)
		return Vector2(0.0, size.x)
	return Vector2(0.0, right_at(kind, size, cuts, reach, event, y))


## 높이 `y` 에서 판의 오른쪽 변이 어디인가. **실루엣이 흔들리는지 재는 자다.**
##
## 스크롤은 「이음매를 자료가 정한다」와 정면으로 싸운다 — 자료가 흐르면 이음매도
## 흐르고 **실루엣이 매 프레임 달라진다.** 그것을 눈으로 「좀 움직이네」로 넘기지
## 않으려고 재는 함수를 둔다(§20.13.1 — 재는 축이 모자라면 없는 합격이 나온다).
static func right_at(
	kind: Kind,
	size: Vector2,
	cuts: PackedFloat32Array,
	reach: PackedFloat32Array,
	event: Vector3,
	y: float
) -> float:
	var rights := step_rights(kind, size, cuts, reach, event)
	if rights.is_empty():
		return size.x
	var edge := edges(kind, size, cuts)
	for i in rights.size():
		if y >= edge[i] and y < edge[i + 1]:
			return rights[i]
	return rights[rights.size() - 1]


## 층마다 오른쪽 변이 다른 **한 장짜리** 실루엣.
##
## **조각으로 쪼개면 안 된다.** 처음에 층마다 다각형을 하나씩 냈더니 층마다 테두리가
## 그려져 **가로줄이 글줄을 관통했다.** 「이음매가 안 보인다」고 적어 놓고 실제로는
## 테두리가 이음매를 그리고 있었다 — 정지 화면 한 장 뽑고 나서야 보였다.
##
## > **안 보여야 하는 이음매는 「안 그린다」로 부족하고 애초에 조각이 아니어야 한다.**
static func _staircase(edge: PackedFloat32Array, rights: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in rights.size():
		out.append(Vector2(rights[i], edge[i]))
		out.append(Vector2(rights[i], edge[i + 1]))
	out.append(Vector2(0.0, edge[edge.size() - 1]))
	out.append(Vector2(0.0, edge[0]))
	return out


## 계단 한 칸의 오른쪽 변. **글이 닿은 끝을 디딤 격자로 올림한 자리**라
## 세로 변이 언제나 낱말 바깥에 선다.
static func _tread(
	box: Rect2, reach: PackedFloat32Array, index: int, size: Vector2, event: Vector3
) -> float:
	var end_x := box.end.x
	if index < reach.size() and reach[index] > box.position.x:
		end_x = reach[index]
	var stepped := box.position.x + ceilf((end_x - box.position.x) / TREAD) * TREAD
	# 손이 닿으면 계단이 더 나오고 눌리면 한 줄로 가지런해진다 — 같은 축의 양끝.
	var jut := 14.0 + 26.0 * event.x
	var flat := lerpf(stepped + jut, box.end.x + 40.0, event.y)
	return clampf(flat, box.position.x + TREAD, size.x)


## 「끝에 붙은 판」의 층별 오른쪽 변. 붙은 변(x=0)은 절대 안 움직인다.
static func _jut(index: int, size: Vector2, event: Vector3) -> float:
	var turn := fposmod(0.44 + float(index) * 0.6180339887, 1.0)
	var deep := size.x - 72.0 * turn
	return lerpf(deep, size.x, event.x * 0.7 + event.y * 0.3)


## 층이 평상시 좌우로 밀리는 거리.
static func _sway(size: Vector2) -> float:
	return size.x * 0.026


## 손이 닿았을 때까지 포함한 **최대** 밀림. 글 상자가 이만큼 물러나 있어야 한다.
static func _sway_max(size: Vector2) -> float:
	return _sway(size) * (1.0 + HOVER_GAIN)


## 겹친 장이 한 겹씩 어긋나는 거리.
static func _sheaf_step(size: Vector2) -> float:
	return size.x * 0.020


static func _poly(numbers: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, numbers.size(), 2):
		out.append(Vector2(numbers[i], numbers[i + 1]))
	return out
