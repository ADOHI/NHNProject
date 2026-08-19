class_name EncounterPlanner
extends RefCounted
## NPC 탐험가가 조우에서 무엇을 고르는가. **성향 x 상황이다.**
##
## docs/design/05-rules.md §5.4 · docs/design/35-encounter.md §35.4.
##
## ## 난수로 고르면 안 된다
##
## §5.4 가 협상의 조건을 이렇게 적었다.
##
## > **협상이 성립하려면 플레이어가 상대를 읽을 수 있어야 한다.**
## > 성향이 완전히 숨겨져 있으면 협상은 도박이고, 완전히 공개되면 긴장이 없다.
## > *"단서는 보이지만 확신은 못 한다"* 가 목표 지점이다.
##
## 난수로 고르면 **읽을 것이 없다.** 그러면 조우는 심리전이 아니라 주사위가 되고,
## 렉카 기사가 성향 정보원이 될 이유도 사라진다.
##
## 그래서 선택은 **점수**로 정한다. 점수를 미는 것은 전부 플레이어가 원리상 읽을 수
## 있는 것들이다 — 성향(기사에서 드러난다) · 힘의 차(위험도 숫자) · 짐(기사의 magnitude).
## 난수는 **동점을 가를 때만** 쓰고, 그것도 시드를 받는다.
##
## ## 성향은 여기서 만들지 않는다
##
## `NpcPlanner` 가 이미 성향을 들고 있다 (§33.4). 같은 인물의 성향이 두 곳에 있으면
## 한쪽만 갱신되고, 그때 **이동은 신중한데 조우는 무모한** 인물이 생긴다.
## 원본은 `NpcPlanner` 하나다.
##
## ## 축 넷만 쓴다
##
## `HIERARCHY`(위계/자유) 와 `SHOWY`(과시/은둔) 는 소속과 평판의 축이라
## 조우 한 번에서 뜻을 갖게 하려면 억지가 들어간다. §33.4 가 같은 태도로 다섯을
## 남겨 뒀고 그 판단이 옳았다 — 그때 억지로 썼으면 지금 여기서 다시 정의하고 있을 것이다.

## 힘의 차 1당 점수. 조우 판단에서 가장 무거운 항이다.
const FORCE_WEIGHT := 4

## 짐 1당 점수. 내 짐은 도주를, 상대의 짐은 전투를 민다.
const LOAD_WEIGHT := 3

## 성향 100 이 내는 점수. 100 / 10 = 10 점이 한 축의 최대 기여다.
const AXIS_DIVISOR := 10

## 이번 판에 한 번 누울 때마다 도주로 기우는 폭. **부상의 자리다** (§35.7).
const DOWN_WEIGHT := 10

## 힘이 정확히 같을 때 협상이 갖는 값. 여기서 힘의 차만큼 깎인다.
const PARITY_BASE := 20

## 성향 축이 점수에 실리는 배수. 축마다 성질이 달라 따로 둔다.
const PULL_STRONG := 4
const PULL_MID := 3
const PULL_WEAK := 2

var _npc: NpcPlanner
var _haul: Haul
var _rng := RandomNumberGenerator.new()

## 주체 id -> 플레이어에 대한 친밀도(-100 ~ 100). 안 넣으면 0(모르는 사이)이다.
var _affinity: Dictionary = {}


func _init(npc_planner: NpcPlanner, haul: Haul, planner_seed: int = 0) -> void:
	_npc = npc_planner
	_haul = haul
	_rng.seed = planner_seed


## 친밀도를 넣는다. **이 레인은 관계도를 직접 읽지 않는다** (§35.4.3) —
## 인물 번호와 판의 id 를 잇는 것은 세계와 판을 잇는 자리의 일이다.
func set_affinity(actor_id: String, value: int) -> void:
	_affinity[actor_id] = clampi(value, RelationGraph.AFFINITY_MIN, RelationGraph.AFFINITY_MAX)


func affinity_of(actor_id: String) -> int:
	return int(_affinity.get(actor_id, 0))


## 그 NPC 의 선택과 근거.
##
## `here` 는 자기를 포함한 그 방의 전원이다. `allies` 는 **직전 턴에 함께한 자들**이고,
## 그 안에 지금 눈앞에 있는 자가 있으면 배신이 열린다 (E8 · §35.4.2).
func plan_for(
	actor: Actor, here: Array[Actor], stakes: EncounterStakes, allies: Array[String], downs: int = 0
) -> EncounterPlan:
	var situation := _situation(actor, here, stakes, allies, downs)
	var scores: Array[int] = []
	var top := -1 << 30
	for slot in EncounterChoice.count():
		var score := _score_of(slot as EncounterChoice.Kind, situation)
		scores.append(score)
		top = maxi(top, score)

	# 동점은 시드로 가른다. 전역 난수를 쓰지 않는다 — 같은 시드가 같은 판을 내야
	# 이상한 판이 나왔을 때 다시 볼 수 있다 (§35.4.5).
	var tied: Array[int] = []
	for slot in EncounterChoice.count():
		if scores[slot] == top:
			tied.append(slot)
	var picked: int = tied[0] if tied.size() == 1 else tied[_rng.randi_range(0, tied.size() - 1)]

	var best := picked as EncounterChoice.Kind
	var plan := EncounterPlan.new(actor.id, best, _reason_for(best, situation))
	plan.scores = scores
	return plan


# ---------------------------------------------------------------- 상황


## 점수의 입력을 한 번에 모은다.
##
## 항마다 방을 다시 훑으면 같은 값을 네 번 세게 되고, 그때 한 곳만 고치면
## 선택지끼리 **다른 상황을 보고 다투게** 된다.
func _situation(
	actor: Actor, here: Array[Actor], stakes: EncounterStakes, allies: Array[String], downs: int
) -> Dictionary:
	var traits := _npc.temperament_of(actor.id)
	var rivals := 0
	var rival_count := 0
	var monsters := 0
	var rival_load := 0
	var affinity_sum := 0
	var betrayable := false
	for other in here:
		if other.id == actor.id:
			continue
		if other.kind == Actor.Kind.MONSTER:
			monsters += other.threat
			continue
		rivals += other.threat
		rival_count += 1
		rival_load += _haul.carried_by(other.id)
		affinity_sum += affinity_of(other.id)
		if allies.has(other.id):
			betrayable = true
	return {
		"mine": actor.threat,
		"rivals": rivals,
		"rival_count": rival_count,
		"monsters": monsters,
		"my_load": _haul.carried_by(actor.id),
		"rival_load": rival_load,
		"downs": maxi(0, downs),
		"affinity": affinity_sum / maxi(1, rival_count),
		"betrayable": betrayable,
		"pot": stakes.pot if stakes != null else 0,
		"flight_bonus": stakes.flight_bonus if stakes != null else 0,
		"reckless": traits[int(NpcAxis.Kind.RECKLESS)],
		"good": traits[int(NpcAxis.Kind.GOOD)],
		"loyal": traits[int(NpcAxis.Kind.LOYAL)],
		"honest": traits[int(NpcAxis.Kind.HONEST)],
	}


# ---------------------------------------------------------------- 점수


func _score_of(kind: EncounterChoice.Kind, s: Dictionary) -> int:
	var total := 0
	for term in _terms_of(kind, s):
		total += int(term[1])
	return total


## 그 선택지를 미는 항들. `[이름, 점수]` 의 목록이고 합이 곧 점수다.
##
## 이름을 값과 함께 드는 이유는 근거 문장이 여기서 나오기 때문이다 —
## 문장을 따로 지어내면 점수와 설명이 갈린다 (§35.4.4).
func _terms_of(kind: EncounterChoice.Kind, s: Dictionary) -> Array:
	match kind:
		EncounterChoice.Kind.FIGHT:
			return _fight_terms(s)
		EncounterChoice.Kind.NEGOTIATE:
			return _negotiate_terms(s)
		EncounterChoice.Kind.FLEE:
			return _flee_terms(s)
		EncounterChoice.Kind.COOPERATE:
			return _cooperate_terms(s)
		_:
			# 대치는 **안 고른 것**이므로 NPC 가 고를 것이 못 된다 (§35.1.2).
			return [["", -999]]


func _fight_terms(s: Dictionary) -> Array:
	var force := int(s["mine"]) - int(s["rivals"]) - int(s["monsters"])
	var terms: Array = [
		["유리하다" if force >= 0 else "불리하다", force * FORCE_WEIGHT],
		["뺏을 것이 있다", int(s["rival_load"]) * LOAD_WEIGHT],
		["판돈이 크다", int(s["pot"])],
		["무모하다", int(s["reckless"]) * PULL_MID / AXIS_DIVISOR],
		["악하다", -int(s["good"]) * PULL_WEAK / AXIS_DIVISOR],
		["사이가 나쁘다", -int(s["affinity"]) * PULL_MID / AXIS_DIVISOR],
		["지쳤다", -int(s["downs"]) * DOWN_WEIGHT],
	]
	if bool(s["betrayable"]):
		# **E8 — 협력과 배신.** 조우가 여러 턴에 걸치므로 배신이 표현될 자리가 생겼다.
		# 기만 쪽(`HONEST` 가 음수)일수록 어제의 동료를 오늘 친다.
		terms.append(["배신한다", -int(s["honest"]) * PULL_STRONG / AXIS_DIVISOR])
	return terms


func _negotiate_terms(s: Dictionary) -> Array:
	var gap: int = absi(int(s["mine"]) - int(s["rivals"]))
	return [
		["대등하다", PARITY_BASE - gap * PULL_WEAK],
		["나눌 것이 있다", int(s["pot"]) * PULL_WEAK],
		["선하다", int(s["good"]) * PULL_MID / AXIS_DIVISOR],
		["사이가 좋다", int(s["affinity"]) * PULL_STRONG / AXIS_DIVISOR],
		["말로 푼다", int(s["honest"]) * PULL_WEAK / AXIS_DIVISOR],
		# 몬스터는 협상하지 않는다. 말을 걸 상대가 아니다.
		["몬스터가 있다", -int(s["monsters"]) * PULL_WEAK],
	]


func _flee_terms(s: Dictionary) -> Array:
	var force := int(s["rivals"]) + int(s["monsters"]) - int(s["mine"])
	return [
		["불리하다" if force >= 0 else "유리하다", force * FORCE_WEIGHT],
		["잃을 것이 많다", int(s["my_load"]) * LOAD_WEIGHT],
		["신중하다", -int(s["reckless"]) * PULL_STRONG / AXIS_DIVISOR],
		["이미 한 번 눕었다", int(s["downs"]) * DOWN_WEIGHT],
		["도망칠 만한 방이다", int(s["flight_bonus"]) / PULL_STRONG],
	]


func _cooperate_terms(s: Dictionary) -> Array:
	if int(s["monsters"]) <= 0 or int(s["rival_count"]) <= 0:
		# 협력할 상대나 상대할 몬스터가 없다. `EncounterChoice.settle()` 이
		# 어차피 전투로 내리므로 여기서 고르게 두면 근거만 이상해진다.
		return [["", -999]]
	return [
		["몬스터가 세다", int(s["monsters"]) * PULL_MID],
		["의리가 있다", int(s["loyal"]) * PULL_STRONG / AXIS_DIVISOR],
		["사이가 좋다", int(s["affinity"]) * PULL_WEAK / AXIS_DIVISOR],
	]


# ---------------------------------------------------------------- 근거


## 점수를 가장 크게 민 항 둘. **깎은 항은 근거가 아니다** — 왜 골랐는지를 묻는 것이므로.
func _reason_for(kind: EncounterChoice.Kind, s: Dictionary) -> String:
	var pushing: Array = []
	for term in _terms_of(kind, s):
		if int(term[1]) > 0 and not str(term[0]).is_empty():
			pushing.append(term)
	if pushing.is_empty():
		return "달리 고를 것이 없다"
	pushing.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var names: Array[String] = []
	for index in mini(2, pushing.size()):
		names.append(str(pushing[index][0]))
	return ", ".join(names)
