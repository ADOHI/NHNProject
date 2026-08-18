extends GutTest
## 조사 고르기의 단위 테스트.
##
## 이 파일이 생긴 이유는 아지트 화면에 **"공방 와 겹친다"** 가 떴기 때문이다.
## 코어가 문장을 만드는 이상(conventions.md §3.1) 조사도 코어의 몫이다.

const Josa := preload("res://src/core/text/korean_josa.gd")


func test_final_consonant_is_detected() -> void:
	assert_true(Josa.has_final_consonant("공방"), "ㅇ 받침")
	assert_true(Josa.has_final_consonant("정보실"), "ㄹ 받침")
	assert_false(Josa.has_final_consonant("접선처"), "받침 없음")
	assert_false(Josa.has_final_consonant("나"))


func test_empty_and_non_hangul_are_treated_as_open() -> void:
	assert_false(Josa.has_final_consonant(""))
	assert_false(Josa.has_final_consonant("shop"))
	assert_false(Josa.has_final_consonant("12"))


## 이 세 줄이 이 파일이 생긴 이유다 — 시설 셋의 이름이 셋 다 다르게 갈린다.
func test_the_three_facility_names() -> void:
	assert_eq(Josa.wa(Facility.label(Facility.Kind.WORKSHOP)), "공방과")
	assert_eq(Josa.wa(Facility.label(Facility.Kind.INTEL_ROOM)), "정보실과")
	assert_eq(Josa.wa(Facility.label(Facility.Kind.CONTACT_POINT)), "접선처와")


func test_common_particles() -> void:
	assert_eq(Josa.eul("공방"), "공방을")
	assert_eq(Josa.eul("접선처"), "접선처를")
	assert_eq(Josa.i("공방"), "공방이")
	assert_eq(Josa.i("접선처"), "접선처가")
	assert_eq(Josa.eun("공방"), "공방은")
	assert_eq(Josa.eun("접선처"), "접선처는")


## ㄹ 받침만 다르다. 이 한 줄 때문에 pick 을 그대로 못 쓴다.
func test_ro_treats_rieul_as_open() -> void:
	assert_eq(Josa.ro("접선처"), "접선처로", "받침 없음")
	assert_eq(Josa.ro("정보실"), "정보실로", "ㄹ 받침은 로")
	assert_eq(Josa.ro("공방"), "공방으로", "다른 받침은 으로")


func test_pick_returns_only_the_particle() -> void:
	assert_eq(Josa.pick("공방", "와", "과"), "과")
	assert_eq(Josa.pick("접선처", "와", "과"), "와")


## 겹침 이유가 실제로 고쳐졌는지를 격자 쪽에서 확인한다.
func test_the_blocked_reason_now_reads_correctly() -> void:
	var grid: HideoutGrid = preload("res://src/core/hideout/hideout_grid.gd").new(8, 8)
	var shop: HideoutBuilding = preload("res://src/core/hideout/hideout_building.gd").new(
		"shop", Facility.Kind.WORKSHOP, Vector2i(2, 2), Vector2i(0, 0)
	)
	grid.place(shop)
	assert_eq(grid.blocked_reason(Vector2i.ONE, Vector2i.ZERO), "공방과 겹친다")
