/*
  Toon Shading + Rim Light Shader
  ================================
  A cel-shading implementation with:
    - Stepped diffuse lighting (hard tone bands)
    - Fresnel-based rim light (colored, artist-controllable)
    - Ink outline via normal discontinuity in screen space
    - Specular highlight with hard cutoff (anime-style)
    - Subtle color banding per tone zone

  The key insight most toon shaders miss:
    Real anime/cel shading doesn't just posterize brightness —
    each tone zone has a *slightly different hue shift*, not just
    a darker version of the same color. This gives the characteristic
    "painted" warmth in shadows and coolness in highlights.

  Technique:
    - Diffuse: smoothstep-based hard steps instead of linear falloff
    - Rim: pow(1 - NdotV, rimPow) * rimColor, additive
    - Outline: ddx/ddy normal discontinuity → silhouette detection
    - Hue shift: shadow zone shifts toward --SHADOW_HUE,
                 highlight zone shifts toward --HIGHLIGHT_HUE

  Unity port:
    Works as a surface shader with custom lighting model,
    or as a post-process for the outline pass.
    Outline in Unity: compare normals in G-buffer → Roberts cross edge detect.

  Author: lalunru
  License: MIT
*/

// ── ARTIST PARAMETERS ────────────────────────────────────
#define BASE_COLOR      vec3(0.42, 0.62, 0.85)   // main surface color
#define SHADOW_COLOR    vec3(0.18, 0.22, 0.45)   // shadow zone (cool/blue shift)
#define MIDTONE_COLOR   vec3(0.35, 0.50, 0.78)   // mid tone
#define HIGHLIGHT_COLOR vec3(0.88, 0.92, 1.00)   // highlight zone (warm white)
#define RIM_COLOR       vec3(0.95, 0.60, 0.20)   // rim light color (warm orange)
#define OUTLINE_COLOR   vec3(0.08, 0.06, 0.10)   // ink outline
#define SPEC_COLOR      vec3(1.00, 0.98, 0.92)   // specular dot color

#define TONE_BANDS      3.0     // number of diffuse steps
#define RIM_POWER       3.5     // rim light falloff (higher = thinner rim)
#define RIM_STRENGTH    0.75    // rim light intensity
#define SPEC_SIZE       0.97    // specular threshold (higher = smaller dot)
#define SPEC_SMOOTH     0.004   // specular edge softness
#define OUTLINE_THRESH  0.28    // outline detection sensitivity

// ── HELPERS ──────────────────────────────────────────────

// stepped value: posterizes x into n bands with soft edge
float bandStep(float x, float bands, float softness) {
    float s = x * bands;
    return (floor(s) + smoothstep(0.0, softness, fract(s))) / bands;
}

// rotate vec3 around Y axis (for light animation)
vec3 rotY(vec3 v, float a) {
    float c = cos(a), s = sin(a);
    return vec3(c*v.x + s*v.z, v.y, -s*v.x + c*v.z);
}

// ── SDF SCENE ────────────────────────────────────────────
// smooth union of sphere + small bumps for interest
float sdSphere(vec3 p, float r) { return length(p) - r; }

float scene(vec3 p) {
    float s = sdSphere(p, 0.55);
    // subtle surface detail: two small indentations
    float d1 = sdSphere(p - vec3( 0.28, 0.22, 0.42), 0.18);
    float d2 = sdSphere(p - vec3(-0.22, 0.30, 0.40), 0.15);
    // smooth union
    float k = 0.18;
    s = s - k * exp(-max(s,d1)/k);   // smooth min approximation
    s = s - k * exp(-max(s,d2)/k);
    return s;
}

vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.0005, 0.0);
    return normalize(vec3(
        scene(p+e.xyy) - scene(p-e.xyy),
        scene(p+e.yxy) - scene(p-e.yxy),
        scene(p+e.yyx) - scene(p-e.yyx)
    ));
}

float rayMarch(vec3 ro, vec3 rd) {
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        float d = scene(ro + t * rd);
        if (d < 0.001) return t;
        if (t > 6.0)   return -1.0;
        t += d;
    }
    return -1.0;
}

// ── OUTLINE: screen-space normal discontinuity ────────────
float outlineDetect(vec2 fragCoord, vec3 ro, vec3 rd_center) {
    vec2 px = vec2(1.0, 0.0);
    vec2 py = vec2(0.0, 1.0);

    // sample normals at neighbouring pixels
    vec3 rdR = normalize(vec3((fragCoord + px - 0.5*iResolution.xy) / iResolution.y, -1.0));
    vec3 rdU = normalize(vec3((fragCoord + py - 0.5*iResolution.xy) / iResolution.y, -1.0));

    float tC = rayMarch(ro, rd_center);
    float tR = rayMarch(ro, rdR);
    float tU = rayMarch(ro, rdU);

    if (tC < 0.0) return 0.0;

    vec3 nC = calcNormal(ro + tC * rd_center);
    vec3 nR = (tR > 0.0) ? calcNormal(ro + tR * rdR) : vec3(0.0);
    vec3 nU = (tU > 0.0) ? calcNormal(ro + tU * rdU) : vec3(0.0);

    float edge = length(nC - nR) + length(nC - nU);
    return smoothstep(OUTLINE_THRESH, OUTLINE_THRESH + 0.15, edge);
}

// ── MAIN ─────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro = vec3(0.0, 0.0, 2.2);
    vec3 rd = normalize(vec3(uv, -1.0));

    vec3 col = vec3(0.96, 0.96, 0.98); // background: near-white

    float t = rayMarch(ro, rd);

    if (t > 0.0) {
        vec3 pos = ro + t * rd;
        vec3 nor = calcNormal(pos);
        vec3 vdir = -rd;  // view direction

        // animated key light
        vec3 lgt = normalize(rotY(vec3(0.6, 0.7, 1.0), iTime * 0.5));

        float NdotL = dot(nor, lgt);
        float NdotV = dot(nor, vdir);

        // ── Stepped diffuse ──
        float diff = clamp(NdotL * 0.5 + 0.5, 0.0, 1.0); // half-lambert
        float stepped = bandStep(diff, TONE_BANDS, 1.8);

        // tone-zone color mixing (hue shift per band)
        vec3 surfaceCol;
        if (stepped < 0.35) {
            surfaceCol = SHADOW_COLOR;
        } else if (stepped < 0.68) {
            float f = smoothstep(0.35, 0.68, stepped);
            surfaceCol = mix(SHADOW_COLOR, MIDTONE_COLOR, f);
        } else {
            float f = smoothstep(0.68, 1.0, stepped);
            surfaceCol = mix(MIDTONE_COLOR, HIGHLIGHT_COLOR, f);
        }

        // ── Rim light ──
        float rim = pow(1.0 - clamp(NdotV, 0.0, 1.0), RIM_POWER);
        // only on light-facing hemisphere
        rim *= smoothstep(-0.1, 0.4, NdotL);
        vec3 rimContrib = rim * RIM_STRENGTH * RIM_COLOR;

        // ── Specular (hard anime dot) ──
        vec3 hdir = normalize(lgt + vdir);
        float spec = dot(nor, hdir);
        float specMask = smoothstep(SPEC_SIZE - SPEC_SMOOTH,
                                    SPEC_SIZE + SPEC_SMOOTH, spec);
        vec3 specContrib = specMask * SPEC_COLOR;

        col = surfaceCol + rimContrib + specContrib;

        // ── Outline ──
        float outline = outlineDetect(fragCoord, ro, rd);
        col = mix(col, OUTLINE_COLOR, outline);
    }

    // background gradient (subtle)
    col = mix(col, vec3(0.88, 0.90, 0.96), (1.0 - float(t > 0.0)) * (0.4 + 0.6 * uv.y));

    // vignette
    col *= 1.0 - 0.25 * dot(uv * 0.9, uv * 0.9);

    fragColor = vec4(col, 1.0);
}
