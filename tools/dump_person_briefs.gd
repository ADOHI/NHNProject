extends SceneTree
## 인물 하나를 LLM 입력으로 직렬화한다. **`dump_rekka_prompts.gd` 와 같은 자리다.**
##
## docs/design/27-portraits.md §27.3 의 파이프라인 첫 칸이다.
##
##     PersonRegistry --> [이 도구] --> gpt-5.6-luna --> 설정 시트 + 이미지 프롬프트
##
## ## 왜 손으로 안 적나
##
## [`19-rekka-voice.md`](../docs/design/19-rekka-voice.md) §19.B.0 의 규율이다 —
## *"5차 표본의 「판이 이미 아는 것」은 손으로 적은 것이었고, 그래서 수집기가 실제로
## 그런 줄을 뽑는지는 검증되지 않았다."*
##
## **여기 나가는 값은 전부 `PersonRegistry` 가 실제로 들고 있는 것이다.**
## 지어낸 설정을 넣으면 그 순간 시트가 거짓말이 된다.
##
## ## 이름을 홑화살괄호로 감싼다
##
## 렉카가 실측한 사고다 (§19.A.5) — `웃는 베른` 을 안 감쌌더니 모델이 이름을 서술로 읽어
## *"베른이 웃고 있었습니다"* 가 나왔다. **초상에서는 그게 그림으로 나온다.**
## 괄호는 입력 전용이고 산출에서는 걷어낸다.
##
## ## 나이와 가족은 지금 빈칸이다
##
## 인물 레인이 만드는 중이다 (§27.3.1). **빈칸인 것을 빈칸이라고 적어 내보낸다** —
## `person_sheet.gd` 의 `MISSING` 이 하는 것과 같다(§24.17.7). 아무 말도 없으면
## 모델이 그 자리를 **지어낸다.**
##
##     godot --headless --path . -s res://tools/dump_person_briefs.gd -- --index 7
##     godot --headless --path . -s res://tools/dump_person_briefs.gd -- --pick 12

## 기준 시드. `survey_npc_population.gd` 와 같은 값이라 **같은 3000명이 나온다** (§24.16.7).
## **데모 캐스트는 시드를 고정한다** — 격자를 폐기한 근거가 이것이다 (§27.2.2).
const _SEED := 20260808

## 인구. §24.8 의 상한이고 §24.16.9 의 실측이 이 값으로 잡혀 있다.
const _POPULATION := 3000

## `--pick` 이 후보를 고를 때 쓰는 최소 극 축 수.
## 극이 하나도 없는 인물로 파이프라인을 시험하면 **성향이 아무것도 안 보인다.**
const _PICK_MIN_POLES := 2


func _initialize() -> void:
	var args := _args()
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()

	if args.has("pick"):
		_print_candidates(registry, int(args["pick"]))
	else:
		var index := int(args.get("index", 0))
		if index < 0 or index >= registry.size():
			printerr("인물 인덱스가 범위 밖이다: %d (인구 %d)" % [index, registry.size()])
			quit(1)
			return
		print(brief_of(registry, index))
	quit()


## `-- --index 7` 처럼 넘어온 것을 모은다.
func _args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var key := String(argv[i]).lstrip("-")
		var value := "1"
		if i + 1 < argv.size() and not String(argv[i + 1]).begins_with("--"):
			value = String(argv[i + 1])
			i += 1
		out[key] = value
		i += 1
	return out


## 극 축이 여럿인 인물을 몇 명 보여 준다. **누구로 시험할지 고르는 데만 쓴다.**
func _print_candidates(registry: PersonRegistry, want: int) -> void:
	var factions := FactionIndex.new(registry)
	print("=== 극 축 %d개 이상인 인물 (시드 %d · 인구 %d) ===" %
			[_PICK_MIN_POLES, _SEED, _POPULATION])
	var shown := 0
	for i in registry.size():
		var traits := registry.traits_of(i)
		if PersonTag.poles_of(traits).size() < _PICK_MIN_POLES:
			continue
		print("  %5d  %-10s %-4s 전투%2d 민첩%2d 유명세%3d  %s" % [
			i,
			registry.name_of(i),
			MemberDiscipline.label(registry.discipline_of(i)),
			registry.threat_of(i),
			registry.agility_of(i),
			registry.fame_of(i),
			PersonTag.of(traits),
		])
		shown += 1
		if shown >= want:
			break
	print("\n  소속 분포는 참고: 소속 %d개" % factions.populated_count())


## 인물 하나의 LLM 입력. **두 칸이다** — 사실과 성향 (§19.A.5 의 형식을 따른다).
func brief_of(registry: PersonRegistry, index: int) -> String:
	var traits := registry.traits_of(index)
	var poles := PersonTag.poles_of(traits)
	var factions := FactionIndex.new(registry)
	var discipline := registry.discipline_of(index)

	var lines := PackedStringArray()
	lines.append("인물")
	lines.append("- 이름 <%s>" % registry.name_of(index))
	lines.append("- 계열 %s — %s" % [
		MemberDiscipline.label(discipline),
		MemberDiscipline.eye_note(discipline),
	])
	lines.append("- 전투력 %d · 민첩 %d (계열 기본은 전투 %d · 민첩 %d)" % [
		registry.threat_of(index),
		registry.agility_of(index),
		MemberDiscipline.base_threat(discipline),
		MemberDiscipline.base_agility(discipline),
	])
	var faction := registry.faction_of(index)
	if faction == PersonRegistry.NO_FACTION:
		lines.append("- 소속 없음")
	else:
		lines.append("- 소속 %s" % factions.describe(faction))
	lines.append("- 유명세 %d (%s)" % [registry.fame_of(index), _fame_note(registry.fame_of(index))])
	# **빈칸인 것을 빈칸이라고 적는다.** 아무 말도 없으면 모델이 지어낸다 (§24.17.4).
	lines.append("- 나이 아직 없음 — 인물 레인이 만드는 중")
	lines.append("- 가족 아직 없음 — 나이가 있어야 만들 수 있다")

	lines.append("성향")
	for axis in NpcAxis.count():
		var value := traits[axis]
		# **부호를 그대로 내보내지 않는다. 1차 실호출이 여기서 졌다** (§27.15.4).
		#
		# 처음엔 `정직/기만 +52` 로 냈다. 모델이 **두 축에서 부호를 뒤집어 읽었다** —
		# `정직 +52` 인 사람을 *"진실을 필요한 만큼만 흘린다"* 로,
		# `과시 +37` 인 사람을 *"앞에 나서기보다 조용히"* 로 썼다.
		# 「+ 가 앞 이름 쪽」이라는 규칙을 모델이 알 방법이 없다.
		#
		# `NpcAxis.pole_label()` 이 이미 그 해석을 코드로 들고 있다. **그것을 쓴다** —
		# 해석을 모델에게 시키지 않는다.
		lines.append("- %s 축: %s 쪽으로 %d%s" % [
			NpcAxis.label(axis),
			NpcAxis.pole_label(axis, value),
			absi(value),
			"  (극)" if poles.has(axis) else "",
		])
	lines.append("  (0 이면 두 쪽 어디도 아니고, 100 이면 그쪽 극단이다)")
	lines.append("- 딱지 %s" % PersonTag.of(traits))
	return "\n".join(lines)


## 유명세를 말로 옮긴다. §24.16.9 실측 — 중위 0, 50 이상 7.8%, 90 이상 1.2%.
##
## **수치를 그대로 주면서 말도 같이 준다.** 렉카는 수치를 아예 뺐지만(§19.3.2)
## 여기는 개발용 시트라 수치가 보여야 하고, 다만 모델이 3 과 30 의 차이를
## 인구 분포 안에서 읽지는 못하므로 그 자리만 말로 받쳐 준다.
func _fame_note(fame: int) -> String:
	if fame >= 90:
		return "이 세계에서 손꼽히게 유명하다 — 상위 1%"
	if fame >= 50:
		return "이름이 알려져 있다 — 상위 8%"
	if fame >= 15:
		return "아는 사람은 안다"
	return "거의 무명이다 — 대다수가 여기다"
