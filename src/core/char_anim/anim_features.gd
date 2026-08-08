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

## 좌우 파츠의 차이와 무게 이동. `0` 이면 두 손이 같아지고 발이 죽은 듯 멈춘다.
var asymmetry := 1.0


static func all_on() -> AnimFeatures:
	return AnimFeatures.new()


static func all_off() -> AnimFeatures:
	var f := AnimFeatures.new()
	f.delay = 0.0
	f.arc = 0.0
	f.squash = 0.0
	f.asymmetry = 0.0
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
	return f
