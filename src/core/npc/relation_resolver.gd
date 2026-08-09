class_name RelationResolver
extends RefCounted
## 사건 하나를 받아 관계 그래프를 갱신한다. **이 게임의 관계는 전부 여기를 지난다.**
##
## docs/design/24-npc-relations.md §24.4 · §24.6 · §24.21.5.
##
## ## 규칙 하나로 모든 사건 × 모든 인물이 갈린다
##
##     호감 변화(목격자) = dot(사건 벡터, 목격자 성향) / (Σ|벡터| × 100) × 강도 × 관여도
##
## 특별 케이스 표를 쓰지 않는다 (설계 24.4). 사건을 하나 더 만드는 값은
## `RelationEvent` 에 벡터 한 줄이고, 이 파일은 안 바뀐다.
##
## ## 역할 셋이 서로 다른 계산이다 (설계 24.6 · 24.21.5)
##
## | 역할 | 무엇이 바뀌나 | 성향을 타나 |
## | --- | --- | --- |
## | **행위자** | 유대만. 평판은 미구현 | **아니다** |
## | **대상** | 호감이 가장 크게. 유형과 근거 사건이 남는다 | **아니다** — 당한 건 당한 것이다 |
## | **목격자** | 호감만. **유대는 안 오른다** | **여기서만 탄다** |
##
## **목격자 계산이 이 시스템의 전부다.** 나머지 둘은 사실 관계라 성향을 안 탄다.
##
## ## 목격자는 유대가 안 오른다 — 희소성이 거기 걸려 있다
##
## 보는 것은 엮이는 것이 아니다. 유대가 오르면 **사건 한 번에 목격자 전원이
## 서로 아는 사이가 되어** 설계 24.2 의 희소가 무너진다.
##
## 그래서 목격자가 남기는 것은 **유대 0 짜리 한쪽뿐인 관계**다 —
## *"나는 저 사람을 알지만 저 사람은 나를 모른다."* 설계 24.21.2 가 비대칭을 고른
## 이유가 화면에 나오는 자리가 정확히 여기다.

## 관여도의 아래끝. **목격 자체가 최소한의 관여이기 때문이다** — 그 자리에 있었다
## (설계 24.21.5). 0 으로 두면 남의 일에는 아무 반응이 없어서 세계가 안 퍼진다.
const WITNESS_FLOOR := 0.15

## 목격이 **새 관계를 만들 만한** 호감의 최소 크기.
##
## 관여도의 바닥이 0.15 라 남의 일을 본 사람은 대개 한둘밖에 안 움직인다.
## 그것까지 관계로 적으면 **사건 하나가 방향 관계를 수십 개씩 만들고**
## 설계 24.2 의 희소가 거짓이 된다 — 그리고 화면에 「신뢰 +2」 같은 줄이 뜬다.
##
## **이미 있는 관계는 이 문턱을 안 본다.** 아는 사이의 호감은 조금씩도 움직여야 한다.
const WITNESS_MARK_MIN := 5

## 전해 들은 이야기가 얼마나 약해지나 (설계 24.10).
##
## **1홉만 간다.** 2홉 이상은 계산이 터지고 플레이어가 체감하지도 못한다.
## 그래서 감쇠를 세게 준다 — 소문이 목격만큼 세면 **목격이 뜻을 잃는다.**
const RUMOR_DECAY := 0.35

## 소문이 **새 관계를 만들** 호감의 최소 크기.
##
## 목격의 문턱(WITNESS_MARK_MIN)보다 높다. **전파는 성김을 죽인다** —
## 사건마다 연루자 여섯이 각자 아는 사람 두셋에게 전하면 관계가 배로 늘어난다.
##
## **그리고 이 문턱이 유명세를 「거리」로 바꾸는 장치다.** 문턱을 낮추면 무명인 사람의
## 소문도 다 통과해서 유명세가 아무 일도 안 한다 — 실측으로 소문 대상이 유명할 비율이
## 문턱 8 에서 17%, 5 에서 12% 다 (인구 자체는 7.8%). 설계 24.28.3 에 표가 있다.
const RUMOR_MARK_MIN := 8

## 한 사건의 소문이 닿을 수 있는 사람 수의 상한.
const RUMOR_MAX := 24

## 전멸이 유대로 훑을 때의 문턱. **이 아래는 「유대 높은 사람」이 아니다.**
##
## 태생 관계의 유대 하한이 사제 45 이므로(KinSeeder) 가족과 스승은 전부 들어오고,
## 협력 한 번이 만든 얇은 관계(유대 20)는 안 들어온다.
const SWEEP_BOND_MIN := 40

## 한 사건이 훑어 늘릴 수 있는 목격자의 상한.
##
## 상한이 없으면 유대 높은 인물 하나가 죽을 때 세계의 절반이 같은 방향으로 움직인다.
## 설계 24.10 이 전파를 1홉으로 자른 것과 같은 이유다 — **체감되지 않는 것에 비용을 쓰지 않는다.**
const SWEEP_MAX := 24

var _registry: PersonRegistry
var _graph: RelationGraph
var _ledger: RelationLedger

## 소문을 퍼뜨리나 (설계 24.10).
##
## **끄는 스위치가 있는 이유는 재기 위해서다.** 전파가 성김을 죽이는지는
## 같은 시드의 세계를 켜고 끄고 두 번 세워야 답이 나온다 — 도구가 그렇게 쓴다
## (`tools/survey_npc_events.gd`). 게임은 늘 켜고 돈다.
var _spreads: bool


func _init(
	registry: PersonRegistry,
	graph: RelationGraph,
	ledger: RelationLedger,
	spreads_rumors: bool = true
) -> void:
	_registry = registry
	_graph = graph
	_ledger = ledger
	_spreads = spreads_rumors


## 사건 하나를 굴린다. 돌려주는 것은 **근거 사건 id** 이고 그것이 관계에 박힌다.
##
## witnesses 는 **그 자리에 있던 사람들**이다. 행위자와 대상은 빼고 세며,
## 전멸처럼 `sweeps_bonded` 인 사건은 여기에 **죽은 자와 유대 높은 사람들**이 더해진다.
##
## **대상이 비어도 되는 사건이 있다** (`RelationEvent.needs_target`). 길드 이탈은
## 누구에게 한 일이 아니라 한 일 그 자체이고, 그때는 행위자와 목격자만 남는다 —
## 관여도가 행위자와의 유대 하나로 계산되고 대상 쌍 처리를 통째로 건너뛴다.
func resolve(
	kind: RelationEvent.Kind, actor: int, targets: PackedInt32Array, witnesses: PackedInt32Array
) -> int:
	if not _registry.has(actor):
		return RelationLedger.NO_CAUSE
	var kept := PackedInt32Array()
	for target in targets:
		if _registry.has(target) and target != actor:
			kept.append(target)

	var event := RelationEvent.of(kind)
	if kept.is_empty() and event.needs_target:
		return RelationLedger.NO_CAUSE
	var cause := _ledger.record(kind, actor, kept)
	for target in kept:
		_apply_pair(event, actor, target, cause)
	var seen := _witnesses(event, actor, kept, witnesses)
	for witness in seen:
		_apply_witness(event, witness, actor, kept, cause)
	if _spreads:
		_spread(event, actor, kept, seen, cause)
	return cause


## 행위자와 대상 사이. **성향이 여기 안 들어온다** (설계 24.6).
func _apply_pair(event: RelationEvent, actor: int, target: int, cause: int) -> void:
	# 대상 -> 행위자. 호감이 가장 크게 움직이고 유형과 근거가 남는다.
	# 유형이 NONE 이면 그 슬롯을 안 건드린다 — 전멸의 대상은 죽은 사람이다.
	if event.target_kind != RelationKind.Kind.NONE:
		# 당한 사람은 소문으로 안 것이 아니다 — 표시가 남아 있으면 지운다.
		_graph.set_heard(
			_graph.adjust(
				target, actor, event.target_affinity, event.bond_gain, event.target_kind, cause
			),
			false
		)
	# **행위자 쪽도 유형이 NONE 이면 안 건드린다.** 「못 본 척 지나감」이 그렇다 —
	# 설계 24.5 가 *"거의 아무 일도 일어나지 않는다"* 고 못 박았고, 그래야
	# 회피가 진짜 중립 선택이 된다. 슬롯을 만들면 안 만난 것보다 더 엮이게 된다.
	if event.actor_kind == RelationKind.Kind.NONE:
		return
	# 행위자 -> 대상. 유대만 오른다. 평판이 굳는 것은 유명세 쪽이고 아직 없다 (설계 24.15).
	_graph.set_heard(
		_graph.adjust(actor, target, 0, event.bond_gain, event.actor_kind, cause), false
	)


## 목격자 하나. **여기서만 성향이 작동한다.**
func _apply_witness(
	event: RelationEvent, witness: int, actor: int, targets: PackedInt32Array, cause: int
) -> void:
	var shift := roundi(
		(
			event.alignment(_registry.traits_of(witness))
			* float(event.strength)
			* _involvement(witness, actor, targets)
		)
	)
	if shift == 0:
		return

	# **유형은 새로 생길 때만 정한다.** 이미 있는 관계의 딱지를 목격이 갈아치우면
	# 생사고락이 한 번 본 일로 「원한」이 되어 설계 24.2 의 "유형은 딱지" 가 무너진다.
	if _graph.knows(witness, actor):
		# 소문으로 알던 사람을 이번에는 직접 봤다. 그러면 더 이상 들은 이야기가 아니다.
		_graph.set_heard(
			_graph.adjust(witness, actor, shift, 0, RelationKind.Kind.NONE, cause), false
		)
		return

	# 무색한 사람과 남의 일을 스친 사람은 관계가 안 남는다 (설계 24.21.6) —
	# 아무 감정도 안 생긴 사람을 아는 사이로 적으면 희소가 거짓이 된다.
	if absi(shift) < WITNESS_MARK_MIN:
		return
	var kind := RelationKind.Kind.TRUST if shift > 0 else RelationKind.Kind.GRUDGE
	_graph.link(witness, actor, kind, shift, RelationGraph.BOND_MIN, cause)


## 소문 — **1홉만 간다** (설계 24.10).
##
## *"친구의 원수는 나의 원수."* 그 자리에 없던 사람도 *"그 사람이 배신했다더라"* 를 안다.
##
## ## 무엇이 전해지나
##
## **사건 그 자체다.** 들은 사람도 제 성향으로 판단한다 — 같은 이야기를 듣고
## 의리형은 치를 떨고 실리형은 고개를 끄덕인다 (설계 24.4). 규칙이 하나뿐인 것이
## 여기서도 값을 한다. 다른 것은 셋이다.
##
## | | 목격 | 소문 |
## | --- | --- | --- |
## | 관여도 | 행위자·대상과의 유대 | **전한 사람과의 유대** — 남의 말은 그 사람만큼만 무겁다 |
## | 세기 | 그대로 | `RUMOR_DECAY` 만큼 준다 |
## | 관계에 남는 것 | 「봤다」 | **「들었다」** |
##
## ## 유명세가 소문의 거리를 정한다 (설계 24.7)
##
## 설계 24.7 — *"무명인 사람 얘기는 아무도 보지 않는다."*
## 행위자의 유명세가 세기를 밀어 올리고, 문턱이 그것을 **거리**로 바꾼다 —
## **무명인 사람의 사건은 소문이 아무에게도 안 닿고 유명한 사람의 사건은 멀리 간다.**
## 유명세 중위가 0 이라(설계 24.16.6) 대부분의 사건은 보정이 없다. 그것이 의도다.
##
## ## 저장한다 — 설계 24.10 의 「조회할 때 계산」과 갈린다
##
## §24.10 은 전파를 조회 시 보정으로 그렸다. **그러면 화면에 안 나온다** —
## 관계가 없는 쌍에는 보여줄 줄이 없고, 그러면 *"그 사람이 배신했다더라"* 가
## 플레이어에게 도달하지 않는다. 전멸(§24.21.7)과 같은 판단으로 여기서는 만든다.
func _spread(
	event: RelationEvent,
	actor: int,
	targets: PackedInt32Array,
	witnesses: PackedInt32Array,
	cause: int
) -> void:
	var told := {}
	told[actor] = true
	for target in targets:
		told[target] = true
	for witness in witnesses:
		told[witness] = true

	# 전하는 사람은 그 자리에 있던 사람 전부다. 대상은 죽었을 수 있으므로 빼지 않는다 —
	# 죽은 사람의 이야기를 그 가족이 전한다.
	var tellers := PackedInt32Array([actor])
	tellers.append_array(targets)
	tellers.append_array(witnesses)

	var reach := float(event.strength) * RUMOR_DECAY * _fame_reach(actor)
	var spread := 0
	for teller in tellers:
		for hearer in _graph.mutuals_of(teller):
			if spread >= RUMOR_MAX:
				return
			if told.has(hearer):
				continue
			told[hearer] = true
			if _tell(event, hearer, teller, actor, reach, cause):
				spread += 1


## 한 사람에게 전한다. 관계가 실제로 움직였으면 true.
func _tell(
	event: RelationEvent, hearer: int, teller: int, actor: int, reach: float, cause: int
) -> bool:
	var trust := float(_graph.bond(hearer, teller)) / float(RelationGraph.BOND_MAX)
	var shift := roundi(event.alignment(_registry.traits_of(hearer)) * reach * trust)
	if shift == 0:
		return false

	# 이미 아는 사이면 호감만 움직인다. **「들었다」 표시는 안 켠다** —
	# 직접 겪어서 안 사람이 소문을 한 번 들었다고 전해 들은 사이가 되지 않는다.
	if _graph.knows(hearer, actor):
		_graph.adjust(hearer, actor, shift, 0, RelationKind.Kind.NONE, cause)
		return true

	if absi(shift) < RUMOR_MARK_MIN:
		return false
	var kind := RelationKind.Kind.TRUST if shift > 0 else RelationKind.Kind.GRUDGE
	var slot := _graph.link(hearer, actor, kind, shift, RelationGraph.BOND_MIN, cause)
	_graph.set_heard(slot, true)
	return true


## 유명세가 소문을 얼마나 멀리 보내나. 무명이면 1.0, 유명세 100 이면 2.0.
func _fame_reach(actor: int) -> float:
	return 1.0 + float(_registry.fame_of(actor)) / float(PersonGenerator.FAME_MAX)


## 관여도 — **행위자 · 대상 중 가까운 쪽과의 유대 / 100** (설계 24.21.5).
##
## 남이면 무덤덤하고 제 사람이면 크다. 아래끝이 `WITNESS_FLOOR` 다.
func _involvement(witness: int, actor: int, targets: PackedInt32Array) -> float:
	var closest := _graph.bond(witness, actor)
	for target in targets:
		closest = maxi(closest, _graph.bond(witness, target))
	return maxf(float(closest) / float(RelationGraph.BOND_MAX), WITNESS_FLOOR)


## 실제로 계산할 목격자들. 중복과 당사자를 걷어내고, 전멸이면 유대로 더 훑는다.
##
## **순서가 결정론적이다** — 준 순서 먼저, 그다음 훑은 순서. 사전의 키 순서가
## 넣은 순서라서 같은 시드가 같은 세계를 만든다 (설계 24.16.7).
func _witnesses(
	event: RelationEvent, actor: int, targets: PackedInt32Array, given: PackedInt32Array
) -> PackedInt32Array:
	var taken := {}
	taken[actor] = true
	for target in targets:
		taken[target] = true

	var found := PackedInt32Array()
	for witness in given:
		if not _registry.has(witness) or taken.has(witness):
			continue
		taken[witness] = true
		found.append(witness)

	if not event.sweeps_bonded:
		return found

	# 죽은 자들과 유대 높은 사람 전원에게 사건이 간다 (설계 24.5 B).
	# **이것이 세계에서 원한이 만들어지는 주된 통로다.**
	for target in targets:
		for other in _graph.targets_of(target):
			if found.size() >= SWEEP_MAX:
				return found
			if taken.has(other) or _graph.bond(target, other) < SWEEP_BOND_MIN:
				continue
			taken[other] = true
			found.append(other)
	return found
