extends GutTest
## 세계에서 난 일이 아웃게임에 **한 줄로** 나오는가.
##
## docs/design/37-meta-loop.md §37.6, docs/design/15-world.md §15.2.1.
##
## **고르는 규칙이 이 클래스의 전부다.** 그래서 시험도 거기에 몰려 있다 —
## 무엇을 남기고 무엇을 버리는가.
##
## ## 「비어 있는가」로는 못 잰다
##
## 세계는 **이미 사건 수백 건을 들고 선다** (`EventSeeder` 가 인구/6 을 굴린다).
## 그래서 새 사건을 하나 적고 「소식이 비었나」를 물으면 언제나 거짓이다 —
## 처음에 그렇게 썼다가 여섯 개가 한꺼번에 빨갛게 났다.
##
## **적기 전과 뒤를 비교한다.** 새 사건은 장부의 맨 끝이고 최신이 앞이므로,
## 소식이 되면 `after[0]` 이고 버려지면 `after == before` 다.

const _SEED := 20260819
const _POPULATION := 300


func _world() -> NpcWorld:
	return NpcWorld.create(_SEED, _POPULATION)


## 유명하지 않은 사람 둘. **뽑기가 아니라 골라야** 시험이 흔들리지 않는다.
func _two_unknowns(world: NpcWorld) -> PackedInt32Array:
	var found := PackedInt32Array()
	for person in world.registry.size():
		if world.registry.fame_of(person) < PersonGenerator.FAME_KNOWN:
			found.append(person)
		if found.size() == 2:
			break
	return found


func _famous(world: NpcWorld) -> int:
	var best := 0
	for person in world.registry.size():
		if world.registry.fame_of(person) > world.registry.fame_of(best):
			best = person
	return best


## 이 길드의 대원이 **아닌** 사람 둘. 인물 번호를 손으로 박으면 마침 대원일 수 있다.
func _outsiders(guild: Guild) -> PackedInt32Array:
	var mine := Array(GuildCircle.own_of(guild))
	var found := PackedInt32Array()
	for person in 100:
		if not mine.has(person):
			found.append(person)
		if found.size() == 2:
			break
	return found


func _record(world: NpcWorld, kind: RelationEvent.Kind, actor: int, target: int) -> int:
	return world.ledger.record(kind, actor, PackedInt32Array([target]))


func _news(world: NpcWorld, known: PackedInt32Array, mine := PackedInt32Array()) -> Array[String]:
	return WorldNews.gather(world, known, mine, WorldNews.MAX_LINES)


# ---------------------------------------------------------------- 고르는 규칙


func test_an_event_between_strangers_is_not_news() -> void:
	var world := _world()
	var pair := _two_unknowns(world)
	var before := _news(world, PackedInt32Array())
	_record(world, RelationEvent.Kind.BETRAYAL, pair[0], pair[1])
	assert_eq(_news(world, PackedInt32Array()), before)


func test_a_known_face_makes_it_news() -> void:
	var world := _world()
	var pair := _two_unknowns(world)
	var cause := _record(world, RelationEvent.Kind.BETRAYAL, pair[0], pair[1])
	var news := _news(world, PackedInt32Array([pair[0]]))
	assert_eq(news[0], WorldNews.line_for(world, cause))
	assert_true(news[0].contains(world.registry.name_of(pair[1])), news[0])


func test_a_known_target_makes_it_news_too() -> void:
	# **당한 쪽이 아는 얼굴이어도 소식이다.** 행위자만 보면 절반을 놓친다.
	var world := _world()
	var pair := _two_unknowns(world)
	var cause := _record(world, RelationEvent.Kind.PLUNDER, pair[0], pair[1])
	assert_eq(_news(world, PackedInt32Array([pair[1]]))[0], WorldNews.line_for(world, cause))


func test_a_famous_stranger_makes_it_news() -> void:
	# §24.7 — 무명인 사람 얘기는 아무도 안 본다. 뒤집으면 유명한 사람 얘기는 본다.
	var world := _world()
	var famous := _famous(world)
	assert_gte(world.registry.fame_of(famous), PersonGenerator.FAME_KNOWN)
	var cause := _record(world, RelationEvent.Kind.PLUNDER, famous, _two_unknowns(world)[0])
	assert_eq(_news(world, PackedInt32Array())[0], WorldNews.line_for(world, cause))


func test_what_i_did_myself_is_not_news() -> void:
	# **재 보고 넣은 규칙이다** — 안 거르면 다섯 줄이 전부 내 대원 얘기가 된다.
	var world := _world()
	var pair := _two_unknowns(world)
	var before := _news(world, pair, pair)
	_record(world, RelationEvent.Kind.COOPERATION, pair[0], pair[1])
	assert_eq(_news(world, pair, pair), before)


func test_my_member_tangled_with_an_outsider_is_still_news() -> void:
	# 내 사람끼리만 걸러 낸다. 바깥과 얽힌 것은 **그것이야말로 소식이다.**
	var world := _world()
	var pair := _two_unknowns(world)
	var mine := PackedInt32Array([pair[0]])
	var cause := _record(world, RelationEvent.Kind.BETRAYAL, pair[0], pair[1])
	assert_eq(_news(world, mine, mine)[0], WorldNews.line_for(world, cause))


func test_the_limit_is_kept_and_the_newest_comes_first() -> void:
	var world := _world()
	var pair := _two_unknowns(world)
	var older := _record(world, RelationEvent.Kind.PLUNDER, pair[0], pair[1])
	var newer := _record(world, RelationEvent.Kind.BETRAYAL, pair[0], pair[1])
	assert_gt(newer, older)
	var news := WorldNews.gather(world, pair, PackedInt32Array(), 1)
	assert_eq(news.size(), 1)
	assert_eq(news[0], WorldNews.line_for(world, newer))


# ---------------------------------------------------------------- 문장


func test_the_particle_follows_the_name() -> void:
	# `양은담와` 가 실제로 나간 적이 있다 (설계 19.B.5). 받침 계산은 RekkaSlots 가 한다.
	var world := _world()
	var pair := _two_unknowns(world)
	var cause := _record(world, RelationEvent.Kind.BETRAYAL, pair[0], pair[1])
	var line := WorldNews.line_for(world, cause)
	var actor := world.registry.name_of(pair[0])
	var target := world.registry.name_of(pair[1])
	assert_true(line.contains(actor + KoreanParticle.subject(actor)), line)
	assert_true(line.contains(target + KoreanParticle.object_of(target)), line)


func test_every_kind_has_a_line_or_is_deliberately_empty() -> void:
	# 틀이 enum 과 어긋나면 **새 사건이 조용히 안 나온다.**
	assert_eq(WorldNews.LINES.size(), RelationEvent.count())
	assert_eq(WorldNews.LINES[int(RelationEvent.Kind.AFTERMATH)], "")


func test_the_aftermath_never_becomes_news() -> void:
	# 그 사건의 대상 칸에는 사람이 아니라 **틱 번호**가 들어 있다 (WorldStep._shock).
	var world := _world()
	var pair := _two_unknowns(world)
	var before := _news(world, pair)
	var cause := world.ledger.record(RelationEvent.Kind.AFTERMATH, pair[0], PackedInt32Array([3]))
	assert_eq(WorldNews.line_for(world, cause), "")
	assert_eq(_news(world, pair), before)


func test_a_missing_world_gives_no_news() -> void:
	assert_eq(WorldNews.gather(null, PackedInt32Array()), [] as Array[String])
	assert_eq(WorldNews.line_for(null, 0), "")
	assert_eq(WorldNews.line_for(_world(), 99999), "")


# ---------------------------------------------------------------- 길드 쪽


func test_the_guild_knows_its_members_and_prospects() -> void:
	var world := _world()
	var guild := Guild.create_starting(_SEED, "시험 길드", world)
	var outsiders := _outsiders(guild)
	var prospect := RecruitProspect.new("p_1", "닿은 사람", MemberDiscipline.Kind.SCOUT, 0)
	prospect.person = outsiders[0]
	prospect.introduced_by = outsiders[1]
	guild.add_prospect(prospect)

	var known := Array(GuildCircle.known_of(guild))
	assert_true(known.has(outsiders[0]))
	assert_true(known.has(outsiders[1]))
	for member in guild.members:
		assert_true(known.has(member.person))
	# **후보는 내 사람이 아니다.** 둘을 안 가르면 뉴스가 후보 소식까지 걸러 낸다.
	assert_false(Array(GuildCircle.own_of(guild)).has(outsiders[0]))


func test_a_guild_without_a_world_knows_nobody() -> void:
	var guild := Guild.create_starting(_SEED, "세계 없는 길드")
	assert_eq(GuildCircle.known_of(guild).size(), 0)
	assert_eq(GuildCircle.own_of(guild).size(), 0)


func test_a_missing_guild_knows_nobody() -> void:
	assert_eq(GuildCircle.known_of(null).size(), 0)
	assert_eq(GuildCircle.own_of(null).size(), 0)


# ---------------------------------------------------------------- 정산 칸


func _report(guild: Guild) -> ExpeditionReport:
	return ExpeditionReport.new(
		"exp_0",
		Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED),
		ExpeditionReport.Outcome.ESCAPED,
		5,
		guild.member_ids(),
		[] as Array[String]
	)


func test_the_settlement_grows_a_world_pane() -> void:
	var guild := Guild.create_starting(_SEED, "시험 길드", _world())
	var report := _report(guild)
	var titles := PackedStringArray()
	for sheet in SettlementSheet.build(report, GuildSettlement.apply(guild, report), guild):
		titles.append(sheet.title)
	assert_true(Array(titles).has("세계"), "세계 칸이 없다: %s" % titles)


func test_a_settlement_without_a_world_has_no_world_pane() -> void:
	# **빈 칸을 남기지 않는다.** 자리만 있고 내용이 없으면 고장 난 것처럼 보인다.
	var guild := Guild.create_starting(_SEED, "세계 없는 길드")
	var report := _report(guild)
	for sheet in SettlementSheet.build(report, GuildSettlement.apply(guild, report), guild):
		assert_ne(sheet.title, "세계")
