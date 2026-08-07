class_name ProtoUnitAgent
extends RefCounted
## 유닛 하나의 이동 상태. **노드가 아니다.**
##
## 그리는 방식과 움직이는 방식을 갈라 두는 이유는, 이번 프로토타입이 도형으로 그려지지만
## 나중에 배경과 스프라이트로 갈아 끼워야 하기 때문이다. 여기에는 좌표와 속도만 있고
## 무엇으로 보이는지는 없다.

## 유닛이 지금 무엇을 하고 있는가. 개발 표시에 그대로 나간다.
##
## HOLDING 만 성질이 다르다. **되돌아올 수 있는 정지**이고, 나머지 셋은 끝난 상태다.
## 명령과 자기 자리를 그대로 들고 있다가 앞을 막은 아군이 비키면 스스로 다시 간다.
enum State {
	IDLE,  ## 명령이 없다
	MOVING,  ## 자기 자리로 가는 중
	HOLDING,  ## 앞을 막은 아군이 이미 자리를 잡아 기다린다. 비키면 다시 간다
	ARRIVED,  ## 자리에 섰다
	BLOCKED,  ## 갈 수 없다고 판단하고 그만두었다
}

## 종류별 이름. 더블클릭으로 같은 종류를 전부 고를 때의 기준이기도 하다.
const KIND_NAMES: Array[String] = ["보병", "사수", "정찰병"]

## 종류별 (몸 반지름, 속도 배수). 속도가 다른 유닛을 섞어 두어야 대형 유지가 시험된다.
const KIND_SHAPES: Array[Vector2] = [Vector2(12.0, 1.0), Vector2(11.0, 0.88), Vector2(9.0, 1.3)]

var id: int
var kind: int
var position: Vector2
var velocity: Vector2

## 진행 방향(라디안). 회전 속도 제한이 걸리는 대상이다.
var facing: float

var radius: float
var speed_scale: float

## 이번 명령에서 이 유닛이 서기로 한 자리.
var goal: Vector2

var state: State = State.IDLE

## 이 유닛이 따르는 명령의 일련번호. 0 이면 명령 없음.
var order_id: int = 0

## 대형 유지로 걸린 속도 배수. 앞서 나간 유닛이 뒤를 기다리는 정도다.
var pace: float = 1.0

## 이번 프레임에 조향이 가리키는 방향(단위 벡터).
##
## 흐름장에서 갓 읽은 값이 아니라 **평활을 거친 값**이다. 격자에서 읽은 방향은 칸을 넘을 때마다
## 튀는데, 그 튐을 그대로 쫓으면 좌우로 왕복한다. 막힌 쪽을 판단할 때도 이 방향을 쓴다.
var steer_dir: Vector2 = Vector2.ZERO

## 이번 프레임 시작 시점의 목표까지 거리. 양보 규칙이 이웃마다 다시 재지 않도록 한 번만 구한다.
var goal_distance: float = 0.0

## 목적지까지 이 유닛이 지금껏 도달한 최단 거리. 벽에 비비는 것을 알아채는 마지막 그물이다.
var best_distance: float = INF

## 최단 거리가 줄지 않은 채 흘려보낸 프레임 수. 위와 같은 목적이다.
var grind_frames: int = 0

## 앞을 막은 아군에게 눌린 채 나아가지 못한 프레임 수.
##
## 한 프레임만 보고 멈추면 스쳐 지나가는 순간에도 서 버린다. 네 프레임 남짓 이어질 때만
## 기다림으로 넘긴다. **포기 시간과 다르다** — 이 값이 하는 일은 판정을 미루는 것이 아니라
## 떨림을 걸러내는 것이고, 넘어간 상태는 언제든 되돌아온다.
var press_frames: int = 0

## 이번 프레임에 **이미 자리를 잡은 아군**이 진행 방향을 막고 있는가.
##
## 분리력을 구하며 이웃을 훑는 김에 함께 채운다. 이 판정 하나를 위해 이웃을 또 훑으면
## 유닛이 늘 때 비용이 배로 든다.
var blocked_by_settled: bool = false

## 목적지가 그대로 보이는가. 매 프레임 확인하면 비싸서 주기적으로만 갱신한다.
var has_sight: bool = false
var sight_timer: float = 0.0

## 개발 표시용. 이번 프레임에 어떤 힘이 걸렸는지 그대로 그린다.
var debug_seek: Vector2 = Vector2.ZERO
var debug_separation: Vector2 = Vector2.ZERO


func _init(agent_id: int, agent_kind: int, spawn: Vector2) -> void:
	id = agent_id
	kind = clampi(agent_kind, 0, KIND_SHAPES.size() - 1)
	position = spawn
	goal = spawn
	velocity = Vector2.ZERO
	facing = 0.0
	radius = KIND_SHAPES[kind].x
	speed_scale = KIND_SHAPES[kind].y


func kind_name() -> String:
	return KIND_NAMES[kind]


func is_moving() -> bool:
	return state == State.MOVING


## 명령을 새로 받는다. 이전 명령의 흔적(막힘 판정, 대형 속도)을 반드시 지운다.
##
## 지우지 않으면 직전에 막혀 포기한 유닛이 새 명령에도 그대로 서 있는다.
## 명령을 냈는데 일부가 안 움직이는 것이 조작감을 가장 크게 해친다.
func accept_order(new_order_id: int, slot: Vector2, sight_interval: float) -> void:
	order_id = new_order_id
	goal = slot
	state = State.MOVING
	goal_distance = position.distance_to(slot)
	best_distance = goal_distance
	grind_frames = 0
	press_frames = 0
	pace = 1.0
	# 조향을 자기 자리 쪽으로 미리 맞춰 둔다. 평활을 영벡터에서 시작하면 명령 직후 한 박자 뜬다.
	var to_slot := slot - position
	steer_dir = to_slot.normalized() if to_slot.length_squared() > 0.0001 else Vector2.ZERO
	# 확인 시점을 유닛마다 어긋나게 둔다. 전원이 같은 프레임에 광선을 쏘면 그 프레임만 튄다.
	sight_timer = float(id % 11) / 11.0 * sight_interval


## 그 자리에서 멈춘다. 도착이든 포기든 뒤처리는 같다. **여기서 멈추면 되돌아오지 않는다.**
func settle(final_state: State) -> void:
	state = final_state
	order_id = 0
	velocity = Vector2.ZERO
	pace = 1.0
	debug_seek = Vector2.ZERO
	debug_separation = Vector2.ZERO


## 앞을 막은 아군이 비킬 때까지 기다린다. **명령과 자기 자리를 놓지 않는다.**
##
## 이것이 포기 시간을 대신한다. 시간으로 재면 늘릴수록 굼뜨고 줄일수록 일찍 포기하는데,
## 어느 쪽도 답이 아니었다. 막혔다는 판단 자체가 틀렸기 때문이다 — 다시 명령하면 가지 않던가.
## 상태로 물으면 막은 쪽이 비키는 순간 조건이 저절로 풀려 재명령이 필요 없어진다.
func hold() -> void:
	state = State.HOLDING
	velocity = Vector2.ZERO
	pace = 1.0
	debug_seek = Vector2.ZERO
	debug_separation = Vector2.ZERO


## 기다림을 풀고 다시 간다. 막고 있던 유닛이 비켰을 때 불린다.
func resume() -> void:
	state = State.MOVING
	best_distance = position.distance_to(goal)
	grind_frames = 0
	press_frames = 0


## 목적지까지 남은 거리.
func remaining() -> float:
	return position.distance_to(goal) if state == State.MOVING else 0.0


func state_name() -> String:
	match state:
		State.MOVING:
			return "이동"
		State.HOLDING:
			return "양보"
		State.ARRIVED:
			return "도착"
		State.BLOCKED:
			return "막힘"
		_:
			return "대기"
