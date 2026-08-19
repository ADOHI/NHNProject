extends GutTest
## 파일에 쓰고 읽는다. **진짜 `user://` 를 쓰되 자기 경로에 쓴다** —
## 시험이 사용자의 세이브를 덮어쓰면 그것이 이 시스템의 첫 사고가 된다.

const SEED := 20260819
const TEST_PATH := "user://test_save/store_test.json"

var _store: SaveStore


func before_each() -> void:
	_store = SaveStore.new(TEST_PATH)
	_erase()


func after_each() -> void:
	_erase()


func _erase() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _write_text(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_PATH.get_base_dir()))
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _guild() -> Guild:
	var guild := Guild.create_starting(SEED, "파일 시험 길드")
	guild.add_funds(345)
	guild.add_base_progress(2)
	return guild


func test_the_default_path_lives_under_user() -> void:
	# res:// 는 내보낸 빌드에서 읽기 전용이다. 개발 중에만 되는 저장이 가장 늦게 잡힌다.
	assert_string_starts_with(SaveStore.DEFAULT_PATH, "user://")


func test_a_missing_file_says_so() -> void:
	assert_false(_store.exists())
	var result := _store.read(false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.MISSING)
	assert_string_contains(result.message(), "새로 시작")


func test_writing_then_reading_gives_the_same_guild() -> void:
	var guild := _guild()
	assert_eq(_store.write(guild, SEED), OK)
	assert_true(_store.exists())
	var result := _store.read(false)
	assert_true(result.is_ok(), result.message())
	assert_eq(result.guild.funds, guild.funds)
	assert_eq(result.guild.base_progress, guild.base_progress)
	assert_eq(result.guild.member_ids(), guild.member_ids())
	assert_eq(result.campaign_seed, SEED)


func test_the_written_file_is_readable_by_a_human() -> void:
	_store.write(_guild(), SEED)
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	assert_string_contains(text, "\n", "한 줄로 쏟으면 열어 봐도 못 읽는다")
	assert_string_contains(text, '"version"')


func test_broken_json_leaves_a_reason() -> void:
	_write_text("이건 JSON 이 아니다 {{{")
	var result := _store.read(false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.NOT_JSON)


func test_a_non_dictionary_root_leaves_a_reason() -> void:
	_write_text("[1, 2, 3]")
	var result := _store.read(false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.BAD_SHAPE)


func test_a_broken_file_is_not_deleted() -> void:
	# 조용히 지우면 사용자는 자기 진행이 어디로 갔는지 영영 모른다.
	_write_text("깨진 것")
	_store.read(false)
	assert_true(_store.exists(), "불러오기가 사용자의 파일을 없애면 안 된다")


func test_a_broken_file_can_be_overwritten() -> void:
	_write_text("깨진 것")
	assert_eq(_store.write(_guild(), SEED), OK)
	assert_true(_store.read(false).is_ok())


func test_erasing_removes_the_file() -> void:
	_store.write(_guild(), SEED)
	assert_eq(_store.erase(), OK)
	assert_false(_store.exists())
	assert_eq(_store.erase(), OK, "없는 것을 지우는 것은 오류가 아니다")


func test_nothing_is_written_without_a_guild() -> void:
	assert_ne(_store.write(null, SEED), OK)
	assert_false(_store.exists())
