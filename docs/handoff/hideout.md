# HANDOFF — hideout 레인

> **이 파일을 먼저 읽고** [`design/30-hideout.md`](design/30-hideout.md) §30.13–§30.14 로 내려가라.
> 세션 대화는 사라질 수 있다. **디스크에 쓴 것만 진실이다** (`CLAUDE.md` 원칙 1).

## 한 줄

아이소 거점 UI 레인. **규칙·에셋 정합 = 칸 그리드 + fit.** 시점 **2:1**.  
다음: 사용자가 뽑은 건물 PNG → **fit(그리드 캔버스)** → 배치·캡처.

## 위치

| | |
| --- | --- |
| 브랜치 | `hideout` |
| 워크트리 | `C:\Users\adohi\NHNProject\.claude\worktrees\hideout` |
| main | **미머지.** `main` 의 `src/ui/base/` 는 패널 아지트(§22)일 뿐, hideout 아이소 없음 |
| 독립 실행 | `godot --path . res://src/ui/hideout/hideout_screen.tscn` |

## 읽기 순서

1. 이 파일
2. `docs/design/30-hideout.md` — **§30.10 발주·fit**, **§30.13 그리드+fit (충돌식 폐기)**, **§30.14 이어받기**
3. `docs/design/hideout-building-art.json` — dump 산출 (손으로 고치지 말 것)
4. 프롬프트 전문: **§30.13.3**
5. `CLAUDE.md` 검증 4줄 · GPU 규칙 · 공용 문서 금지

## 확정 결정 (요약)

| 결정 | 내용 |
| --- | --- |
| ★1 시점 | **2:1** (`96×48`), 3:1 폐기. 근거: 배회 후 가림 + 건물 각도 |
| ★10 정합 | **그리드 + fit.** 충돌 자유 배치 폐기. 「스티커」는 충돌안 비유였고 **아트 모드 아님** (오기록 정정) |

## 코드 지도

```
src/core/hideout/     규칙·투영·군중
src/core/nav/         nav_grid + flow_field
src/ui/hideout/       그리기·입력·hideout_screen.tscn
tools/dump_hideout_art_spec.gd
tools/fit_hideout_building_art.py   ← 그리드 발주 캔버스에 맞춤
tools/capture_hideout.gd
test/unit/test_hideout_*.gd · test_iso_projection.gd
```

## 다음 작업 체크리스트

사용자가 이미지 경로를 주면:

- [ ] 원본을 `docs/design/samples/hideout_art/in/` 에 보관
- [ ] `godot --headless --path . -s res://tools/dump_hideout_art_spec.gd`
- [ ] `python tools/fit_hideout_building_art.py <원본> --facility workshop --storeys 1`
- [ ] UI/painter 가 읽는 파일명으로 연결 (`workshop_1l.png` 등)
- [ ] `tools/capture_hideout.gd` 로 배치 확인 (GPU 짧게)
- [ ] GUT + import 검증
- [ ] 이 파일·§30.14 에 캡처 경로·fit 결과 기록

## 하지 말 것

- 그리드 포기 / 충돌식 「스티커」 재설계
- 문서·JSON 에 `art_mode: sticker` 다시 넣기
- `11-decisions` / `ai-usage` / `architecture` 레인 단독 장문 개편
- 다른 레인 워크트리 삭제·머지

## 워킹트리 주의

2:1 전환·dump/fit 문서 정정이 **미커밋**일 수 있다. 착수 시 `git status` / `git diff --stat`.
