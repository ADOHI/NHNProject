extends SceneTree
## 판을 이어 돌리면 세계가 실제로 움직이나. 그리고 **껐다 켜고 이어 돌려도 그대로인가.**
##
## docs/design/37-meta-loop.md §37.10.
##
## **한 판만 보면 안 보인다.** 세계 틱은 여러 판을 이어 돌려야 드러나고,
## 저장을 건너는지는 **껐다 켜고 그 뒤로 더 돌려 봐야** 드러난다 —
## 저장 직후를 비교하는 것만으로는 「불러온 세계 위에서 다음 판이 제대로 도는가」를 못 잰다.
##
## ## 결과가 두 길에서 같아야 한다
##
##     곧장 스무 판
##     열 판 -> 저장 -> 껐다 켬 -> 열 판 더
##
## 이 둘이 갈리면 ①이 안 고쳐진 것이다 (§37.2.1).
##
##   godot --headless --path . -s res://tools/survey_meta_loop.gd

const _SEED := 20260819
const _POPULATION := 3000

## 몇 판을 돌리나. 한 회차가 스무 판 남짓이다 (설계 24.30.5).
const _RUNS := 20

## 껐다 켜는 지점. 절반쯤에서 끊어야 앞뒤가 둘 다 보인다.
const _BREAK_AT := 10

## 쓰러지는 비율. 성공만 돌리면 후유증이 안 보인다.
const _DOWN_RATE := 0.35

## 도구 전용 세이브. **진짜 세이브를 건드리지 않는다.**
const _SAVE_PATH := "user://survey_meta_loop.json"


func _initialize() -> void:
	print(
		(
			"== 메타 루프를 잰다 (인구 %d · 시드 %d · %d판 · 쓰러짐 %.0f%%) =="
			% [_POPULATION, _SEED, _RUNS, _DOWN_RATE * 100.0]
		)
	)
	var world := NpcWorld.create(_SEED, _POPULATION)
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	_staff(guild)

	print("\n-- 판을 돌리면 세계가 움직이나 --")
	print("%-10s %8s %8s %10s %8s %8s" % ["판", "관계", "사건", "대원호감", "후보", "영입가능"])
	_row(world, guild, 0)
	for run in _RUNS:
		_settle(guild, run)
		if (run + 1) % 5 == 0:
			_row(world, guild, run + 1)

	_report_news(world, guild)
	_report_resume(guild)
	_report_recruit()
	_report_growth(world, guild)
	quit()


# ---------------------------------------------------------------- 껐다 켜고 이어 돌린다


## **이것이 이 도구의 핵심이다.** 저장 직후만 비교하면 반쪽이다 —
## 불러온 세계 위에서 **다음 판이 제대로 도는가**를 봐야 루프가 닫힌 것이다.
func _report_resume(straight: Guild) -> void:
	print("\n-- 껐다 켜고 이어 돌려도 같은가 --")

	var world := NpcWorld.create(_SEED, _POPULATION)
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	_staff(guild)
	for run in _BREAK_AT:
		_settle(guild, run)

	var store := SaveStore.new(_SAVE_PATH)
	if store.write(guild, _SEED) != OK:
		print("저장하지 못했다")
		return
	var loaded := store.read()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))
	if not loaded.is_ok():
		print("불러오지 못했다 — %s" % loaded.message())
		return
	# **불러온 세계 위에서 남은 판을 돌린다.** 여기가 진짜 물음이다.
	for run in range(_BREAK_AT, _RUNS):
		_settle(loaded.guild, run)

	print("%-24s %8s %8s %8s %8s" % ["", "관계", "사건", "자금", "진척"])
	_resume_row("곧장 %d판" % _RUNS, straight.world, straight)
	_resume_row("%d판 · 껐다 켬 · %d판" % [_BREAK_AT, _RUNS - _BREAK_AT], loaded.world, loaded.guild)

	var same := (
		straight.world.graph.size() == loaded.world.graph.size()
		and straight.world.ledger.size() == loaded.world.ledger.size()
		and straight.funds == loaded.guild.funds
		and straight.base_progress == loaded.guild.base_progress
	)
	print("두 길의 결과가 %s" % ["**갈렸다 — 루프가 안 닫혔다**", "같다"][int(same)])

	# 봉투 v1 이 하던 것 — 씨앗에서 처녀 세계를 세우고 끝이다.
	var pristine := NpcWorld.create(_SEED, _POPULATION)
	print(
		(
			"참고: 되감기가 없으면 불러온 세계가 관계 %d · 사건 %d 로 돌아간다 (판 0)"
			% [pristine.graph.size(), pristine.ledger.size()]
		)
	)


func _resume_row(label: String, world: NpcWorld, guild: Guild) -> void:
	print(
		(
			"%-24s %8d %8d %8d %8d"
			% [label, world.graph.size(), world.ledger.size(), guild.funds, guild.base_progress]
		)
	)


# ---------------------------------------------------------------- 영입


## **후보가 실제로 대원이 되나** (설계 37.8). 판정만 서고 데려오는 함수가 없던 자리다.
func _report_recruit() -> void:
	var world := NpcWorld.create(_SEED, _POPULATION)
	var guild := Guild.create_starting(_SEED, "새벽 길드", world)
	_staff(guild)
	var before := guild.members.size()
	var hired := PackedStringArray()
	for run in _RUNS:
		_settle(guild, run)
		for prospect in guild.prospects.duplicate():
			var member := GuildRecruit.hire(guild, prospect.id)
			if member != null:
				hired.append("%s(판 %d)" % [member.display_name, run + 1])

	print("\n-- 영입이 걸리나 (%d판 동안 보이는 대로 데려온다) --" % _RUNS)
	print("대원 %d명 -> %d명" % [before, guild.members.size()])
	print("데려온 사람   %s" % ("없다" if hired.is_empty() else " ".join(hired)))
	print("스쿼드 정원 %d — **정원이 늘지 않으면 인원이 늘어도 한 판에 다 못 나간다**" % guild.squad_capacity())


# ---------------------------------------------------------------- 뉴스와 성장


## 뉴스가 실제로 무엇을 내는가. **읽어 보지 않으면 문장이 말이 되는지 알 수 없다.**
func _report_news(world: NpcWorld, guild: Guild) -> void:
	print("\n-- 아지트에 뜨는 소식 (%d판 뒤) --" % _RUNS)
	var news := WorldNews.gather(world, GuildCircle.known_of(guild), GuildCircle.own_of(guild))
	if news.is_empty():
		print("아는 얼굴 소식은 없다")
	for line in news:
		print("  %s" % line)
	print("사건 %d건 중에서 골랐다 (아는 얼굴 %d명)" % [world.ledger.size(), GuildCircle.known_of(guild).size()])


## Q28 — **세계가 플레이어를 앞질러 가나** (설계 15.5).
##
## 물음이 「NPC 가 무한히 강해지는가」인데, 이 저장소에는 아직 **NPC 의 전투력이 없다.**
## 세계가 굴리는 것은 관계와 유명세뿐이라 **앞지를 수치 자체가 없다.**
## 그래서 대신 재는 것은 「내 대원이 세계에 비해 뒤처지나」다 — 유명세로 본다.
func _report_growth(world: NpcWorld, guild: Guild) -> void:
	var world_fame := PackedInt32Array()
	for person in world.registry.size():
		world_fame.append(world.registry.fame_of(person))
	world_fame.sort()

	var ours := PackedStringArray()
	for member in guild.members:
		if member.is_in_world():
			ours.append(str(world.registry.fame_of(member.person)))

	print("\n-- Q28 세계가 나를 앞지르나 (%d판 뒤) --" % _RUNS)
	print(
		(
			"세계 유명세   중위 %d · 90%% %d · 최대 %d"
			% [
				world_fame[world_fame.size() / 2],
				world_fame[world_fame.size() * 9 / 10],
				world_fame[world_fame.size() - 1],
			]
		)
	)
	print("내 대원      %s" % " ".join(ours))


# ---------------------------------------------------------------- 한 판


## 시설에 사람을 넣는다. **안 넣으면 접선처가 후보를 한 명도 안 찾아낸다** —
## `GuildBalance.prospects_for(0)` 이 0 이라 영입 칸이 통째로 안 열린다.
func _staff(guild: Guild) -> void:
	var ids := guild.member_ids()
	var places := [
		Facility.Kind.CONTACT_POINT,
		Facility.Kind.CONTACT_POINT,
		Facility.Kind.WORKSHOP,
		Facility.Kind.WORKSHOP,
		Facility.Kind.INTEL_ROOM,
	]
	for slot in mini(ids.size(), places.size()):
		guild.assignment.assign(ids[slot], places[slot])


## 이 판이 어떻게 끝나나. **판 번호에서 뽑는다** —
## 난수 발생기를 들고 다니면 두 길이 같은 순서를 못 걷고, 그러면 비교가 성립하지 않는다.
func _outcome_for(run: int) -> ExpeditionReport.Outcome:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED + run * 7919
	return (
		ExpeditionReport.Outcome.DOWNED
		if rng.randf() < _DOWN_RATE
		else ExpeditionReport.Outcome.ESCAPED
	)


func _settle(guild: Guild, run: int) -> void:
	var everyone := guild.member_ids()
	var went: Array[String] = []
	for slot in mini(guild.squad_capacity(), everyone.size()):
		went.append(everyone[(run + slot) % everyone.size()])
	var stayed: Array[String] = []
	for member_id in everyone:
		if not went.has(member_id):
			stayed.append(member_id)
	var gate := Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED + run)
	GuildSettlement.apply(
		guild,
		ExpeditionReport.new("exp_%d" % run, gate, _outcome_for(run), 5, went, stayed),
		_SEED + run
	)


func _row(world: NpcWorld, guild: Guild, run: int) -> void:
	print(
		(
			"%-10d %8d %8d %10.1f %8d %8d"
			% [
				run,
				world.graph.size(),
				world.ledger.size(),
				_squad_affinity(world, guild),
				guild.prospects.size(),
				_open_prospects(guild),
			]
		)
	)


## 대원의 **나가는** 호감 평균. 후유증이 보이는 유일한 자리다 (설계 24.30.5).
func _squad_affinity(world: NpcWorld, guild: Guild) -> float:
	var total := 0
	var seen := 0
	for member in guild.members:
		if not member.is_in_world() or not world.registry.has(member.person):
			continue
		for other in world.graph.targets_of(member.person):
			total += world.graph.affinity(member.person, other)
			seen += 1
	return float(total) / maxf(float(seen), 1.0)


## 지금 실제로 데려올 수 있는 후보 수. **관계도가 보상을 주고 있나**가 이 칸이다.
func _open_prospects(guild: Guild) -> int:
	var open := 0
	for prospect in guild.prospects:
		if prospect.can_recruit():
			open += 1
	return open
