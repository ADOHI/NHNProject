"""CC0 원본 효과음을 게임이 쓸 형태로 굽는다 (docs/design/29-sound.md §29.5).

**게임에는 안 들어간다.** 받은 원본을 골라서 다듬는 개발 보조 도구다.
결과물(`assets/audio/sfx/`)만 저장소에 들어간다.

    python tools/build_sfx_library.py --src <원본폴더> [--analyze]

원본은 CC0 세 묶음이다 (§29.9.2). 받은 자리가 아니라 여기서 다시 굽는 이유는 셋이다.

1. **선행 무음을 잘라야 한다.** 천 소리는 앞에 64.7 ms 가 붙어 있어서, 그대로 틀면
   타격 순간보다 65 ms 늦게 난다. 체인 타 간격이 350 ms 인데 그중 19 % 다.
2. **음량이 27.7 dB 벌어져 있다.** 파일마다 녹음 레벨이 달라서 그대로 쓰면
   재질을 바꿀 때마다 음량이 널뛴다. 축(무게)이 정해야 할 것을 파일이 정해 버린다.
3. **샘플레이트를 맞춰야 한다.** 원본이 44100 과 48000 으로 섞여 있다.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

# 대부분의 재질은 11 kHz 위에 에너지가 1 % 도 없어서 22050 으로 충분하다.
# 천만 9.65 % 라 44100 을 준다 — 천 소리의 정체가 바로 그 고역이기 때문이다 (§29.7.9).
DEFAULT_RATE = 22050
CLOTH_RATE = 44100

# 이 값 아래는 무음으로 본다 (피크 대비).
#
# **0.02 는 너무 느슨했다.** 65개 중 19개가 다듬은 뒤에도 10 ms 넘게 늦게 시작했고
# 최악은 84.8 ms 였다. 신호가 2 % 를 넘긴 뒤에도 실제로 들리는 지점까지 한참 걸리는 것 —
# 타격음에서 그건 그대로 "늦게 난다" 로 느껴진다.
#
# 타악기적인 재질은 15 % 에서 자르고, 원래 부드럽게 차오르는 것(천 · 바람 · 음정 신호)은
# 5 % 에서 자른다. 후자에 15 % 를 쓰면 실제 소리의 앞부분을 잘라 먹는다.
PERCUSSIVE_FLOOR = 0.15
SMOOTH_FLOOR = 0.05
SMOOTH_GROUPS = ("cloth", "air", "tone_up", "tone_down")

# **끝은 완전히 다른 문턱으로 자른다.**
#
# 시작과 같은 15 % 를 쓰면 감쇠 꼬리를 통째로 잘라 먹는다 — 실제로 그렇게 당했다.
# 금속 타격이 18.6 ms 로 줄어 무게 4가 무게 1보다 짧아졌다.
# **앞은 "언제 시작하나"(높은 문턱), 뒤는 "언제 안 들리나"(낮은 문턱) 라 서로 다른 질문이다.**
TAIL_FLOOR = 0.004
# 어택을 자르지 않도록 이만큼 앞을 남긴다.
PRE_ROLL_MS = 3.0
# 꼬리를 이만큼 선형으로 죽인다. 자른 자리에 계단이 남으면 "틱" 이 난다.
FADE_OUT_MS = 4.0
# 이보다 긴 것은 자른다. 타격음에 1.3초짜리 꼬리는 필요 없다.
MAX_SECONDS = 1.5

# 재질별로 어떤 원본을 몇 개 쓸지. **무기 13종이 아니라 재질 여섯이다** (§29.9.1).
#
# 무게 1~4 와 변주는 엔진이 계산하므로 (§29.4), 재질당 예닐곱이면 충분하다.
# 더 넣으면 웹 다운로드만 늘고 들리는 것은 안 늘어난다.
# 재질별 · **강도별** 원본. `<재질>/<강도>_NN.wav` 로 나온다.
#
# **2판의 실패가 여기서 나왔다.** 파일 하나를 리샘플로 3배까지 늘여 무게 4를 만들었더니
# "무거운 소리" 가 아니라 **"느리게 튼 소리"** 로 들렸다. 큰 물체가 부딪혀도
# **부딪히는 순간 자체는 순간이다** — 어택은 안 길어지고 감쇠만 길어진다.
#
# 그래서 무게마다 **원래 그 강도로 녹음된 다른 파일**을 쓴다. 리샘플은 계단 사이를
# 메우는 데만 쓴다 (SfxVoice.RESIDUAL_* 로 ±25 % 안쪽).
#
# Kenney Impact 가 light/medium/heavy 로 이미 갈려 있어서 그대로 쓴다.
CURATION: dict[str, dict[str, list[str]]] = {
    "metal": {
        "light": ["impactMetal_light_000", "impactMetal_light_002", "impactPlate_light_000"],
        "medium": ["impactMetal_medium_000", "impactMetal_medium_002", "impactTin_medium_000"],
        "heavy": ["impactMetal_heavy_000", "impactMetal_heavy_002", "impactPlate_heavy_000"],
    },
    "wood": {
        "light": ["impactWood_light_000", "impactWood_light_002", "impactWood_light_004"],
        "medium": ["impactWood_medium_000", "impactWood_medium_002", "impactPlank_medium_000"],
        "heavy": ["impactWood_heavy_000", "impactWood_heavy_002", "sfx100v2_wood_hit_01"],
    },
    "flesh": {
        "light": ["impactSoft_medium_000", "impactSoft_medium_002", "sfx100v2_hit_03"],
        "medium": ["impactPunch_medium_000", "impactPunch_medium_002", "impactPunch_medium_004"],
        "heavy": ["impactPunch_heavy_000", "impactPunch_heavy_002", "impactSoft_heavy_000"],
    },
    "stone": {
        "light": ["sfx100v2_stones_01", "sfx100v2_stones_03"],
        "medium": ["impactMining_000", "impactMining_001", "stones_01"],
        "heavy": ["bfh1_rock_hit_01", "bfh1_rock_breaking_01", "impactMining_003"],
    },
    # 강도별 녹음이 없는 재질은 한 단만 둔다. 나머지는 리샘플과 층 쌓기가 메운다.
    "cloth": {"medium": ["cloth1", "cloth2", "cloth3", "clothBelt", "dropLeather"]},
    "dirt": {
        "medium": [
            "footstep_grass_000", "footstep_grass_002", "footstep_concrete_000",
            "gravel", "mud02",
        ]
    },
    # **저역 몸통 레이어.** 무거울 때 얹는다 — 늘이는 게 아니라 더한다.
    # 무게가 여기 있고, 위의 재질 파일이 어택과 음색을 맡는다.
    "low": {
        "medium": [
            "bfh1_hit_01", "bfh1_hit_05", "bfh1_rock_falling_01",
            "impactSoft_heavy_002", "impactSoft_heavy_004",
        ]
    },
    "air": {"medium": ["sfx100v2_air_01", "sfx100v2_air_02", "sfx100v2_air_03"]},
    "click": {
        "medium": ["click1", "click3", "click5", "rollover1", "rollover3", "mouseclick1", "switch2"]
    },
    # confirmation_001 은 뺐다. 원본 중심이 808 Hz 라 혼자 어둡고, 처리 후 536 Hz 로
    # 전투음(757 Hz) 아래로 깔렸다. **UI 는 전투 위에 있어야 한다** (§29.7.6).
    "tone_up": {"medium": ["confirmation_003", "confirmation_002", "confirmation_004"]},
    "tone_down": {"medium": ["error_002", "error_003", "back_001", "close_001"]},
}

# 어느 묶음에서 왔는지. CREDITS.md 와 §29.9.2 표의 근거가 된다.
ORIGIN = {
    "impact": ("Kenney Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
    "rpg": ("Kenney RPG Audio", "https://kenney.nl/assets/rpg-audio"),
    "kenney_impact-sounds": ("Kenney Impact Sounds", "https://kenney.nl/assets/impact-sounds"),
    "kenney_rpg-audio": ("Kenney RPG Audio", "https://kenney.nl/assets/rpg-audio"),
    "oga2": ("OpenGameArt 100 CC0 SFX #2 (rubberduck)", "https://opengameart.org/content/100-cc0-sfx-2"),
    "kenney_interface-sounds": ("Kenney Interface Sounds", "https://kenney.nl/assets/interface-sounds"),
    "kenney_ui-audio": ("Kenney UI Audio", "https://kenney.nl/assets/ui-audio"),
    "oga_80rpg": ("OpenGameArt 80 CC0 RPG SFX (rubberduck)", "https://opengameart.org/content/80-cc0-rpg-sfx"),
    "oga_breaking": ("OpenGameArt 75 CC0 breaking/falling/hit (rubberduck)", "https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx"),
    "oga_steps": ("OpenGameArt Different steps (kddekadenz)", "https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud"),
}


def find_sources(root: pathlib.Path) -> dict[str, pathlib.Path]:
    """원본 폴더 전체에서 파일 이름 -> 경로 지도를 만든다."""
    found: dict[str, pathlib.Path] = {}
    for path in root.rglob("*.ogg"):
        if "preview" in path.name.lower():
            continue
        found[path.stem] = path
    return found


def origin_of(path: pathlib.Path, root: pathlib.Path) -> tuple[str, str]:
    """어느 묶음에서 왔는지. **부분 문자열로 맞추면 안 된다.**

    실제로 틀렸다 — `oga_80rpg` 가 `"rpg"` 키에 걸려 OpenGameArt 파일 셋이
    Kenney RPG Audio 로 표기됐다. 제출물에서 출처가 틀리는 것은 그 자체가 사고다.
    그래서 **압축을 푼 최상위 폴더 이름과 정확히 일치**할 때만 인정한다.
    """
    try:
        parts = path.relative_to(root).parts
    except ValueError:
        return ("미확인", "")
    if not parts:
        return ("미확인", "")
    return ORIGIN.get(parts[0], ("미확인", ""))


def load_mono(path: pathlib.Path) -> tuple[np.ndarray, int]:
    data, rate = sf.read(str(path), always_2d=True)
    return data.mean(axis=1).astype(np.float64), rate


def trim(samples: np.ndarray, rate: int, floor: float) -> tuple[np.ndarray, float]:
    """앞뒤 무음을 자른다. 잘라 낸 앞 무음의 길이(ms)를 함께 돌려준다."""
    peak = np.abs(samples).max()
    if peak <= 0.0:
        return samples, 0.0
    loud = np.abs(samples) > peak * floor
    if not loud.any():
        return samples, 0.0
    first = int(np.argmax(loud))
    # 끝은 훨씬 낮은 문턱으로 찾는다. 안 그러면 감쇠가 통째로 잘린다.
    audible = np.abs(samples) > peak * TAIL_FLOOR
    last = len(samples) - int(np.argmax(audible[::-1]))
    last = max(last, first + 1)
    removed_ms = 1000.0 * first / rate
    start = max(0, first - int(PRE_ROLL_MS * rate / 1000.0))
    return samples[start:last], removed_ms


def fade_tail(samples: np.ndarray, rate: int) -> np.ndarray:
    count = min(int(FADE_OUT_MS * rate / 1000.0), len(samples))
    if count <= 0:
        return samples
    samples = samples.copy()
    samples[-count:] *= np.linspace(1.0, 0.0, count)
    return samples


def build_one(
    path: pathlib.Path, target_rate: int, root: pathlib.Path, floor: float
) -> tuple[np.ndarray, dict]:
    samples, rate = load_mono(path)
    source_peak = float(np.abs(samples).max())
    samples, removed_ms = trim(samples, rate, floor)

    if rate != target_rate:
        gcd = np.gcd(int(rate), int(target_rate))
        samples = resample_poly(samples, target_rate // gcd, rate // gcd)

    samples = samples[: int(MAX_SECONDS * target_rate)]
    samples = fade_tail(samples, target_rate)

    # 피크를 1.0 으로 맞춘다. 여기서 맞춰 두면 게임 안에서는 SfxCatalog 의 gain 과
    # 무게 축만 음량을 정한다 — 파일이 정하지 않는다.
    peak = np.abs(samples).max()
    if peak > 0.0:
        samples = samples / peak

    return samples, {
        "source": path.name,
        "origin": origin_of(path, root)[0],
        "url": origin_of(path, root)[1],
        "source_rate": rate,
        "source_peak": source_peak,
        "trimmed_ms": removed_ms,
        "seconds": len(samples) / target_rate,
        "rate": target_rate,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True, type=pathlib.Path)
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("assets/audio/sfx"))
    parser.add_argument("--analyze", action="store_true", help="쓰지 않고 숫자만 본다")
    args = parser.parse_args()

    sources = find_sources(args.src)
    if not sources:
        print("원본을 못 찾았다: %s" % args.src)
        return 1

    rows: list[dict] = []
    missing: list[str] = []
    total_bytes = 0

    for group, tiers in CURATION.items():
        rate = CLOTH_RATE if group in ("cloth", "air") else DEFAULT_RATE
        floor = SMOOTH_FLOOR if group in SMOOTH_GROUPS else PERCUSSIVE_FLOOR
        for tier, names in tiers.items():
            index = 0
            for name in names:
                path = sources.get(name)
                if path is None:
                    missing.append(name)
                    continue
                samples, info = build_one(path, rate, args.src, floor)
                info["group"] = group
                info["tier"] = tier
                info["name"] = "%s_%02d" % (tier, index)
                rows.append(info)
                index += 1

                if not args.analyze:
                    out_dir = args.out / group
                    out_dir.mkdir(parents=True, exist_ok=True)
                    out_path = out_dir / ("%s.wav" % info["name"])
                    sf.write(str(out_path), samples, rate, subtype="PCM_16")
                    total_bytes += out_path.stat().st_size

    print("%-10s %-12s %-24s %9s %9s" % ("재질", "이름", "원본", "잘라낸ms", "길이ms"))
    for row in rows:
        print("%-10s %-12s %-24s %9.1f %9.0f" % (
            row["group"], row["name"], row["source"][:24],
            row["trimmed_ms"], row["seconds"] * 1000.0,
        ))

    print("")
    print("파일 %d 개 / %d 묶음" % (len(rows), len(CURATION)))
    print("GDScript 용 COUNTS:")
    for group, tiers in CURATION.items():
        made = {t: sum(1 for r in rows if r["group"] == group and r["tier"] == t) for t in tiers}
        print('	"%s": {%s},' % (
            group, ", ".join('"%s": %d' % (t, n) for t, n in made.items() if n)
        ))
    if missing:
        print("원본에서 못 찾은 것 %d 개: %s" % (len(missing), ", ".join(missing)))
    if not args.analyze:
        print("합계 %.0f KB -> %s" % (total_bytes / 1024.0, args.out))
        write_credits(args.out, rows)
    return 0


def write_credits(out: pathlib.Path, rows: list[dict]) -> None:
    """출처 증빙. 제출물이므로 파일마다 어디서 왔는지 남긴다 (§29.9.5)."""
    lines = [
        "# 효과음 출처",
        "",
        "이 폴더의 모든 파일은 **CC0 (퍼블릭 도메인)** 이다. **저작자 표시 의무가 없다.**",
        "아래 표는 의무가 아니라 **제출물의 증빙**으로 남긴다.",
        "",
        "원본을 그대로 두지 않고 `tools/build_sfx_library.py` 로 다시 구웠다 —",
        "선행 무음 제거 · 피크 정규화 · 샘플레이트 통일. 근거는 `docs/design/29-sound.md` §29.7.9.",
        "",
        "| 파일 | 원본 | 출처 | 라이선스 |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append("| `%s/%s.wav` | `%s` | [%s](%s) | CC0 |" % (
            row["group"], row["name"], row["source"], row["origin"], row["url"],
        ))
    lines += [
        "",
        "## 원본 묶음",
        "",
        "| 묶음 | URL | 라이선스 | 표시 의무 | 받은 날 |",
        "| --- | --- | --- | --- | --- |",
        "| Kenney Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 1.0 | **없음** | 2026-08-09 |",
        "| Kenney RPG Audio | https://kenney.nl/assets/rpg-audio | CC0 1.0 | **없음** | 2026-08-09 |",
        "| OpenGameArt 100 CC0 SFX #2 | https://opengameart.org/content/100-cc0-sfx-2 | CC0 1.0 | **없음** | 2026-08-09 |",
        "",
        "Kenney 두 묶음은 zip 안의 `License.txt` 원문에 "
        "`License: (Creative Commons Zero, CC0)` 와 표시가 필수가 아니라는 문장이 들어 있다.",
        "OGA 묶음은 작품 페이지의 `License(s): CC0` 표기로 확인했다 (작성자 rubberduck).",
    ]
    (out / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
