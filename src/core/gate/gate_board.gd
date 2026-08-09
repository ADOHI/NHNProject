class_name GateBoard
extends RefCounted
## 지금 열려 있는 게이트 목록. "이번에 어디로 갈 것인가" 가 여기서 갈린다.
##
## ## SampleDungeons 로부터 넘겨받은 것
##
## 예전에는 SampleDungeons 가 "판을 만든다" 를 통째로 들고 있었다.
## 그것을 여기서 나눈다 — **무엇을 열 것인가는 게이트가, 어떻게 만들 것인가는 생성기가** 맡는다.
## SampleDungeons 는 그대로 두고 호출만 한다 (Gate.create_run).
##
## ## 목록은 재현 가능해야 한다
##
## 같은 목록 씨앗과 같은 길드 등급이면 언제나 같은 게이트들이 나온다.
## 이상한 목록이 나왔을 때 씨앗이 없으면 다시 볼 수 없다
## (docs/design/17-dungeon-generation.md §17.7 과 같은 이유다).

## 이름 앞머리. 게이트가 열린 자리의 인상.
const _PREFIXES := [
	"무너진",
	"잿빛",
	"붉은",
	"물에 잠긴",
	"오래된",
	"검은",
	"뒤틀린",
	"버려진",
	"얼어붙은",
	"울리는",
]

## 이름 뒷머리. 게이트 안쪽의 인상.
const _NOUNS := [
	"지하도",
	"회랑",
	"채석장",
	"환승로",
	"수로",
	"주차장",
	"급수탑",
	"터널",
	"계단실",
	"저수조",
]

## 게이트 씨앗을 자리 번호에서 갈라내는 간격.
##
## 곱셈만으로 만들면 목록 씨앗이 인접할 때 게이트 씨앗도 인접해진다.
## 서로소에 가까운 큰 수를 써서 자리마다 확실히 떨어뜨린다.
const _SEED_STRIDE := 7919


## 지금 열려 있는 게이트들을 만든다.
##
## 길드 등급이 상한을 정한다 (GateRank.is_open_to). 상한 아래로 두 등급까지만
## 목록에 올리는 이유는, 너무 쉬운 게이트가 계속 남아 있으면
## 목록이 길어지기만 하고 선택은 사라지기 때문이다.
static func create(board_seed: int, guild_rank: int, count: int) -> Array[Gate]:
	var rng := RandomNumberGenerator.new()
	rng.seed = board_seed

	var highest := clampi(guild_rank - 1, 0, GateRank.count() - 1)
	var lowest := maxi(0, highest - 2)

	# **넷이 서로 달라야 고르는 것이 된다.** 등급만으로는 갈리지 않는다 — 길드 등급 1 에서는
	# E급만 열 수 있어 네 게이트가 전부 같은 등급이 된다. 그래서 성격과 크기 흔들림을
	# 겹치지 않게 나눠 준다 (Gate.size_offset 주석).
	var flavours := _flavours(rng)

	var gates: Array[Gate] = []
	var used_names := {}
	for index in maxi(0, count):
		var rank: GateRank.Kind = rng.randi_range(lowest, highest) as GateRank.Kind
		var gate := Gate.new(
			"gate_%d" % index, _pick_name(used_names, rng), rank, _seed_for(board_seed, index)
		)
		var flavour: Vector2i = flavours[index % flavours.size()]
		gate.dungeon_character = flavour.x
		gate.size_offset = flavour.y
		gates.append(gate)
	return gates


## 게이트마다 나눠 줄 (성격, 크기 흔들림) 짝. **겹치지 않게 섞는다.**
##
## 목록을 그대로 쓰면 자리 순서가 늘 같은 성격이 되어 "1번은 늘 얕은 갱도" 가 된다.
## 섞되 시드에서 나오므로 같은 목록은 언제나 같은 짝을 낸다.
static func _flavours(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for character in DungeonCatalog.count():
		result.append(Vector2i(character, (character % 3) - 1))
	# 피셔-예이츠. 비교 함수 안에서 난수를 뽑지 않는다 (§17.7).
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var kept := result[index]
		result[index] = result[other]
		result[other] = kept
	return result


## 자리 번호에서 던전 씨앗을 결정론적으로 뽑는다.
##
## 게이트가 이 씨앗을 들고 다니므로, 목록을 다시 만들어도 같은 자리의 게이트는
## 같은 던전을 연다.
static func seed_for(board_seed: int, index: int) -> int:
	return _seed_for(board_seed, index)


static func _seed_for(board_seed: int, index: int) -> int:
	return absi(board_seed * 31 + (index + 1) * _SEED_STRIDE)


## 목록 안에서 이름이 겹치지 않게 고른다.
##
## 겹치면 플레이어가 두 게이트를 구분할 수 없고, 그러면 목록이 선택지가 아니다.
static func _pick_name(used: Dictionary, rng: RandomNumberGenerator) -> String:
	for _attempt in 24:
		var name := (
			"%s %s"
			% [_PREFIXES[rng.randi() % _PREFIXES.size()], _NOUNS[rng.randi() % _NOUNS.size()]]
		)
		if not used.has(name):
			used[name] = true
			return name
	# 후보를 다 써 버린 경우. 실제 목록 크기에서는 오지 않는다.
	var fallback := "이름 없는 균열 %d" % used.size()
	used[fallback] = true
	return fallback
