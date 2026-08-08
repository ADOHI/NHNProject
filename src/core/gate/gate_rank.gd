class_name GateRank
extends RefCounted
## 게이트의 등급. 안쪽 던전의 크기와 보상 배수를 함께 정한다.
##
## 등급 하나가 두 가지를 정하는 이유는 [`06-progression.md`] §6.3 이
## **"던전 선택이 곧 난이도 선택"** 이라고 확정했기 때문이다.
## 난이도와 보상이 따로 놀면 플레이어가 비교할 축이 둘이 되고,
## 그 순간 "위험도 <-> 보상" 이라는 단일 저울이 깨진다.
##
## 크기가 곧 난이도인 것은 잠정이다. 방이 많으면 오래 머물게 되고,
## 오래 머물면 주목도가 오른다 (§6.3). 그래서 지금은 크기 하나로 충분하다.
##
## 수치는 여기 있지만 조정 손잡이는 GuildBalance 다 (docs/design/22-guild-base.md §22.4).
## 등급 자체의 정의는 게이트의 성질이라 여기 남긴다.

## 등급. 낮은 것이 앞이다 — 순서가 곧 접근 순서다.
enum Kind {
	E,  ## 갓 열린 소형 게이트
	D,
	C,
	B,
	A,  ## 길드 하나가 통째로 매달리는 규모
}

const _LABELS := ["E급", "D급", "C급", "B급", "A급"]

## 등급별 던전 크기 단계. SampleDungeons.SIZE_MIN ~ SIZE_MAX 와 같은 축이다.
const _SIZES := [1, 2, 3, 4, 5]

## 등급별 보상 배수. 잠정.
const _REWARD_MULTIPLIERS := [1, 2, 3, 5, 8]


## 등급의 개수. 목록 생성이 이 값을 넘지 않도록 쓴다.
static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 이 등급의 게이트가 여는 던전의 크기 단계.
static func dungeon_size(kind: Kind) -> int:
	return _SIZES[clampi(int(kind), 0, _SIZES.size() - 1)]


## 전리품 배수. 정산에서 자금으로 환산된다 (GuildBalance.loot_for).
static func reward_multiplier(kind: Kind) -> int:
	return _REWARD_MULTIPLIERS[clampi(int(kind), 0, _REWARD_MULTIPLIERS.size() - 1)]


## 길드 등급이 이 게이트를 열 수 있는가.
##
## 등급 번호와 길드 등급을 1 대 1 로 맞춘다 — E급(0)은 길드 등급 1 이면 들어간다.
## 상한을 두는 이유는 게이트 목록이 곧 난이도 선택지이기 때문이다.
## 처음부터 A급이 목록에 있으면 "고르는 재미" 가 "안 되는 것 구경" 이 된다.
static func is_open_to(kind: Kind, guild_rank: int) -> bool:
	return int(kind) < guild_rank
