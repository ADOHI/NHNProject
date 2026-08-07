class_name Room
extends RefCounted
## 던전의 방 하나. 위치의 최소 단위이며, 이 게임에서 위치란 곧 방이다.
##
## 통로에는 아무것도 존재하지 않는다. 조우는 전부 방에서만 일어나고,
## 서로 지나쳐 가는 것은 사건이 아니다 (docs/design/05-rules.md §5.6 E1·E2).
## 세계관적으로도 통로는 중계 구역이 아니다 (docs/design/02-overview.md §2.6.1).
##
## 방은 자기 안에 누가 있는지만 안다. 어느 방과 이어져 있는지는 DungeonGraph 가 안다.
## 연결 정보를 방에 두면 양쪽 방을 동시에 고쳐야 해서 한쪽만 갱신되는 사고가 난다.

## 방의 성격. 생성기가 필요 민첩 등급에 따라 배치한다
## (docs/design/07-level-design.md §7.2.9).
enum Kind {
	ENTRANCE,  ## 스쿼드가 시작하는 방
	EMPTY,  ## 통로
	TREASURE,  ## 귀중품
	HAZARD,  ## 함정 · 고위험
	BOSS,  ## 고위험 고보상
	EXIT,  ## 탈출 지점
}

## 그래프에서 이 방을 가리키는 식별자.
var id: String

## 방의 성격.
var kind: Kind = Kind.EMPTY

## 고도. 이동 가능 여부가 이 값의 차이로 결정된다.
##
## 내려가기와 평지는 자유, 올라가기는 상승폭이 민첩 이하일 때만 가능하다
## (docs/design/07-level-design.md §7.2.6).
##
## 화면에서는 이 값이 그대로 Y 축이 된다. 고도가 게임 규칙이면서
## 동시에 레이아웃 축이라, 좌표를 따로 설계하지 않아도 된다.
var elevation: int = 0

## 렉카 기사에 장소로 등장하기 위한 표시명.
##
## 기사에서 장소는 과장 대상이 아니라 사실이다. 여기가 틀리면 기사가 판과 연결되지 않아
## 정보로서 무가치해진다 (docs/design/13-information-design.md §13.3.1).
var display_name: String

var _occupants: Array[Actor] = []


func _init(
	room_id: String, name: String = "", room_elevation: int = 0, room_kind: Kind = Kind.EMPTY
) -> void:
	id = room_id
	display_name = name if not name.is_empty() else room_id
	elevation = room_elevation
	kind = room_kind


## 이 방의 위험도. 안에 있는 모든 존재의 전투력 합이다.
##
## 플레이어에게 공개되는 것은 이 값 자체가 아니라 인접한 방들의 합이며,
## 그 합이 어떻게 구성되어 있는지는 공개되지 않는다
## (docs/design/07-level-design.md §7.2).
func threat() -> int:
	var total := 0
	for actor in _occupants:
		total += actor.threat
	return total


## 이 방에 있는 존재의 수.
##
## 합과 개체 수는 서로 다른 정보다. 합이 6 이고 개체가 1 이면 보스가 확정되고,
## 개체가 4 면 분산이 확정된다. 이 값을 볼 수 있는지는 스쿼드 편성에 달려 있다
## (docs/design/14-squad.md §14.4).
func occupant_count() -> int:
	return _occupants.size()


## 점유자 목록의 복사본. 외부에서 내부 배열을 직접 건드리지 못하게 한다.
func occupants() -> Array[Actor]:
	return _occupants.duplicate()


func has_occupant(actor: Actor) -> bool:
	return _occupants.has(actor)


## 같은 주체를 두 번 넣지 않는다. 중복되면 위험도가 부풀려져 판이 거짓말을 한다.
func add_occupant(actor: Actor) -> void:
	if _occupants.has(actor):
		return
	_occupants.append(actor)


func remove_occupant(actor: Actor) -> void:
	_occupants.erase(actor)
