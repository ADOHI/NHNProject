class_name Gate
extends RefCounted
## 열린 게이트 하나. 아웃게임에서 고르는 대상이다.
##
## ## 게이트와 던전은 다른 것이다
##
## 게이트는 **문**이고 던전은 **안쪽 공간**이다 (docs/design/22-guild-base.md §22.0).
## 그래서 이 클래스는 방도 간선도 들지 않는다 — 등급 · 이름 · 공개 수준 · 씨앗만 든다.
## 안쪽은 기존 생성기가 그대로 만든다 (src/core/dungeon/).
##
## ## 씨앗이 고정인 이유
##
## 같은 게이트를 고르면 언제나 같은 던전이 나와야 한다.
## 고를 때마다 안쪽이 달라지면 "이 게이트를 고른다" 는 결정이 도박이 되고,
## 정보실이 미리 보여 준 것(§22.5)도 거짓말이 된다.
## 정보를 파는 시스템은 그 정보가 참일 때만 성립한다.

## 목록에서 이 게이트를 가리키는 식별자.
var id: String

## 표시명.
var display_name: String

## 등급. 안쪽 던전의 크기와 보상 배수를 정한다.
var rank: GateRank.Kind

## 안쪽 던전의 씨앗. 이 값이 고정이라 같은 게이트가 같은 판을 낸다.
var dungeon_seed: int

## 같은 등급 안에서의 크기 흔들림 (-1 / 0 / +1).
##
## **등급만으로는 목록이 갈리지 않는다.** 길드 등급 1 에서는 E급 게이트만 열 수 있으므로
## (`GateRank.is_open_to`) 네 게이트가 전부 같은 등급이 된다. 그러면 「어느 걸 갈까」가
## 성립하지 않는다 — 첫 판에서 보는 화면이 그렇다.
##
## 등급 상한을 올릴 수는 없다. 못 들어가는 게이트를 목록에 올리면
## "고르는 재미" 가 "안 되는 것 구경" 이 된다 (GateRank 주석).
## 그래서 **같은 등급 안에서 크기를 흔든다** — 넓은 판은 방이 많아 귀중품도 많고
## 그만큼 오래 머문다. 위험과 보상이 같이 움직이므로 저울이 돈다.
var size_offset := 0

## 안쪽 던전의 **성격** (DungeonCatalog 의 색인).
##
## 등급이 크기를 정하는 것과 **다른 축**이다. 같은 등급의 「벌집」과 「수직 회랑」이
## 따로 있을 수 있어야 §7.3 의 "선택이 곧 난이도 선택" 이 성립한다.
## 아직 이 값을 고르는 아웃게임 화면이 없어서 기본값은 0 이다.
var dungeon_character := 0

## 해부 수준에서만 만들어지는 설계도. 만들기 전에는 null 이다.
var _blueprint: DungeonBlueprint = null


func _init(gate_id: String, name: String, gate_rank: GateRank.Kind, seed_value: int) -> void:
	id = gate_id
	display_name = name
	rank = gate_rank
	dungeon_seed = seed_value


## 안쪽 던전의 크기 단계. SampleDungeons 의 크기 축과 같다.
func dungeon_size() -> int:
	return clampi(
		GateRank.dungeon_size(rank) + size_offset, SampleDungeons.SIZE_MIN, SampleDungeons.SIZE_MAX
	)


## 안쪽 던전을 실제로 세운다.
##
## **생성은 기존 것을 그대로 쓴다.** 게이트가 넘겨받은 것은
## "어떤 판을 열 것인가" 이지 "판을 어떻게 만드는가" 가 아니다.
func create_run() -> DungeonRun:
	return SampleDungeons.create_run(dungeon_seed, dungeon_size(), dungeon_character)


## 설계도만 본다. 처음 한 번만 만들고 이후에는 같은 것을 돌려준다.
##
## 존재 배치 없이 구조만 필요할 때 쓴다 — 해부 수준의 미리보기가 그것이다.
func blueprint() -> DungeonBlueprint:
	if _blueprint == null:
		var generator := DungeonGenerator.new(
			dungeon_seed, SampleDungeons.params_for_size(dungeon_size(), dungeon_character)
		)
		_blueprint = generator.generate()
	return _blueprint


## 입장 전에 보이는 줄들. 공개 수준이 높을수록 길어진다.
##
## 문자열을 여기서 만드는 이유는 화면이 여럿이기 때문이다.
## 임시 화면과 나중에 올 조형 화면이 같은 문장을 봐야 정보량이 어긋나지 않는다.
func preview_lines(level: GateDisclosure.Level) -> Array[String]:
	var lines: Array[String] = ["등급 %s" % GateRank.label(rank)]
	if level >= GateDisclosure.Level.SURVEYED:
		lines.append("예상 규모 %d 개 방" % SampleDungeons.room_estimate(dungeon_size()))
		# 성격은 **값을 치르고 얻는 정보**다. 소문 수준에서는 등급만 보인다
		# (test_gate.gd 가 그 계약을 지킨다).
		lines.append("성격 %s" % DungeonCatalog.name_of(dungeon_character))
	if GateDisclosure.needs_blueprint(level):
		var plan := blueprint()
		# **잰 값은 해부 수준에서만 나올 수 있다.** 재려면 설계도가 있어야 하고
		# 설계도는 이 수준에서만 만든다(22-guild-base.md). 구현 제약과 정보 설계가
		# 같은 곳을 가리킨다 (docs/design/17-dungeon-generation.md §17.20.5).
		var grade := DungeonGrade.of(plan)
		lines.append("실제 방 %d 개" % plan.room_ids().size())
		(
			lines
			. append(
				(
					"규모 %d/%d • 복잡 %d/%d • 험난 %d/%d"
					% [
						grade["scale"],
						DungeonGrade.SCALE_MAX,
						grade["complexity"],
						DungeonGrade.COMPLEXITY_MAX,
						grade["hardship"],
						DungeonGrade.HARDSHIP_MAX,
					]
				)
			)
		)
		# 등급만 보여 주면 왜 그 등급인지 알 수 없다. 근거를 한 줄 붙인다.
		lines.append(
			(
				"갈림길 %d%% • 한 걸음 평균 상승 %.1f"
				% [int(round(float(grade["junction_pct"]))), float(grade["average_climb"])]
			)
		)
		lines.append("고가치 방 %d 개" % plan.rooms_of_kind(Room.Kind.TREASURE).size())
		lines.append(
			"보스 %s" % ("있음" if not plan.rooms_of_kind(Room.Kind.BOSS).is_empty() else "없음")
		)
	return lines
