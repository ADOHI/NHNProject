class_name HoloPalette
extends RefCounted
## **파스텔 사이버펑크 팔레트.** 색이 여기 한 곳에서만 정해진다.
##
## docs/design/20-ui-kit.md §20.31.
##
## ## 싫었던 것은 색상이 아니라 채도였다
##
## 「네온은 아니게」를 **색상 금지**로 옮긴 것이 틀렸다. 사용자가 싫어한 것은
## **쨍한 채도**지 청록·자홍·보라 자체가 아니다.
##
## > **사이버펑크 색상 그대로 쓰되 채도를 내리고 밝기를 올려 파스텔로.**
## > 형광이 아니라 **뿌옇게 빛나는** 느낌.
##
## ## 왜 한 클래스에 모으나
##
## 색만 바꿔 여러 장을 빨리 찍으려면 **바꾸는 자리가 한 줄이어야 한다.**
## 화면 코드에 색이 흩어져 있으면 팔레트 하나 더 만드는 데 파일을 뒤져야 한다.

## 판을 채우는 강조색과 뒤판 색이 **다를 수 있다** — 둘을 섞은 팔레트가 그것을 쓴다.
const _NAMES := ["박하", "연자", "남보라", "청람", "혼합"]
const _SLUGS := ["mint", "lotus", "iris", "azure", "duo"]

## 바탕. 순검정이 아니라 **색이 아주 조금 도는 어두운 색**이다.
const _VOID := ["#0e1618", "#150f16", "#101020", "#0b1220", "#0d1418"]

## 밝은 판. 미색이되 강조색 쪽으로 아주 살짝 기운다.
const _PAPER := ["#e6f1ef", "#f2e8f0", "#ebeaf7", "#e8eff9", "#e7f0f0"]

## 채워진 판의 강조색. **파스텔이라 채도가 낮고 밝다.**
const _ACCENT := ["#7fd3cc", "#dda2c8", "#a8a1e4", "#8fbcec", "#7fd3cc"]

## 어긋난 뒤판의 색. 대개 강조색과 같고, 「혼합」만 다른 색이다.
const _BACK := ["#7fd3cc", "#dda2c8", "#a8a1e4", "#8fbcec", "#dda2c8"]


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


static func accent(which: int) -> Color:
	return Color(_ACCENT[wrapi(which, 0, count())])


static func back(which: int) -> Color:
	return Color(_BACK[wrapi(which, 0, count())])


## 강조색이 정말 파스텔인가. **채도가 높으면 그 순간 네온이다.**
static func is_pastel(which: int) -> bool:
	var tint := accent(which)
	return tint.s < 0.55 and tint.v > 0.70
