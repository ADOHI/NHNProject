class_name NacrePhase
extends RefCounted
## 자개 조각의 편광 위상 · 표류 궤적 · 배치를 계산한다.
##
## 노드 트리에 의존하지 않는 순수 함수뿐이다. 씬 없이 검증할 수 있다.
##
## **난수를 쓰지 않는다.** 캡처마다 화면이 달라지면 심사가 흔들리고, 무엇보다
## 난수로 흩은 것은 난수처럼 보인다. 대신 무리수 보폭을 써서 어느 두 조각도
## 같은 박자에 놓이지 않게 한다.

## 황금비의 소수부. 이 보폭으로 돌면 몇 개를 뽑아도 값이 고르게 흩어지고
## 어떤 두 인덱스도 위상이 겹치지 않는다.
const GOLDEN: float = 0.6180339887

## 조각 하나가 표류하는 폭. 이보다 크면 조각이 "떠다니는" 것으로 보이고,
## 작으면 정지 화면과 구별되지 않는다.
const DRIFT_AMPLITUDE: float = 1.5


## 조각 하나의 편광 위상. 한 조각이 시안일 때 옆 조각이 라일락이어야 한다.
static func shard_phase(index: int) -> float:
	return fposmod(float(index) * GOLDEN, 1.0)


## 조각 하나가 표류하는 자리. 주기가 조각마다 다르므로 둘이 영영 같은 자리에 오지 않는다.
##
## 리사주 곡선을 쓰는 이유는 왕복이 눈에 띄지 않기 때문이다. 사인 하나로 흔들면
## 좌우로 오가는 것이 보이고, 그건 표류가 아니라 진동이다.
static func drift(index: int, time: float) -> Vector2:
	var ph := shard_phase(index) * TAU
	var period_x := 12.0 + fposmod(float(index) * 7.0, 8.0)
	var period_y := 15.0 + fposmod(float(index) * 5.0, 6.0)
	return (
		Vector2(sin(TAU * time / period_x + ph), cos(TAU * time / period_y + ph * 1.7))
		* DRIFT_AMPLITUDE
	)


## 눌렸을 때 조각이 튀어 나가는 방향. 잘려 나간 모서리에서 바깥으로 흩어진다.
static func kick_direction(index: int) -> Vector2:
	var a := shard_phase(index) * TAU
	return Vector2(0.62 + cos(a) * 0.38, -0.62 + sin(a) * 0.38).normalized()


## 흩어진 조각을 판의 **잘린 모서리 바깥**에 놓는다.
##
## 모서리를 비스듬히 자를 때 떨어져 나온 부스러기라는 뜻이다. 그래서 조각은
## 판 안이 아니라 **틀 밖**에 있어야 하고, 그것이 이 키트에서 요소가 자기 사각형을
## 넘어가는 유일한 자리다.
## `slot` 이 거리를 정한다. 거리를 위상에만 맡겼더니 두 조각이 같은 자리에 겹쳐
## 나비 모양의 얼룩이 됐다 (1차 렌더). **가까운 것 하나, 먼 것 하나**로 못 박는다.
static func chip_offset(index: int, slot: int, plate_size: Vector2, chamfer: float) -> Vector2:
	var corner := Vector2(plate_size.x - chamfer * 0.5, chamfer * 0.5)
	var t := shard_phase(index * 3 + 1)
	var reach := chamfer * (1.05 + float(slot) * 1.60 + t * 0.55)
	var angle := -PI * 0.40 + t * PI * 0.42 + float(slot) * 0.30
	return corner + Vector2(cos(angle), sin(angle)) * reach


## 조각 하나의 화면 크기. 자리마다 달라야 손으로 깬 부스러기로 보인다.
##
## 1차 렌더에서 9~18px 로 잡았더니 자개가 아니라 **먼지**로 보였다.
## 재료가 재료로 읽히려면 무늬가 보일 만큼은 커야 한다.
static func chip_size(index: int) -> float:
	return 10.0 + shard_phase(index * 5 + 2) * 9.0


## 이 판이 쓸 조각 파일 번호. 판마다 다른 조각을 쓰되 **매번 같아야** 한다.
static func chip_texture_index(seed_value: int, slot: int, pool: int) -> int:
	if pool <= 0:
		return 0
	return int(fposmod(float(seed_value) * 3.0 + float(slot) * 7.0, float(pool)))
