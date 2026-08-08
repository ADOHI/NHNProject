# 캐릭터 애니메이션 프로토타입

머리 · 몸 · 손 둘 · 발 둘 **여섯 파츠**를 **이동 · 회전 · 배율만으로** 움직인다.
관절도, 뼈대 변형도, 스프라이트 프레임 교체도 쓰지 않는다.

설계 근거와 값을 고른 이유는 [`docs/design/25-character-animation.md`](../../../docs/design/25-character-animation.md).

> **상태: idle 1 종.** walk · run · jump · get hit · die 는 미착수.

---

## 1. 실행

```
godot --path . res://src/proto/char_anim/char_anim_proto.tscn
```

에디터에서는 `src/proto/char_anim/char_anim_proto.tscn` 을 열고 **현재 씬 실행**(F6).
`main.tscn` 과 완전히 독립이라 무엇도 건드리지 않는다.

### 조작

| 조작 | 하는 일 |
| --- | --- |
| Space | 멈춤 · 재생 |
| 왼쪽 · 오른쪽 화살표 | 멈춘 상태에서 한 걸음(0.04 초)씩. GIF 프레임과 같은 간격이다 |
| **Q** | **지연** 켜기 · 끄기 |
| **W** | **호** 켜기 · 끄기 |
| **E** | **배율** 켜기 · 끄기 |
| **A** | **비대칭** 켜기 · 끄기 |
| **Z** | 넷 다 끄기 · 켜기 |
| G | 쉬는 자세의 피벗 기준선 |
| Tab | 조절판 접기 · 펴기 |
| H | 도움말 접기 · 펴기 |
| 대괄호 열기 · 닫기 | 느리게 · 빠르게 |
| R | 처음으로 |
| Esc | 나가기 |

조절판의 슬라이더로 0 과 1 사이의 중간값도 줄 수 있다. 키는 0 과 1 만 오간다.

### 무엇을 봐야 하나

**Z 를 눌러 넷을 다 껐다 켜 보는 것이 이 프로토타입의 요점이다.**

끈 상태는 "위아래로 뻣뻣하게 진동하는 도형 여섯"이다. 파츠가 한 몸으로 움직이고,
좌우로 흐르지 않고, 눌리지 않고, 좌우가 똑같다. **그 상태와 켠 상태의 차이가 이 작업의 전부다.**

하나씩 켜 보면 어느 축이 무엇을 만드는지 갈린다.

| 축 | 껐을 때 사라지는 것 |
| --- | --- |
| 지연 | 머리가 몸보다 늦게 오는 것, 손이 가장 늦게 오는 것 |
| 호 | 머리가 그리는 8 자. 몸이 좌우로 흐르는 것. 고개의 갸웃 |
| 배율 | 가슴이 부풀며 몸통이 좁아지는 것. 실린 발이 눌리는 것 |
| 비대칭 | 두 손의 어긋남. **발의 무게 이동 전부** (발이 죽은 듯 멈춘다) |

---

## 2. 구조

```
src/core/char_anim/            # 노드에 의존하지 않는 순수 로직
├── char_part.gd               # 파츠 여섯의 식별자와 그리는 순서
├── char_rig.gd                # 피벗 · 치수
├── char_pose.gd               # 트랜스폼 한 벌 + 좌표계 변환
├── anim_features.gd           # 지연 · 호 · 배율 · 비대칭 가중치
├── char_clip.gd               # 기반: sample(t, features) -> CharPose
└── idle_clip.gd               # idle 의 수식

src/proto/char_anim/           # 띄워 보는 층
├── char_anim_proto.tscn/gd    # 진입점. 입력 · 조절판 · 배경
├── char_parts_view.gd         # 파츠 여섯을 노드로 만들고 포즈를 트랜스폼에 넣는다
├── char_part_shape.gd         # 도형 그리기
└── anim_tuning_panel.gd       # 슬라이더 조절판
```

**애니메이션은 순수 함수다.**

```gdscript
func sample(t: float, features: AnimFeatures) -> CharPose
```

노드도, 이전 프레임도, 난수도 안 본다. 같은 `t` 면 언제나 같은 포즈다.
그래서 테스트가 되고, GIF 캡처가 실시간을 안 기다린다.

**스프라이트로 갈아 끼울 때 바뀌는 파일은 `char_rig.gd` 와 `char_part_shape.gd` 둘이다.**
애니메이션 수식은 하나도 안 건드린다.

---

## 3. GIF 뽑기

```
godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/idle
godot --path . -s res://tools/capture_char_anim.gd -- .renders-char-anim/doll off
python tools/make_gif.py .renders-char-anim/idle
python tools/make_gif.py .renders-char-anim/idle --beside .renders-char-anim/doll --out .renders-char-anim/idle_vs_doll.gif
```

두 번째 인자로 조절판을 지정한다 — `off` · `on` · `delay` · `arc` · `squash` · `asymmetry`.
축 이름을 주면 **그 축만 켠** 상태가 찍힌다.

`--beside` 는 두 묶음을 나란히 붙인다. **따로 두 개를 보면 사람은 기억으로 비교하게 되고,
그러면 미세한 지연과 비대칭은 그냥 안 보인다.** 나란히 놓는 순간 보인다.

25 fps · 100 프레임 · 한 바퀴 4.00 초. GIF 프레임 지연이 정확히 40 ms 라 시간이 안 밀린다.

산출물은 `.renders-char-anim/` 에 남고 `.gitignore` 되어 있다 (검증용이므로 커밋하지 않는다).

---

## 4. 테스트

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```

| 파일 | 무엇을 잡나 |
| --- | --- |
| `test/unit/test_char_pose.gd` | 좌표계 변환(회전은 뒤집히고 배율은 안 뒤집힌다) · 피벗 · 파츠 간 간격 |
| `test/unit/test_idle_clip.gd` | 파형 · 지연 순서 · 루프 이음매 · 접지 |
| `test/unit/test_idle_features.gd` | **조절판 스위치 넷의 계약** — 0 에서 무엇이 정확히 사라지는가 |
| `test/support/char_anim_probe.gd` | 위 둘이 공유하는 계측 도구 (테스트가 아니다) |

> **`src/` 나 `test/` 에 `class_name` 을 새로 넣었으면 먼저 `--import` 를 돌려라.**
> 스크립트 클래스 캐시가 낡으면 그 이름을 쓰는 테스트가 **파싱 실패**하고,
> **GUT 은 그것을 실패로 세지 않고 건너뛰며 「전부 통과」를 찍는다.**
> 이 레인에서 실제로 두 파일이 조용히 빠진 채 "469 통과"가 나왔다.
> `Scripts` 와 `Tests` 숫자가 실제로 늘었는지 눈으로 확인하는 것이 유일한 방어다.
