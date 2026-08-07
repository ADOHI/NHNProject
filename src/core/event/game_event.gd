class_name GameEvent
extends RefCounted
## 던전에서 일어난 사건 하나. 렉카 기사와 세계 갱신의 **공통 입력**이다.
##
## 이 구조를 착수 시점에 못 박는 이유는 소비자가 둘이기 때문이다
## (docs/design/16-build-order.md §16.2).
##
##     행동 페이즈 -> 이벤트 로그 -+-> 렉카 기사 생성 (인게임 · 아웃게임 뉴스)
##                                 +-> 세계 갱신 (NPC 상태 반영)
##
## 나중에 만들면 턴 처리 코드를 다시 짜야 한다.
##
## 칸은 넷이다 — 누가 · 어디서 · 무엇을 · 얼마나.
## 렉카 기사에 담기는 요소와 같은 칸이다 (docs/design/08-ui-ux.md §8.3.6).
##
## **여기에 담기는 값은 언제나 진실이다.** 과장은 기사를 만드는 단계에서 일어나고,
## 그것도 magnitude 에만 적용된다. 누가 · 어디서 · 무엇을 은 사실로 보존된다
## (docs/design/13-information-design.md §13.3.1).
## 로그에 과장을 섞으면 세계 갱신까지 오염되어 판 자체가 어긋난다.

## 사건의 종류. "무엇을" 에 해당하며 기사에서 사실로 전달된다.
enum Kind {
	MOVED,  ## 방을 옮겼다
	SEARCHED,  ## 방을 탐색했다
	ACQUIRED,  ## 귀중품을 얻었다
	ENCOUNTERED,  ## 다른 주체와 마주쳤다
	FOUGHT,  ## 전투가 벌어졌다
	NEGOTIATED,  ## 협상이 성립했다
	FLED,  ## 도주했다
	DOWNED,  ## 쓰러졌다 (영구 사망 아님 — docs/design/14-squad.md §14.6)
	ESCAPED,  ## 던전에서 탈출했다
}

## 이 사건이 일어난 턴. 아웃게임 세계 갱신에서 만들어진 사건은 -1 을 쓴다.
var turn: int

## 누가.
var actor_id: String

## 누가 — 표시용 이름.
##
## id 만 두지 않고 이름을 함께 남기는 이유는, 기사가 사건보다 오래 살기 때문이다.
## 죽거나 떠난 주체를 나중에 조회하려 하면 이미 없다.
var actor_name: String

## 어디서.
var room_id: String

## 어디서 — 표시용 이름.
var room_name: String

## 무엇을.
var kind: Kind

## 얼마나. 사건 종류에 따라 뜻이 다르다 (전리품 가치 · 피해량 · 인원 수 등).
##
## **기사에서 유일하게 과장되는 값이다.** 부풀리기만 하고 축소하지 않으므로
## 플레이어는 기사에서 하한선을 읽을 수 있다
## (docs/design/13-information-design.md §13.3).
var magnitude: int

## 이 사건에 함께 엮인 다른 주체들의 id (조우 · 전투 · 협상 상대).
var related_actor_ids: Array[String] = []


func _init(
	event_turn: int,
	event_kind: Kind,
	actor: Actor,
	room: Room,
	event_magnitude: int = 0,
	related: Array[String] = [] as Array[String]
) -> void:
	turn = event_turn
	kind = event_kind
	actor_id = actor.id if actor != null else ""
	actor_name = actor.display_name if actor != null else ""
	room_id = room.id if room != null else ""
	room_name = room.display_name if room != null else ""
	magnitude = event_magnitude
	related_actor_ids = related.duplicate()


## 이 사건이 다른 주체와 얽혀 있는가. 얽힌 사건이 기사 소재로서 가치가 높다.
func involves_others() -> bool:
	return not related_actor_ids.is_empty()
