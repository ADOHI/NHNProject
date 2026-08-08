class_name GuildBalance
extends RefCounted
## 아웃게임 수치와 계산식이 **전부** 모여 있는 곳.
##
## docs/design/06-progression.md §6.5 — "조정할 수치는 한 곳에 모은다.
## 마감 직전에 밸런스를 만질 시간은 짧고, 그때 코드를 뒤지면 늦는다."
##
## ## 값만이 아니라 식까지 여기 둔 이유
##
## 값만 모으고 식을 여기저기 두면, 밸런스를 만질 때 결국 식을 고치게 되어
## 같은 일이 된다. 시설 효과가 어떻게 수치로 바뀌는지까지 이 파일에서 끝난다.
##
## **전부 잠정이다.** 시설 종류가 통째로 갈릴 것을 전제로 짰다
## (docs/design/22-guild-base.md §22.4). 갈릴 때 손댈 곳은 이 파일과
## Facility.Kind 두 군데다.

# ---------------------------------------------------------------- 시작 상태

## 시작 자금.
const STARTING_FUNDS := 0

## 시작 아지트 레벨. 이 값이 곧 길드 등급이기도 하다 (§22.10).
const STARTING_BASE_LEVEL := 1

# ---------------------------------------------------------------- 스쿼드 정원

## 기본 정원. 계열 수(5)보다 반드시 작아야 한다 (docs/design/14-squad.md §14.4.3).
const SQUAD_CAPACITY_BASE := 3

## 정원 상한. 계열 수를 넘으면 편성이 결정이 아니게 된다.
const SQUAD_CAPACITY_MAX := 4

## 이 아지트 레벨에서 정원이 하나 늘어난다.
const SQUAD_CAPACITY_LEVEL := 3

# ---------------------------------------------------------------- 시설

## 시설 하나에 배치할 수 있는 인원.
##
## 무제한이면 "누굴 어디에" 가 아니라 "전부 한 곳에" 가 정답이 된다.
const FACILITY_CAPACITY := 2

# ---------------------------------------------------------------- 공방

## 원정 한 번에 들어오는 기본 진척.
const BASE_PROGRESS_PER_RUN := 1

## 공방에 남은 대원 한 명당 추가 진척.
const BASE_PROGRESS_PER_WORKSHOP_STAFF := 2

## 레벨 하나를 올리는 데 필요한 진척.
const BASE_PROGRESS_TO_LEVEL := 6

## 아지트 레벨 상한. 게이트 등급 수와 맞춘다.
const BASE_LEVEL_MAX := 5

# ---------------------------------------------------------------- 정보실

## 정보실 인원이 이 수 이상이면 정찰 수준.
const INTEL_STAFF_FOR_SURVEYED := 1

## 정보실 인원이 이 수 이상이면 해부 수준.
const INTEL_STAFF_FOR_MAPPED := 2

# ---------------------------------------------------------------- 접선처

## 접선처에 남은 대원 한 명당 찾아내는 영입 후보 수.
const PROSPECTS_PER_CONTACT_STAFF := 1

## 후보 명단이 쌓일 수 있는 최대치. 넘치면 오래된 것부터 밀려난다.
const PROSPECT_POOL_MAX := 5

# ---------------------------------------------------------------- 게이트 목록

## 한 번에 열려 있는 게이트 수. 한 화면에 놓고 비교할 수 있는 최소다.
const GATE_BOARD_SIZE := 4

# ---------------------------------------------------------------- 전리품

## 탈출에 성공했을 때의 기본 전리품.
const LOOT_BASE := 4

## 던전 안에서 보낸 턴 하나당 전리품.
##
## 오래 머물수록 더 번다 — 그리고 오래 머물수록 위험해진다
## (docs/design/06-progression.md §6.3 주목도). 저울이 여기서 걸린다.
const LOOT_PER_TURN := 2


## 아지트 레벨에 따른 스쿼드 정원.
static func squad_capacity(base_level: int) -> int:
	var capacity := SQUAD_CAPACITY_BASE
	if base_level >= SQUAD_CAPACITY_LEVEL:
		capacity += 1
	return mini(capacity, SQUAD_CAPACITY_MAX)


## 원정 한 번으로 들어오는 아지트 진척.
##
## **실패해도 들어온다.** 공방에 남은 사람은 계속 일했다.
## docs/design/14-squad.md §14.6 의 "빈손 귀환" 은 전리품 얘기지 주둔지 얘기가 아니다
## (docs/design/06-progression.md §6.1 — 주둔지는 잃지 않는다).
static func base_progress_for(workshop_staff: int) -> int:
	return BASE_PROGRESS_PER_RUN + maxi(0, workshop_staff) * BASE_PROGRESS_PER_WORKSHOP_STAFF


## 이번 원정의 전리품을 자금으로 환산한다.
##
## 실패하면 0 이다 — 대원은 죽지 않고 전리품만 잃는다 (§14.6).
static func loot_for(rank: GateRank.Kind, turns: int, escaped: bool) -> int:
	if not escaped:
		return 0
	var raw := LOOT_BASE + maxi(0, turns) * LOOT_PER_TURN
	return raw * GateRank.reward_multiplier(rank)


## 접선처가 이번에 찾아내는 영입 후보 수.
static func prospects_for(contact_staff: int) -> int:
	return maxi(0, contact_staff) * PROSPECTS_PER_CONTACT_STAFF
