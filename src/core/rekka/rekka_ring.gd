class_name RekkaRing
extends RefCounted
## 목록을 **행진 없이** 한 바퀴 도는 자리 계산.
##
## ## 왜 따로 떼어 놓는가
##
## 이 계산은 원래 `RekkaHandles` 안에 있었고, 거기서 얻은 교훈이 있다 —
## **반복을 없애려고 넣은 장치가 더 읽기 쉬운 반복을 만드는 일이 두 차수 연속으로 났다**
## (docs/design/19-rekka-voice.md §19.B.4, §19.B.9 3차).
##
## | 잘못 | 무슨 일이 났나 |
## | --- | --- |
## | 목록을 순서대로 소비 | 심사자 둘이 같은 표를 그렸다. `낄낄이` 다음은 언제나 `지하실단골` |
## | 소금으로 시작점만 이동 | 순서가 그대로라 한 칸 밀린 같은 고리. 심사자가 통째로 복원했다 |
## | 소금을 그대로 나눔 | 서로 다른 시드가 같은 걸음에 몰렸다 |
##
## 접두어와 닉네임만 이 함정에 걸리는 것이 아니다. 예비 문안의 어미도 댓글도
## 같은 성질을 갖는다 — **고르는 규칙이 규칙적이면 그 규칙이 새로운 틀이 된다.**
## 그래서 고친 계산을 한 곳에 두고 전부 여기서 가져다 쓴다.

## 목록을 건너뛰는 걸음의 후보. **판마다 다른 걸음을 고른다.**
##
## 걸음이 하나면 소금은 시작점만 옮긴다 — 순서는 그대로고 한 칸 밀릴 뿐이다.
## 걸음이 바뀌어야 배열 자체가 다시 꿰인다.
##
## 값은 전부 홀수이고 3 의 배수가 아니다. 그래야 12(접두어)와 36(닉네임) 양쪽에
## 서로소라 한 바퀴가 온전히 돌고, 어떤 항목도 빠지거나 두 배로 나오지 않는다.
##
## **1 은 뺐다.** 걸음이 1 이면 목록 순서 그대로 행진하는데, 그것이 바로
## 심사자가 잡아낸 결함이다. 어떤 소금에서도 그 배열이 나오면 안 된다.
const STRIDES: Array[int] = [5, 7, 11, 13, 17, 19, 23, 25, 29, 31, 35]

## 소금을 섞는 상수. 그냥 나누면 서로 다른 시드가 같은 걸음에 몰린다.
const _MIX_MULTIPLIER := 3266489917
const _MIX_ADDEND := 1013904223
const _MIX_MODULUS := 1048573


## `index` 번째 항목이 앉을 자리. 같은 소금이면 언제나 같은 자리라 재현된다.
##
## **걸음과 시작점을 둘 다 소금에서 뽑는다.** 시작점만 옮기면 순서가 그대로라
## 판이 바뀌어도 같은 셋이 늘 붙어 다닌다.
static func slot(index: int, salt: int, size: int) -> int:
	if size <= 0:
		return 0
	var mixed := posmod(salt * _MIX_MULTIPLIER + _MIX_ADDEND, _MIX_MODULUS)
	var stride := stride_for(mixed, size)
	return posmod(index * stride + posmod(mixed / STRIDES.size(), size), size)


## 이 크기에 쓸 걸음. **목록 길이와 서로소인 것만 쓴다.**
##
## 서로소가 아니면 고리가 짧아진다 — 걸음 5 에 크기 5 면 언제나 같은 자리다.
## 접두어(12)와 닉네임(36)은 후보 전부가 이미 서로소라 첫 후보가 그대로 뽑히고,
## **그 둘의 배열은 이 검사를 넣기 전과 똑같다.**
static func stride_for(mixed: int, size: int) -> int:
	var start := posmod(mixed, STRIDES.size())
	for offset in STRIDES.size():
		var candidate: int = STRIDES[(start + offset) % STRIDES.size()]
		if _coprime(candidate, size):
			return candidate
	return 1


static func _coprime(a: int, b: int) -> bool:
	var left := absi(a)
	var right := absi(b)
	while right != 0:
		var next := left % right
		left = right
		right = next
	return left == 1
