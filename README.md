# npr-shaders

> 한국어 설명은 [여기](#korean)를 참고하세요.

A collection of real-time GLSL shaders focused on **NPR (Non-Photorealistic Rendering)** —  
techniques used in stylized games, anime rendering, and technical art pipelines.

Each shader includes a live Shadertoy demo, parameter documentation, and Unity porting notes.

---

## Shaders

| Shader | Style | Shadertoy | Technique |
|---|---|---|---|
| [Cross-Hatching](./crosshatch/) | Pen & ink | [▶ Live](https://www.shadertoy.com/view/7f2GWR) | Luminance-driven hatch layers + value noise |
| [Toon + Rim Light](./toon-rimlight/) | Cel / anime | [▶ Live](#) | Stepped diffuse + hue-shift zones + Fresnel rim |

> More shaders coming soon.

---

## Why NPR

Photorealistic rendering is a solved problem for most engines.  
What's harder — and more interesting for stylized games — is controlling *how* light
is interpreted, not just simulated.

NPR gives artists direct control over tone, outline, and color language.  
These shaders explore that space from a technical art perspective.

---

## Structure

```
npr-shaders/
├── crosshatch/
│   ├── shader.glsl   — Shadertoy source
│   ├── README.md     — technique breakdown + Unity port notes
│   └── preview.gif
└── toon-rimlight/
    ├── shader.glsl
    ├── README.md
    └── preview.gif
```

---

## Unity compatibility

All shaders are written in GLSL (Shadertoy) with HLSL porting notes in each README.  
Tested target: Unity URP / Built-in RP.

---

## License

MIT — use freely in personal or commercial projects.  
Credit appreciated but not required.

---

<a name="korean"></a>
## 한국어 소개

실시간 NPR(비사실적 렌더링) GLSL 셰이더 모음입니다.  
셀 애니메이션, 스타일라이즈드 게임, TA 파이프라인에서 활용되는 기법들을 구현했습니다.

각 셰이더마다 Shadertoy 라이브 데모, 파라미터 설명, Unity 이식 가이드를 포함합니다.

**제작 배경**  
미술 전공 + 컴퓨터공학 전공 경험을 바탕으로, 전통적인 회화/드로잉 기법을 실시간 셰이더로 구현하는 데 초점을 맞췄습니다. TA(Technical Artist)로서 아트와 기술의 접점을 탐구하는 프로젝트입니다.
