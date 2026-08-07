class_name ProtoUnitAgent
extends RefCounted
## 유닛 하나의 이동 상태. **노드가 아니다.**
##
## 그리는 방식과 움직이는 방식을 갈라 두는 이유는, 이번 프로토타입이 도형으로 그려지지만
## 나중에 배경과 스프라이트로 갈아 끼워야 하기 때문이다. 여기에는 좌표와 속도만 있고
## 무엇으로 보이는지는 없다.

## 유닛이 지금 무엇을 하고 있는가. 개발 표시에 그대로 나간다.
enum State {
	IDLE,  ## 명령이 없다
	MOVING,  ## 자기 자리로 가는 중
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

## 목적지까지 이 유닛이 지금껏 도달한 최단 거리. 나아가지 못하는 상태를 재는 기준이다.
var best_distance: float = INF
var stuck_time: float = 0.0

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
	best_distance = position.distance_to(slot)
	stuck_time = 0.0
	pace = 1.0
	# 확인 시점을 유닛마다 어긋나게 둔다. 전원이 같은 프레임에 광선을 쏘면 그 프레임만 튄다.
	sight_timer = float(id % 11) / 11.0 * sight_interval


## 그 자리에서 멈춘다. 도착이든 포기든 뒤처리는 같다.
func settle(final_state: State) -> void:
	state = final_state
	order_id = 0
	velocity = Vector2.ZERO
	pace = 1.0
	debug_seek = Vector2.ZERO
	debug_separation = Vector2.ZERO


## 목적지까지 남은 거리.
func remaining() -> float:
	return position.distance_to(goal) if state == State.MOVING else 0.0


func state_name() -> String:
	match state:
		State.MOVING:
			return "이동"
		State.ARRIVED:
			return "도착"
		State.BLOCKED:
			return "막힘"
		_:
			return "대기"
