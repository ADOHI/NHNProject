class_name Actor
extends RefCounted
## 던전 안에 존재하는 행동 주체. 몬스터 · NPC 탐험가 · 플레이어 스쿼드를 모두 이 클래스로 표현한다.
##
## 종류를 나누지 않고 하나로 묶는 이유는 위험도 때문이다.
## 방의 위험도는 그 방에 있는 모든 존재의 전투력 합이며, 몬스터든 탐험가든
## 플레이어든 같은 단위를 쓴다 (docs/design/07-level-design.md §7.2.0).
## 종류별로 클래스를 나누면 합산 로직이 갈라지고, 그 순간 판이 하나의 판이 아니게 된다.
##
## kind 는 합산이 아니라 행동 방식을 가르는 데만 쓴다.
## 몬스터는 대체로 제자리를 지키고 탐험가는 이동한다 —
## 이 차이가 "숫자의 변화량은 사람을 알려 준다"는 추론을 성립시킨다
## (docs/design/13-information-design.md §13.5).

## 행동 주체의 종류. 위험도 합산에는 영향을 주지 않는다.
enum Kind {
	MONSTER,  ## 던전을 지킨다. 대체로 이동하지 않는다
	NPC_EXPLORER,  ## 플레이어와 같은 목표로 움직이는 경쟁자
	PLAYER_SQUAD,  ## 플레이어가 조작하는 스쿼드. 항상 함께 행동한다
}

## 로그·기사에서 이 주체를 가리키는 식별자.
var id: String

## 렉카 기사에 이름으로 등장하기 위한 표시명.
## 이름이 없으면 NPC 는 경쟁자가 아니라 장애물이 된다
## (docs/design/08-ui-ux.md §8.3.6).
var display_name: String

## 종류. 행동 방식만 가른다.
var kind: Kind

## 전투력. 그대로 방의 위험도에 더해진다.
##
## 이 수치는 두 가지를 동시에 뜻한다 — 내 힘이면서, 남에게 보이는 내 크기다.
## 강해지는 것과 눈에 띄는 것이 분리되지 않는다
## (docs/design/14-squad.md §14.3).
var threat: int


func _init(actor_id: String, name: String, actor_kind: Kind, actor_threat: int) -> void:
	id = actor_id
	display_name = name
	kind = actor_kind
	threat = maxi(0, actor_threat)


## 방 사이를 이동하는 종류인가.
##
## 몬스터가 고정이라는 전제가 깨지면 위험도 변화량으로 사람을 추적할 수 없다.
## 이동하는 몬스터를 나중에 넣게 되면 이 함수가 아니라 그 추론 전체를 다시 봐야 한다.
func is_mobile() -> bool:
	return kind != Kind.MONSTER


## 플레이어가 조작하는 주체인가.
func is_player() -> bool:
	return kind == Kind.PLAYER_SQUAD
