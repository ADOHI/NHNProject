class_name RelationEvent
extends RefCounted
## 사건 하나의 정의 — 성향 벡터 · 강도 · 대상 호감 · 유대.
##
## docs/design/24-npc-relations.md §24.5 · §24.21.4.
##
## ## 왜 사건이 「벡터」인가
##
## "성향에 따라 같은 사건이 호감도 되고 비호감도 된다" 를 표로 만들면
## **사건 종류 × 성향 종류만큼 규칙을 써야 한다.** 사건과 성향을 같은 축 위에 놓으면
## 내적 하나로 끝난다 (설계 24.4). 그래서 사건은 **성향 6축 위의 벡터**다.
##
## ## 기호를 수치로 옮기는 규칙이 하나뿐이다
##
## 설계 24.5 의 표는 세기를 `+ ++ +++` 로 적었다. 규칙을 정해 두지 않으면
## **사건마다 수치를 지어내게 되고 그러면 표가 근거를 잃는다** (설계 24.21.4).
##
## ## 부호는 (+) 극 기준이다 — 나갈 때는 극 이름으로 바꾼다
##
## `NpcAxis.Kind.LOYAL` 에 -100 은 **실리 쪽으로 100** 이다.
## 이 규칙은 `NpcAxis` 를 읽어야 알 수 있으므로 **이 클래스 밖으로 나가는 값은
## 부호가 아니라 극 이름으로 나간다** (`vector_text()`). 설계 24.25 —
## *"입력 형식이 해석을 요구하면 읽는 쪽이 해석을 틀린다."*

## 지금 만든 사건. **설계 24.5 의 25종 중 열다섯이다** — 다섯씩 붙이며 매번 다시 잰다.
##
## 처음 셋(협력 · 배신 · 전멸)을 설계 24.15 가 골랐다 —
## **협력과 배신은 방향이 반대라 공식이 양쪽으로 작동하는지 둘로 확인되고,**
## 전멸은 모양이 아예 달라서 (대상이 여럿이고 목격자를 유대로 훑는다) 구조를 시험한다.
##
## **순서는 붙인 순서다.** `EventSeeder.KIND_WEIGHTS` 가 이 순서와 나란하므로
## 가운데에 끼워 넣으면 모든 가중치가 조용히 다른 사건으로 옮겨 간다.
enum Kind {
	COOPERATION,  ## 협력 조우 — 함께 싸웠다
	BETRAYAL,  ## 배신 — 협력 후 공격했다
	WIPEOUT,  ## 전멸 — 이끌고 들어간 원정이 몰살당했다
	AFTERMATH,  ## 후유증 — 제거되고 돌아왔다 (설계 2.6.1.5)
	RESCUE,  ## 구조 — 죽을 사람을 끌고 나왔다
	INFORM,  ## 정보 제공 — 알아야 할 것을 알려 줬다
	BARGAIN,  ## 협상 성립 — 서로 안 싸우기로 했다
	AMBUSH,  ## 선제 공격 — 말 없이 먼저 쳤다
	PLUNDER,  ## 약탈 — 털어 갔다
	DESERT,  ## 동료 유기 — 두고 나왔다
	PASS_BY,  ## 못 본 척 지나감 — **아무 일도 안 일어난다**
	FALSE_LEAD,  ## 거짓 정보 유포 — 함정으로 보냈다
	SELL_INFO,  ## 정보 판매 — 알던 것을 팔았다
	SNITCH,  ## 밀고 — 위치를 흘렸다
	LOOT_BODY,  ## 시체 털이 — **대상이 죽어 있다. 유족만 반응한다**
	DEFECT,  ## 길드 이탈 — **대상이 없다**
	BREAK_PACT,  ## 계약 파기 — 대상이 없다
	FOUND_GUILD,  ## 길드 창설 — 대상이 없다
	HEADLINE,  ## 렉카 1면 — 대상이 없다
	HAUL,  ## 대박 회수 — 대상이 없다
	DELVE,  ## 심층 진입 — 대상이 없다
}

## 설계 24.5 표의 `+` / `++` / `+++` 에 대응하는 값 (설계 24.21.4).
const NOTCH_ONE := 33
const NOTCH_TWO := 66
const NOTCH_THREE := 100

const _LABELS := [
	"협력",
	"배신",
	"전멸",
	"후유증",
	"구조",
	"정보",
	"협상",
	"선제공격",
	"약탈",
	"유기",
	"지나침",
	"거짓정보",
	"정보판매",
	"밀고",
	"시체털이",
	"길드이탈",
	"계약파기",
	"길드창설",
	"렉카1면",
	"대박회수",
	"심층진입",
]

## 이 사건이 무엇인가.
var kind: Kind

## 강도. 목격자 호감 변화의 상한이다 — 내적과 관여도가 둘 다 1 일 때의 값.
var strength: int

## **대상이 행위자에게 갖는 호감의 변화.** 성향을 안 탄다 —
## 당한 것은 당한 것이다 (설계 24.6).
var target_affinity: int

## 행위자와 대상 사이의 유대 변화. **양쪽에 같이 들어간다.**
##
## 배신에서 이 값이 양수인 것이 이 설계의 전부다 (설계 24.21.4) —
## *"호감은 무너지는데 유대는 떨어지지 않는다."* 떨어뜨리지 않는 정도가 아니라 **올린다.**
var bond_gain: int

## 행위자 -> 대상 슬롯에 남는 유형.
var actor_kind: RelationKind.Kind

## 대상 -> 행위자 슬롯에 남는 유형.
##
## **`NONE` 이면 그 슬롯을 아예 안 건드린다.** 전멸의 대상은 죽은 사람이고
## **사망은 관계를 동결하므로**(설계 24.5 D) 죽은 쪽의 호감은 움직이면 안 된다.
var target_kind: RelationKind.Kind

## 목격자를 **유대로 훑어 늘리는가.** 전멸과 시체 털이가 참이다 (설계 24.5 B) —
## *"죽은 자들과 유대 높은 사람 전원에게 사건이 간다."*
##
## **둘 다 대상이 죽어 있다는 것이 공통점이다.** 죽은 쪽 슬롯은 못 건드리므로
## (설계 24.5 D) 반응이 나올 곳이 유족밖에 없다.
var sweeps_bonded := false

## **당한 사람이 있는 사건인가.** 거의 다 참이고 길드 이탈만 거짓이다.
##
## 설계 24.5 D 의 사건들(길드 이탈 · 길드 창설 · 렉카 1면 · 대박 회수 …)은
## **누구에게 한 일이 아니라 한 일 그 자체**다. 대상을 억지로 하나 붙이면
## 그 사람과의 관계가 생기는데, 그런 관계는 설계 표에 없다 —
## 없는 관계를 만드는 것이 §24.34.2 가 「지나침」에서 막은 바로 그것이다.
##
## 거짓이면 `RelationResolver` 가 대상 없이 굴리고 목격자만 반응한다.
## `RelationLedger.describe()` 는 처음부터 대상 없는 사건을 낼 수 있었다.
var needs_target := true

var _vector := PackedInt32Array()


func _init(event_kind: Kind) -> void:
	kind = event_kind
	_vector.resize(NpcAxis.count())


## 사건 정의를 가져온다. **수치의 원본은 여기 하나다.**
static func of(kind: Kind) -> RelationEvent:
	match kind:
		Kind.BETRAYAL:
			return _betrayal()
		Kind.WIPEOUT:
			return _wipeout()
		Kind.AFTERMATH:
			return _aftermath()
		Kind.RESCUE:
			return _rescue()
		Kind.INFORM:
			return _inform()
		Kind.BARGAIN:
			return _bargain()
		Kind.AMBUSH:
			return _ambush()
		Kind.PLUNDER:
			return _plunder()
		Kind.DESERT:
			return _desert()
		Kind.PASS_BY:
			return _pass_by()
		Kind.FALSE_LEAD:
			return _false_lead()
		Kind.SELL_INFO:
			return _sell_info()
		Kind.SNITCH:
			return _snitch()
		Kind.LOOT_BODY:
			return _loot_body()
		Kind.DEFECT:
			return _defect()
		Kind.BREAK_PACT:
			return _break_pact()
		Kind.FOUND_GUILD:
			return _found_guild()
		Kind.HEADLINE:
			return _headline()
		Kind.HAUL:
			return _haul()
		Kind.DELVE:
			return _delve()
		_:
			return _cooperation()


static func count() -> int:
	return _LABELS.size()


static func label(kind: Kind) -> String:
	return _LABELS[clampi(int(kind), 0, _LABELS.size() - 1)]


## 이 축에 대한 사건의 성향. 부호는 (+) 극 기준이다.
func axis(kind_of_axis: NpcAxis.Kind) -> int:
	return _vector[int(kind_of_axis)]


func vector() -> PackedInt32Array:
	return _vector.duplicate()


## 벡터의 절댓값 합. **정규화의 분모다** (설계 24.21.5) —
## 축을 셋 건드리는 사건과 하나 건드리는 사건이 같은 강도에서 같은 크기로 움직여야
## 강도가 뜻을 갖는다.
func magnitude() -> int:
	var total := 0
	for slot in _vector.size():
		total += absi(_vector[slot])
	return total


## 사건 벡터와 성향의 **정규화 내적.** -1 ~ +1 이다.
##
## 설계 24.4 —
##
##     호감 변화 = dot(사건 벡터, 보는 사람 성향) / (Σ|벡터| × 100) × 강도 × 관여도
##
## 이 함수가 앞의 나눗셈까지다. 강도와 관여도는 `RelationResolver` 가 곱한다.
func alignment(traits: PackedInt32Array) -> float:
	var span := magnitude()
	if span == 0 or traits.size() != _vector.size():
		return 0.0
	var dot := 0
	for slot in _vector.size():
		dot += _vector[slot] * traits[slot]
	return clampf(float(dot) / (float(span) * float(NpcAxis.MAX_VALUE)), -1.0, 1.0)


## 벡터를 **극 이름으로** 읽는다 — `실리 100 · 기만 100 · 악 66`.
##
## 부호로 내보내면 읽는 쪽이 `NpcAxis` 배열 순서를 알아야 하고, **실제로 그것 때문에
## 정직한 사람이 기만형으로 읽힌 적이 있다** (설계 24.25). 여기서 미리 풀어서 낸다.
func vector_text() -> String:
	var parts := PackedStringArray()
	for slot in _vector.size():
		var value := _vector[slot]
		if value == 0:
			continue
		parts.append("%s %d" % [NpcAxis.pole_label(slot as NpcAxis.Kind, value), absi(value)])
	if parts.is_empty():
		return "성향 없음"
	return " • ".join(parts)


## 협력 조우 — 의리 ++ 선 + (설계 24.5 A · 24.21.4).
static func _cooperation() -> RelationEvent:
	var event := RelationEvent.new(Kind.COOPERATION)
	event._set_axis(NpcAxis.Kind.LOYAL, NOTCH_TWO)  # 의리 쪽
	event._set_axis(NpcAxis.Kind.GOOD, NOTCH_ONE)  # 선 쪽
	event.strength = 25
	event.target_affinity = 18
	event.bond_gain = 20
	event.actor_kind = RelationKind.Kind.COMRADESHIP
	event.target_kind = RelationKind.Kind.COMRADESHIP
	return event


## 배신 — 선 −66 · 의리 −100 · 정직 −100 (설계 24.5 A · 24.21.4).
##
## **유형이 양쪽에서 다르다.** 당한 쪽은 「배신당함」, 한 쪽은 「배신함」이다 —
## 관계가 비대칭이라(설계 24.21.2) 같은 사건이 두 사람의 화면에 다르게 적힌다.
static func _betrayal() -> RelationEvent:
	var event := RelationEvent.new(Kind.BETRAYAL)
	# 음수는 반대 극이다 — 악 · 실리 · 기만.
	event._set_axis(NpcAxis.Kind.GOOD, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_THREE)
	event._set_axis(NpcAxis.Kind.HONEST, -NOTCH_THREE)
	event.strength = 55
	event.target_affinity = -70
	event.bond_gain = 8
	event.actor_kind = RelationKind.Kind.BETRAYER
	event.target_kind = RelationKind.Kind.BETRAYED
	return event


## 전멸 — 무모 +33 (설계 24.5 B 의 「(약함)」).
##
## **벡터가 약하다는 것이 반응이 작다는 뜻이 아니다.** 정규화가 분모로 Σ|벡터| 를 쓰므로
## (설계 24.21.5) 축 하나짜리 벡터도 방향만 맞으면 최대로 흔든다.
## **약한 것은 강도이고, 이 사건이 세계를 흔드는 힘은 강도가 아니라 사람 수에서 나온다** —
## 죽은 자마다 유대 높은 이웃 전원에게 간다 (설계 24.5 B).
##
## 방향을 무모로 잡은 이유: 전멸은 **이끈 사람이 무모했다는 사실**을 세계에 보여 준다.
## 그래서 무모형 목격자는 *"나였어도 들어갔다"* 로, 신중형은 원한으로 갈린다 (설계 24.4).
static func _wipeout() -> RelationEvent:
	var event := RelationEvent.new(Kind.WIPEOUT)
	event._set_axis(NpcAxis.Kind.RECKLESS, NOTCH_ONE)
	event.strength = 40
	# 죽은 사람의 호감은 안 움직인다 — **사망은 관계를 동결한다** (설계 24.5 D).
	event.target_affinity = 0
	event.bond_gain = 12
	# 이끈 사람에게는 그들과 같이 들어갔던 기록이 남는다. 죽은 쪽은 안 건드린다.
	event.actor_kind = RelationKind.Kind.COMRADESHIP
	event.target_kind = RelationKind.Kind.NONE
	event.sweeps_bonded = true
	return event


## 구조 — 의리 +++ 선 ++ 무모 + (설계 24.5 A).
##
## **호감을 가장 크게 되돌리는 사건이다.** 세계에 호감을 올리는 길이 협력 하나뿐이면
## 오래 돌릴수록 한쪽으로만 기운다 (설계 24.31). 구조가 그 반대편이다 —
## 배신이 −70 을 내리듯 구조는 +60 을 올린다.
static func _rescue() -> RelationEvent:
	var event := RelationEvent.new(Kind.RESCUE)
	event._set_axis(NpcAxis.Kind.LOYAL, NOTCH_THREE)
	event._set_axis(NpcAxis.Kind.GOOD, NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.RECKLESS, NOTCH_ONE)
	event.strength = 45
	event.target_affinity = 60
	event.bond_gain = 25
	# **유형이 양쪽에서 다르다.** 구한 쪽에는 생사고락, 구해진 쪽에는 은혜가 남는다.
	event.actor_kind = RelationKind.Kind.COMRADESHIP
	event.target_kind = RelationKind.Kind.GRATITUDE
	return event


## 정보 제공 — 정직 ++ 의리 + (설계 24.5 C).
##
## **작고 흔한 사건이다.** 구조가 드물게 크게 올린다면 이쪽은 자주 조금 올린다 —
## 되돌리는 길이 큰 것 하나뿐이면 그것이 안 날 때 세계가 계속 내려간다.
static func _inform() -> RelationEvent:
	var event := RelationEvent.new(Kind.INFORM)
	event._set_axis(NpcAxis.Kind.HONEST, NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.LOYAL, NOTCH_ONE)
	event.strength = 20
	event.target_affinity = 25
	event.bond_gain = 10
	event.actor_kind = RelationKind.Kind.TRUST
	event.target_kind = RelationKind.Kind.TRUST
	return event


## 협상 성립 — 정직 + (설계 24.5 A). **거래**를 남긴다.
static func _bargain() -> RelationEvent:
	var event := RelationEvent.new(Kind.BARGAIN)
	event._set_axis(NpcAxis.Kind.HONEST, NOTCH_ONE)
	event.strength = 15
	event.target_affinity = 12
	event.bond_gain = 15
	event.actor_kind = RelationKind.Kind.DEAL
	event.target_kind = RelationKind.Kind.DEAL
	return event


## 선제 공격 — 선 −66 무모 +33 (설계 24.5 A). **양쪽에 원한이 남는다** —
## 친 쪽도 그 사람을 다시 만나면 경계한다.
static func _ambush() -> RelationEvent:
	var event := RelationEvent.new(Kind.AMBUSH)
	event._set_axis(NpcAxis.Kind.GOOD, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.RECKLESS, NOTCH_ONE)
	event.strength = 40
	event.target_affinity = -45
	event.bond_gain = 6
	event.actor_kind = RelationKind.Kind.GRUDGE
	event.target_kind = RelationKind.Kind.GRUDGE
	return event


## 약탈 — 선 −100 의리 −33 (설계 24.5 A). 원한을 가장 크게 남긴다.
static func _plunder() -> RelationEvent:
	var event := RelationEvent.new(Kind.PLUNDER)
	event._set_axis(NpcAxis.Kind.GOOD, -NOTCH_THREE)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_ONE)
	event.strength = 50
	event.target_affinity = -60
	event.bond_gain = 10
	event.actor_kind = RelationKind.Kind.GRUDGE
	event.target_kind = RelationKind.Kind.GRUDGE
	return event


## 동료 유기 — 의리 −100 무모 −66 (설계 24.5 A).
##
## **배신과 짝을 이룬다.** 배신은 친 것이고 유기는 안 한 것인데 둘 다 의리 축을 밟는다.
## 유형이 양쪽에서 다른 것도 같다 — 두고 온 쪽과 남겨진 쪽의 화면이 달라야 한다.
static func _desert() -> RelationEvent:
	var event := RelationEvent.new(Kind.DESERT)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_THREE)
	event._set_axis(NpcAxis.Kind.RECKLESS, -NOTCH_TWO)
	event.strength = 45
	event.target_affinity = -55
	event.bond_gain = 6
	event.actor_kind = RelationKind.Kind.ABANDONER
	event.target_kind = RelationKind.Kind.ABANDONED
	return event


## 못 본 척 지나감 — 무모 −66 과시 −33 (설계 24.5 A).
##
## **관계를 하나도 안 만든다.** 설계 24.5 가 *"거의 아무 일도 일어나지 않는다 —
## 그래야 회피가 진짜 중립 선택이 된다"* 고 못 박은 자리다.
## 유형이 양쪽 다 NONE 이라 `RelationResolver` 가 슬롯을 아예 안 건드린다.
##
## **대조군이기도 하다.** 호감만 흔들고 선을 안 만드는 사건이 세계를 어떻게 바꾸는지
## (또는 안 바꾸는지) 이것으로 잰다 (§24.34.2).
static func _pass_by() -> RelationEvent:
	var event := RelationEvent.new(Kind.PASS_BY)
	event._set_axis(NpcAxis.Kind.RECKLESS, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.SHOWY, -NOTCH_ONE)
	event.strength = 10
	event.target_affinity = 0
	event.bond_gain = 0
	event.actor_kind = RelationKind.Kind.NONE
	event.target_kind = RelationKind.Kind.NONE
	return event


## 거짓 정보 유포 — 정직 −100 · 선 −66 (설계 24.5 C). 함정으로 보냈다.
##
## **정보 계열에서 가장 큰 사건이다.** 벡터의 합이 배신 다음이고, 당한 사람은
## 죽을 뻔했다. 배신과 갈리는 것은 **축이 정직 쪽으로 기운 것**이다 —
## 배신은 의리를 밟고 이쪽은 말을 밟는다. 그래서 정직형이 배신보다 이쪽에 더 떤다.
static func _false_lead() -> RelationEvent:
	var event := RelationEvent.new(Kind.FALSE_LEAD)
	event._set_axis(NpcAxis.Kind.HONEST, -NOTCH_THREE)
	event._set_axis(NpcAxis.Kind.GOOD, -NOTCH_TWO)
	event.strength = 50
	event.target_affinity = -65
	event.bond_gain = 8
	event.actor_kind = RelationKind.Kind.GRUDGE
	event.target_kind = RelationKind.Kind.GRUDGE
	return event


## 정보 판매 — 의리 −33 (설계 24.5 C). **거래**를 남긴다.
##
## ## 벡터가 음수인데 대상 호감이 양수인 첫 사건이다
##
## 지금까지는 음수 벡터면 대상 호감도 음수였다 — 나쁜 짓의 대상은 당한 사람이니까.
## **정보 판매의 대상은 산 사람이다.** 값을 치르고 원하던 것을 받았으므로 호감이 오르고,
## 손해를 본 사람은 **거래에 없다** (정보의 주인은 이 자리에 안 나온다).
##
## 그래서 세계가 이 사건으로 어두워지지 않는다. **의리형 목격자만 등을 돌린다** —
## §24.31 이 *"내리는 길이 여럿이고 오르는 길이 하나"* 를 고친 뒤,
## **음수 벡터를 붙이면서 호감을 안 내리는 유일한 방법**이 이 모양이다.
static func _sell_info() -> RelationEvent:
	var event := RelationEvent.new(Kind.SELL_INFO)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_ONE)
	event.strength = 15
	event.target_affinity = 10
	event.bond_gain = 12
	event.actor_kind = RelationKind.Kind.DEAL
	event.target_kind = RelationKind.Kind.DEAL
	return event


## 밀고 — 정직 −66 · 의리 −100 (설계 24.5 C). 위치를 흘렸다.
##
## **유기와 벡터 합이 같아서 강도와 호감도 같다** (Σ166 · 강도 45 · 대상 −55).
## 지어낸 수치가 아니라 §24.21.4 의 눈금 규칙이 그렇게 낸 것이고,
## **같은 무게의 사건이 같은 크기로 움직이는 것이 그 규칙의 목적이다.**
## 갈리는 것은 축이다 — 유기는 무모를, 밀고는 정직을 밟는다.
static func _snitch() -> RelationEvent:
	var event := RelationEvent.new(Kind.SNITCH)
	event._set_axis(NpcAxis.Kind.HONEST, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_THREE)
	event.strength = 45
	event.target_affinity = -55
	event.bond_gain = 6
	event.actor_kind = RelationKind.Kind.GRUDGE
	event.target_kind = RelationKind.Kind.GRUDGE
	return event


## 시체 털이 — 선 −66 · 의리 −33 (설계 24.5 A). **유족의 원한**을 남긴다.
##
## ## 관계를 오직 훑기로만 만드는 첫 사건이다
##
## 대상이 죽어 있으므로 **대상 쪽 슬롯을 못 건드리고**(설계 24.5 D),
## 시체와 관계를 맺는 행위자 슬롯도 뜻이 없다. 그래서 양쪽 유형이 다 `NONE` 이고
## 남는 것은 `sweeps_bonded` 가 훑어 온 **유족의 반응뿐**이다.
##
## **전멸과 짝이면서 반대다.** 전멸은 이끈 사람에게 생사고락이 남고 유족이 갈리는데,
## 시체 털이는 **아무 기록도 안 남고 유족만 갈린다.** 설계 24.5 가 유명세 칸을
## `—` 로 둔 것과 같은 판단이다 — 아무도 자랑하지 않는 일이다.
static func _loot_body() -> RelationEvent:
	var event := RelationEvent.new(Kind.LOOT_BODY)
	event._set_axis(NpcAxis.Kind.GOOD, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.LOYAL, -NOTCH_ONE)
	event.strength = 35
	event.target_affinity = 0
	event.bond_gain = 0
	event.actor_kind = RelationKind.Kind.NONE
	event.target_kind = RelationKind.Kind.NONE
	event.sweeps_bonded = true
	return event


## 길드 이탈 — 위계 −100 (설계 24.5 D). **대상이 없는 첫 사건이다.**
##
## ## 위계 축을 밟는 첫 사건이기도 하다
##
## 사건 열 종이 붙는 동안 위계는 **한 번도 안 쓰였다.** 성향 6축 중 하나가
## 인물 화면에는 나오는데 세계에서는 아무 일도 안 하고 있었다는 뜻이다 (§24.36.2).
## 이 사건이 그 축을 켠다 — **자유형은 반기고 위계형은 등을 돌린다.**
##
## 벡터가 축 하나뿐이라 정규화가 그것을 최대로 키운다 (§24.21.4 의 전멸과 같은 자리).
## 그래서 강도를 낮게 둔다 — 사람이 죽는 일이 아니다.
static func _defect() -> RelationEvent:
	var event := RelationEvent.new(Kind.DEFECT)
	event._set_axis(NpcAxis.Kind.HIERARCHY, -NOTCH_THREE)
	event.strength = 30
	event.target_affinity = 0
	event.bond_gain = 0
	event.actor_kind = RelationKind.Kind.NONE
	event.target_kind = RelationKind.Kind.NONE
	event.needs_target = false
	return event


## 계약 파기 — 자유 66 · 기만 100 (설계 24.5 D). **대상이 없다.**
##
## 벡터 합이 유기·밀고와 같은 Σ166 인데 **대상 호감이 0 이다.**
## 설계 24.5 D 표에는 「남기는 관계」 칸이 아예 없다 — 없는 칸을 채우면
## 표에 없는 관계가 생긴다 (§24.38.1). 그래서 힘이 전부 목격자 쪽으로 간다.
static func _break_pact() -> RelationEvent:
	var event := RelationEvent.new(Kind.BREAK_PACT)
	event._set_axis(NpcAxis.Kind.HIERARCHY, -NOTCH_TWO)
	event._set_axis(NpcAxis.Kind.HONEST, -NOTCH_THREE)
	event.strength = 45
	event.needs_target = false
	return event


## 길드 창설 — 자유 33 · 과시 66 (설계 24.5 D). **대상이 없다.**
##
## **길드 이탈의 반대편이 아니다.** 이탈은 위계만 밟고 창설은 과시를 같이 밟는다 —
## 나가는 것은 조용히 할 수 있지만 세우는 것은 알려야 한다.
static func _found_guild() -> RelationEvent:
	var event := RelationEvent.new(Kind.FOUND_GUILD)
	event._set_axis(NpcAxis.Kind.HIERARCHY, -NOTCH_ONE)
	event._set_axis(NpcAxis.Kind.SHOWY, NOTCH_TWO)
	event.strength = 30
	event.needs_target = false
	return event


## 렉카 1면 — 과시 100 (설계 24.5 D). **대상이 없다.**
##
## 설계 24.5 —
## *"벡터가 과시 하나뿐이다. 그래서 과시형에게는 상, 은둔형에게는 벌이 자동으로 나온다 —
## 사건 하나에 규칙 하나다."* **이 문서가 공식을 설명할 때 든 예가 이것이고,
## 사건 열다섯이 붙는 동안 그 예가 코드에 없었다** (§24.38.2).
static func _headline() -> RelationEvent:
	var event := RelationEvent.new(Kind.HEADLINE)
	event._set_axis(NpcAxis.Kind.SHOWY, NOTCH_THREE)
	event.strength = 35
	event.needs_target = false
	return event


## 대박 회수 — 과시 33 (설계 24.5 B). **대상이 없다.**
##
## **자주 조금 흔드는 쪽이다** — 정보 제공이 호감 쪽에서 하는 일을 과시 축에서 한다.
## 유명세는 ↑↑↑ 인데 강도는 낮다: 많이 알려지는 것과 사람 사이가 갈리는 것은 다르다.
static func _haul() -> RelationEvent:
	var event := RelationEvent.new(Kind.HAUL)
	event._set_axis(NpcAxis.Kind.SHOWY, NOTCH_ONE)
	event.strength = 20
	event.needs_target = false
	return event


## 심층 진입 — 무모 100 (설계 24.5 B). **대상이 없다.**
##
## **전멸과 같은 축을 반대 방향에서 밟는다.** 전멸은 무모 +33 이고 이쪽은 +100 인데
## 전멸의 강도가 더 크다 — 전멸은 사람이 죽고 이것은 아직 아무 일도 안 났다.
## 무모형은 *"저래야 뭐가 나온다"*, 신중형은 *"저러다 죽는다"* 로 갈린다.
static func _delve() -> RelationEvent:
	var event := RelationEvent.new(Kind.DELVE)
	event._set_axis(NpcAxis.Kind.RECKLESS, NOTCH_THREE)
	event.strength = 30
	event.needs_target = false
	return event


## 후유증 — 제거되고 돌아온 사람이 겪는 것 (설계 2.6.1.5).
##
## **다른 셋과 모양이 다르다.** 나머지는 「누가 누구에게 한 일」이라 행위자에 대한
## 호감이 움직이는데, 후유증은 **당한 사람이 세상을 보는 눈**이 나빠지는 것이다.
## 그래서 벡터도 강도도 안 쓴다 — `ExpeditionAftermath` 가 성향에서 크기를 뽑는다.
##
## **그래도 사건으로 두는 이유**는 열전이 사건 기록을 먹기 때문이다 (설계 24.19).
## 후유증이 사건이 아니면 *"그 판에서 제거됐다"* 가 인물의 이력에 안 남는다.
static func _aftermath() -> RelationEvent:
	var event := RelationEvent.new(Kind.AFTERMATH)
	event.strength = 0
	event.target_affinity = 0
	event.bond_gain = 0
	event.actor_kind = RelationKind.Kind.NONE
	event.target_kind = RelationKind.Kind.NONE
	return event


func _set_axis(kind_of_axis: NpcAxis.Kind, value: int) -> void:
	_vector[int(kind_of_axis)] = NpcAxis.clamp_value(value)
