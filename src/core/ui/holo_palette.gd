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

## 네 벌. **셋의 배치가 벌마다 다르다** — 색상만 돌리면 같은 그림 네 장이 된다.
##
## | 팔레트 | 신호 | 고름 | 험 |
## | --- | --- | --- | --- |
## | **심해** | 벽청 | 군청 | 주홍 |
## | **자실** | 자홍 | 보라 | 진홍 |
## | **청람** | 전기파랑 | 벽청 | 장미 |
## | **단청** | **치자황** | 벽록 | 단홍 — 팔레트에서 가장 센 물감(丹)이 위험한 자리에 |
const _NAMES := ["심해", "자실", "청람", "단청"]
const _SLUGS := ["abyss", "plum", "azure", "dancheong"]

## 이 밝기를 넘으면 형광펜이다. 채도는 얼마든 높여도 되지만 **밝기는 여기 묶인다.**
const GLARE := 0.88

## 채도가 이보다 낮으면 물 빠진 색이다.
const MUD := 0.55

## 면의 밝기가 이보다 높으면 **글자가 어두워져야** 한다.
const INK_LINE := 0.42

## 바탕. 순검정이 아니라 **색이 아주 조금 도는 어두운 색**이다.
const _VOID := ["#06151a", "#150a17", "#070f1e", "#12100e"]

## 밝은 판. 미색이되 강조색 쪽으로 아주 살짝 기운다.
const _PAPER := ["#dbe9e6", "#ece0ef", "#dae6f6", "#eae1cf"]

## **신호.** 「지금 여기」 한 곳에만 쓴다.
##
## 「청람」의 전기파랑만 한 번 더 내렸다 — 밝기가 `INK_LINE` 바로 위에 앉아
## **밝은 글자가 겨우 뜨는** 자리였다. 경계에 걸친 색은 밝기를 확실히 한쪽으로 보낸다.
const _ACCENT := ["#12a894", "#c22e86", "#1f5cb4", "#d99a1c"]

## **고름.** 켜져 있는 것 · 골라 둔 것 · 값이 차 있는 쪽.
const _PICK := ["#3559c9", "#6f38c2", "#14a08f", "#17907d"]

## **험.** 되돌릴 수 없는 것.
const _PERIL := ["#cc3f2b", "#d43a4e", "#cf3568", "#cb3a22"]

## 어긋난 뒤판. **고름의 짙은 쪽**이라 판 한 겹이 색으로도 읽히되 신호를 안 뺏는다.
const _BACK := ["#1e3576", "#3c1d78", "#0d5a52", "#0f5148"]

## 브라운관 인광. **면이 아니라 방의 빛**이라 셋 중 어느 신호도 아니다.
const _GLOW := ["#7fe0d0", "#e79bd0", "#8dc4f2", "#f0cf8a"]


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
