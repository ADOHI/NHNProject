"""PNG 묶음을 GIF 한 장으로 잇는다.

    python tools/make_gif.py .renders-char-anim/idle --fps 25

`tools/capture_char_anim.gd` 가 남긴 `<prefix>_000.png` … 를 순서대로 읽는다.

**팔레트를 한 벌만 쓴다.** 프레임마다 따로 뽑으면 셀 색이 프레임 사이에서 미세하게
흔들려 평면이 끓어 보인다. 그래서 여러 프레임을 이어 붙인 것에서 팔레트를 한 번 뽑고
전 프레임에 같은 것을 적용한다. 디더링도 끈다 — 셀 그림에 점무늬가 끼면 지저분하다.

**프레임 지연은 10 ms 단위로만 저장된다.** 25 fps(40 ms)가 정확히 떨어지는 이유이고,
24 fps 를 쓰면 41.67 ms 가 40 ms 로 깎여 한 바퀴가 4 % 짧아진다.
"""

import argparse
import pathlib
import sys

from PIL import Image

# 팔레트를 뽑을 때 표본으로 삼는 프레임 수. 셀 색이라 몇 장이면 전 색을 덮는다.
PALETTE_SAMPLES = 6

# 팔레트 색 수. 잉크 윤곽선의 안티에일리어싱까지 담으려면 128 은 있어야 띠가 안 생긴다.
PALETTE_COLORS = 128


def load_frames(prefix: pathlib.Path) -> list[Image.Image]:
    paths = sorted(prefix.parent.glob(f"{prefix.name}_*.png"))
    if not paths:
        sys.exit(f"프레임이 없다: {prefix}_*.png")
    return [Image.open(path).convert("RGB") for path in paths]


def build_palette(frames: list[Image.Image]) -> Image.Image:
    """여러 프레임을 세로로 이어 붙인 것에서 팔레트를 한 번 뽑는다."""
    step = max(1, len(frames) // PALETTE_SAMPLES)
    samples = frames[::step][:PALETTE_SAMPLES]
    width, height = samples[0].size
    strip = Image.new("RGB", (width, height * len(samples)))
    for index, frame in enumerate(samples):
        strip.paste(frame, (0, height * index))
    return strip.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT)


def beside(columns: list[list[Image.Image]]) -> list[Image.Image]:
    """여러 묶음을 나란히 붙인다. 축을 끈 것과 켠 것을 **같은 화면에서** 보려는 것.

    따로 GIF 로 보면 사람은 차이를 기억으로 비교해야 하고, 그러면 미세한 지연과
    비대칭은 그냥 안 보인다. 나란히 놓는 순간 보인다.

    **길이가 다르면 짧은 쪽이 마지막 장에서 기다린다.** 무기 무게처럼 길이 자체가
    비교 대상일 때 잘라 맞추면 그 차이가 통째로 사라진다 — 가벼운 것이 먼저 끝나고
    서서 기다리는 것이 곧 「빠르다」의 표현이다.
    """
    span = max(len(c) for c in columns)
    width, height = columns[0][0].size
    joined = []
    for i in range(span):
        canvas = Image.new("RGB", (width * len(columns), height))
        for column, frames in enumerate(columns):
            canvas.paste(frames[min(i, len(frames) - 1)], (column * width, 0))
        joined.append(canvas)
    return joined


def main() -> None:
    parser = argparse.ArgumentParser(description="PNG 묶음을 GIF 로 잇는다")
    parser.add_argument("prefix", help="캡처 접두사. 예: .renders-char-anim/idle")
    parser.add_argument("--fps", type=int, default=25)
    parser.add_argument("--out", default=None, help="기본값은 <prefix>.gif")
    parser.add_argument(
        "--beside", action="append", default=[], help="나란히 붙일 다른 접두사 (여러 번 줄 수 있다)"
    )
    args = parser.parse_args()

    prefix = pathlib.Path(args.prefix)
    out = pathlib.Path(args.out) if args.out else prefix.with_suffix(".gif")

    delay_ms = round(1000.0 / args.fps)
    if delay_ms % 10 != 0:
        print(f"주의: {args.fps} fps 는 {delay_ms} ms 라 10 ms 격자에 안 맞는다", file=sys.stderr)

    frames = load_frames(prefix)
    if args.beside:
        columns = [frames] + [load_frames(pathlib.Path(p)) for p in args.beside]
        frames = beside(columns)
    palette = build_palette(frames)
    quantized = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]

    quantized[0].save(
        out,
        save_all=True,
        append_images=quantized[1:],
        duration=delay_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )
    seconds = len(frames) * delay_ms / 1000.0
    size_kb = out.stat().st_size / 1024.0
    print(f"{out}  {len(frames)} 장  {seconds:.2f} 초  {size_kb:.0f} KB")


if __name__ == "__main__":
    main()
