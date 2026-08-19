extends SceneTree
## 판을 이어 돌리면 세계가 실제로 움직이나. 그리고 **그것이 저장을 건너나.**
##
## docs/design/37-meta-loop.md §37.10.
##
## **한 판만 보면 안 보인다.** 세계 틱은 여러 판을 이어 돌려야 드러나고,
## 저장을 건너는지는 **껐다 켜는 것을 흉내 내야** 드러난다.
##
##   godot --headless --path . -s res://tools/survey_meta_loop.gd

const _SEED := 20260819
const _POPULATION := 3000

## 몇 판을 돌리나. 한 회차가 스무 판 남짓이다 (설계 24.30.5).
const _RUNS := 20

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
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	for run in _RUNS:
		_settle(guild, rng, run)
		if (run + 1) % 5 == 0:
			_row(world, guild, run + 1)

	_report_save(guild)
	_report_growth(world, guild)
	quit()


## 껐다 켜는 것을 흉내 낸다. **§37.2.1 ①이 무엇이었는지가 여기서 보인다.**
func _report_save(guild: Guild) -> void:
	var store := SaveStore.new(_SAVE_PATH)
	var error := store.write(guild, _SEED)
	if error != OK:
		print("\n저장하지 못했다 (오류 %d)" % error)
		return
	var loaded := store.read()
	if not loaded.is_ok():
		print("\n불러오지 못했다 — %s" % loaded.message())
		return

	# 봉투 v1 이 하던 것 — 씨앗에서 처녀 세계를 세우고 끝이다.
	var pristine := NpcWorld.create(_SEED, _POPULATION)

	print("\n-- 세계가 저장을 건너나 --")
	print("%-22s %8s %8s %10s" % ["", "관계", "사건", "대원호감"])
	_save_row("저장 직전", guild.world, guild)
	_save_row("불러온 뒤 (봉투 v2)", loaded.world, loaded.guild)
	_save_row("되감기 없이 (봉투 v1)", pristine, loaded.guild)
	print(
		(
			"틱 %d회 · 세계 사건 %d건이 세이브에 남았다"
			% [guild.world_progress.tick_count(), guild.world_progress.events_rolled()]
		)
	)
	var same := guild.world.graph.size() == loaded.world.graph.size()
	print("불러온 세계가 저장한 세계와 %s" % ["다르다 — 되감기가 깨졌다", "같다"][int(same)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


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


func _settle(guild: Guild, rng: RandomNumberGenerator, run: int) -> void:
	var everyone := guild.member_ids()
	var went: Array[String] = []
	for slot in mini(guild.squad_capacity(), everyone.size()):
		went.append(everyone[(run + slot) % everyone.size()])
	var stayed: Array[String] = []
	for member_id in everyone:
		if not went.has(member_id):
			stayed.append(member_id)
	var outcome := (
		ExpeditionReport.Outcome.DOWNED
		if rng.randf() < _DOWN_RATE
		else ExpeditionReport.Outcome.ESCAPED
	)
	var gate := Gate.new("gate_0", "붉은 회랑", GateRank.Kind.C, _SEED + run)
	GuildSettlement.apply(
		guild, ExpeditionReport.new("exp_%d" % run, gate, outcome, 5, went, stayed), _SEED + run
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


func _save_row(label: String, world: NpcWorld, guild: Guild) -> void:
	print(
		(
			"%-22s %8d %8d %10.1f"
			% [label, world.graph.size(), world.ledger.size(), _squad_affinity(world, guild)]
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
