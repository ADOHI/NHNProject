class_name TurnIntent
extends RefCounted
## 한 주체가 이번 턴에 하려는 일. 계획 페이즈의 산출물이자 행동 페이즈의 입력이다.
##
## 이 구조를 2단계 착수 시점에 못 박는 이유는 생산자가 셋이기 때문이다
## (docs/design/16-build-order.md §16.4).
##
##     계획 페이즈 -+- 플레이어 조작 (화면)
##                  +- NPC 탐험대 행동 결정 (자동)
##                  +- 몬스터 (대체로 STAY)
##                          |
##                          v
##                     행동 페이즈 (동시 해결) --> 이벤트 로그
##
## 셋이 같은 형태로 의도를 내야 해결기가 **누가 냈는지 모른 채** 처리할 수 있다.
## 플레이어만 특별 취급하는 경로가 하나라도 생기면 동시성이 거기서 깨진다.
##
## **의도는 약속이지 결과가 아니다.** 낼 때 갈 수 있었다고 해서 성사되지는 않는다.
## 동시 해결이므로 남이 무엇을 할지 모르는 채로 내기 때문이다
## (docs/design/03-core-loop.md §3.6).
## 그래서 유효성 검사는 제출 시점이 아니라 **해결 시점에 다시** 한다.

## 하려는 일의 종류.
enum Kind {
	STAY,  ## 제자리를 지킨다. 의도를 내지 않은 주체의 기본값이다
	MOVE,  ## 인접한 방으로 옮긴다
	SEARCH,  ## 지금 방을 뒤진다
}

## 누가. Actor 참조가 아니라 id 를 드는 이유는, 의도가 해결 도중 살아 있어야 하고
## 그 사이 주체 목록이 바뀔 수 있기 때문이다.
var actor_id: String

## 무엇을.
var kind: Kind

## 어디로. MOVE 가 아니면 언제나 비어 있다.
var target_room_id: String


func _init(intent_actor_id: String, intent_kind: Kind, target: String = "") -> void:
	actor_id = intent_actor_id
	kind = intent_kind
	target_room_id = target if intent_kind == Kind.MOVE else ""


## 인접한 방으로 옮기려는 의도.
static func move(intent_actor_id: String, room_id: String) -> TurnIntent:
	return TurnIntent.new(intent_actor_id, Kind.MOVE, room_id)


## 제자리를 지키려는 의도. 의도를 내지 않은 주체에게도 이것이 주어진다.
##
## "아무것도 하지 않음"을 빈 값이 아니라 명시적 의도로 두는 이유는,
## 해결기가 모든 주체를 같은 방식으로 훑을 수 있어야 하기 때문이다.
## 빠진 주체를 따로 처리하는 분기는 반드시 빠뜨리는 곳이 생긴다.
static func stay(intent_actor_id: String) -> TurnIntent:
	return TurnIntent.new(intent_actor_id, Kind.STAY)


## 지금 방을 뒤지려는 의도.
static func search(intent_actor_id: String) -> TurnIntent:
	return TurnIntent.new(intent_actor_id, Kind.SEARCH)


func is_move() -> bool:
	return kind == Kind.MOVE


## 판을 바꾸는 의도인가. STAY 는 아무 사건도 남기지 않는다.
func changes_board() -> bool:
	return kind != Kind.STAY
