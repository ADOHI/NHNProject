extends GutTest
## RekkaLibrary 테스트 — 열쇠와 고르기.
##
## **실려 있는 자산 자체**를 지키는 것은 test_rekka_library_asset.gd 에 있다.
## 여기서 보는 것은 자산이 없거나 빈칸일 때도 무너지지 않는가다 —
## 못 찾으면 예비 문안으로 가야 하고, 그 길이 막히면 피드가 빈다
## (docs/design/32-rekka-feed.md §32.1).

const ActorScript := preload("res://src/core/dungeon/actor.gd")
const RoomScript := preload("res://src/core/dungeon/room.gd")
const EventScript := preload("res://src/core/event/game_event.gd")
const LibraryScript := preload("res://src/core/rekka/rekka_library.gd")

var _room: Room
var _johan: Actor


func before_each() -> void:
	_room = RoomScript.new("hall", "회랑", 0, Room.Kind.EMPTY)
	_johan = ActorScript.new("johan", "칼날의 요한", Actor.Kind.NPC_EXPLORER, 4, 2)


func _event(kind: GameEvent.Kind, magnitude: int = 0) -> GameEvent:
	return EventScript.new(4, kind, _johan, _room, magnitude)


func _library(pairs: Array) -> RekkaLibrary:
	var library: RekkaLibrary = LibraryScript.new()
	for pair in pairs:
		library.keys.append(pair[0])
		library.posts.append(pair[1])
	return library


# ---------------------------------------------------------------- 열쇠


func test_the_key_is_a_grade_not_a_number() -> void:
	# 수치를 열쇠로 쓰면 조합이 터진다 (19-rekka-voice.md §19.10.1).
	assert_eq(LibraryScript.key_for(_event(GameEvent.Kind.SEARCHED, 11)), "SEARCHED:대박")
	assert_eq(LibraryScript.key_for(_event(GameEvent.Kind.SEARCHED, 12)), "SEARCHED:대박")
	assert_eq(LibraryScript.key_for(_event(GameEvent.Kind.FOUGHT, 2)), "FOUGHT:한줌")


func test_a_kind_without_an_axis_leaves_the_grade_empty() -> void:
	assert_eq(LibraryScript.key_for(_event(GameEvent.Kind.MOVED)), "MOVED:")


func test_a_turn_with_no_event_is_quiet() -> void:
	assert_eq(LibraryScript.key_for(null), LibraryScript.QUIET_KEY)


func test_the_key_names_the_kind_in_words_not_numbers() -> void:
	# enum 값을 적으면 항목이 하나 끼는 순간 자산 전체가 조용히 어긋난다.
	for kind in GameEvent.Kind.values():
		assert_true(LibraryScript.KIND_NAMES.has(kind), "이름 없는 종류: %d" % kind)
		assert_false(str(LibraryScript.KIND_NAMES[kind]).is_empty())


# ---------------------------------------------------------------- 고르기


func test_a_missing_key_returns_nothing_instead_of_failing() -> void:
	# 빈 문자열이 곧 "예비 문안으로 가라" 다.
	var library := _library([["FOUGHT:한줌", "붙었다"]])
	assert_eq(library.pick("SEARCHED:대박", 0), "")


func test_an_empty_library_never_crashes() -> void:
	var library: RekkaLibrary = LibraryScript.new()
	assert_eq(library.count(), 0)
	assert_eq(library.pick(LibraryScript.QUIET_KEY, 3, 7), "")


func test_several_posts_under_one_key_all_get_used() -> void:
	# 같은 상황이 두 번 나왔을 때 같은 글이 나오면 안 된다.
	var library := _library([["QUIET", "가"], ["QUIET", "나"], ["QUIET", "다"], ["FOUGHT:한줌", "라"]])
	var seen: Dictionary = {}
	for index in 3:
		seen[library.pick("QUIET", index, 20260808)] = true
	assert_eq(seen.size(), 3, str(seen.keys()))


func test_posts_for_only_returns_that_key() -> void:
	var library := _library([["QUIET", "가"], ["MOVED:", "나"], ["QUIET", "다"]])
	var found := library.posts_for("QUIET")

	assert_eq(found.size(), 2, str(found))
	assert_false(found.has("나"))


func test_a_ragged_library_does_not_read_past_the_end() -> void:
	# 두 배열이 어긋난 자산은 실수로 만들어질 수 있다. 그때 터지면 안 된다.
	var library: RekkaLibrary = LibraryScript.new()
	library.keys.append("QUIET")
	library.keys.append("MOVED:")
	library.posts.append("가")

	assert_eq(library.count(), 1)
	assert_eq(library.pick("MOVED:", 0), "")


# ---------------------------------------------------------------- 실린 자산


func test_the_shipped_library_loads() -> void:
	# `load()` 로 열리는 자원이어야 한다. 원본 파일을 직접 읽으면 웹에서 깨진다.
	var shared := LibraryScript.shared()

	assert_not_null(shared)
	assert_gt(shared.count(), 0, "자산이 비어 있다. tools/build_rekka_library.gd 를 돌려라")
