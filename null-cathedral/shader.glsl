/*
  Null Cathedral
  ============================
  Author: lalunru
*/

// ── PARAMETERS ────────────────────────────────────────────
#define ITER       4 
#define RAY_STEPS  160
#define DETAIL     0.0006
#define MAXD       65.0

#define BRIGHTNESS 1.15
#define SATURATION 0.78

#define SPD        0.40    
#define FOLD       0.80  
#define GLOW       0.55   
#define FOV        1.40     

#define t (iTime * SPD)
#define PI  3.14159265
#define TAU 6.28318530

// ── 유틸 ──────────────────────────────────────────────────
mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

// ── 프랙탈 변환 ───────────────────────────────────────────
vec4 formula(vec4 p) {
    float f = FOLD;

    p.xy = abs(p.xy + f) - abs(p.xy - f) - p.xy;
    p.xz = abs(p.xz + f * 0.6) - abs(p.xz - f * 0.6) - p.xz;

    p.xz *= rot(0.28 + sin(t * 0.20) * 0.18);
    p.yz *= rot(0.12 + cos(t * 0.15) * 0.12);

    p.y -= 0.22;

    float d2 = dot(p.xyz, p.xyz);
    p *= 2.6 / clamp(d2, 0.25, 0.90);

    return p;
}

// ── DISTANCE ESTIMATOR ────────────────────────────────────
float de(vec3 pos) {
    vec3 tp = pos;
    tp.z = abs(3.5 - mod(tp.z, 7.0));

    vec4 p = vec4(tp, 1.0);
    for (int i = 0; i < ITER; i++) {
        p = formula(p);
    }

    float sphere = (length(p.xyz) - 1.15) / p.w;

    float cyl = length(pos.xy) - 2.8;

    float flr = abs(pos.y + 1.85) - 0.005;
    float cel = abs(pos.y - 2.25) - 0.005;

    return min(sphere, min(min(flr, cel), -cyl * 0.3));
}

// ── 소프트 섀도우 (5-step) ────────────────────────────────
float softShadow(vec3 ro, vec3 rd, float mint, float k) {
    float res = 1.0, ph = 1e10;
    for (int i = 0; i < 5; i++) {
        float h = de(ro + rd * (mint + float(i) * 0.4));
        float y = h * h / (2.0 * ph);
        float d = sqrt(h * h - y * y);
        res = min(res, k * d / (mint + float(i) * 0.4 - y));
        ph = h;
    }
    return clamp(res, 0.0, 1.0);
}

// ── 엣지 검출 + 법선 ──────────────────────────────────────
float gEdge = 0.0;

vec3 calcNormal(vec3 p, float totDist) {
    float eps = DETAIL * 7.0 * (1.0 + totDist * 0.05);
    vec3 e = vec3(eps, 0.0, 0.0);

    float d  = de(p);
    float d1 = de(p - e.xyy), d2 = de(p + e.xyy);
    float d3 = de(p - e.yxy), d4 = de(p + e.yxy);
    float d5 = de(p - e.yyx), d6 = de(p + e.yyx);

    float lap = abs(d - 0.5*(d1+d2))
              + abs(d - 0.5*(d3+d4))
              + abs(d - 0.5*(d5+d6));
    gEdge = min(1.0, pow(lap, 0.45) * 28.0);

    return normalize(vec3(d1-d2, d3-d4, d5-d6));
}

// ── 색상 ──────────────────────────────────────────────────
vec3 colorize(vec3 norm, vec3 pos, vec3 rd, float totDist) {
    vec3 Lkey = normalize(vec3( 0.6,  0.7, -0.4)); 
    vec3 Lfil = normalize(vec3(-0.5,  0.3,  0.6));  
    vec3 Lrim = normalize(vec3( 0.1, -0.8,  0.5)); 

    float dkey = max(0.0, dot(norm,  Lkey));
    float dfil = max(0.0, dot(norm, -Lfil)); 
    float drim = max(0.0, dot(norm,  Lrim));

    vec3 cKey = vec3(0.85, 0.90, 0.85) * dkey;
    vec3 cFil = vec3(0.60, 0.50, 0.45) * dfil * 0.6;
    vec3 cRim = vec3(0.40, 0.60, 0.65) * pow(drim, 2.5) * 1.0;

    vec3 col = cKey + cFil + cRim;

    float irid = sin(dot(norm, rd) * PI * 5.0 + pos.z * 0.4 + t * 0.7) * 0.5 + 0.5;
    vec3 sheen = mix(vec3(0.3, 0.1, 0.6), vec3(0.1, 0.6, 0.7), irid) * 0.28;
    col += sheen;

    float spec = pow(max(0.0, dot(norm, normalize(Lkey - rd))), 12.0);
    col += vec3(0.8, 0.6, 1.0) * spec * 0.5;

    col *= 1.0 - gEdge * 0.88;

    float fres = pow(1.0 - abs(dot(norm, -rd)), 3.5);
    col += vec3(0.6, 0.2, 1.0) * fres * GLOW * 0.9;

    float hd = sin(pos.z * 0.25 + t * 0.4) * 0.5 + 0.5;
    col = mix(col, col.zxy * 1.1, hd * 0.3);

    float fog = exp2(-totDist * 0.028);
    vec3 fogCol = vec3(0.15, 0.12, 0.18);
    col = mix(fogCol, col, fog);

    return col;
}

// ── 배경 ──────────────────────────────────────────────────
vec3 background(vec3 rd) {
    float up = rd.y * 0.5 + 0.5;
    vec3 bg = mix(
        mix(vec3(0.08, 0.02, 0.16), vec3(0.02, 0.01, 0.06), smoothstep(0.0, 0.5, up)),
        vec3(0.00, 0.00, 0.02),
        smoothstep(0.5, 1.0, up)
    );

    vec2 uv2 = vec2(atan(rd.z, rd.x) / TAU, asin(rd.y) / PI) * 200.0;
    vec2 id  = floor(uv2);
    vec2 fr  = fract(uv2) - 0.5;
    float h  = fract(sin(dot(id, vec2(127.1, 311.7))) * 43758.5);
    float star = smoothstep(0.48, 0.5, 1.0 - length(fr)) * (h > 0.94 ? 1.0 : 0.0);
    bg += vec3(0.9, 0.8, 1.0) * star * 0.7;

    bg += vec3(0.10, 0.04, 0.20) * pow(max(-rd.z, 0.0), 3.0);

    return bg;
}

// ── 카메라 경로 ───────────────────────────────────────────
vec3 camPath(float s) {
    return vec3(
        sin(s * 0.22) * 0.5 + cos(s * 0.31) * 0.2,
        sin(s * 0.18) * 0.22,
        -s * 3.2
    );
}

// ── ACES 톤매핑 ───────────────────────────────────────────
vec3 tonemapACES(vec3 x) {
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// ── 레이마칭 ──────────────────────────────────────────────
vec3 raymarch(vec3 ro, vec3 rd) {
    float totDist = 0.0;

    for (int i = 0; i < RAY_STEPS; i++) {
        vec3 p = ro + rd * totDist;
        float d = de(p);
        float det = DETAIL * exp(0.10 * totDist);
        if (d < det || totDist > MAXD) break;
        totDist += d * 0.70;
    }

    vec3 col = background(rd);
    totDist = clamp(totDist, 0.0, MAXD + 1.0);

    if (totDist < MAXD) {
        vec3 p    = ro + rd * totDist;
        vec3 norm = calcNormal(p, totDist);

        vec3 Lkey = normalize(vec3(0.6, 0.7, -0.4));
        float sh  = softShadow(p, Lkey, 0.04, 6.0);

        col = colorize(norm, p, rd, totDist);
        col *= 0.6 + 0.4 * sh;
    }

    return col;
}

// ── POST-PROCESS ──────────────────────────────────────────
vec3 chromAberr(vec3 col, vec2 uv, float str) {
    vec2 d = (uv - 0.5);
    float a = dot(d, d) * str;
    col.r = mix(col.r, col.r * (1.0 + a * 0.9) - col.g * a * 0.4, 1.0);
    col.b = mix(col.b, col.b * (1.0 + a * 0.7) - col.g * a * 0.3, 1.0);
    return col;
}

// ── MAIN ──────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv  = fragCoord / iResolution.xy;
    vec2 ndc = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 ro  = camPath(t);
    vec3 ro2 = camPath(t + 0.05);
    vec3 fw  = normalize(ro2 - ro);
    vec3 rt  = normalize(cross(fw, vec3(0, 1, 0)));
    vec3 up  = cross(rt, fw);
    vec3 rd  = normalize(ndc.x * rt + ndc.y * up + FOV * fw);

    if (iMouse.z > 0.0) {
        vec2 m = (iMouse.xy / iResolution.xy - 0.5) * 2.0;
        rd.xz *= rot(m.x * 1.1);
        rd.yz *= rot(-m.y * 0.7);
    }

    vec3 col  = raymarch(ro, rd);
    vec2 off  = vec2(0.5) / iResolution.xy;
    vec3 col2 = raymarch(ro, normalize((ndc + off).x * rt + (ndc + off).y * up + FOV * fw));
    col = (col + col2) * 0.5;

    col = tonemapACES(col * BRIGHTNESS);

    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(lum), col, SATURATION);

    col = chromAberr(col, uv, 0.032);

    float line = floor(uv.y * iResolution.y);
    float jit  = fract(sin(line * 127.1 + iTime * 31.7) * 43758.5) * 2.0 - 1.0;
    float g1   = step(0.992, fract(sin(iTime * 7.3 + line * 0.001) * 9999.0));
    col.r     += jit * 0.005 * g1;

    col *= 0.97 + 0.03 * sin(uv.y * iResolution.y * PI);

    float grain = (fract(sin(dot(uv * 1400.0 + iTime,
                  vec2(12.9898, 78.233))) * 43758.5) - 0.5) * 0.018;
    col += grain;

    vec2 vig = uv - 0.5;
    col *= smoothstep(0.0, 1.0, 1.0 - dot(vig, vig) * 2.6);

    col = mix(col, col * vec3(0.80, 0.74, 1.12), 0.20);

    fragColor = vec4(max(col, 0.0), 1.0);
}