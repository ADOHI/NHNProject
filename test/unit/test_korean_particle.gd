extends GutTest
## KoreanParticle 테스트.
##
## 조사가 틀리면 모델이 어디까지가 이름인지 다시 추측한다.
## 방 이름과 인물 이름은 생성기가 만들어 내므로 목록으로 못 박을 수 없고,
## 그래서 글자에서 계산한다 (docs/design/19-rekka-voice.md §19.B.5).

const ParticleScript := preload("res://src/core/rekka/korean_particle.gd")


func test_subject_follows_the_final_consonant() -> void:
	assert_eq(ParticleScript.subject("칼날의 요한"), "이")
	assert_eq(ParticleScript.subject("두더지 미나"), "가")


func test_topic_follows_the_final_consonant() -> void:
	assert_eq(ParticleScript.topic("웃는 베른"), "은")
	assert_eq(ParticleScript.topic("우리 스쿼드"), "는")


func test_object_follows_the_final_consonant() -> void:
	assert_eq(ParticleScript.object_of("봉인된 금고"), "를")
	assert_eq(ParticleScript.object_of("밀실"), "을")


func test_conjunction_follows_the_final_consonant() -> void:
	# `<웃는 베른>와` 가 실제로 나갔다. 이름 뒤가 어색하면 이름으로 안 읽힌다.
	assert_eq(ParticleScript.conjunction("웃는 베른"), "과")
	assert_eq(ParticleScript.conjunction("두더지 미나"), "와")


func test_rieul_takes_the_short_direction_particle() -> void:
	# ㄹ 받침은 받침이 없는 것처럼 붙는다. 이 하나가 유일한 예외다.
	assert_eq(ParticleScript.direction("탈출 승강기"), "로")
	assert_eq(ParticleScript.direction("전시실"), "로")
	assert_eq(ParticleScript.direction("회랑"), "으로")


func test_copula_follows_the_final_consonant() -> void:
	# `규모는 한줌다` 가 실제로 나갔다.
	assert_eq(ParticleScript.copula("한줌"), "이다")
	assert_eq(ParticleScript.copula("맞대면"), "이다")
	assert_eq(ParticleScript.copula("푼돈"), "이다")


func test_numbered_room_names_are_read_as_sino_korean() -> void:
	# 생성기는 같은 이름이 두 번 나오면 번호를 붙인다 (room_kind_planner.pick_name).
	# `중정 3` 은 "중정 삼" 이므로 받침이 있다.
	assert_eq(ParticleScript.topic("중정 3"), "은")
	assert_eq(ParticleScript.topic("가스 저장고 4"), "는")
	assert_eq(ParticleScript.direction("중정 3"), "으로")
	assert_eq(ParticleScript.direction("밀실 1"), "로")


func test_non_korean_endings_fall_back_to_no_final() -> void:
	assert_false(ParticleScript.has_final("Vault"))
	assert_eq(ParticleScript.subject(""), "가")
