"""캡처한 연속 프레임을 GIF 한 장으로 묶는다.

    python tools/make_gif.py .renders/slam .renders/slam.gif
    python tools/make_gif.py .renders/53-mark .renders/53-mark.gif 1.0 2

네 번째 낱말은 **몇 편에 하나씩 쓸 것인가**다(기본 1). 지연을 그만큼 늘리므로
길이는 그대로고 편만 준다.

**줄여야 하는 이유는 파일 크기다.** 브라운관 덮개(phosphor_*.gdshader)가 인터레이스
떨림 · 필름 결 · 먼지를 **매 편 모든 픽셀에** 다시 뿌려서 편 사이에 같은 자리가 없다.
GIF 는 안 바뀐 자리를 건너뛰어 줄이는 형식이라 이 화면에서는 그 이득이 0 이고,
편 수가 그대로 크기가 된다. 배율을 줄이는 것은 잘 안 듣는다 — 잡음의 엔트로피는
픽셀 수에 비례해서 줄지 않는다(실측: 배율 0.6 이 크기를 40% 밖에 못 줄였다).

가만히 있는 것을 재는 판처럼 **한 바퀴가 길어서 편이 백 장을 넘으면** 2 를 준다.
스냅은 원래 한두 편짜리라 10fps 에서도 스냅으로 읽힌다.

「톡톡 튀는가」는 정지 화면으로 판단할 수 없어서 견본은 늘 움직이는 형태로 낸다.
엔진 안에서 팔레트를 짜지 않고 여기서 묶는 이유는, 실패해도 프레임이 남아
다시 띄우지 않아도 되기 때문이다 (gl_compatibility 라 창을 띄울 때마다
GL 컨텍스트를 새로 만들고, 그 반복이 드라이버를 흔든 전례가 있다).
"""

import glob
import os
import sys

from PIL import Image

# 캡처와 같아야 한다. 20fps = GIF 지연 5/100초 (정확히 표현된다).
FPS = 20


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: make_gif.py <프레임 앞머리> <내보낼 gif> [배율] [편 간격]")
        return 2
    prefix, out = sys.argv[1], sys.argv[2]
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    stride = max(1, int(sys.argv[4])) if len(sys.argv) > 4 else 1

    names = sorted(glob.glob(f"{prefix}_f*.png"))[::stride]
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
        duration=round(1000 * stride / FPS),
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"{out}  {len(frames)}프레임  {os.path.getsize(out)/1024:.0f} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
