class_name TypeGrid
extends RefCounted
## 활자 격자. **이 컨셉의 중심이다.**
##
## 앞 판이 「타이포그래피가 없다」는 지적을 받은 자리다 (§20.3 ④).
## 폰트를 추가할 수 없으므로(SongMyung 하나, 굵기 하나) 위계를 굵기에서 만들 수 없다.
## 대신 **활자를 셀에 앉힌다** — 글자마다 폭이 같은 칸을 하나씩 차지한다.
##
## 이것이 세 가지를 한꺼번에 푼다.
##
##   **위계** — 셀 크기가 급이다. 본문 셀 · 두 배 셀 · 네 배 셀
##   **자간** — 셀이 정해지면 자간이 저절로 고르다. 따로 벌릴 필요가 없다
##   **정렬** — 모든 것이 같은 격자에 앉으므로 여백이 우연이 아니다
##
## 그리고 이 격자는 **디지털과 클래식이 만나는 자리**다. 납활자를 조판대에 앉히는 것과
## 화면이 문자 셀에 글자를 찍는 것이 같은 일이다. 장식을 섞은 것이 아니라
## **두 기술이 실제로 공유하는 구조**를 쓴 것이다.
##
## 한글 음절은 원래 정사각형이라 셀에 그대로 맞고, 라틴 글자와 숫자도 같은 칸을 쓴다
## (전각). 동아시아 조판의 사실이고, 화면이 문자 셀을 쓰는 방식과도 같다.

## 급. 값은 셀 폭이고, 글자 크기는 그 함수다.
enum Rank {
	MICRO,  ## 안 읽어도 되는 말
	BODY,  ## 본문
	HEAD,  ## 제목
	DISPLAY,  ## 표제
}

## 셀 폭. 전부 본문 셀(13)의 정수배이거나 그 약수라 어느 급이든 같은 격자에 앉는다.
const _CELL_WIDTH: Array[float] = [10.0, 13.0, 19.5, 39.0]

## 셀 높이. 폭의 1.72배로 잡았다 — 한글 음절이 정사각형이라 위아래 여유가 필요하다.
const _CELL_HEIGHT: Array[float] = [17.0, 22.0, 33.0, 66.0]

## 글자 크기는 셀 폭보다 조금 작다. 꽉 채우면 이웃 글자와 붙는다.
const _FONT_SIZE: Array[int] = [11, 14, 21, 42]

## 괘선 굵기 둘. 셋을 두면 어느 것이 무거운지 알 수 없게 된다.
const RULE_HAIR: float = 1.0
const RULE_THICK: float = 3.0

## 여백의 원자. 본문 셀 높이의 절반이다 — 여백도 격자에서 나와야 한다.
const GUTTER: float = 11.0


static func cell(rank: Rank) -> Vector2:
	return Vector2(_CELL_WIDTH[rank], _CELL_HEIGHT[rank])


static func font_size(rank: Rank) -> int:
	return _FONT_SIZE[rank]


## 글자 수만큼의 폭. 셀 격자이므로 글꼴 측정이 필요 없다 — **폭이 미리 정해져 있다.**
##
## 이것이 격자의 실질적인 이득이다. 글자가 바뀌어도 자리가 안 흔들리므로
## 배치를 미리 짤 수 있고, 갱신되는 화면에서 글자가 바뀔 때 판이 출렁이지 않는다.
static func width_of(text: String, rank: Rank) -> float:
	return float(text.length()) * _CELL_WIDTH[rank]


## 격자에 맞춰 올림한다. 어떤 치수든 셀의 정수배여야 한다.
static func snap(value: float, rank: Rank = Rank.BODY) -> float:
	var unit := _CELL_WIDTH[rank]
	return ceilf(value / unit) * unit
