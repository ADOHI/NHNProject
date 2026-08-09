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

## 지금 만든 사건. 설계 24.15 가 고른 셋이다 —
## **협력과 배신은 방향이 반대라 공식이 양쪽으로 작동하는지 둘로 확인되고,**
## 전멸은 모양이 아예 달라서 (대상이 여럿이고 목격자를 유대로 훑는다) 구조를 시험한다.
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
}

## 설계 24.5 표의 `+` / `++` / `+++` 에 대응하는 값 (설계 24.21.4).
const NOTCH_ONE := 33
const NOTCH_TWO := 66
const NOTCH_THREE := 100

const _LABELS := ["협력", "배신", "전멸", "후유증", "구조", "정보", "협상", "선제공격", "약탈", "유기", "지나침"]

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

## 목격자를 **유대로 훑어 늘리는가.** 전멸만 참이다 (설계 24.5 B) —
## *"죽은 자들과 유대 높은 사람 전원에게 사건이 간다."*
var sweeps_bonded := false

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
