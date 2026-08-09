class_name DungeonCatalog
extends RefCounted
## 던전마다 **성격**을 준다. 생성 파라미터를 다르게 주는 것이 성격이다
## (docs/design/07-level-design.md §7.3.1).
##
## ## 왜 필요한가
##
## 파라미터 9개 중 8개가 전 던전 공통이었다. 그래서 던전끼리 「강함」만 달랐고,
## §7.3 이 적어 둔 대로 그건 **선택이 아니라 순서**였다.
##
## ## 성격은 크기와 다른 축이다
##
## 게이트 등급이 이미 던전의 **크기**를 정한다(`GateRank.dungeon_size`).
## 성격은 그것과 **직교한다** — 같은 크기의 「벌집」과 「수직 회랑」이 있을 수 있어야 한다.
## 그래서 이 카탈로그는 방 개수를 건드리지 않고 **성격 축만** 얹는다.
##
## ## 흔드는 축을 고른 근거
##
## 아무 파라미터나 흔들면 잡음만 는다. **흔든 것이 플레이어에게 읽혀야** 성격이다.
## 어느 축이 읽히는지는 실측으로 갈랐다
## (docs/design/17-dungeon-generation.md §17.16).
##
##     신호대잡음 = |축 높음 - 축 낮음| / (같은 파라미터에서 시드만 바꿨을 때의 편차 x 2)
##
## **1.5 아래면 쓰지 않는다.** 시드가 더 크게 흔드는 축은 플레이어에게 「이번 판은 운이
## 나빴다」로 읽히지 「이 던전은 다르다」로 읽히지 않는다.
##
## 그래서 **층 안 기복**(0.48)과 **기복의 잔 정도**(0.11)는 어느 던전도 쓰지 않는다.
##
## ## 한 던전에 축은 둘까지
##
## 셋 이상 흔들면 어느 것이 그 던전의 성격인지 읽히지 않는다. 그리고 축은 서로 독립이
## 아니라서 — 귀중품을 올리면 위험방이 줄고, 곁가지를 올리면 보스 필요 민첩이 내린다 —
## 여럿을 흔들면 서로 상쇄해 결국 「그냥 다른 판」이 된다.


## 던전 하나의 성격.
##
## `axes` 는 `DungeonGenerator.Params` 의 필드 이름 -> 값이다.
## **비어 있으면 기본 성격**이고, 그것도 하나의 던전이다.
class Character:
	extends RefCounted

	var id: String
	var display_name: String

	## 판에서 무엇으로 읽히는가. 정보실 미리보기와 문서가 같은 문장을 쓴다.
	var summary: String

	## 흔드는 축. 둘까지.
	var axes: Dictionary

	func _init(character_id: String, name: String, reads_as: String, shaken: Dictionary) -> void:
		id = character_id
		display_name = name
		summary = reads_as
		axes = shaken


## 성격 목록. 순서가 곧 색인이다.
##
## **이름과 성격은 기획이라 뒤집힐 수 있다. 구조는 이름을 모른다** — 생성기는 축 값만 받는다.
static func all() -> Array[Character]:
	return [
		(
			Character
			. new(
				"shallow_pit",
				"얕은 갱도",
				# **「고도 숫자가 작다」는 약속을 지킨 적이 없다.** 단차 1.0 은 기본 2.0 과 너무
				# 가까워 판 하나만 봐서는 25% 만 알아봤다(§17.34.3). 단차를 **0 으로** 내리자
				# 65% 가 됐고, 그때 가장 센 지표가 「최고 고도」가 아니라 **「평지%」**로 바뀐다
				# — 다른 넷과 겹치지 않는 지표다(§17.35).
				#
				# **중간값은 안 듣는다.** 0.6 · 0.3 은 25% · 20% 로 같거나 나쁘다. 고도가
				# 정수라 반올림되면 층이 생기기 때문이고, **0 에서만 판이 통째로 평평해진다.**
				# 계단 함수라 「조금 더 밀어 보기」로는 못 찾는다.
				#
				# **곁가지는 그대로 둔다.** 이름("선이 성기다")이 그쪽을 가리켜서 밀어 봤는데
				# 25 -> 30% 로 안 듣고 갈림길만 목표에서 멀어졌다 — 효과 없는 손잡이를 함께
				# 당기면 대가만 치른다(§17.35.1).
				"층이 없다시피 평평하다. 오름은 보장된 한 군데뿐이라 숫자 추리가 쉽다",
				{"extra_edge_ratio": 0.10, "elevation_gain": 0.0}
			)
		),
		Character.new(
			"hive", "벌집", "선이 촘촘하다. 차수가 높아 인접 합이 뭉쳐 확신이 안 선다", {"extra_edge_ratio": 0.46}
		),
		Character.new(
			"vertical",
			"수직 회랑",
			"고도 숫자가 크고 오름 표시가 잦다. 기본 민첩으로는 판의 3분의 1이 잠긴다",
			{"elevation_gain": 5.0}
		),
		(
			Character
			. new(
				"far_exit",
				"먼 출구",
				"판이 나뭇가지처럼 뻗고 탈출구가 그 판의 가장 먼 끝에 있다",
				# 탈출구 거리 하나만으로는 **한 판만 봐서는 갈리지 않았다** — 다른 성격의 판이
				# 우연히 더 먼 탈출구를 갖는 일이 흔했다(신호대잡음 1.68 로 쓰는 축 중 가장 약하다).
				# 막다른 방 하한을 함께 올린다. 둘은 상쇄하지 않고 **같은 방향으로 민다** —
				# 막다른 방이 늘면 지름이 늘고(15.2 -> 16.8) 탈출구도 함께 멀어진다.
				#
				# **이 축은 상대값이다.** 그 판의 최대 깊이에 대한 비율이라 "다른 던전보다 멀다"
				# 를 뜻하지 않는다. 그래서 요약을 "판 반대편" 이 아니라 "그 판의 가장 먼 끝"
				# 으로 적는다 — 이름이 약속하는 것과 실제로 주는 것을 맞춘다.
				#
				# **하한은 0.30 이 아니라 0.22 다 (2026-08-10).** 0.30 은 **생성기가
				# 못 닿는 값**이라 40 판 중 20 판이 미달이었고, 못 맞추는 값을 요구하면
				# 평균은 안 오르고 **흩어짐만 는다**(변동계수 0.096 -> 0.181).
				# **덜 밀어야 갈린다** (§17.34.2 · §17.36.3). 기본 `max` 0.30 과 같아
				# **띠 폭이 0** 이던 것도 함께 풀린다.
				{"exit_distance_ratio": 0.95, "dead_end_ratio_min": 0.22}
			)
		),
		Character.new(
			"vault",
			"금고층",
			"위험방이 흔하고 귀중품은 드물다. 하나를 노리고 들어간다",
			{"treasure_ratio": 0.05, "hazard_ratio": 0.36}
		),
	]


static func count() -> int:
	return all().size()


## 색인을 목록 범위 안으로 접는다. 바깥에서 아무 수나 넘겨도 죽지 않는다.
##
## 이름이 `wrap` 이 아닌 이유는 **GDScript 내장 `wrap(value, min, max)` 와 부딪히기 때문**이다.
## `DungeonCatalog.wrap(i)` 라고 한정해 불러도 내장 쪽으로 풀려 "인자가 모자라다" 로 죽었다.
static func wrapped(index: int) -> int:
	var total := count()
	return 0 if total <= 0 else ((index % total) + total) % total


static func character_at(index: int) -> Character:
	return all()[wrapped(index)]


static func name_of(index: int) -> String:
	return character_at(index).display_name


static func summary_of(index: int) -> String:
	return character_at(index).summary


## 크기가 정한 파라미터 위에 성격을 얹는다.
##
## **순서가 중요하다.** 크기가 방 개수를 정하고 성격이 나머지를 손본다.
## 반대로 하면 성격이 방 개수를 덮어써 게이트 등급이 뜻을 잃는다.
static func apply(params: DungeonGenerator.Params, index: int) -> DungeonGenerator.Params:
	for field in character_at(index).axes:
		var name := String(field)
		# **`set()` 은 없는 이름을 말없이 삼킨다.** 오타가 나면 그 축이 죽는데 로그 한 줄
		# 없고, 그래프만 보는 테스트로는 방 종류 축(귀중품·위험방·탈출구 거리)의 죽음이
		# 원리적으로 안 잡힌다. 그래서 여기서 확인한다.
		if params.get(name) == null:
			push_error("던전 성격이 없는 축을 흔들려 합니다: %s" % name)
			continue
		params.set(name, float(character_at(index).axes[field]))
	return params


## 성격이 흔드는 축 이름이 전부 실재하는가. 테스트와 개발 도구가 쓴다.
static func unknown_axes() -> Array[String]:
	var known := {}
	for entry in DungeonGenerator.Params.new().get_property_list():
		known[String(entry["name"])] = true

	var result: Array[String] = []
	for character in all():
		for field in character.axes:
			if not known.has(String(field)):
				result.append("%s/%s" % [character.id, field])
	return result
