extends GutTest
## 이름 조합기를 덮는다.
##
## **이름은 이 게임에서 기능이다** (docs/design/08-ui-ux.md §8.3.2).
## 세계 인구가 1000~3000명이므로(docs/design/24-npc-relations.md §24.8)
## 이름 풀이 그만큼을 겹치지 않게 내야 한다. 못 내면 렉카 기사가
## 누구 얘기인지 말할 수 없고, 그 순간 「기억되는 인물」이 죽는다.

## docs/design/24-npc-relations.md §24.8 의 인구 상한.
const _TARGET_POPULATION := 3000

const _SEED := 20260808


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	return rng


func test_capacity_covers_the_target_population() -> void:
	assert_gte(MemberNames.capacity(), _TARGET_POPULATION)


func test_capacity_leaves_room_for_rejection_sampling() -> void:
	# 용량에 가까워지면 거절 표집이 시도를 다 태우고 「무명 N」 으로 떨어진다.
	# 여유가 두 배는 있어야 3000명이 조용히 성공한다.
	assert_gte(MemberNames.capacity(), _TARGET_POPULATION * 2)


func test_three_thousand_names_never_repeat() -> void:
	var rng := _rng()
	var used := {}
	for _person in _TARGET_POPULATION:
		MemberNames.pick(rng, used)
	assert_eq(used.size(), _TARGET_POPULATION, "중복이 나오면 사전 크기가 줄어든다")


func test_three_thousand_names_never_fall_back() -> void:
	var rng := _rng()
	var used := {}
	for _person in _TARGET_POPULATION:
		assert_false(MemberNames.pick(rng, used).begins_with("무명 "))


func test_names_are_three_syllables() -> void:
	var rng := _rng()
	var used := {}
	for _person in 200:
		assert_eq(MemberNames.pick(rng, used).length(), 3, "성 하나 + 이름 둘")


func test_given_name_syllables_differ() -> void:
	# "민민" 같은 이름은 사람 이름으로 읽히지 않는다.
	var rng := _rng()
	var used := {}
	for _person in 500:
		var name := MemberNames.pick(rng, used)
		assert_ne(name.substr(1, 1), name.substr(2, 1), name)


func test_pick_respects_names_already_taken() -> void:
	var rng := _rng()
	var used := {}
	var first := MemberNames.pick(rng, used)
	var mirror := {}
	mirror[first] = true
	assert_ne(MemberNames.pick(_rng(), mirror), first, "이미 쓴 이름을 다시 주면 안 된다")


func test_same_seed_gives_the_same_names() -> void:
	var one := {}
	var other := {}
	for _person in 50:
		MemberNames.pick(_rng(), one)
		MemberNames.pick(_rng(), other)
	assert_eq(one.keys(), other.keys())


func test_pick_adds_exactly_one_name_each_call() -> void:
	# 장부에 등록하지 않고 이름을 돌려주면 다음 호출이 같은 이름을 또 낸다.
	var rng := _rng()
	var used := {}
	for expected in range(1, 21):
		MemberNames.pick(rng, used)
		assert_eq(used.size(), expected)
