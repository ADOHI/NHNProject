class_name FactionNames
extends RefCounted
## 소속의 이름. **부르기 위한 것이고 정보를 나르지 않는다.**
##
## docs/design/24-npc-relations.md §24.33.
##
## ## 왜 이름이 정보를 안 나르나
##
## 이름이 계열이나 성향을 말하게 하고 싶었지만 **소속에 그런 성질이 없다.**
## 성향은 소속과 독립이고(§24.16.3) 계열도 그렇다. 없는 성질을 이름이 주장하면
## §24.20.1 의 *"수치가 진실이고 서술이 따라간다"* 가 거꾸로 뒤집힌다.
##
## **크기는 진짜인데 이름에 넣으면 안 된다.** §24.17.6 이 이미 기각했다 —
## *"등급 이름을 만들지 않았다. 문턱을 정하는 순간 그 문턱이 근거 없는 상수가 되고,
## 인원 숫자는 문턱 없이 읽힌다."* 크기는 이름 옆에 숫자로 이미 나간다.
##
## **그래서 이름이 하는 일은 하나다 — 다시 만났을 때 같은 무리인 줄 아는 것.**
## 그것이 조우에서 필요한 전부다. *"또 그 길드다"* 가 성립하면 된다.
##
## ## 번호 순서가 이름에 안 비쳐야 한다
##
## `#1 무쇠 문` · `#2 무쇠 손` 처럼 나오면 **읽는 사람이 번호를 본다.**
## 이 레인이 계속 지킨 원칙이다 — **손잡이 값이 결과와 같아 보이면 기계가 드러난다**
## (§24.29.3 · §24.30.6). 그래서 번호를 시드와 섞어 흩은 뒤에 고른다.
##
## ## 겹치면 안 된다
##
## 두 소속이 같은 이름이면 조우에서 *"또 그 길드다"* 가 거짓말이 된다.
## `MemberNames` 와 같은 방식으로 **거절 표집**하고, 용량은 `capacity()` 가 세어 준다.

## 앞말. 색과 재질과 상태 — **무엇을 말하려는 것이 아니라 부르려는 것이다.**
const _HEADS := [
	"무쇠",
	"잿빛",
	"붉은",
	"검은",
	"흰",
	"푸른",
	"서리",
	"마른",
	"굽은",
	"낡은",
	"먼",
	"깊은",
	"높은",
	"어린",
	"늦은",
	"이른",
	"조용한",
	"무거운",
	"성긴",
	"단단한",
	"젖은",
	"타는",
	"닳은",
	"갈라진",
]

## 뒷말. 몸과 물건과 자리.
const _TAILS := [
	"문",
	"손",
	"발",
	"이빨",
	"눈",
	"뼈",
	"그늘",
	"바닥",
	"모루",
	"저울",
	"사슬",
	"열쇠",
	"고리",
	"둑",
	"터",
	"굴",
	"층계",
	"천막",
	"등불",
	"울타리",
]

## 이름을 못 만들었을 때. **화면에 나가므로 빈 문자열을 안 쓴다.**
const UNNAMED := "이름 없는 무리"

## 거절 표집을 몇 번 하나. 부하가 낮아 한 번에 걸리는 것이 보통이다.
const _TRIES := 24


## 만들 수 있는 이름의 수. **여기 숫자를 베끼지 마라** — 풀을 늘리면 이 함수가 맞다.
static func capacity() -> int:
	return _HEADS.size() * _TAILS.size()


## 소속마다 이름을 하나씩. `factions` 는 이름이 필요한 소속 번호들이다.
##
## 돌려주는 것은 **소속 번호 -> 이름** 사전이다. 배열로 돌려주면 번호가 성기어
## (인원 0 인 소속이 중간에 있다) 빈 칸이 생긴다.
static func assign(world_seed: int, factions: PackedInt32Array) -> Dictionary:
	var names := {}
	var used := {}
	var rng := RandomNumberGenerator.new()
	for faction in factions:
		# **번호를 시드와 섞는다.** 그냥 번호를 쓰면 이웃한 소속이 이웃한 이름을 받는다.
		rng.seed = PersonSeed.stream(world_seed, PersonSeed.Field.FACTION_NAME, faction)
		names[faction] = _pick(rng, used)
	return names


static func _pick(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for _try in _TRIES:
		var name := (
			"%s %s" % [_HEADS[rng.randi() % _HEADS.size()], _TAILS[rng.randi() % _TAILS.size()]]
		)
		if not used.has(name):
			used[name] = true
			return name
	return UNNAMED
