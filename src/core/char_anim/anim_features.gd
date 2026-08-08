class_name AnimFeatures
extends RefCounted
## 관절 없이 무게를 만드는 수단 넷의 가중치. `0.0` 이면 완전히 끈다.
##
## **결과물의 일부다.** 넷을 다 끄면 "위아래로 뻣뻣하게 진동하는 도형 여섯" 이 되고,
## 그 상태와 켠 상태의 차이가 이 작업의 전부다. 사람이 씬에서 직접 갈라 볼 수 있어야
## 무엇이 무엇을 만드는지 판정할 수 있다 (`docs/design/25-character-animation.md` §25.5).

## 파츠가 몸을 늦게 따라오는 정도. `0` 이면 여섯 파츠가 한 몸으로 움직인다.
var delay := 1.0

## 파츠 경로의 좌우 성분. `0` 이면 직선으로만 오간다 — 머리의 8 자가 사라진다.
var arc := 1.0

## 눌림과 늘어남. `0` 이면 모든 배율이 정확히 `1` 이다.
var squash := 1.0

## 좌우 파츠의 차이와 무게 이동. `0` 이면 발이 죽은 듯 멈춘다.
var asymmetry := 1.0

## **앞뒤.** 먼 파츠가 얼마나 덜, 그리고 얼마나 뭉툭하게 움직이는가.
##
## `0` 이면 뒷손이 앞손과 **똑같이** 움직인다 — 크기만 작을 뿐 궤도가 같아서
## 종이 인형 두 장을 겹친 것처럼 보인다. 사이드 사선에서 이것이 가장 잘 티 나는 실패다.
##
## 켜면 셋이 한꺼번에 걸린다: 진폭이 줄고, 지연이 길어지고, **고주파가 깎인다.**
## 셋째가 「느려 보인다」를 만든다 — 사람은 잔떨림의 양으로 속도를 읽기 때문이다.
var depth := 1.0

## **디딘 발을 땅에 붙여 두는가.** `walk` 부터 쓴다 (idle 은 안 본다).
##
## `1` 이면 땅에 닿아 있는 동안 앞뒤 속도가 **일정**하다 — 지면이 흐르는 속도와 같다.
## `0` 이면 발이 사인파로 앞뒤로 흔들려 **속도가 계속 변하고, 그래서 미끄러진다.**
##
## 걸음에서 가장 잘 보이는 실패가 이것이라 껐다 켤 수 있게 두었다
## (`docs/design/25-character-animation.md` §25.10.4).
var plant := 1.0


static func all_on() -> AnimFeatures:
	return AnimFeatures.new()


static func all_off() -> AnimFeatures:
	var f := AnimFeatures.new()
	f.delay = 0.0
	f.arc = 0.0
	f.squash = 0.0
	f.asymmetry = 0.0
	f.depth = 0.0
	f.plant = 0.0
	return f


## 하나만 끄고 나머지를 켠 상태. 「그 축이 있고 없고」를 나란히 놓을 때 쓴다.
static func without(field: String) -> AnimFeatures:
	var f := AnimFeatures.all_on()
	f.set(field, 0.0)
	return f


## 이름으로 하나만 켜고 나머지를 끈 상태. 어느 축이 무엇을 만드는지 하나씩 볼 때 쓴다.
static func only(field: String) -> AnimFeatures:
	var f := AnimFeatures.all_off()
	f.set(field, 1.0)
	return f


func copy() -> AnimFeatures:
	var f := AnimFeatures.new()
	f.delay = delay
	f.arc = arc
	f.squash = squash
	f.asymmetry = asymmetry
	f.depth = depth
	f.plant = plant
	return f
