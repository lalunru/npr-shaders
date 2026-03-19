/*
  Real-Time Cross-Hatching Shader
  ================================
  Pen-and-ink hatching driven by surface luminance.
  4 hatch layers accumulate in shadow, clean paper in light.

  Author: lalunru | License: MIT
*/

#define LINE_FREQ   60.0
#define LINE_WIDTH  0.45
#define NOISE_AMP   0.015
#define PAPER_COLOR vec3(0.96, 0.94, 0.88)
#define INK_COLOR   vec3(0.10, 0.09, 0.08)

mat2 rot2(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i),             hash21(i + vec2(1,0)), u.x),
        mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x),
        u.y);
}

// one hatch family: returns 0.0=ink line, 1.0=paper gap
float hatchLayer(vec2 uv, float angle) {
    vec2 ruv = rot2(angle) * uv;
    float w  = NOISE_AMP * (vnoise(uv * 4.0) - 0.5);
    float s  = fract((ruv.y + w) * LINE_FREQ);
    float fw = fwidth(ruv.y * LINE_FREQ) * 1.5;
    return smoothstep(0.0, fw, s) * smoothstep(0.0, fw, 1.0 - s) +
           smoothstep(LINE_WIDTH, LINE_WIDTH + fw, s) *
           (1.0 - smoothstep(1.0 - LINE_WIDTH - fw, 1.0 - LINE_WIDTH, s));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // normalized coords, y-up
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 col = PAPER_COLOR;

    // ── Ray vs sphere (radius 0.42, centered) ──────────────
    vec3 ro = vec3(0.0, 0.0, 2.0);
    vec3 rd = normalize(vec3(uv, -1.0));
    float R  = 0.42;

    float b   = dot(ro, rd);
    float det = b*b - dot(ro,ro) + R*R;

    if (det >= 0.0) {
        float t   = -b - sqrt(det);
        vec3  pos = ro + t * rd;
        vec3  nor = normalize(pos);          // sphere normal = pos/R

        // rotating key light
        float lt  = iTime * 0.6;
        vec3  lgt = normalize(vec3(cos(lt), 0.45, sin(lt)));

        float diff    = max(dot(nor, lgt), 0.0);
        float ambient = 0.06;
        float rim     = pow(1.0 - max(dot(-rd, nor), 0.0), 4.0) * 0.12;
        float lum     = clamp(ambient + diff + rim, 0.0, 1.0);

        // screen-space UV for hatching (scale keeps lines consistent)
        vec2 suv = fragCoord / iResolution.y;

        // 4 rotated hatch layers, each activated at a darker threshold
        float h0 = hatchLayer(suv, 0.0);
        float h1 = hatchLayer(suv, 0.7854);   // 45°
        float h2 = hatchLayer(suv, 1.5708);   // 90°
        float h3 = hatchLayer(suv, 2.3562);   // 135°

        float t0 = smoothstep(0.70, 0.55, lum);
        float t1 = smoothstep(0.50, 0.35, lum);
        float t2 = smoothstep(0.32, 0.20, lum);
        float t3 = smoothstep(0.20, 0.10, lum);

        float paper = 1.0;
        paper = min(paper, mix(1.0, h0, t0));
        paper = min(paper, mix(1.0, h1, t1));
        paper = min(paper, mix(1.0, h2, t2));
        paper = min(paper, mix(1.0, h3, t3));

        // paper grain
        paper += (vnoise(suv * 220.0) - 0.5) * 0.018;
        paper  = clamp(paper, 0.0, 1.0);

        col = mix(INK_COLOR, PAPER_COLOR, paper);

        // hard silhouette stroke
        float edge = pow(1.0 - max(dot(-rd, nor), 0.0), 8.0);
        col = mix(col, INK_COLOR, smoothstep(0.3, 1.0, edge));
    }

    // light vignette
    col *= 1.0 - 0.35 * dot(uv * 1.1, uv * 1.1);

    fragColor = vec4(col, 1.0);
}
