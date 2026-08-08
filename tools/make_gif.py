"""캡처한 연속 프레임을 GIF 한 장으로 묶는다.

    python tools/make_gif.py .renders/slam .renders/slam.gif

「톡톡 튀는가」는 정지 화면으로 판단할 수 없어서 견본은 늘 움직이는 형태로 낸다.
엔진 안에서 팔레트를 짜지 않고 여기서 묶는 이유는, 실패해도 프레임이 남아
다시 띄우지 않아도 되기 때문이다 (gl_compatibility 라 창을 띄울 때마다
GL 컨텍스트를 새로 만들고, 그 반복이 드라이버를 흔든 전례가 있다).
"""

import glob
import os
import sys

from PIL import Image

FPS = 25


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: make_gif.py <프레임 앞머리> <내보낼 gif> [배율]")
        return 2
    prefix, out = sys.argv[1], sys.argv[2]
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0

    names = sorted(glob.glob(f"{prefix}_f*.png"))
    if not names:
        print(f"프레임이 없다: {prefix}_f*.png")
        return 1

    frames = []
    for name in names:
        img = Image.open(name).convert("RGB")
        if scale != 1.0:
            img = img.resize(
                (round(img.width * scale), round(img.height * scale)), Image.LANCZOS
            )
        # 색이 몇 개 안 되는 화면이라 팔레트 128 로도 밴딩이 안 보인다.
        frames.append(img.convert("P", palette=Image.ADAPTIVE, colors=128))

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=round(1000 / FPS),
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"{out}  {len(frames)}프레임  {os.path.getsize(out)/1024:.0f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
