class_name EncounterStakes
extends RefCounted
## **E5 — 특수방에서 마주쳤을 때.** 방이 조우에서 무엇을 바꾸는가.
##
## docs/design/05-rules.md §5.6 E5 가 *"보류 — 구현하며 결정"* 으로 남긴 것을
## docs/design/35-encounter.md §35.3.2 가 이렇게 채웠다.
##
## > **방은 분기를 바꾸지 않는다. 방은 판돈과 확률을 바꾼다.**
##
## ## 왜 분기를 안 바꾸나
##
## 분기를 방마다 다르게 하면 §5.8 의 흐름도가 방 종류만큼 갈라진다.
## 그러면 플레이어가 조우마다 **다른 게임**을 배워야 하고, 동시 선택의 심리전이
## *"이 방에서는 무엇을 고를 수 있더라"* 라는 암기 문제로 바뀐다.
##
## 판돈만 바꾸면 **같은 세 선택지가 방마다 다른 값을 갖는다.**
## 그것이 방을 고르는 이유가 되고, docs/design/07-level-design.md 가 방에 성격을
## 준 목적이 조우에서도 살아난다.
##
## ## 이 클래스가 없으면 방 조건이 해결기에 흩어진다
##
## 「함정방이면」 · 「탈출 지점이면」 · 「귀중품이 남아 있으면」이 판정마다 박히면
## E5 를 다시 손볼 때 그 `if` 를 전부 찾아야 한다. **한 곳에 모은다.**

## 함정방의 도주 보정(%p). **잠정** (§35.7).
##
## 함정방을 「그냥 나쁜 방」이 아니라 **쓸 데가 있는 방**으로 만든다 —
## 어수선한 곳은 도망치기 좋다.
const HAZARD_FLIGHT_BONUS := 20

## 이 조우가 벌어진 방의 성격.
var room_kind: Room.Kind = Room.Kind.EMPTY

## 방에 걸린 귀중품. **이긴 편이 가져가고, 협상이 성립하면 나눈다.**
##
## *"늦으면 이미 털려 있다"* (docs/design/05-rules.md §5.2)가 조우에서도
## 성립해야 한다. 조우가 났다고 방의 귀중품이 얼어붙으면, 마주친 자리에서
## 아무도 못 줍고 둘 다 물러난 뒤에 제3자가 줍는다.
var pot: int = 0

## 도주 성공 확률에 얹히는 값(%p).
var flight_bonus: int = 0

## 도주하면 탈출 진행이 0 으로 돌아가는가. **탈출 지점에서만 참이다.**
##
## docs/design/05-rules.md §5.9 — *"다 챙기고 문 앞에서 죽는 것"* 이 이 게임의
## 절정이다. **문 앞에서 물러나는 데 대가가 없으면 절정이 없다.**
var flight_clears_escape: bool = false


## 방과 그 방에 남은 귀중품으로 판돈을 짠다.
static func of(kind: Room.Kind, loot_value: int) -> EncounterStakes:
	var stakes := EncounterStakes.new()
	stakes.room_kind = kind
	stakes.pot = maxi(0, loot_value)
	stakes.flight_bonus = HAZARD_FLIGHT_BONUS if kind == Room.Kind.HAZARD else 0
	stakes.flight_clears_escape = kind == Room.Kind.EXIT
	return stakes


func has_pot() -> bool:
	return pot > 0


## 협상이 성립했을 때 한 사람의 몫. **나머지는 방에 남는다.**
##
## 나눠떨어지지 않는 것을 누구에게 얹으면 "누구부터 세는가"가 규칙이 된다.
## 방에 남기면 아무도 안 유리하고, 남은 것이 다음 조우의 판돈이 된다.
func share_for(count: int) -> int:
	if count <= 0:
		return 0
	return pot / count


## 위처럼 나누고 방에 남는 값.
func remainder_for(count: int) -> int:
	if count <= 0:
		return pot
	return pot - share_for(count) * count
