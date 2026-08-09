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
