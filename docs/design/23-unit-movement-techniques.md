# 23. 여럿이 좁은 목을 지나가게 하는 기법 조사

> **상태: 조사 중.** 이 문서는 코드를 바꾸지 않는다. 무엇을 어떤 순서로 넣을지 정하기 위한 근거 모음이다.
> 대상은 [`../../src/proto/unit_move/`](../../src/proto/unit_move/README.md) 프로토타입이다.

---

## 23.1 왜 이 조사를 하는가

`unit_move` 프로토타입은 밀치기를 걷어내면서 **지터와 튕김을 잡았고, 그 대가로 교착을 얻었다.**
README §11 의 실측이 그대로 문제 목록이다.

| 증상 | 지금 값 | 어디에 |
| --- | --- | --- |
| **교착** — 좁은 통로 100 명 중 문을 못 넘는 인원 | **83 명** | README §11 |
| 교착 — 좁은 통로 40 명 | 5 명 | README §11 |
| **꺾임** — 열린 곳 100 명 (도/초) | 33 → 실주행 기준 **237** | README §11 · 재측정 |
| 꺾임 — 구석 24 명 | **770** | 재측정 |
| **뭉침** — 문 앞에서 줄이 서지 않는다 | `HOLDING` 30~58 명 | README §11 |
| **벽 붙기** — 통로 중앙으로 끄는 힘이 없다 | 정성적 | README §7 · §11 |
| 튕김 (지키고 싶다) | **0.0 정지밀림** | README §9 |

**지켜야 하는 것부터 못 박는다.**

- `정지밀림 0.00 px` — 서 있는 유닛은 밀리지 않는다. 이 게임은 물리력 게임이 아니다 (README §9)
- 도착이 끝난다 — 멎은 뒤 다시 움직이지 않는다 (`뒤진동 0`)
- 100 명 이동 계산 **5 ms 이내**, 웹 단일 스레드 (`01-constraints.md` §1.1)

## 23.2 조사 범위를 좌우하는 제약

| 항목 | 값 | 조사에 주는 뜻 |
| --- | --- | --- |
| 엔진 | Godot 4.7.1 · GDScript | C++ 라이브러리를 그대로 가져올 수 없다 |
| 제출 | 웹(HTML5) · `gl_compatibility` | GDExtension 웹 빌드는 추가 검증이 든다 → §23.4 에서 확인 |
| 스레드 | **단일 스레드** (`SharedArrayBuffer` 불가) | 병렬화로 비용을 숨길 수 없다. 프레임 예산이 곧 총량이다 |
| 격자 | 32 px 칸 | 이보다 얇은 틈은 표현되지 않는다 (README §11) |
| 유닛 반지름 | 9 / 11 / 12 | **섞여 있다.** 균일 반지름을 가정하는 기법은 손봐야 한다 |
| 시험 문 폭 | 64 px (2 칸) | 지름 24 유닛 **두 명 나란히** |
| 시험 인원 | 4 · 8 · 12 · 24 · 40 · **100** | 100 은 줄일 수 없다 (기획 판단) |
| 남은 시간 | 90 시간 · 1 인 (`01-constraints.md` §1.3) | **처음 보는 기술을 쓰지 않는다**가 이미 확정 제약이다 |

---

## 23.3 먼저 바로잡을 것 — 우리가 이미 가진 것

조사를 시작하기 전에 코드를 직접 읽고 확인했다. **의뢰 시점의 진단 하나가 정확하지 않다.**

| 진단 | 실제 | 근거 |
| --- | --- | --- |
| "100 명이 전부 같은 한 점을 목적지로 받는다" | **아니다.** `ProtoFormation.build_slots` 가 육각 격자로 자리를 만들어 나눠 준다 | `core/formation.gd` |
| — 다만 **좁은 곳에서는 맞는 말이 된다** | 통행 불가로 걸러져 자리가 모자라면 `while slots.size() < count: slots.append(center)` — **남은 인원 전부가 같은 한 점을 받는다** | `core/formation.gd` `build_slots` 끝 |
| — 그리고 **흐름장은 하나다** | 목적지 칸 하나로 향하는 장을 전원이 공유한다. 자리는 흩어져도 **가는 길은 한 줄기다** | `core/flow_field.gd` |

**그래서 「산개」는 두 층으로 갈라야 한다.**

| 층 | 지금 | 필요한가 |
| --- | --- | --- |
| **도착지 산개** | 있다 (육각 자리) | 좁은 곳 폴백(`center` 몰아주기)만 고치면 된다 |
| **경로 산개** | **없다.** 100 명이 같은 흐름장 한 줄기를 탄다 | **여기가 비어 있다** |

구석 24 명의 정지 시간이 3.02 → 10.02 초로 나빠진 것(README §11)은 이 폴백과 정확히 같은 자리다 —
구석은 자리 후보가 벽에 걸려 대량으로 걸러지는 판이다. **재현 조건이 코드에 그대로 보인다.**

---

## 23.4 먼저 확인 — Godot 내장 회피는 쓸 수 있는가

**이미 있는 것을 다시 짜는 것이 최악이다.** 그래서 이것부터 봤다.

### 무엇이 있는가

Godot 4 는 `NavigationAgent2D.avoidance_enabled` 로 **RVO 계열 상호 회피를 내장**한다.
켜면 에이전트가 `NavigationServer2D` 의 회피 콜백에 등록되고, 매 물리 프레임
`velocity_computed(safe_velocity)` 시그널로 안전한 속도를 돌려받는다.
(`set_velocity()` 로 원하는 속도를 넣고 `safe_velocity` 를 실제로 적용하는 구조다.)

### 그런데 우리 판에는 그대로 안 맞는다 — 넷

| 문제 | 공식 문서가 말하는 것 |
| --- | --- |
| **벽을 모른다** | "Behind the scene avoidance agents are just circles with different radius on a flat 2D plane" — 회피는 내비메시·물리와 **독립**이다. 64 px 문의 벽은 회피 계산에 **존재하지 않는다** |
| 벽을 알리려면 별 장치가 필요 | `NavigationObstacle2D` 정적 장애물(정점 배열 폴리곤)을 따로 넣어야 "hard do-not-cross boundaries" 가 된다. 그리고 **"the constant rebuild has a high performance cost"** |
| **정면 대치에서 깨진다** | "very clinical avoidance test scenarios will commonly fail. E.g. agents moved directly against each other with perfect opposite velocities will fail" — 우리 `맞교차` 시나리오가 정확히 이것이다 |
| **비싸다** | "Avoidance processing with many registered agents has a significant performance cost and should only be enabled on agents that currently require it" |

### 결정적인 것 — 스레드풀

공식 문서: **"the NavigationServer uses a threadpool by default for some functionality like avoidance calculation between agents."**

**우리는 웹 단일 스레드다**(`01-constraints.md` §1.1, `SharedArrayBuffer` 불가).
즉 이 기능이 성능을 내는 전제 자체가 우리 빌드에서 사라진다. 데스크톱에서 재면 멀쩡한데
웹에서 무너지는 종류의 비용이고, **네이티브 벤치로는 이 위험이 안 보인다.**

> **미확인:** 웹 단일 스레드 빌드에서 `WorkerThreadPool` 이 정확히 어떻게 퇴화하는지
> (동기 실행으로 폴백인지, 회피 자체가 꺼지는지)는 문서에서 확인하지 못했다.
> **쓰기로 한다면 이 한 가지는 반드시 웹 빌드에서 실측해야 한다.**

### 결론

**내장 회피는 우리 프로토타입의 대안이 아니다.** 이유가 셋이다.

1. 우리는 `NavigationServer` 를 아예 안 쓴다 — 자체 격자(`ProtoNavGrid`)와 흐름장이다.
   내장 회피를 쓰려면 내비게이션 층을 통째로 갈아야 하고, 그건 90 시간 안에 할 일이 아니다
2. 벽을 모르는 회피는 **문 통과를 못 고친다.** 우리 문제의 중심이 문이다
3. 웹 단일 스레드에서 성능 전제가 무너진다

**다만 버릴 것은 아니다.** RVO 의 *아이디어*(상호 책임 분담)는 §23.7 에서 따로 본다 —
`NavigationAgent2D` 를 쓰는 것과 ORCA 의 반쪽 책임 규칙만 가져오는 것은 다른 일이다.

---

## 23.5 후보 일람 — 무엇이 무슨 증상을 고치는가

증상 넷은 §23.1 의 표다. **○ 고친다 · △ 부분적 · ✕ 못 고친다 · ⚠ 오히려 나빠질 수 있다.**

| # | 기법 | 교착 | 꺾임 | 뭉침 | 벽 붙기 | 첫인상 |
| --- | --- | --- | --- | --- | --- | --- |
| A | **밀도 기반 정지** (SC2Avoidance) | **○** | ✕ | **○** | ✕ | 가장 싸다. 반나절 |
| B | **자리 폴백 고치기** (`center` 몰아주기 제거) | **○** | ✕ | ○ | ✕ | 우리 코드 한 곳. 시간 단위 |
| C | **벽 거리 비용** (clearance cost in flow field) | △ | **○** | ✕ | **○** | 흐름장 생성에만 손댄다 |
| D | **양보 우선순위** (avoidancePriority 계열) | **○** | △ | ✕ | ✕ | 규칙이 단순. 교착 직결 |
| E | **접근 방향 배정** (formation assign) | ○ | △ | ○ | ✕ | README §11 이 이미 지목 |
| F | **경로 산개** (다중 목표 · 밀도 비용) | **○** | ✕ | **○** | △ | Continuum Crowds 의 축소판 |
| G | **ORCA / RVO2** (직접 구현) | △ | ○ | ✕ | ✕ | 비싸다. 벽을 모른다 |
| H | **예측형 회피** (time-to-collision) | △ | **○** | ✕ | ✕ | 자연스러움에 직결 |
| I | **PBD 위치 기반 군중** | ○ | △ | ○ | ✕ | ⚠ 밀치기가 되살아난다 |
| J | **퍼널 / string pulling** | ✕ | **○** | ✕ | ○ | ⚠ 우리는 폴리곤 회랑이 없다 |
| K | **`dtCrowd` 식 회랑 + 국소 회피** | ○ | ○ | ○ | ○ | ⚠ 통째로 갈아엎기 |

### 이 표에서 바로 읽히는 것

- **교착을 푸는 데 꺾임 기법이 필요하지 않다.** A · B · D · F 는 전부 꺾임 열이 비어 있는데
  교착 열이 채워져 있다. 두 문제는 **서로 다른 손잡이로 푼다**
- **벽 붙기를 고치는 것은 C 하나뿐이고, C 는 꺾임도 같이 고친다.** README §7 이
  "통로 한가운데로 끌어당겨야 한다. 그건 벽까지의 거리를 재는 조회가 따로 필요해서 손대지 않았다"
  고 적어 둔 바로 그 항목이다 — **미룬 이유가 지금은 유효하지 않다**(흐름장은 명령당 한 번만 돈다)
- **⚠ 셋(I · J · K)은 우리 판을 갈아엎는다.** 90 시간에서는 이것부터 잘라야 한다

---

## 23.6 조사 중에 튀어나온 것 — 흐름장 생성이 44 ms 다

**이건 조사 항목이 아니었다. C 의 비용을 재려다 나왔다.**

`build_flow_field` 를 200 회 평균으로 직접 쟀다 (Godot 4.7.1 헤드리스, 네이티브, 60×34 = 2040 칸).

| 무엇 | 열린 곳 | 좁은 통로 |
| --- | --- | --- |
| **`build_flow_field` 전체** | **46.8 ms** | **55.8 ms** |
| 그중 `_derive_directions` | — | **19.2 ms** (44 %) |
| 나머지 (`_integrate` + 배열 초기화) | — | 약 25 ms |

**이것은 매 프레임 비용이 아니라 명령 하나당 비용이다** — `unit_field.gd:305` 에서
우클릭을 처리하는 그 프레임 안에서 동기로 돈다.

| 따져 볼 것 | 값 |
| --- | --- |
| 프레임 예산 (60 fps) | 16.7 ms |
| 우클릭 한 번 | **44~56 ms = 네이티브에서 약 3 프레임 정지** |
| README §11 이 보고한 "이동 계산" | 100 명 3.24 ms (**매 프레임** 조향 비용. 이 44 ms 는 여기 안 들어 있다) |
| 웹 (단일 스레드 · wasm) | **미측정.** GDScript 가 웹에서 더 느린 것은 확실하나 배수는 재야 안다 |

**왜 지금까지 안 보였나.** 지표 도구는 명령을 한 번 주고 40 초를 굴린다. 44 ms 는
전체의 0.1 % 라 평균에 묻힌다. `fps` 와 `이동 계산` 둘 다 이 값을 안 센다.

**왜 이렇게 비싼가.** 2040 칸에 대해 칸마다 8 이웃을 훑고, 대각선마다 `_diagonal_open` 이
`is_walkable` 을 두 번 더 부른다. `_derive_directions` 만 2040 × 8 × 3 ≈ 4.9 만 회의
GDScript 함수 호출이다. **알고리즘이 아니라 호출 횟수가 비용이다.**

> **구현 레인에 바로 전달할 것.** 이 절의 나머지 권고와 무관하게 독립된 문제다.
> 줄일 여지는 커 보인다 — `_derive_directions` 를 `_integrate` 안으로 접거나,
> `_diagonal_open` 의 `is_walkable` 두 번을 비트 조회로 바꾸거나, 아예
> 방향을 미리 굽지 않고 `direction_at` 에서 비용 기울기로 즉석에서 구하는 방법이 있다.
> **다만 이 문서는 코드를 안 고친다. 여기까지가 조사다.**

---

## 23.7 기법별 상세

### 23.7.1 지금 — 공짜로 얻는 것 (기법이 아니라 버그 수정)

#### B. 자리 폴백 — `slots.append(center)`

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | 기법이 아니다. `ProtoFormation.build_slots` 는 통행 불가 자리를 걸러 내고, 자리가 모자라면 남은 인원 **전원에게 목표 지점 하나**를 준다. 걸러지는 자리가 많은 판(구석·문 앞)에서 수십 명이 같은 좌표를 목표로 받는다 |
| **고치는 증상** | 교착 ○ · 뭉침 ○ / 꺾임 ✕ · 벽 붙기 ✕ |
| **비용** | 0. 오히려 줄어든다 |
| **구현 규모** | **한 함수.** 시간 단위 |
| **충돌** | 없다. `assign` 은 자리 개수만 본다 |
| **출처** | 우리 코드 `src/proto/unit_move/core/formation.gd` |

**고치는 방향은 격자를 넓히는 것이다** — 자리가 모자라면 육각 격자의 고리를 더 돌려
통행 가능한 자리를 더 찾는다. 한 점에 몰아주는 것만 없애면 된다.

**재현 조건이 지표와 맞아떨어진다.** 구석 24 명 정지 시간 3.02 → 10.02 초(README §11).
구석은 자리 후보가 벽 밖으로 대량 걸러지는 판이다.

---

### 23.7.2 지금 — 교착을 푸는 최단 경로

#### A. 밀도 기반 정지 (density-based stopping)

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | 목적지를 중심으로, 내 현재 위치가 테두리에 닿는 원을 그린다. 그 원의 넓이를 `A`, 원 안에 든 유닛들의 **몸 넓이 합**을 `a` 라 할 때 `a > A × k` 면 **더 밀지 않고 그 자리에 선다.** 목적지에 가까워질수록 원이 작아지므로, 이미 꽉 찬 목적지에는 뒤에서 온 유닛이 애초에 진입하지 않는다 |
| **고치는 증상** | 교착 ○ · 뭉침 ○ / 꺾임 ✕ · 벽 붙기 ✕ |
| **비용** | 유닛당 이웃 훑기 1 회. **우리는 이미 격자 해시로 이웃을 훑고 있다** — 그 훑기에 넓이 누산 한 줄을 얹으면 끝이다. 100 명 기준 **0.1 ms 미만** 추정 |
| **구현 규모** | **반나절.** 판정 하나와 상태 하나 |
| **충돌** | 없다. `HOLDING`(README §8)과 같은 층이고, 오히려 `HOLDING` 이 늘어난 것(30~58 명)을 앞당겨 정리한다 |
| **출처** | A* Pathfinding Project `SC2Avoidance` — 원문: *"Take the circle with the center at the AI's destination and a radius such that the AI's current position is touching its border. Let 'A' be the area of that circle. Further let 'a' be the total area of all individual agents inside that circle. The agent should stop if a > A*0.6"* (`densityFraction` 기본 0.5) |

> **반지름이 섞여 있다 — 개수로 세면 안 된다.**
> 우리 유닛은 반지름 9 · 11 · 12 다. `a` 는 **반드시 `Σ π·r_i²`(각자의 실제 넓이 합)로 구해야 하고**,
> `개수 × 대표 반지름` 으로 근사하면 안 된다. 정찰병(9)과 보병(12)의 넓이비가
> `(9/12)² = 0.5625` 라 **거의 두 배가 어긋난다** — 정찰병 무리는 너무 일찍 서고
> 보병 무리는 너무 늦게 선다. `π` 는 양변에서 약분되므로 실제로는 `Σ r_i² > R² × k` 로 재면 된다.

#### D. 양보 우선순위 (avoidance priority)

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | 유닛마다 우선순위를 주고, **낮은 쪽이 회피 책임을 전부 진다.** Unity 는 0~99 로 두고 "agents of lower priority are ignored" — 높은 쪽은 상대가 없는 것처럼 제 길을 가고 낮은 쪽만 비킨다. 대칭이 깨지므로 서로 되밀며 떠는 진동이 **구조적으로** 안 생긴다 |
| **고치는 증상** | 교착 ○ · 꺾임 △ / 뭉침 ✕ · 벽 붙기 ✕ |
| **비용** | 0 에 가깝다. 비교 한 번 |
| **구현 규모** | **반나절.** 어려운 건 코드가 아니라 **무엇으로 순위를 매기느냐**다 |
| **충돌** | **우리는 이미 절반을 갖고 있다.** `_separation` 의 「양보」(목적지에 가까운 쪽에 우선권)가 바로 이것이다. 지금은 슬라이더 세기(0.70)로 섞어 넣는데, **순서로 못 박으면** 교착이 풀린다 |
| **출처** | [Unity `NavMeshAgent.avoidancePriority`](https://docs.unity3d.com/ScriptReference/AI.NavMeshAgent-avoidancePriority.html) · A* Pathfinding Project `SC2Avoidance` (도착한 유닛의 우선순위를 낮춘다) |

**순위를 무엇으로 매길 것인가 — 좁은 목에서는 「목적지까지의 흐름장 비용」이 답이다.**
우리는 `flow.costs` 를 이미 들고 있다. **비용이 낮은 쪽(= 문에 가까운 쪽)이 먼저 지나간다.**
전순서(total order)라 순환 교착이 생길 수 없고, 추가 계산이 **0** 이다 — 배열 조회 한 번.

> **주의: 우선순위만으로는 정면 대치가 안 풀린다.** 맞교차 시나리오처럼 서로 반대편에서
> 오는 두 무리는 흐름장이 **다르므로** 비용을 비교할 수 없다. 그 판에는 별도의 결정 규칙
> (예: 유닛 id 로 결정론적 tie-break)이 필요하다. 이건 우리가 이미 `_separation` 에서
> "비껴가기 방향을 늘 같은 손으로 고정"(README §7)한 것과 같은 수법이다.

---

### 23.7.3 그다음 — 꺾임과 자연스러움

#### C. 벽 거리 비용 (clearance cost)

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | 칸마다 **가장 가까운 벽까지의 거리**를 미리 구해 두고(모든 벽 칸에서 동시에 퍼뜨리는 다중 시작점 BFS = 거리 변환), 흐름장 통합에서 벽에 가까운 칸에 **가산 비용**을 얹는다. 최단 경로가 통로 한가운데로 밀린다. 유닛을 옆에서 미는 힘이 아니라 **길 자체를 가운데로 옮기는 것**이라 새 진동원이 생기지 않는다 |
| **고치는 증상** | **꺾임 ○ · 벽 붙기 ○** / 교착 △ (문 입구 정렬이 좋아져 간접적으로) · 뭉침 ✕ |
| **비용** | **아래 표. 사실상 공짜다** |
| **구현 규모** | **하루.** BFS 한 벌 + `_integrate` 의 비용식에 한 항 |
| **충돌** | 없다. 흐름장 안에서 끝나고 조향·분리·`push_out` 을 건드리지 않는다. **유닛에 힘을 더하지 않으므로 `정지밀림 0.00` 이 위협받지 않는다** |
| **출처** | Continuum Crowds 의 비용식(지형 비용 + 밀도 비용)에서 지형 항만 떼어 온 형태 · [Emerson, *Crowd Pathfinding and Steering Using Flow Field Tiles*, Game AI Pro ch.23](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf) (Supreme Commander 2 의 흐름장 구조. **본문은 확인하지 못했다 — 미확인**) |

**README §7 이 미룬 이유는 수치로 무효다.** 원문은 "줄을 세우려면 밀치기를 깎을 게 아니라
통로 한가운데로 끌어당겨야 한다. **그건 벽까지의 거리를 재는 조회가 따로 필요해서 손대지 않았다**"
였다. 직접 재 봤다 (200 회 평균, 60×34 = 2040 칸, 네이티브).

| 무엇 | 언제 도는가 | 비용 |
| --- | --- | --- |
| 벽 거리 BFS (4 방향, 전 칸) | **지형당 1 회.** 벽은 안 움직인다 | 6.5 ~ 7.3 ms |
| 통합 중 칸마다 배열 1 회 읽기 + 곱 | 명령당 1 회 | **0.036 ~ 0.053 ms** |
| (대조) `build_flow_field` 전체 | 명령당 1 회 | **44 ~ 56 ms** |

**핵심은 「벽까지의 거리」가 목적지와 무관하다는 것이다.** 명령마다 다시 잴 필요가 없고
맵을 만들 때 한 번 구워 두면 된다. 명령당 추가되는 비용은 **0.05 ms — 지금 흐름장 생성
비용의 0.1 % 미만이다.** 미룬 근거였던 "조회가 따로 필요해서"는 성립하지 않는다.

**튜닝 주의 둘.**

1. **가산 비용이 세면 좁은 문을 아예 안 지나간다.** 2 칸 문은 모든 칸이 벽에 붙어 있다.
   벽 거리 페널티는 **상한을 씌워야** 한다 (예: 몸이 들어가는 최소 거리 이상은 페널티 0)
2. **`_integrate` 는 SPFA 형태다.** 지금도 대각선 비용 1.414 를 쓰므로 비균일 비용을
   이미 다루지만, 페널티를 얹으면 재완화 횟수가 늘어 44 ms 가 더 커질 수 있다. **재야 안다**

#### E. 접근 방향을 자리 배정에 넣기

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | `ProtoFormation.assign` 은 안쪽 자리부터 가장 가까운 유닛을 데려간다. 그래서 왼쪽에서 온 무리 일부가 **오른쪽 바깥 자리**를 받고 대열을 가로지른다. 배정 기준에 무리의 진입 방향을 넣어, 먼저 닿는 쪽이 먼 쪽 자리를 안 받게 한다 |
| **고치는 증상** | 교착 ○ · 뭉침 ○ · 꺾임 △ / 벽 붙기 ✕ |
| **비용** | 0. 명령당 1 회, 정렬 기준만 바뀐다 |
| **구현 규모** | **반나절** |
| **충돌** | 없다 |
| **출처** | 우리 자신 — README §11 이 이미 지목했다: *"접근 방향을 배정에 넣으면 정지 시간과 `HOLDING` 이 함께 내려갈 것으로 본다"* |

#### F. 경로 산개 — 밀도를 비용에 넣기 (Continuum Crowds 의 축소판)

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | Continuum Crowds 는 유닛 밀도를 **동적 potential field** 에 넣어, 붐비는 칸을 비싸게 만들어 무리가 저절로 여러 갈래로 갈라지게 한다. 원 논문은 *"a dynamic potential field simultaneously integrates global navigation with moving obstacles ... without the need for explicit collision avoidance"* 라고 쓴다 |
| **고치는 증상** | 교착 ○ · 뭉침 ○ · 벽 붙기 △ / 꺾임 ✕ |
| **비용** | **원형 그대로는 불가능하다.** 밀도가 매 프레임 바뀌므로 장을 **매 프레임** 다시 풀어야 한다. 우리 실측으로 **44 ms × 60 = 2.6 초/초.** 웹 단일 스레드에서 논외다 |
| **구현 규모** | 원형: 며칠. **축소판: 하루** |
| **충돌** | 원형은 흐름장을 통째로 대체한다. 축소판은 얹기만 한다 |
| **출처** | [Treuille, Cooper, Popović, *Continuum Crowds*, SIGGRAPH 2006](https://dl.acm.org/doi/10.1145/1141911.1142008) · [프로젝트 페이지](http://graphics.cs.cmu.edu/?p=375) |

**축소판이 우리가 쓸 형태다.** 매 프레임 장을 다시 풀지 않는다.

- **목적지를 여러 개로 쪼갠다.** 100 명에게 흐름장 하나가 아니라 **문 건너편 여러 집결지**로
  향하는 흐름장 2~3 개를 만들고 무리를 나눈다. 명령당 44 ms × 3 이 되므로
  **§23.6 의 44 ms 를 먼저 줄이지 않으면 이건 못 쓴다 — 의존 관계가 있다**
- 또는 **자리 배정만 나눈다.** 흐름장은 하나로 두고 도착 자리를 문 건너편에 넓게 편다.
  이건 B · E 의 연장이고 **추가 비용이 0** 이다

#### H. 예측형 회피 (time-to-collision)

| 항목 | 내용 |
| --- | --- |
| **무엇인가** | 지금 거리가 아니라 **앞으로 부딪히기까지의 시간** `τ` 로 상호작용 세기를 정한다. Karamouzas 등이 실제 보행자 데이터에서 측정한 상호작용 에너지가 `τ` 의 멱법칙(`E ∝ τ^-2` 꼴)을 따랐다 — *"based not on the physical separation between pedestrians but on their projected time to a potential future collision, and is therefore fundamentally anticipatory"*. 부딪힌 뒤 반응하지 않고 **미리 비껴서** 사람처럼 보인다 |
| **고치는 증상** | **꺾임 ○** (늦게 반응해 급히 꺾는 것이 사라진다) · 교착 △ / 뭉침 ✕ · 벽 붙기 ✕ |
| **비용** | 이웃당 2 차 방정식 하나. 이미 도는 이웃 훑기 안에서 끝난다. 100 명 **0.3~0.5 ms 추정** (미측정) |
| **구현 규모** | **하루~이틀.** 힘 식 하나를 갈고 다시 튜닝해야 한다 |
| **충돌** | `_separation` 을 갈아 끼우는 일이다. **README §7 · §10 이 두 번 배운 교훈 — "자르는 축이 곧 지터의 씨앗"에 정면으로 걸린다.** `τ` 는 상대 속도로 정해지므로 이웃이 바뀌면 축도 바뀐다. **위험하다** |
| **출처** | [Karamouzas, Skinner, Guy, *Universal Power Law Governing Pedestrian Interactions*, PRL 113, 238701 (2014)](https://arxiv.org/abs/1412.1082) |

**꺾임에 가장 잘 듣는 후보이지만, 우리 판에서 가장 위험한 후보이기도 하다.**
C 를 먼저 넣고 그래도 꺾임이 남을 때만 손댄다.

---

### 23.7.4 안 쓸 것 — 이 문단으로 끝낸다

> **누군가 나중에 이것들을 다시 꺼내면, 이 문단을 보여 주고 끝내라.**

| 기법 | 자르는 이유 (한 줄) |
| --- | --- |
| **Godot 내장 회피** (`NavigationAgent2D.avoidance_enabled`) | **벽을 모른다.** 공식 문서: *"avoidance agents are just circles ... on a flat 2D plane."* 우리 문제의 중심이 64 px 문인데 그 문이 회피 계산에 존재하지 않는다. 게다가 우리는 `NavigationServer` 를 안 쓴다(자체 격자) — 도입은 내비게이션 층 전면 교체다. 그리고 **스레드풀 전제**(*"the NavigationServer uses a threadpool by default for ... avoidance calculation"*)가 웹 단일 스레드에서 무너진다 |
| **G. ORCA / RVO2 직접 구현** | 원리는 옳다 — 각자 회피 책임을 반씩 져서 진동이 구조적으로 안 생긴다. **하지만 ORCA 도 벽을 모른다** (정적 장애물은 별도 선분 제약을 손으로 넣어야 한다). 그리고 유닛마다 이웃 수만큼 반평면을 세워 **저차원 선형계획을 푼다.** C++ RVO2 가 "수천 에이전트를 수 밀리초"에 하는 것은 C++ 이라서다. GDScript 로 100 명 × 이웃 10 = 반평면 1000 개 + LP 100 회는 **5 ms 예산에 들어갈 근거가 없다**(미측정 추정). **무엇보다 D(양보 우선순위)가 ORCA 가 푸는 문제의 대부분을 0 에 가까운 비용으로 푼다** |
| **I. PBD 위치 기반 군중** | **위치로 겹침을 푸는 방식이 곧 우리가 §9 에서 걷어낸 밀치기다.** 제약 투영은 양쪽 위치를 다 옮기고, 그 순간 `정지밀림 0.00 px` 이 깨진다. "이 게임은 물리력 게임이 아니다"라는 기획 판단과 정면으로 충돌한다. 성능은 오히려 좋지만(수십만 에이전트) **살 수 없는 것을 판다** |
| **J. 퍼널 / string pulling** | **우리에게는 펼 실이 없다.** 퍼널은 폴리곤 회랑(portal 로 이어진 폴리곤 열)을 전제하는데 우리는 **흐름장**이라 유닛별 경로 자체가 없다. 회랑을 만들려면 유닛마다 A* 를 돌려야 하고, 그건 흐름장을 쓴 이유(`flow_field.gd` 주석: 재탐색이 여럿에게 동시에 걸리면 웹 단일 스레드에서 프레임 끊김)를 정면으로 되돌린다. **게다가 우리 꺾임의 원인은 경로가 계단이어서가 아니라 조향 목표가 튀어서다**(README §7) — 원인이 다른 곳에 있다 |
| **K. `dtCrowd` 식 회랑 + 국소 회피** | 실전 검증된 조합이 맞다(경로 회랑 + 국소 회피 + 분리 가중치). **하지만 이건 기법이 아니라 아키텍처다.** 도입은 내비메시 · 회랑 · 국소 회피 · 분리를 통째로 갈아 끼우는 일이고, 남은 90 시간(실작업 30~40 시간, `01-constraints.md` §1.3) 중 이동에 이미 상당량을 썼다. **확정 제약이 "처음 보는 기술을 쓰지 않는다"고 못 박고 있다.** 다만 **읽을 값어치는 있다** — `separationWeight * (1 - (dist/range)²)` 같은 식은 그대로 참고할 수 있다 |

**셋의 공통점을 보라 — G · I · K 는 전부 "우리 판을 갈아엎고 그 대가로 얻는 것이
D · A 가 이미 주는 것"이다.** J 만 다른 이유로 잘렸다(원인 오진).

---

## 23.8 권고

### 지금 (교착을 푸는 최단 경로) — 하루 반

| 순서 | 무엇 | 규모 | 왜 이 순서인가 |
| --- | --- | --- | --- |
| 1 | **B. 자리 폴백 고치기** | 시간 단위 | 버그다. 다른 무엇을 재기 전에 없애야 지표가 믿을 만해진다 |
| 2 | **D. 양보 우선순위를 흐름장 비용으로 못 박기** | 반나절 | 추가 계산 **0**(`flow.costs` 조회 1 회). 전순서라 순환 교착이 없다 |
| 3 | **A. 밀도 기반 정지** | 반나절 | 이미 도는 이웃 훑기에 넓이 누산 한 줄. **`Σ r_i²` 로 재라** |

**셋 다 꺾임을 안 고친다. 그래서 셋 다 지금 넣어도 서로 안 싸운다.**
좁은 통로 100 명 「83 명이 못 넘는다」를 겨냥한 조합이다.

### 그다음 (꺾임과 자연스러움) — 이틀

| 순서 | 무엇 | 규모 |
| --- | --- | --- |
| 4 | **C. 벽 거리 비용** | 하루. 명령당 추가 비용 **0.05 ms** — 미룰 근거가 없다 |
| 5 | **E. 접근 방향 배정** | 반나절 |
| 6 | **F 의 축소판** (자리만 넓게 펴기) | 반나절. 흐름장을 늘리는 쪽은 §23.6 을 먼저 해결해야 한다 |

### 순서 밖 — 독립 문제

| 무엇 | 왜 |
| --- | --- |
| **§23.6 흐름장 생성 44 ms** | 위 권고와 무관하게 존재한다. 우클릭마다 네이티브 3 프레임 정지이고 **웹에서는 미측정**이다. F 의 다중 흐름장은 이게 먼저 풀려야 가능하다 |

### 안 한다

**Godot 내장 회피 · G(ORCA) · I(PBD) · J(퍼널) · K(dtCrowd)** — 이유는 §23.7.4 표.
한 줄로 줄이면: **넷은 우리 판을 갈아엎고 그 대가로 D · A 가 이미 주는 것을 준다.
J 는 우리 꺾임의 원인이 경로가 아니라 조향 목표라서 애초에 겨냥이 빗나갔다.**

### 이 문서가 지키려는 한 줄

> **교착과 꺾임은 다른 손잡이로 푼다.**
> 교착은 **순서**(D)와 **멈춤 규칙**(A)으로, 꺾임은 **길의 모양**(C)으로 푼다.
> 둘을 한 기법으로 같이 풀려는 시도(G · I · K)가 우리를 두 번 갈아엎게 만든다.

---

## 23.9 출처

| 기법 | 출처 |
| --- | --- |
| Godot 내장 회피 | [Using NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html) · [Using NavigationObstacles](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationobstacles.html) · [Using NavigationServers](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationservers.html) |
| ORCA / RVO2 | [ORCA 프로젝트](https://gamma.cs.unc.edu/ORCA/) · [van den Berg 외, *Reciprocal n-body Collision Avoidance*](https://gamma.cs.unc.edu/ORCA/publications/ORCA.pdf) · [RVO2 구현](https://github.com/snape/RVO2) |
| Continuum Crowds | [Treuille, Cooper, Popović, SIGGRAPH 2006](https://dl.acm.org/doi/10.1145/1141911.1142008) · [프로젝트 페이지](http://graphics.cs.cmu.edu/?p=375) |
| 흐름장 타일 (Supreme Commander 2) | [Emerson, *Crowd Pathfinding and Steering Using Flow Field Tiles*, Game AI Pro ch.23 (PDF)](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter23_Crowd_Pathfinding_and_Steering_Using_Flow_Field_Tiles.pdf) — **본문 미확인** |
| 예측형 회피 | [Karamouzas, Skinner, Guy, *Universal Power Law Governing Pedestrian Interactions*, PRL 113, 238701 (2014)](https://arxiv.org/abs/1412.1082) |
| PBD 군중 | [Weiss 외, *Position-Based Multi-Agent Dynamics for Real-Time Crowd Simulation*, MiG 2017](https://arxiv.org/abs/1802.02673) |
| 퍼널 / SSFA | [Mononen, *Simple Stupid Funnel Algorithm*](http://digestingduck.blogspot.com/2010/03/simple-stupid-funnel-algorithm.html) |
| `dtCrowd` | [DetourCrowd.h](https://github.com/recastnavigation/recastnavigation/blob/main/DetourCrowd/Include/DetourCrowd.h) · [`dtCrowdAgentParams`](https://recastnav.com/structdtCrowdAgentParams.html) |
| 우선순위 회피 | [Unity `NavMeshAgent.avoidancePriority`](https://docs.unity3d.com/ScriptReference/AI.NavMeshAgent-avoidancePriority.html) · [A* Pathfinding Project `SC2Avoidance`](https://www.arongranberg.com/astar/documentation/rts_4_1_18_5eec8424/old/class_s_c2_avoidance.php) |

### 이 문서가 직접 잰 것

| 값 | 조건 |
| --- | --- |
| `build_flow_field` 44 ~ 56 ms · `_derive_directions` 19.2 ms | Godot 4.7.1 헤드리스 · 네이티브 · 60×34 = 2040 칸 · 200 회 평균 |
| 벽 거리 BFS 6.5 ~ 7.3 ms | 같은 조건. **지형당 1 회** |
| 칸마다 배열 1 회 읽기+곱 0.036 ~ 0.053 ms | 같은 조건. 2040 칸 전체 |

계측에 쓴 스크립트는 임시로 만들어 지웠다. **웹 빌드에서는 아무것도 재지 않았다.**
