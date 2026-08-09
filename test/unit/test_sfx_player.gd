extends GutTest
## 겹칠 때의 재생 규칙 (docs/design/29-sound.md §29.7.12).
##
## **데모는 소리를 하나씩 차례로 낸다. 게임은 안 그렇다.**
## 여러 명이 같은 프레임에 맞으면 같은 파형이 그대로 더해지고,
## 위상이 맞아서 **정확히 배로 커진다** — 셋이면 피크 1.308 로 넘쳤다.

var _player: SfxPlayer


func before_each() -> void:
	_player = SfxPlayer.new()
	add_child_autofree(_player)


func test_the_same_event_stops_stacking_after_three() -> void:
	# 넷째부터는 커지기만 하고 또렷해지지 않는다. 버리는 편이 낫다.
	var played := 0
	for attempt in 8:
		if _player.play(SfxEvent.Kind.HIT_LANDED, 2.0):
			played += 1
	assert_eq(played, SfxPlayer.MAX_SAME_EVENT, "같은 사건이 상한을 넘어 났다")
	assert_gt(_player.dropped_count(), 0, "넘친 것은 버려야 한다")


func test_different_events_do_not_share_the_cap() -> void:
	# 상한은 **사건마다** 다. 타격이 셋 났다고 발소리가 막히면 안 된다.
	for attempt in SfxPlayer.MAX_SAME_EVENT:
		_player.play(SfxEvent.Kind.HIT_LANDED, 2.0)
	assert_true(_player.play(SfxEvent.Kind.FOOT_WALK), "다른 사건까지 막혔다")
	assert_true(_player.play(SfxEvent.Kind.UI_PRESS), "다른 사건까지 막혔다")


func test_stopping_clears_the_overlap_memory() -> void:
	for attempt in 8:
		_player.play(SfxEvent.Kind.HIT_LANDED, 2.0)
	_player.stop_all()
	assert_true(_player.play(SfxEvent.Kind.HIT_LANDED, 2.0), "멈춘 뒤에는 다시 나야 한다")


func test_silencing_blocks_everything() -> void:
	_player.set_enabled(false)
	assert_false(_player.play(SfxEvent.Kind.HIT_LANDED, 2.0))
	_player.set_enabled(true)
	assert_true(_player.play(SfxEvent.Kind.HIT_LANDED, 2.0))


func test_the_stagger_is_short_enough_to_be_inaudible() -> void:
	# 겹친 소리를 앞에서부터 건너뛰어 위상을 어긋내는데, 너무 많이 건너뛰면
	# 어택이 잘려 타격이 흐려진다. 어택 보존 구간(25 ms)보다 훨씬 짧아야 한다.
	var total := SfxPlayer.STAGGER_SECONDS * (SfxPlayer.MAX_SAME_EVENT - 1)
	assert_lt(total, SfxVoice.KEEP_ATTACK_SECONDS, "어긋내기가 어택을 먹고 있다")


func test_playing_never_raises_even_with_nothing_baked() -> void:
	# 소리 때문에 게임이 멈추는 일은 없어야 한다.
	for event in SfxEvent.all():
		_player.play(event)
		_player.play(event, 4.0)
	assert_true(true, "전수 재생이 예외 없이 끝났다")
