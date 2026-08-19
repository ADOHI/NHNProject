extends GutTest
## 세이브의 봉투 — 버전과 모양. **파일을 안 만지므로 디스크 없이 판정된다.**

const SEED := 20260819


func _guild() -> Guild:
	var guild := Guild.create_starting(SEED, "봉투 시험 길드")
	guild.add_funds(120)
	return guild


func test_the_envelope_carries_a_version() -> void:
	var data := GameSave.capture(_guild(), SEED)
	assert_eq(int(data[GameSave.KEY_VERSION]), GameSave.VERSION)
	assert_eq(int(data[GameSave.KEY_SEED]), SEED)
	assert_true(data.has(GameSave.KEY_SAVED_AT), "파일을 열어 본 사람이 언제 것인지 알아야 한다")


func test_no_guild_makes_an_empty_envelope() -> void:
	assert_true(GameSave.capture(null, SEED).is_empty())


func test_a_round_trip_returns_the_same_guild() -> void:
	var guild := _guild()
	var result := GameSave.restore(GameSave.capture(guild, SEED), false)
	assert_true(result.is_ok(), result.message())
	assert_eq(result.campaign_seed, SEED)
	assert_eq(result.guild.funds, guild.funds)
	assert_eq(result.guild.member_ids(), guild.member_ids())
	assert_null(result.world, "세계를 안 세우기로 했으면 안 세운다")


func test_a_missing_version_is_a_bad_shape() -> void:
	var result := GameSave.restore({"guild": {"members": []}}, false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.BAD_SHAPE)


func test_a_newer_version_is_refused() -> void:
	var data := GameSave.capture(_guild(), SEED)
	data[GameSave.KEY_VERSION] = GameSave.VERSION + 1
	var result := GameSave.restore(data, false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.VERSION_AHEAD)
	assert_string_contains(result.message(), "새 빌드")


func test_a_missing_guild_leaves_a_reason() -> void:
	var result := GameSave.restore({GameSave.KEY_VERSION: GameSave.VERSION}, false)
	assert_false(result.is_ok())
	assert_eq(result.status, SaveResult.Status.BAD_SHAPE)
	assert_string_contains(result.message(), "길드가 없다")


func test_a_broken_guild_leaves_a_reason() -> void:
	var result := GameSave.restore(
		{GameSave.KEY_VERSION: GameSave.VERSION, GameSave.KEY_GUILD: {}}, false
	)
	assert_false(result.is_ok())
	assert_string_contains(result.message(), "대원 명단")


func test_every_status_has_a_readable_line() -> void:
	for status in SaveResult.Status.values():
		var result := SaveResult.failed(status as SaveResult.Status)
		assert_ne(result.message(), "", "사유 없는 실패는 사용자를 어리둥절하게 한다")
