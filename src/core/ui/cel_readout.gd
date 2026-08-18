class_name CelReadout
extends RefCounted
## **아무 정보도 없는 정보.** 90년대 셀 화면의 구석을 채우는 것들.
##
## docs/design/20-ui-kit.md §20.29.
##
## ## 이게 왜 핵심인가
##
## 1995년의 애니메이터가 손으로 셀에 그린 컴퓨터 화면은 **진짜 컴퓨터 UI 가 아니라
## 컴퓨터 UI 의 그림**이다. 그래서 정확하지 않고, 예쁘고, **실제로는 아무것도 안 가리키는
## 눈금이 잔뜩** 있다. 그 잔뜩이 「손으로 그린 미래」를 만든다.
##
## ## 그러나 장식과 신호를 갈라야 한다
##
## > **장식은 흐리고 작게. 진짜 신호는 하나만.**
##
## 안 가르면 §20.1 이 죽은 자리로 돌아간다 — *"이건 무슨 수학 같음"*.
## 그래서 이 클래스가 내는 것은 전부 **읽으라고 내는 것이 아니다.** 부르는 쪽이
## 흐린 색으로만 쓰게 이름을 그렇게 지었다(`noise_*`).
##
## ## 값이 시각의 함수다
##
## 난수를 들고 있지 않고 **시각에서 계산한다.** 그래야 캡처가 같은 편을 다시 뽑고
## (§20.21.1), 되감아도 같은 숫자가 나온다.


## 뜻 없는 숫자열. 자리 수가 고정이라 폭이 안 흔들린다 —
## **폭이 흔들리면 눈이 그리로 간다.** 장식은 눈을 안 끌어야 장식이다.
static func noise_digits(slot: int, t: float, digits: int = 4) -> String:
	var span := int(pow(10.0, float(digits)))
	# 슬롯마다 다른 속도로 돈다. 같은 속도면 전부 한 몸으로 보인다.
	var rate := 0.7 + float(slot % 5) * 0.9
	var raw := int(abs(sin(float(slot) * 12.9898) * 43758.5453)) + int(t * rate * 97.0)
	return str(raw % span).pad_zeros(digits)


## 십육진 조각. 숫자열만 있으면 계기판이 되고, 섞으면 「기계」가 된다.
static func noise_hex(slot: int, t: float, digits: int = 2) -> String:
	var span := int(pow(16.0, float(digits)))
	var raw := int(abs(cos(float(slot) * 7.717) * 24634.6345)) + int(t * 3.0)
	return String.num_int64(raw % span, 16).to_upper().pad_zeros(digits)


## 눈금 하나가 **의미 없이** 흔들리는 양(px). 아주 작아야 한다 —
## 크게 흔들면 고장 난 화면이고, 안 흔들면 죽은 화면이다.
static func tick_jitter(slot: int, t: float, reach: float = 1.0) -> float:
	return sin(t * (2.3 + float(slot % 7) * 0.6) + float(slot) * 1.7) * reach


## 돌아가는 표시자의 각도. 슬롯마다 속도가 다르다.
static func spinner(slot: int, t: float) -> float:
	return t * (0.6 + float(slot % 4) * 0.35) * TAU * 0.25 + float(slot)


## 막대 하나가 차 있는 정도 0..1. **아무것도 안 가리킨다.**
static func noise_level(slot: int, t: float) -> float:
	var a := sin(t * (0.9 + float(slot % 3) * 0.5) + float(slot) * 2.1)
	var b := sin(t * (2.7 + float(slot % 5) * 0.3) + float(slot))
	return clampf(0.5 + a * 0.28 + b * 0.12, 0.05, 0.98)


## 한 줄씩 그려지며 나타나는 판에서, 지금 몇 줄까지 그려졌나.
##
## **판이 통째로 뜨지 않고 한 줄씩 그려지는 것**이 이 시대의 표시 방법이다.
static func drawn_rows(rows: int, since: float, per_row: float = 0.035) -> int:
	if since < 0.0:
		return 0
	return clampi(int(since / maxf(per_row, 0.001)), 0, rows)
