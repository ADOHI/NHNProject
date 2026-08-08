extends SceneTree
## 인물 하나를 LLM 입력으로 직렬화한다. **`dump_rekka_prompts.gd` 와 같은 자리다.**
##
## docs/design/27-portraits.md §27.3 의 파이프라인 첫 칸이다.
##
##     PersonRegistry --> [이 도구] --> gpt-5.6-luna --> 설정 시트 + 이미지 프롬프트
##
## ## 두 번 만들지 않는다 — 본문은 `PersonDossier` 가 낸다
##
## 인물 하나의 설정을 글로 옮기는 일은 **인물 레인이 이미 했다**
## (`src/core/npc/person_dossier.gd`, §24.22.6). 상세 화면과 같은 `PersonSheet` 를
## 읽으므로 칸이 늘면 화면과 이 브리프에 같이 나온다. **그것을 다시 짜지 않는다.**
##
## ## 다만 두 자리를 갈아 끼운다 — **화면의 표기가 LLM 입력으로는 함정이다**
##
## §27.18 이 이 레인의 가장 값나가는 발견이다 —
## **입력 형식이 해석을 요구하면 모델이 해석을 틀린다.**
##
## | 자리 | 화면에서는 | LLM 입력으로는 |
## | --- | --- | --- |
## | `- 이름: 오라빈` | 맞다 | **이름인지 서술인지 모른다** → 홑화살괄호로 감싼다 (§19.A.5) |
## | `- 선/악: -47` | 맞다. 막대가 방향을 그린다 | **부호가 어느 쪽인지 모른다** → 쪽 이름을 적는다 |
##
## 갈아 끼우는 자리를 못 찾으면 **조용히 넘어가지 않고 터뜨린다.** 반쪽짜리 브리프로
## 시트를 뽑으면 무엇이 틀렸는지 알 수 없게 된다.
##
## > **인물 레인에 넘길 것:** `PersonDossier` 자체가 이 함정 위에 있다.
## > 머리말이 *"LLM 입력이 된다"* 라고 적혀 있는데 성향 칸이 `%+d` 로 나간다.
## > 그 레인이 고치면 여기의 갈아 끼우기 하나가 지워진다.
##
## ## 나이와 가족이 붙었다
##
## `npc-relations` 의 `924fab1` 을 받았다 (§27.18.1). 나이 16~58 · 중위 28,
## 가족이 있는 인물 71.7%. **혈연은 부계뿐이고 혼인이 없다** —
## 그것을 브리프가 말하지 않으면 모델이 어머니를 지어낸다 (§24.17.4).
##
##     godot --headless --path . -s res://tools/dump_person_briefs.gd -- --index 13
##     godot --headless --path . -s res://tools/dump_person_briefs.gd -- --pick 12
##     godot --headless --path . -s res://tools/dump_person_briefs.gd -- --pick 12 --mode kin

## 기준 시드. `survey_npc_population.gd` · `survey_npc_kin.gd` 와 같은 값이라
## **같은 3000명이 나온다** (§24.16.7). **데모 캐스트는 시드를 고정한다** (§27.2.2).
const _SEED := 20260808

## 인구. §24.8 의 상한이고 §24.16.9 의 실측이 이 값으로 잡혀 있다.
const _POPULATION := 3000

## `--pick --mode poles` 가 후보를 고를 때 쓰는 최소 극 축 수.
const _PICK_MIN_POLES := 2

## `--pick --mode kin` 이 후보를 고를 때 쓰는 최소 관계 수.
## 차수 중위가 1 이고 90% 가 2 라(실측) 4 면 상위 몇 %다.
const _PICK_MIN_KIN := 4

## 「약간 ~쪽」의 하한. 이 아래는 브리프가 **쪽을 아예 말하지 않는다.**
##
## **1차 실호출이 여기서 졌다** (§27.15.4) — `위계 쪽으로 5`(사실상 가운데)를
## 모델이 *"자유를 중시해 명령과 규율을 가볍게 여긴다"* 로 썼다. 방향도 뒤집고
## 세기도 부풀렸다. **쪽을 말해 주면 모델은 그 쪽을 쓴다.** 5 도 쪽이라고 적으면
## 5 짜리 성향이 문장 한 줄을 가져간다.
##
## **둘로 가르지 않고 셋으로 가른다.** 극(60)만 이름을 붙이고 나머지를 전부
## 「아니다」로 보내면 **59 와 30 이 같아진다.** 59 는 눈에 띄게 기운 사람이다.
##
## 값이 `TraitDistribution.POLE_MIN` 의 절반인 이유: 극의 경계를 코드가 이미
## 들고 있으므로 새 수를 지어내지 않고 그것을 반으로 접는다. 극이 움직이면 같이 움직인다.
const _LEAN_MIN := TraitDistribution.POLE_MIN / 2

## `PersonDossier` 가 내는 성향 칸의 머리. 이 줄을 찾아 통째로 갈아 끼운다.
const _TRAITS_HEAD := "[성향]"

## 관계 칸의 머리. 없으면 **가족이 없는 사람이라** 없다고 적어 넣는다.
const _RELATIONS_HEAD := "[관계]"

## 성별을 뽑는 소금. **레코드에 성별이 없다** (§27.19.1).
##
## 시안에서 **계열마다 성별이 쏠렸다** — 전투 7장 전부 남자, 감식 3장 전부 여자.
## 프롬프트에 성별을 한 번도 안 썼는데 그랬다. **모델이 마음대로 정하고 있었다.**
##
## 인물 레인에 넣어 달라고 넘겼다. 그때까지 **시드에서 결정적으로 뽑는다** —
## `randi()` 를 쓰면 같은 인물의 성별이 부를 때마다 바뀌고, 그러면 시트와 그림이 어긋난다.
const _GENDER_SALT := 8_675_309

## 성별 이름. 레코드가 성별을 갖게 되면 이 배열이 아니라 레코드가 이름을 든다.
const _GENDERS := ["남자", "여자"]


func _initialize() -> void:
	var args := _args()
	var registry := PersonGenerator.new(_SEED, _POPULATION).generate()
	var graph := _seed_kin(registry)

	if args.has("pick"):
		_print_candidates(registry, graph, int(args["pick"]), String(args.get("mode", "poles")))
	else:
		var index := int(args.get("index", 0))
		if index < 0 or index >= registry.size():
			printerr("인물 인덱스가 범위 밖이다: %d (인구 %d)" % [index, registry.size()])
			quit(1)
			return
		var brief := brief_of(registry, graph, index)
		if brief.is_empty():
			quit(1)
			return
		print(brief)
	quit()


## 가족을 심는다. **`survey_npc_kin.gd` 와 같은 시드 · 같은 순서라 같은 가족이 나온다.**
func _seed_kin(registry: PersonRegistry) -> RelationGraph:
	var graph := RelationGraph.new(registry.size())
	KinSeeder.new(_SEED, registry, graph).seed_all()
	return graph


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


## 시험할 사람을 고르는 데만 쓴다. **모드마다 다른 시험이다.**
##
## | 모드 | 무엇을 보나 |
## | --- | --- |
## | `poles` | 극 축이 여럿인 사람. 성향이 시트에 제대로 실리나 |
## | `colorless` | 극이 하나도 없는 사람. **모델이 무엇을 지어내나** |
## | `kin` | 관계가 많은 사람. **모델이 가족을 어떻게 쓰나** |
func _print_candidates(
	registry: PersonRegistry, graph: RelationGraph, want: int, mode: String
) -> void:
	var factions := FactionIndex.new(registry)
	print("=== 후보 (%s · 시드 %d · 인구 %d) ===" % [mode, _SEED, _POPULATION])
	var shown := 0
	for i in registry.size():
		if not _matches(registry, graph, i, mode):
			continue
		print(
			(
				"  %5d  %-10s %-4s %2d세 전투%2d 민첩%2d 유명세%3d 관계%2d  %s"
				% [
					i,
					registry.name_of(i),
					MemberDiscipline.label(registry.discipline_of(i)),
					registry.age_of(i),
					registry.threat_of(i),
					registry.agility_of(i),
					registry.fame_of(i),
					graph.degree_of(i),
					PersonTag.of(registry.traits_of(i)),
				]
			)
		)
		shown += 1
		if shown >= want:
			break
	print("\n  소속 분포는 참고: 소속 %d개" % factions.populated_count())


func _matches(registry: PersonRegistry, graph: RelationGraph, person: int, mode: String) -> bool:
	match mode:
		"colorless":
			return PersonTag.poles_of(registry.traits_of(person)).is_empty()
		"kin":
			return graph.degree_of(person) >= _PICK_MIN_KIN
		_:
			return PersonTag.poles_of(registry.traits_of(person)).size() >= _PICK_MIN_POLES


## 인물 하나의 LLM 입력. **본문은 `PersonDossier` 가 내고 두 자리만 갈아 끼운다.**
func brief_of(registry: PersonRegistry, graph: RelationGraph, index: int) -> String:
	var factions := FactionIndex.new(registry)
	var text := PersonDossier.text(registry, index, factions, graph)
	if text.is_empty():
		printerr("PersonDossier 가 빈 글을 냈다: 인물 %d" % index)
		return ""

	text = _wrap_name(text, registry.name_of(index))
	if text.is_empty():
		return ""
	text = _add_gender(text, registry, index)
	if text.is_empty():
		return ""
	text = _gloss_discipline(text, registry.discipline_of(index))
	if text.is_empty():
		return ""
	text = _replace_traits(text, registry.traits_of(index))
	if text.is_empty():
		return ""
	return _note_kin(text, graph, index)


## 성별을 나이 줄 아래에 끼운다. **레코드에 없는 유일한 칸이다** (§27.19.1).
##
## 시안이 성별 쏠림을 냈다 — 전투 7장 전부 남자, 감식 3장 전부 여자.
## 프롬프트에 성별이 한 낱말도 없었으므로 **모델이 계열 낱말에서 성별을 유추했다.**
## 안 주면 모델이 정한다. 그러니 준다.
func _add_gender(text: String, registry: PersonRegistry, person: int) -> String:
	var line := "- 나이: %d세" % registry.age_of(person)
	if not text.contains(line):
		printerr("나이 줄을 못 찾았다: %s — PersonDossier 형식이 바뀌었다" % line)
		return ""
	return text.replace(line, "%s\n- 성별: %s" % [line, gender_of(registry, person)])


## 계열 이름에 **그 계열이 무슨 일을 하는지**를 붙인다.
##
## **이름 두 글자는 뜻을 실어 나르지 못한다.** 실측으로 걸렸다 (§27.19.3) —
## `- 계열: 기공` 만 주었더니 모델이 그것을 **氣功**으로 읽고 열전 전체를
## *"기의 흐름을 읽는 법"* · *"호흡과 기맥을 다듬고"* 로 썼다. 이 세계의 기공은
## **고도 차이와 통로 상태를 읽는** 기술자다.
##
## `MemberDiscipline.eye_note()` 가 그 뜻을 코드로 들고 있다. **그것을 쓴다** —
## §27.18 과 같은 자리다. 코드가 아는 것을 모델이 이름에서 되짚게 하지 않는다.
func _gloss_discipline(text: String, discipline: MemberDiscipline.Kind) -> String:
	var line := "- 계열: %s" % MemberDiscipline.label(discipline)
	if not text.contains(line):
		printerr("계열 줄을 못 찾았다: %s — PersonDossier 형식이 바뀌었다" % line)
		return ""
	return text.replace(line, "%s — %s" % [line, MemberDiscipline.eye_note(discipline)])


## 인물의 성별. **여기 한 곳만 고치면 레코드로 갈아 끼워진다.**
##
##     return registry.gender_label_of(person)   # 레코드에 성별이 생기면 이 한 줄이다
##
## 지금은 시드에서 뽑는다. **`randi()` 를 쓰지 않는다** — 같은 인물이 부를 때마다
## 성별이 바뀌면 시트와 그림이 어긋나고, 그것을 나중에 눈으로 찾을 수 없다.
## 시드와 인덱스만으로 값이 정해지므로 같은 명령이 같은 성별을 낸다 (§24.16.7 의 규율).
## `_registry` 는 지금 안 쓰지만 **자리를 비워 두는 것이 목적이다** — 레코드가
## 성별을 갖게 되면 밑줄만 떼고 `_registry.gender_label_of(person)` 을 돌려주면 된다.
func gender_of(_registry: PersonRegistry, person: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_SEED) ^ (person * _GENDER_SALT)
	return _GENDERS[rng.randi() % _GENDERS.size()]


## 이름을 홑화살괄호로 감싼다 (§19.A.5).
##
## 렉카가 실측한 사고다 — `웃는 베른` 을 안 감쌌더니 모델이 이름을 서술로 읽어
## *"베른이 웃고 있었습니다"* 가 나왔다. **초상에서는 그게 그림으로 나온다.**
## 괄호는 입력 전용이고 산출에서는 걷어낸다 (시스템 프롬프트가 시킨다).
func _wrap_name(text: String, person_name: String) -> String:
	var line := "- 이름: %s" % person_name
	if not text.contains(line):
		printerr("이름 줄을 못 찾았다: %s — PersonDossier 형식이 바뀌었다" % line)
		return ""
	return text.replace(line, "- 이름: <%s>" % person_name)


## 성향 칸을 통째로 갈아 끼운다. **여기가 §27.18 의 자리다.**
##
## `PersonDossier` 는 화면과 같은 `%+d` 를 낸다. 화면에서는 막대가 방향을 그리므로
## 맞는 표기인데, 글로 나가면 **부호가 어느 쪽인지 아는 방법이 없다.**
## `+` 가 앞 이름 쪽이라는 것은 `NpcAxis._POSITIVE` 배열의 순서이고 모델은 그 배열을
## 본 적이 없다. **코드가 이미 아는 것을 모델에게 다시 알아내라고 시키지 않는다.**
func _replace_traits(text: String, traits: PackedInt32Array) -> String:
	var blocks := text.split("\n\n")
	var found := -1
	for slot in blocks.size():
		if String(blocks[slot]).begins_with(_TRAITS_HEAD):
			found = slot
			break
	if found < 0:
		printerr("성향 칸을 못 찾았다 — PersonDossier 형식이 바뀌었다")
		return ""
	blocks[found] = _traits_block(traits)
	return "\n\n".join(blocks)


## 성향 여섯 줄. **세기를 셋으로 가른다** (`_LEAN_MIN` 주석에 근거가 있다).
func _traits_block(traits: PackedInt32Array) -> String:
	var poles := PersonTag.poles_of(traits)
	var lines := PackedStringArray()
	lines.append(_TRAITS_HEAD)
	lines.append("- 딱지: %s" % PersonTag.of(traits))
	for axis in NpcAxis.count():
		var kind := axis as NpcAxis.Kind
		lines.append("- %s 축: %s" % [NpcAxis.label(kind), _axis_words(kind, traits[axis])])
	lines.append(
		"  (「극」은 그 사람을 부르는 말이 된다. 「약간」은 기울었을 뿐이다." + " 쪽이 안 적힌 축은 가운데라 **그 축으로 이 사람을 설명하지 마라**)"
	)
	# 극이 하나도 없는 사람에게 이 줄이 가장 중요하다 — 안 적으면 모델이 성향을
	# 지어내서 채운다. 딱지의 `무색` 만으로는 「무색한 성격」으로 읽힐 수 있다.
	if poles.is_empty():
		lines.append("  (극이 하나도 없다. 이 사람은 어느 쪽으로도 뚜렷하지 않은 다수에 속한다)")
	return "\n".join(lines)


## 축 하나를 말로. **쪽을 말할지 말지가 여기서 갈린다.**
func _axis_words(kind: NpcAxis.Kind, value: int) -> String:
	var strength := absi(value)
	if strength < _LEAN_MIN:
		# **쪽을 말하지 않는다. 수치도 주지 않는다.** 수치를 주면 모델이 쪽을 되짚으려 한다.
		return "어느 쪽도 아니다"
	if strength < TraitDistribution.POLE_MIN:
		return "약간 %s 쪽으로 %d" % [NpcAxis.pole_label(kind, value), strength]
	return "%s 쪽으로 %d  (극)" % [NpcAxis.pole_label(kind, value), strength]


## 관계 칸에 **자료의 모양**을 한 줄 덧붙인다.
##
## 혈연 2490건 중 성이 다른 것이 0건이고(실측), `RelationKind._SHARES_SURNAME` 가
## 부모 · 자식 · 형제뿐이다. **어머니도 배우자도 자료에 없다.**
## 안 적으면 모델이 그 자리를 지어낸다 (§24.17.4) — 「빈칸을 빈칸이라고 적는다」.
func _note_kin(text: String, graph: RelationGraph, person: int) -> String:
	var lines := PackedStringArray()
	if graph.degree_of(person) == 0:
		lines.append("")
		lines.append(_RELATIONS_HEAD)
		lines.append("- 가족도 스승도 없다. 혼자다")
	lines.append("  (이 세계의 자료에는 부계 혈연과 사제만 있다. 어머니와 배우자는 자료에 없다)")
	return text + "\n" + "\n".join(lines)
