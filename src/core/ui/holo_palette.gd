class_name HoloPalette
extends RefCounted
## **진한 물감 팔레트.** 색이 여기 한 곳에서만 정해진다.
##
## docs/design/20-ui-kit.md §20.31 · §20.32.
##
## ## 파스텔이 틀렸다 — 물 빠진 색이 됐다
##
## §20.31 은 「채도를 내리고 밝기를 올려 파스텔로」였다. 그렇게 하니 **색이 바랬다.**
##
## > **저건 채도가 낮긴 한데 물 빠진 색이잖아. 채도 높아도 되니까 그런 느낌으로.**
##
## 죽여야 하는 것은 **네온의 「쨍함」**이지 채도가 아니었다. 쨍함은 채도가 아니라
## **밝기**에서 온다 — 형광펜은 채도도 밝기도 최대다. 그래서 여기서는
## **채도를 올리고 밝기를 중간에 묶는다.** 형광펜이 아니라 **진한 물감**이다.
##
## ## 강조색 하나가 다 하면 아무것도 안 가리킨다
##
## 앞 판은 강조색 하나가 「지금 여기」 · 선택 · 위험 · 값을 **전부** 칠했다.
## 같은 색이 일곱 군데면 그 색은 신호가 아니라 배경이다.
##
## | 자리 | 색 | 신호인가 |
## | --- | --- | --- |
## | **신호** `accent` | 「지금 여기」 **딱 한 곳** | 그렇다 |
## | **고름** `pick` | 켜짐 · 선택 — 메뉴 선택 · 올린 버튼 · 슬라이더 채운 쪽 · 체크 | 아니다(구분) |
## | **험** `peril` | 되돌릴 수 없는 것 — 팝업 확인 · 닫기 | 아니다(구분) |
##
## **셋으로 나눠도 「지금 여기」는 여전히 하나다.** 나머지 둘은 **구분**을 위한 것이지
## 「여기를 보라」가 아니다. 그래서 장식(꺾쇠 · 눈금 · 숫자열)은 셋 중 무엇도 안 쓴다.

## 여섯 벌. **셋의 배치가 벌마다 다르다** — 색상만 돌리면 같은 그림 여섯 장이 된다.
##
## ## 얌전한 조화가 아니라 **한 번 놀라는 것** (§20.40)
##
## 앞의 넷(심해 · 자실 · 청람 · 단청)은 셋이 전부 **색상환에서 이웃**이거나
## 붉은 하나만 떼어 놓은 배치였다. 그건 안전하지 틀리지 않는다 — 그래서 얌전했다.
##
## 여기서는 **부딪히는 색끼리 붙인다.** 보색에 가까운 짝, 따뜻함과 차가움의 정면,
## 그리고 **험이 안 붉은 벌 하나**를 넣는다.
##
## | 팔레트 | 신호 | 고름 | 험 | 무엇이 도발인가 |
## | --- | --- | --- | --- | --- |
## | **단청** | 치자황 | 벽록 | 단홍 | 없다 — **얌전한 것 한 벌을 남겨 견준다** |
## | **독초** | 산성 라임 | 자홍 | 주홍 | 라임 × 자홍. 거의 보색이고 둘 다 안 물러선다 |
## | **선혈** | 진홍 | 청자 | **자주** | **험이 안 붉다.** 신호가 붉은 자리를 먼저 가져갔다 |
## | **야시장** | 마젠타 | 시안 | 주황 | 마젠타 × 시안에 주황을 하나 더 — 셋이 다 센 색이다 |
## | **전토** | 전기파랑 | 황토 | 진홍 | 가장 찬 색과 가장 흙빛인 색을 맞붙였다 |
## | **온실** | 형광 분홍 | 연두 | 주홍 | **초록 바탕 위의 분홍.** 바탕부터 편을 든다 |
##
## **험이 안 붉은 벌(선혈)이 가장 위험한 실험이다.** 「붉은색은 언제나 이긴다」(§20.35.1)에
## 기대어 온 규칙이 그 벌에서만 안 통한다 — 신호가 붉으니 험은 다른 방식으로 세야 한다.
const _NAMES := ["단청", "독초", "선혈", "야시장", "전토", "온실"]
const _SLUGS := ["dancheong", "hemlock", "gore", "bazaar", "voltearth", "hothouse"]

## 이 밝기를 넘으면 형광펜이다. 채도는 얼마든 높여도 되지만 **밝기는 여기 묶인다.**
const GLARE := 0.88

## 채도가 이보다 낮으면 물 빠진 색이다.
const MUD := 0.55

## 면의 밝기가 이보다 높으면 **글자가 어두워져야** 한다.
const INK_LINE := 0.42

## 바탕. 순검정이 아니라 **색이 아주 조금 도는 어두운 색**이다.
const _VOID := ["#12100e", "#141a08", "#1a0a0e", "#150a16", "#080c1c", "#08190f"]

## 밝은 판. 미색이되 강조색 쪽으로 아주 살짝 기운다.
const _PAPER := ["#eae1cf", "#e9eed4", "#f0dfe0", "#f0dcea", "#dee2f4", "#e6f0e0"]

## **신호.** 「지금 여기」 한 곳에만 쓴다.
##
## **경계에 앉은 색은 한쪽으로 확실히 보낸다.** 밝기가 `INK_LINE` 바로 옆이면 글자가
## 겨우 뜨고, 색을 조금만 손봐도 글자색이 통째로 뒤집힌다. 두 벌을 그래서 옮겼다 —
## 「온실」의 분홍(0.38 이었다)은 더 진하게, 「야시장」의 주황(0.44 였다)은 더 밝게.
const _ACCENT := ["#d99a1c", "#8fbf16", "#cc1f3d", "#d61f7a", "#2a52d6", "#d42a70"]

## **고름.** 켜져 있는 것 · 골라 둔 것 · 값이 차 있는 쪽.
const _PICK := ["#17907d", "#b81f8e", "#199c8f", "#12a3bd", "#b8801e", "#6faa1c"]

## **험.** 되돌릴 수 없는 것.
const _PERIL := ["#cb3a22", "#d94a14", "#a11fc4", "#e06a10", "#cc2233", "#d8401f"]

## 어긋난 뒤판. **고름의 짙은 쪽**이라 판 한 겹이 색으로도 읽히되 신호를 안 뺏는다.
const _BACK := ["#0f5148", "#6b1153", "#0d5a52", "#0b5f70", "#6e4a0c", "#3f6410"]

## 브라운관 인광. **면이 아니라 방의 빛**이라 셋 중 어느 신호도 아니다.
const _GLOW := ["#f0cf8a", "#a9dfe8", "#efd9b0", "#c9e8a8", "#f0b8cf", "#a8e6ee"]


static func count() -> int:
	return _NAMES.size()


static func name_of(which: int) -> String:
	return _NAMES[wrapi(which, 0, count())]


static func slug(which: int) -> String:
	return _SLUGS[wrapi(which, 0, count())]


static func void_color(which: int) -> Color:
	return Color(_VOID[wrapi(which, 0, count())])


static func paper(which: int) -> Color:
	return Color(_PAPER[wrapi(which, 0, count())])


## 신호. **한 화면에 한 번만 쓰라고 있는 색이다.**
static func accent(which: int) -> Color:
	return Color(_ACCENT[wrapi(which, 0, count())])


## 고름 — 켜짐 · 선택 · 값.
static func pick(which: int) -> Color:
	return Color(_PICK[wrapi(which, 0, count())])


## 험 — 되돌릴 수 없는 것.
static func peril(which: int) -> Color:
	return Color(_PERIL[wrapi(which, 0, count())])


static func back(which: int) -> Color:
	return Color(_BACK[wrapi(which, 0, count())])


static func glow(which: int) -> Color:
	return Color(_GLOW[wrapi(which, 0, count())])


## 그 면 위에서 글자가 무슨 색이어야 하나.
##
## **면이 밝으면 글자는 어둡게.** 색을 갈아 끼울 때 같이 뒤집혀야 하는 것이 글자색이라
## 화면 쪽에서 눈으로 고르면 팔레트 한 벌이 늘 때마다 어딘가 하나가 묻힌다.
static func ink(which: int, surface: Color) -> Color:
	if surface.get_luminance() > INK_LINE:
		return void_color(which)
	return paper(which)


## 글자를 세우는 어긋난 한 겹. **글자색의 반대쪽**이라 어느 면에서든 글자가 뜬다.
static func ink_prop(which: int, surface: Color) -> Color:
	if surface.get_luminance() > INK_LINE:
		return paper(which)
	return void_color(which)


## 세 신호색이 **물감인가.** 채도가 낮으면 물 빠진 색이고,
## 밝기가 높으면 그 순간 형광펜이다.
static func is_pigment(which: int) -> bool:
	for tint: Color in [accent(which), pick(which), peril(which)]:
		if tint.s < MUD or tint.v > GLARE:
			return false
	return true
