# Null Cathedral

> 한국어 설명은 [여기](#korean)를 참고하세요.

**[→ Live Demo on Shadertoy](#)** _(업로드 후 링크 교체)_

![preview](preview.gif)

---

A collapsing recursive megastructure drifting beyond observable space.  
Captured through a corrupted deep-space relay.

---

## Technique

A single-pass raymarcher with no lights, no textures, no mesh.  
All geometry emerges from a repeated space-folding formula — the same
4-line transform iterated until simple shapes become cathedrals.

```
Space fold (xy + xz abs-fold)
        │
        ▼
Slow rotation (iTime-driven, xz + yz axes)
        │
        ▼
Spherical inversion  ×4
        │
        ▼
Sphere SDF  →  distance estimator
```

**Edge detection (Kali method)**  
Normals are computed via finite differences. The Laplacian of those
samples reveals surface discontinuities — rendered as dark ink outlines
without any explicit edge-detection pass.

**Lighting**  
Three-point scheme (key / fill / rim) applied to the fractal normal field,
plus Fresnel rim glow, view-dependent iridescence, and a 5-step soft shadow.

**Post-processing**  
ACES tonemapping → chromatic aberration → VHS scanline glitch →
film grain → vignette → purple tint.

---

## Parameters

| Name | Default | Effect |
|---|---|---|
| `ITER` | 4 | Fold iterations — higher = more detail, slower |
| `SPD` | 0.40 | Camera travel speed |
| `FOLD` | 0.80 | Fold magnitude — controls shape complexity |
| `GLOW` | 0.55 | Fresnel rim glow intensity |
| `FOV` | 1.40 | Field of view |
| `DETAIL` | 0.0006 | Ray hit threshold — lower = sharper, slower |
| `BRIGHTNESS` | 1.15 | Pre-tonemap exposure |
| `SATURATION` | 0.78 | Colour saturation |

---

## How to run

1. [shadertoy.com](https://www.shadertoy.com) → New Shader
2. Paste `shader.glsl` → Alt+Enter
3. Click and drag to rotate the view (iMouse)

No buffers, no textures, no external dependencies.

---

## Porting to Unity (HLSL)

The raymarcher runs entirely in a fragment shader — suitable as a
fullscreen blit in Unity URP via `ScriptableRendererFeature`.

Key substitutions:

| GLSL | HLSL |
|---|---|
| `iTime` | `_Time.y` |
| `iResolution` | `_ScreenParams.xy` |
| `iMouse` | custom `float4` uniform |
| `fragCoord` | `i.pos.xy` |

The `de()` and `formula()` functions translate directly to HLSL with no
structural changes. `tonemapACES()` is framework-agnostic.

---

## References

- Kali — *Fractal Cartoon* (edge detection via normal Laplacian)
- Inigo Quilez — SDF primitives, soft shadows, camera setup
- [iquilezles.org](https://iquilezles.org)

---

## License

MIT — use freely in personal or commercial projects.  
Credit appreciated but not required.

---

<a name="korean"></a>
## 한국어 요약

관측 가능한 우주 너머를 표류하는, 붕괴 중인 재귀적 거대 구조물.  
손상된 심우주 중계기를 통해 포착된 영상.

**핵심 기법**

SDF는 단순한 구체 하나. 공간 접기 변환(`formula()`)을 4회 반복하면서 구조물이 출현합니다. 광원 없이 법선 라플라시안으로 엣지를 검출해 윤곽선을 그리는 Kali 방식을 사용했습니다.

- **조명**: 키/필/림 3점 조명 + 프레넬 림 글로우 + 이리데센스 + 소프트 섀도우
- **포스트 프로세스**: ACES 톤매핑 → 색수차 → VHS 글리치 → 필름 그레인 → 비네팅
- **카메라**: 자동 경로 전진 + iMouse 시점 조작

버퍼/텍스처 없는 단일 패스 셰이더입니다.