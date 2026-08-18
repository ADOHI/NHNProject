class_name ExpeditionAftermath
extends RefCounted
## 원정 하나가 **관계에 남기는 것.** 판을 돌면 세계가 조금씩 달라진다.
##
## docs/design/24-npc-relations.md §24.11 · §24.30,
## docs/design/02-overview.md §2.6.1.5 (게이트는 복제된 인간이 들어간다).
##
## ## 「관계도가 악화된다」에는 서로 다른 물음 셋이 섞여 있다
##
## 사용자 원문은 *"제거되면 심각한 정신적 후유증이 남아서 관계도가 악화되는 거임"* 이다.
## **하나로 묶어 「관계도 감쇠」로 만들면 못 쓴다.** 셋으로 갈랐다.
##
## | 물음 | 여기서의 답 |
## | --- | --- |
## | **① 제거되면 그 사람의 선들이 어떻게 되나** | **안 사라진다. 그 사람이 사람을 못 믿게 된다** — 나가는 선의 호감이 내려간다 |
## | **② 살아 돌아오면 같이 간 사람과 굵어지나** | **굵어진다.** 성패와 무관하게 유대가 오른다 (§24.12) |
## | **③ 한 번도 같이 안 나간 둘은 멀어지나** | **안 멀어진다.** 근거는 §24.30.4 |
##
## **①이 몸이 아니라 정신에 걸리는 것이 이 설정의 전부다.** 몸은 복제되므로
## 그 사람은 사라지지 않는다. 사라지는 것은 **그가 남을 보던 눈**이다.
## 그래서 선을 끊지 않고 **나가는 방향의 호감만** 내린다 —
## 상대는 그를 여전히 좋아하는데 그가 상대를 못 믿는, 어긋난 관계가 남는다.
##
## ## 손잡이가 결과와 같으면 안 된다
##
## *"쓰러지면 −12"* 는 사람이 바로 알아챈다. **성향이 그 사이에 든다** —
## 같은 판을 겪어도 **견디는 사람과 부서지는 사람이 갈린다** (`resilience_of`).
## 소속을 중간에 끼워 조우의 손잡이를 가린 것과 같은 수법이다 (§24.29.3).

## 후유증의 기본 크기. **8 이다** (설계 24.37).
##
## 사용자가 *"밸런싱이 어려우니 보수적으로"* 로 판단을 넘겼고, 두 가지로 골랐다 —
##
## 1. **손잡이 값이 분포 안에 들어야 한다.** 성향이 사이에 들어 실제로 입는 크기가
##    `SHOCK × (1 − 견딤)` 이라 12 에서는 **12 를 맞는 사람이 0%** 였다.
##    8 은 분포 안에 드는 **가장 큰** 값이다 (8 을 맞는 사람 1%)
## 2. **한 회차(스무 판)를 돌면 대원 호감이 시작보다 높아야 한다.** 설계 6.1 이
##    *"관계를 쌓아 영입한 대원"* 이라고 했다. 12 에서는 31.9 → 27.9 로 **깎였다.**
##    8 은 31.9 → 35.5 다 (후유증이 없으면 52.6 — 실패가 값을 한다)
##
## **나중에 올려도 이미 생긴 관계는 안 흔들린다.** 이 값은 쓰러진 그 순간
## 델타로 한 번 쓰이고 끝이라(`_shock`) 저장된 값을 다시 읽지 않는다.
##
## 실측표는 §24.37 에 있다. **베끼지 말고 도구를 돌려라** —
## `godot --headless --path . -s res://tools/survey_world_tick.gd`
const SHOCK := 8

## 원정 한 번에 **세계 곳곳에서** 일어나는 사건 수 (설계 24.11).
##
## 내 원정만 관계를 바꾸면 세계가 안 돈다 — 3000명 중 다섯만 움직이고
## **내가 없는 동안 아무 일도 안 일어난다.** 그러면 설계 24.11 의
## *"내가 노리던 영입 후보를 다른 길드가 데려갔을 수 있다"* 가 성립하지 않는다.
##
## **잠정값이다.** 세계를 세울 때 인구/6 을 한 번에 굴렸으므로(EventSeeder)
## 판마다 그 1/50 쯤을 준 것이고, 근거는 §24.30.5 의 실측표다.
const WORLD_EVENTS := 10

## 원정 한 번이 같이 간 사람들 사이에 남기는 것.
##
## 성패를 안 가린다 — **같이 갔다는 사실 자체가 유대**다 (§24.12
## *"유대는 같이 다니면 오른다"*). 실패의 대가는 유대가 아니라 후유증 쪽에 있다.
const TOGETHER := RelationEvent.Kind.COOPERATION


## 원정 하나를 세계에 반영한다. 세계가 없으면 아무 일도 안 한다.
##
## 돌려주는 것은 **후유증을 입은 인원 수**다. 화면과 도구가 그것을 센다.
static func apply(guild: Guild, report: ExpeditionReport, tick: int = 0) -> int:
	if guild == null or report == null or guild.world == null or not guild.world.is_ready():
		return 0

	var world := guild.world
	var went := _people_of(guild, report.deployed_ids)
	if went.is_empty():
		return 0

	# 내가 던전에 있는 동안 세계도 돈다. **내 원정보다 이쪽이 훨씬 크다.**
	world.tick(WORLD_EVENTS)

	var resolver := RelationResolver.new(world.registry, world.graph, world.ledger)
	_bind_together(resolver, went, _people_of(guild, report.garrison_ids))

	if report.outcome != ExpeditionReport.Outcome.DOWNED:
		return 0
	for person in went:
		_shock(world, person, tick)
	return went.size()


## 같이 간 사람들을 엮는다. **쌍마다 한 번씩** — 셋이 갔으면 세 쌍이다.
##
## 한 사람을 행위자로 두고 나머지를 대상으로 묶으면 **대상끼리는 안 엮인다.**
## 스쿼드 정원이 셋이라(GuildBalance) 쌍이 많아야 셋이고, 그 값이면 제곱이 싸다.
##
## 남은 대원은 목격자다 — 아지트에서 소식을 듣는다.
static func _bind_together(
	resolver: RelationResolver, went: PackedInt32Array, stayed: PackedInt32Array
) -> void:
	for one in went.size():
		for other in range(one + 1, went.size()):
			resolver.resolve(TOGETHER, went[one], PackedInt32Array([went[other]]), stayed)


## 한 사람의 후유증. **나가는 선의 호감만 내린다.**
##
## 유대는 안 건드린다 — 엮인 정도가 줄어드는 것이 아니라 **보는 눈이 나빠지는** 것이다.
## 태생 관계도 호감은 내려간다 (§24.18 이 막는 것은 유대와 유형뿐이다).
static func _shock(world: NpcWorld, person: int, tick: int) -> void:
	var damage := shock_for(world.registry.traits_of(person))
	if damage <= 0:
		return
	var cause := world.ledger.record(RelationEvent.Kind.AFTERMATH, person, PackedInt32Array([tick]))
	for other in world.graph.targets_of(person):
		world.graph.adjust(person, other, -damage, 0, RelationKind.Kind.NONE, cause)


## 이 성향이 실제로 입는 크기. **손잡이와 결과 사이에 든 층이다.**
static func shock_for(traits: PackedInt32Array) -> int:
	return roundi(float(SHOCK) * (1.0 - resilience_of(traits)))


## 얼마나 견디나. 0 이면 그대로 다 맞고 1 이면 아무렇지 않다.
##
## **두 축이 근거를 갖는다** (§24.3) —
##
## - **무모↔신중은 「던전 · 위험」 축이다.** 위험을 겪는 일에 대한 반응이 여기 걸린다.
##   무모한 사람은 원래 그런 일이 있는 줄 알고 들어갔다
## - **의리↔실리는 「내 사람」 축이다.** 사람에 기대는 만큼 사람이 안 보일 때 무너진다.
##   실리형은 애초에 사람을 덜 믿었으므로 잃을 믿음도 적다
##
## 나머지 넷은 안 쓴다. **쓸 근거가 없는 축을 넣으면 수치가 늘 뿐 뜻이 안 는다.**
static func resilience_of(traits: PackedInt32Array) -> float:
	if traits.size() != NpcAxis.count():
		return 0.5
	var reckless := traits[int(NpcAxis.Kind.RECKLESS)]
	var loyal := traits[int(NpcAxis.Kind.LOYAL)]
	# 두 축이 각각 -100~+100 이므로 차는 -400~+400 의 절반 폭을 쓴다.
	return clampf(0.5 + float(reckless - loyal) / float(NpcAxis.MAX_VALUE * 4), 0.0, 1.0)


## 대원 식별자를 세계의 인물 번호로. 세계에 안 물린 대원은 빠진다.
static func _people_of(guild: Guild, member_ids: Array[String]) -> PackedInt32Array:
	var found := PackedInt32Array()
	for member_id in member_ids:
		var member := guild.member_by_id(member_id)
		if member != null and member.is_in_world():
			found.append(member.person)
	return found
