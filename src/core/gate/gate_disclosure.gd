class_name GateDisclosure
extends RefCounted
## 게이트에 대해 입장 전에 볼 수 있는 것의 양.
##
## docs/design/06-progression.md §6.2 는 **정보 확장 계열이 이 게임과 가장 잘 맞는다**고
## 확정했다. 주둔지 강화가 능력치가 아니라 **판단 재료**를 늘리는 쪽으로 가야 한다는 뜻이고,
## 이 클래스가 그 재료의 양을 정한다.
##
## ## 왜 길드를 모르는가
##
## 이 클래스는 정보실 인원 수를 **int 로만** 받는다 (docs/design/22-guild-base.md §22.5).
## 길드를 참조하면 게이트를 단독으로 테스트할 수 없고, 나중에 장비나 아이템이
## 공개 수준을 올리게 됐을 때 여기를 다시 고쳐야 한다.

## 공개 수준. 낮은 것이 앞이다.
enum Level {
	RUMOR,  ## 소문. 이름과 등급만
	SURVEYED,  ## 정찰. 대략적인 방 개수까지
	MAPPED,  ## 해부. 실제 구성까지
}

const _LABELS := ["소문", "정찰", "해부"]


static func label(level: Level) -> String:
	return _LABELS[clampi(int(level), 0, _LABELS.size() - 1)]


## 정보실에 남아 있는 인원 수로 공개 수준을 정한다.
##
## **남아 있는** 인원이라는 점이 핵심이다. 던전에 데려간 대원은 시설에서 일하지 않는다
## (docs/design/22-guild-base.md §22.4). 그래서 정보실 인원을 데려가면
## 다음 게이트 목록이 도로 흐려진다 — 편성과 배치가 같은 인원을 놓고 다툰다.
static func level_for(intel_staff: int, surveyed_at: int, mapped_at: int) -> Level:
	if intel_staff >= mapped_at:
		return Level.MAPPED
	if intel_staff >= surveyed_at:
		return Level.SURVEYED
	return Level.RUMOR


## 이 수준에서 던전 설계도를 실제로 만들어 봐야 하는가.
##
## 소문 · 정찰 단계에서 미리 만들어 두면 보지도 않을 정보를 위해 판을 통째로 돌린다.
## 씨앗이 고정이라 나중에 만들어도 같은 판이 나오므로 미리 만들 이유가 없다.
static func needs_blueprint(level: Level) -> bool:
	return level >= Level.MAPPED
