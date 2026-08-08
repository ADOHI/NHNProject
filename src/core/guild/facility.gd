class_name Facility
extends RefCounted
## 아지트의 시설 종류. 대원을 배치하면 효과가 붙는다 — 삼국지의 내정 개념이다.
##
## ## 배치가 결정이 되는 이유는 하나다
##
## **던전에 데려간 대원은 시설 효과를 내지 못한다.**
##
## 스쿼드 정원이 계열 수보다 작으므로(docs/design/14-squad.md §14.4.3)
## 데려갈 사람을 고르면 반드시 남는 사람이 생기고, 남는 사람을 어디에 둘 것인가가
## 다음 결정이 된다. **두 결정이 같은 인원 풀을 놓고 다툰다.**
##
## ## 세 시설은 방향이지 확정이 아니다
##
## 종류를 늘리거나 바꿀 때 손댈 곳은 이 enum 과 GuildBalance 두 군데다
## (docs/design/22-guild-base.md §22.4).

enum Kind {
	WORKSHOP,  ## 공방 — 아지트 업그레이드 속도 상승
	INTEL_ROOM,  ## 정보실 — 게이트 정보를 더 많이 본다
	CONTACT_POINT,  ## 접선처 — 영입 후보를 먼저 찾는다
}

const _LABELS := ["공방", "정보실", "접선처"]

const _NOTES := [
	"아지트 진척이 빨라진다",
	"게이트를 더 자세히 본다",
	"영입 후보를 먼저 찾는다",
]


static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 화면에 붙는 한 줄 설명.
static func note(kind: Kind) -> String:
	return _NOTES[clampi(int(kind), 0, _NOTES.size() - 1)]


## 정의된 모든 시설. 화면이 순서대로 훑을 수 있게 한다.
static func all() -> Array[int]:
	var kinds: Array[int] = []
	for index in _LABELS.size():
		kinds.append(index)
	return kinds
