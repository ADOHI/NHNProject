extends SceneTree
## 조우에서 **아는 얼굴이 얼마나 섞이는지** 재는 개발 도구.
##
## docs/design/24-npc-relations.md §24.29.
##
## **이 수치가 이 덩어리의 전부다.** 너무 자주 섞이면 우연이 아니고,
## 너무 드물면 관계도가 조우 화면에서 아무 일도 안 한다.
##
##   godot --headless --path . -s res://tools/survey_npc_encounter.gd

const _POPULATION := 3000
const _SEED := 20260808

## 몇 번 조우해 보나. 비율을 재려면 한 판으로는 모자란다.
const _TRIALS := 400


func _initialize() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	_report_guild(world, guild)
	_report_encounters(world, guild)
	_report_sample(world, guild)
	_report_nameable(world, guild)
	quit()


## 대원이 세계의 인물인가, 그리고 **서로 엮여 있나.**
func _report_guild(world: NpcWorld, guild: Guild) -> void:
	print("== 길드 대원 (시드 %d) ==" % _SEED)
	print("%-10s %-8s %5s %6s %6s %s" % ["계열", "이름", "나이", "연줄", "가족", "비고"])
	for member in guild.members:
		var mark := "대표" if member.person == guild.leader_person else ""
		var kin := 0
		for other in world.graph.targets_of(member.person):
			if RelationKind.is_inborn(world.graph.kind_of(member.person, other)):
				kin += 1
		print(
			(
				"%-10s %-8s %5d %6d %6d %s"
				% [
					MemberDiscipline.label(member.discipline),
					member.display_name,
					world.registry.age_of(member.person),
					world.graph.mutuals_of(member.person).size(),
					kin,
					mark,
				]
			)
		)

	# 대원끼리 엮여 있는가. **연줄로 뽑았으므로 몇 쌍은 서로 알아야 한다.**
	var pairs := 0
	var known := 0
	for one in guild.members.size():
		for other in range(one + 1, guild.members.size()):
			pairs += 1
			if SocialReach.familiar(
				world.graph, guild.members[one].person, guild.members[other].person
			):
				known += 1
	print("%-26s %d / %d 쌍" % ["대원끼리 아는 사이", known, pairs])


## **아는 얼굴이 몇 %나 섞이나.** 손잡이를 돌려 가며 재는 자리다.
func _report_encounters(world: NpcWorld, guild: Guild) -> void:
	print("\n== 조우 %d회 (스쿼드 %d명) ==" % [_TRIALS, RivalSquad.SIZE])
	print("%-16s %10s %12s %10s" % ["보는 쪽", "아는 얼굴 있음", "조우당 평균", "최대"])

	var ours := PackedInt32Array()
	for member in guild.members:
		ours.append(member.person)

	_measure(world, "대표 한 사람", PackedInt32Array([guild.leader_person]))
	_measure(world, "대원 전원", ours)
	print("%-26s %.2f" % ["기점을 연줄에서 뽑을 확률", RivalSquad.NEARBY_CHANCE])


func _measure(world: NpcWorld, label: String, viewers: PackedInt32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var with_known := 0
	var total := 0
	var worst := 0
	for trial in _TRIALS:
		var squad := RivalSquad.draw(world, rng, viewers)
		var known := squad.familiar_to(viewers).size()
		total += known
		worst = maxi(worst, known)
		if known > 0:
			with_known += 1
	print(
		(
			"%-16s %9.1f%% %12.2f %10d"
			% [
				label,
				100.0 * float(with_known) / float(_TRIALS),
				float(total) / float(_TRIALS),
				worst,
			]
		)
	)


## 아는 얼굴이 섞인 조우 하나를 글로 본다. **UI 레인이 받을 모양이 이것이다.**
func _report_sample(world: NpcWorld, guild: Guild) -> void:
	var ours := PackedInt32Array()
	for member in guild.members:
		ours.append(member.person)

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	for trial in _TRIALS:
		var squad := RivalSquad.draw(world, rng, ours)
		if squad.familiar_to(ours).is_empty():
			continue
		print("\n== 조우 한 판 (%d번째) ==" % (trial + 1))
		for member in squad.members:
			print("   %-40s %s" % [world.registry.summary_of(member), _tie(world, ours, member)])
		return
	print("\n아는 얼굴이 섞인 조우가 %d회 안에 없었다" % _TRIALS)


## 우리 쪽 누구와 어떻게 엮였나. 없으면 빈 문자열이다.
func _tie(world: NpcWorld, ours: PackedInt32Array, other: int) -> String:
	for viewer in ours:
		if not world.registry.has(viewer):
			continue
		if world.graph.knows(viewer, other):
			return (
				"<- %s 가 안다 (%s 호감 %+d)"
				% [
					world.registry.name_of(viewer),
					RelationKind.label(world.graph.kind_of(viewer, other)),
					world.graph.affinity(viewer, other),
				]
			)
		if world.graph.knows(other, viewer):
			return (
				"<- %s 를 안다 (%s 호감 %+d)"
				% [
					world.registry.name_of(viewer),
					RelationKind.label(world.graph.kind_of(other, viewer)),
					world.graph.affinity(other, viewer),
				]
			)
	return ""


## **얼굴이 없어도 「아는 사람」이 느껴지나** (설계 24.32).
##
## 3000명 전원의 초상은 못 만든다 — 캐릭터 파이프라인이 한 명당 여러 단계를 거친다.
## 그러면 조우 화면의 여섯이 이름 여섯 개가 된다. **재인(再認)이 무엇에 걸리는지 센다.**
##
## 부를 이름이 있는가로 셋으로 가른다 —
##
## | 무엇 | 화면에 쓸 수 있는 말 |
## | --- | --- |
## | **태생 유형** | *"당신 대원의 아들"* — 가장 강하다. 얼굴이 없어도 그 자리에서 읽힌다 |
## | **얻은 유형 + 근거 사건** | *"3년 전 그 판에서 배신한 자"* — 설계 24.2 가 노린 것 |
## | **수치뿐** | 부를 말이 없다. **이 몫이 크면 얼굴이 필요하다** |
func _report_nameable(world: NpcWorld, guild: Guild) -> void:
	var ours := PackedInt32Array()
	for member in guild.members:
		ours.append(member.person)

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	var inborn := 0
	var storied := 0
	var bare := 0
	for trial in _TRIALS:
		var squad := RivalSquad.draw(world, rng, ours)
		for face in squad.familiar_to(ours):
			var kind := RelationKind.Kind.NONE
			var cause := RelationLedger.NO_CAUSE
			for viewer in ours:
				if world.graph.knows(viewer, face):
					kind = world.graph.kind_of(viewer, face)
					cause = world.graph.cause_of(viewer, face)
					break
				if world.graph.knows(face, viewer):
					kind = world.graph.kind_of(face, viewer)
					cause = world.graph.cause_of(face, viewer)
					break
			if RelationKind.is_inborn(kind):
				inborn += 1
			elif world.ledger.has(cause):
				storied += 1
			else:
				bare += 1

	var total := maxi(inborn + storied + bare, 1)
	print("\n== 얼굴이 없어도 부를 말이 있나 (아는 얼굴 %d건) ==" % total)
	print("%-26s %.0f%%" % ["태생 유형 (아들 · 스승 …)", 100.0 * float(inborn) / float(total)])
	print("%-26s %.0f%%" % ["유형 + 근거 사건", 100.0 * float(storied) / float(total)])
	print("%-26s %.0f%%" % ["수치뿐 — 부를 말이 없다", 100.0 * float(bare) / float(total)])
