#version 100

//_DEFINES_

#if defined(EXTERNAL)
#extension GL_OES_EGL_image_external : require
#endif

precision highp float;
#if defined(EXTERNAL)
uniform samplerExternalOES tex;
#else
uniform sampler2D tex;
#endif

uniform float alpha;
varying vec2 v_coords;

#if defined(DEBUG_FLAGS)
uniform float tint;
#endif

uniform float niri_scale;

uniform vec2 geo_size;
uniform vec4 corner_radius;
uniform mat3 input_to_geo;

// Liquid glass uniforms
uniform float lg_refraction_strength;
uniform float lg_power_factor;
uniform float lg_refraction_a;
uniform float lg_refraction_b;
uniform float lg_refraction_c;
uniform float lg_refraction_d;
uniform float lg_refraction_power;
uniform float lg_glow_weight;
uniform float lg_glow_bias;
uniform float lg_glow_edge0;
uniform float lg_glow_edge1;
uniform float lg_edge_lighting;
uniform float lg_fringing;
// Refraction mode: >= 0.0 = Snell's Law optical refraction (matching kwin-effects-glass / dolphin.png)
//                  < 0.0  = 2D gradient push
uniform float lg_physical_refraction;
// Dilute refraction
uniform float lg_refraction_dilute;
uniform float lg_dilute_strength;
uniform float lg_dilute_fringing;
// Glass tint and lens uniforms
uniform float lg_lens_distortion;
uniform float lg_brightness;
uniform float lg_contrast;
uniform float lg_saturation;
uniform float lg_vibrancy;
uniform float lg_adaptive_dim;
uniform float lg_adaptive_boost;
uniform float lg_edge_thickness;
uniform float lg_padding_pixels;

float niri_rounding_alpha(vec2 coords, vec2 size, vec4 corner_radius);
vec4 postprocess(vec4 color);
vec2 refractionDir(vec2 uv);

// ============================================================================
// Liquid Glass effect -- Physically-based Snell's Law Refraction
// Inspired by kwin-effects-glass (https://github.com/4v3ngR/kwin-effects-glass)
// ============================================================================

struct GlassFragment {
    vec4 color;
    float dist;
    float edgeFactor;
    float concaveFactor;
    vec3 normal;
    float ior;
};

// Rounded-rect Signed Distance Function (SDF)
// corner_radius: x=top-left, y=top-right, z=bottom-right, w=bottom-left
// p: relative to center in pixel coords.
// Convention: p.y > 0 is TOP, p.y < 0 is BOTTOM, p.x < 0 is LEFT, p.x > 0 is RIGHT.
float roundedRectangleDist(vec2 p, vec2 b, vec4 r)
{
    float radius = p.x > 0.0
        ? (p.y > 0.0 ? r.y : r.z)   // Right: Top-Right (r.y), Bottom-Right (r.z)
        : (p.y > 0.0 ? r.x : r.w);  // Left: Top-Left (r.x), Bottom-Left (r.w)
    vec2 q = abs(p) - b + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Snell's Law Optical Refraction -- Faithful port of kwin-effects-glass snells-glass.glsl
// Models accurate light refraction through curved dielectric glass using refract()
GlassFragment snellsRefraction(
    vec2 uv_tex,
    vec2 uv_min,
    vec2 uv_max,
    vec2 position,
    vec2 halfSize,
    vec4 cornerRadius,
    float minHalfSize,
    float dist,
    float edgeFactor,
    float concaveFactor,
    float refractionStrength,
    float refractionBevelIntensity,
    float refractionOffsetStrength,
    float refractionRGBFringing
) {
    float bandWidth = max(minHalfSize * lg_edge_thickness, 8.0 * niri_scale);
    float ior = 1.0 + clamp(refractionStrength * 0.45, 0.05, 1.8);

    // Compute smooth surface normal from SDF finite difference
    float minR = max(min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w)), 2.0);
    float eps = clamp(min(bandWidth * 0.4, minR * 0.5), 1.0, 6.0);
    float dxp = roundedRectangleDist(position + vec2(eps, 0.0), halfSize, cornerRadius);
    float dxn = roundedRectangleDist(position - vec2(eps, 0.0), halfSize, cornerRadius);
    float dyp = roundedRectangleDist(position + vec2(0.0, eps), halfSize, cornerRadius);
    float dyn = roundedRectangleDist(position - vec2(0.0, eps), halfSize, cornerRadius);

    vec2 smoothGrad = vec2(dxp - dxn, dyp - dyn);
    float gradLen = length(smoothGrad);

    // 3D Glass Surface Normal (curved bevel)
    float normalHeight = concaveFactor * max(refractionBevelIntensity, 0.25);
    vec2 normalXY = gradLen > 0.001 ? (smoothGrad / gradLen) * normalHeight : vec2(0.0);
    vec3 glassNormal = normalize(vec3(normalXY, 1.0));

    // Snell's law refraction ray
    vec3 viewRay = vec3(0.0, 0.0, -1.0);
    vec3 refractRay = refract(viewRay, glassNormal, 1.0 / ior);
    vec2 refractDir = length(refractRay.xy) > 0.001 ? normalize(refractRay.xy) : vec2(0.0);

    // Lens magnitude and optical displacement in UV space
    vec2 uvScale = 1.0 / (halfSize * 2.0);
    float lensMagnitude = concaveFactor * bandWidth * refractionBevelIntensity;
    float maxShiftPx = minHalfSize * 0.20;
    float shiftPx = min(lensMagnitude * refractionStrength, maxShiftPx);

    // Corner optical weighting
    vec2 surfaceNormal = gradLen > 0.001 ? (smoothGrad / gradLen) : vec2(0.0);
    vec2 normalizedPos = position / (halfSize * 2.0);
    float cornerWeight = dot(normalizedPos, normalizedPos) * refractionOffsetStrength;
    surfaceNormal += normalizedPos * concaveFactor * cornerWeight;

    // Convert shift to UV coordinates
    // In position space: +Y is UP. In UV space: +Y is DOWN. Therefore shift.y is inverted.
    vec2 baseShift = (-surfaceNormal * lensMagnitude * 0.35 + refractDir * shiftPx) * uvScale;
    baseShift.y = -baseShift.y;

    float fringing = clamp(refractionRGBFringing, 0.0, 1.0) * 0.35;
    vec4 color = vec4(0.0);

    // 3-channel chromatic dispersion (prism refraction at glass bevel)
    if (fringing > 0.001 && concaveFactor > 0.01) {
        vec2 uvG = clamp(uv_tex + baseShift, uv_min, uv_max);
        vec2 uvR = clamp(uv_tex + baseShift * (1.0 + fringing), uv_min, uv_max);
        vec2 uvB = clamp(uv_tex + baseShift * (1.0 - fringing), uv_min, uv_max);

        color.g = texture2D(tex, uvG).g;
        color.a = texture2D(tex, uvG).a;
        color.r = texture2D(tex, uvR).r;
        color.b = texture2D(tex, uvB).b;
    } else {
        vec2 uvSample = clamp(uv_tex + baseShift, uv_min, uv_max);
        color = texture2D(tex, uvSample);
    }

    return GlassFragment(color, dist, edgeFactor, concaveFactor, glassNormal, ior);
}

// Classical 2D Gradient Refraction
GlassFragment glassRefraction(
    vec2 uv_tex,
    vec2 uv_min,
    vec2 uv_max,
    vec2 position,
    vec2 halfBlurSize,
    vec4 cornerRadius,
    float dist,
    float edgeFactor,
    float concaveFactor,
    float refractionStrength,
    float refractionRGBFringing
) {
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);
    float bezelWidthPx = max(minHalfSize * lg_edge_thickness, 8.0 * niri_scale);
    float edgeProximity = exp(dist / bezelWidthPx);
    vec2 uvScale = 1.0 / (halfBlurSize * 2.0);
    float fringingFactor = refractionRGBFringing * 0.35;

    float minR = max(min(min(cornerRadius.x, cornerRadius.y), min(cornerRadius.z, cornerRadius.w)), 2.0);
    float h = clamp(minR * 0.25, 1.0, 4.0);
    vec2 gradient = vec2(
        roundedRectangleDist(position + vec2(h, 0.0), halfBlurSize, cornerRadius) - roundedRectangleDist(position - vec2(h, 0.0), halfBlurSize, cornerRadius),
        roundedRectangleDist(position + vec2(0.0, h), halfBlurSize, cornerRadius) - roundedRectangleDist(position - vec2(0.0, h), halfBlurSize, cornerRadius)
    );
    vec2 normal = length(gradient) > 0.0 ? -normalize(gradient) : vec2(0.0, 1.0);
    float strength = min(0.4 * concaveFactor * refractionStrength, 1.0);
    vec2 offset = normal * strength * (minHalfSize * 0.15) * uvScale;

    // Fix Y-axis
    offset.y = -offset.y;

    vec3 glassNormal = normalize(vec3(normal * concaveFactor, 1.0));

    vec2 coordG = clamp(uv_tex + offset, uv_min, uv_max);
    vec4 color;
    if (fringingFactor > 0.001 && concaveFactor > 0.01) {
        vec2 coordR = clamp(uv_tex + offset * (1.0 + fringingFactor), uv_min, uv_max);
        vec2 coordB = clamp(uv_tex + offset * (1.0 - fringingFactor), uv_min, uv_max);
        color = vec4(texture2D(tex, coordR).r, texture2D(tex, coordG).g, texture2D(tex, coordB).b, texture2D(tex, coordG).a);
    } else {
        color = texture2D(tex, coordG);
    }

    return GlassFragment(color, dist, edgeFactor, concaveFactor, glassNormal, 1.0);
}

// Dilute Refraction
GlassFragment diluteRefraction(
    vec2 uv_tex,
    vec2 uv_min,
    vec2 uv_max,
    vec2 position,
    vec2 halfBlurSize,
    float dist,
    float edgeFactor,
    float concaveFactor,
    float refractionStrength,
    float refractionRGBFringing,
    float intensity
) {
    vec2 toCenter = -position;
    float lenToCenter = length(toCenter);
    vec2 dirIn = lenToCenter > 0.001 ? toCenter / lenToCenter : vec2(0.0);
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);
    float maxOffsetPixels = minHalfSize * 0.06 * intensity;
    float magnitudePixels = concaveFactor * clamp(refractionStrength, 0.0, 1.0) * maxOffsetPixels;
    vec2 uvScale = 1.0 / (halfBlurSize * 2.0);
    vec2 offset = dirIn * magnitudePixels * uvScale;

    offset.y = -offset.y;
    vec2 c0 = clamp(uv_tex + offset * 0.25, uv_min, uv_max);
    vec2 c1 = clamp(uv_tex + offset * 0.50, uv_min, uv_max);
    vec2 c2 = clamp(uv_tex + offset * 0.75, uv_min, uv_max);
    vec2 c3 = clamp(uv_tex + offset * 1.00, uv_min, uv_max);
    vec4 avg = (texture2D(tex, c0) + texture2D(tex, c1) + texture2D(tex, c2) + texture2D(tex, c3)) * 0.25;
    vec4 color;
    if (refractionRGBFringing > 0.001) {
        float fringe = clamp(refractionRGBFringing, 0.0, 1.0) * 0.3;
        vec2 coordR = clamp(uv_tex + offset * (1.0 + fringe), uv_min, uv_max);
        vec2 coordB = clamp(uv_tex + offset * (1.0 - fringe), uv_min, uv_max);
        color = vec4(texture2D(tex, coordR).r, avg.g, texture2D(tex, coordB).b, avg.a);
    } else {
        color = avg;
    }
    return GlassFragment(color, dist, edgeFactor, concaveFactor, vec3(0.0, 0.0, 1.0), 1.0);
}

// Center-directed vector
vec2 refractionDir(vec2 uv) {
    vec2 toCenterPx = (vec2(0.5) - uv) * geo_size;
    float len = length(toCenterPx);
    return len > 0.1 ? toCenterPx / len : vec2(0.0);
}

// Center dome barrel lens distortion
vec2 applyDomeLens(vec2 uv, float lensDistortion, float edgeProximity) {
    if (lensDistortion < 0.001) {
        return vec2(0.0, 0.0);
    }

    vec2 c = (uv - 0.5) * 2.0;
    vec2 dGrad = vec2(
        -4.0 * c.x * (1.0 - c.y * c.y),
        -4.0 * c.y * (1.0 - c.x * c.x)
    );

    float minDim = min(geo_size.x, geo_size.y);
    float lensMaxPx = lensDistortion * minDim * 0.06;
    float lensFade = 1.0 - edgeProximity;

    return dGrad * lensMaxPx * lensFade / geo_size;
}

// Frosted tint with adaptive luminance
vec3 applyFrostedTint(vec3 color, float edgeProximity) {
    // Saturation
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = clamp(mix(vec3(lum), color, lg_saturation), 0.0, 1.0);

    // Brightness
    color *= clamp(lg_brightness, 0.0, 1.0);

    // Adaptive dim (darkens bright areas)
    if (lg_adaptive_dim > 0.001) {
        float dimFactor = smoothstep(0.3, 0.8, lum);
        color *= 1.0 - lg_adaptive_dim * dimFactor;
    }

    // Adaptive boost (lightens dark areas)
    if (lg_adaptive_boost > 0.001) {
        float boostFactor = 1.0 - smoothstep(0.0, 0.5, lum);
        color += vec3(lg_adaptive_boost * boostFactor * 0.15);
    }

    color = clamp(color, 0.0, 1.0);

    // Contrast
    color = clamp(mix(vec3(0.5), color, lg_contrast), 0.0, 1.0);

    // Vibrancy
    if (lg_vibrancy > 0.001) {
        float currentLum = dot(color, vec3(0.2126, 0.7152, 0.0722));
        float sat = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
        color = clamp(mix(vec3(currentLum), color, 1.0 + lg_vibrancy * sat), 0.0, 1.0);
    }

    return color;
}

// Glass border rim lighting, specular highlight, and natural bevel reflection
// Mathematically smooth monotonically increasing curves prevent pixel/edge glitches.
vec3 glassOutline(vec2 position, vec2 blurSize, GlassFragment s, float glowStrength, float edgeLighting, float edgeProximity)
{
    vec3 col = s.color.rgb;

    // 1. Natural edge lighting from refracted wallpaper
    if (edgeLighting > 0.001) {
        col += s.color.rgb * s.concaveFactor * edgeLighting * 0.45;
    }

    // 2. Subpixel-smooth rim specular highlight (light catching the beveled glass edge)
    // s.dist <= 0 inside the window. d = -s.dist is distance inside the edge in pixels.
    float d = max(-s.dist, 0.0);
    // Smooth peak around 1.0px inside the edge, softly fading away by 3.2px
    float rimProfile = smoothstep(0.0, 1.0, d) * (1.0 - smoothstep(1.0, 3.2, d));

    if (glowStrength > 0.001) {
        // Specular glow along rim (monotonically smoothed, avoiding driver glitch bugs)
        col = mix(col, vec3(1.0), rimProfile * clamp(glowStrength, 0.0, 0.8));
    }

    // 3. Directional highlight on top and side bevels (matching dolphin.png natural light source)
    // In Cartesian coords, position.y > 0 is top of window.
    float topFactor = clamp(s.normal.y * 0.7 + 0.3, 0.0, 1.0);
    float naturalHighlight = rimProfile * topFactor * s.concaveFactor * (glowStrength * 0.35 + 0.15);
    col += vec3(0.96, 0.98, 1.0) * naturalHighlight;

    // 4. Subtle Fresnel grazing angle reflection
    float fresnel = edgeProximity * edgeProximity * 0.06;
    col += vec3(0.96, 0.98, 1.0) * fresnel;

    return col;
}

// Main glass effect orchestrator
vec4 glass_effect(
    vec2 uv_tex,
    vec2 windowUV,
    vec4 baseColor,
    vec2 blurSize,
    vec4 cornerRadius,
    float refractionStrength,
    float refractionNormalPow,
    float refractionRGBFringing,
    float refractionOffsetStrength,
    float refractionBevelIntensity,
    float physicallyBasedRefraction,
    float glowStrength,
    float edgeLighting
) {
    vec2 halfBlurSize = blurSize * 0.5;
    float minHalfSize = min(halfBlurSize.x, halfBlurSize.y);

    // Pixel coords relative to center with +Y pointing UP
    vec2 position = windowUV * blurSize - halfBlurSize.xy;
    position.y = -position.y;
    float dist = roundedRectangleDist(position, halfBlurSize, cornerRadius);

    // Outside rounded rectangle = no refraction
    if (dist > 0.0) {
        return baseColor;
    }

    vec2 uv_min = vec2(0.0);
    vec2 uv_max = vec2(1.0);

    // Edge bevel width and curvature
    float bezelWidthPx = max(minHalfSize * lg_edge_thickness, 10.0 * niri_scale);
    float minEsp = clamp(bezelWidthPx, 1.0, minHalfSize * 0.9);
    float edgeFactor = 1.0 - clamp(abs(dist) / minEsp, 0.0, 1.0);
    float smoothEdge = smoothstep(0.0, 1.0, edgeFactor);
    float concaveFactor = 1.0 - sqrt(max(0.0, 1.0 - pow(smoothEdge, refractionNormalPow)));
    float edgeProximity = exp(dist / bezelWidthPx);

    GlassFragment s;
    if (refractionStrength > 0.0) {
        if (lg_refraction_dilute > 0.0001) {
            float diluteSt = lg_dilute_strength > 0.0
                ? clamp(lg_dilute_strength * 0.05, 0.0, 1.0)
                : clamp(lg_refraction_dilute * 0.15, 0.0, 1.0);
            float diluteIntensity = max(lg_refraction_dilute, 1.0);
            s = diluteRefraction(uv_tex, uv_min, uv_max, position, halfBlurSize, dist, edgeFactor, concaveFactor, diluteSt, lg_dilute_fringing, diluteIntensity);
        } else if (physicallyBasedRefraction >= 0.0) {
            // Default: Snell's Law Optical Refraction (matching kwin-effects-glass / dolphin.png)
            s = snellsRefraction(
                uv_tex, uv_min, uv_max, position, halfBlurSize, cornerRadius,
                minHalfSize, dist, edgeFactor, concaveFactor,
                refractionStrength, refractionBevelIntensity, refractionOffsetStrength, refractionRGBFringing
            );
        } else {
            // Classical 2D gradient push
            s = glassRefraction(
                uv_tex, uv_min, uv_max, position, halfBlurSize, cornerRadius,
                dist, edgeFactor, concaveFactor, refractionStrength, refractionRGBFringing
            );
        }
    } else {
        s = GlassFragment(baseColor, dist, edgeFactor, concaveFactor, vec3(0.0, 0.0, 1.0), 1.0);
    }

    // Dome lens distortion
    vec2 domeUV = applyDomeLens(uv_tex, lg_lens_distortion, edgeProximity);
    if (length(domeUV) > 0.001) {
        vec2 maxOffPos = vec2(1.0) - uv_tex;
        vec2 maxOffNeg = uv_tex;
        domeUV = clamp(domeUV, -maxOffNeg, maxOffPos);
        s.color = texture2D(tex, uv_tex + domeUV);
    }

    // Frosted tint & adaptive luminance
    s.color.rgb = applyFrostedTint(s.color.rgb, edgeProximity);

    // Apply smooth glass outline & specular lighting
    vec3 rgb = glassOutline(position, blurSize, s, glowStrength, edgeLighting, edgeProximity);

    return vec4(rgb, s.color.a);
}

void main() {
    vec3 coords_geo = input_to_geo * vec3(v_coords, 1.0);

    vec4 color = texture2D(tex, v_coords);
#if defined(NO_ALPHA)
    color = vec4(color.rgb, 1.0);
#endif

    // Clip fragments outside geometry bounds completely
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0) {
        gl_FragColor = vec4(0.0);
        return;
    }

    // Determine actual unpadded window size and pixel coordinates
    vec2 winSize = geo_size;
    vec2 winPixel = coords_geo.xy * geo_size;
    if (lg_padding_pixels > 0.5) {
        winSize = geo_size - vec2(lg_padding_pixels * 2.0);
        winPixel = coords_geo.xy * geo_size - vec2(lg_padding_pixels);
    }
    vec2 windowUV = winPixel / winSize;

    // Centered pixel coordinates for SDF (+Y is UP, -Y is DOWN)
    vec2 halfWinSize = winSize * 0.5;
    vec2 position = winPixel - halfWinSize;
    position.y = -position.y;

    // Signed distance to window boundary (dist <= 0 is inside, dist > 0 is outside)
    float dist = roundedRectangleDist(position, halfWinSize, corner_radius);

    // Subpixel-smooth anti-aliased edge coverage across 1 physical pixel
    // This completely eliminates jagged edges and colored line glitches!
    float edgeAlpha = clamp(0.5 - dist * niri_scale, 0.0, 1.0);
    edgeAlpha = edgeAlpha * edgeAlpha * (3.0 - 2.0 * edgeAlpha);

    if (edgeAlpha <= 0.0) {
        gl_FragColor = vec4(0.0);
        return;
    }

    float lgEnabled = step(0.0001, lg_refraction_strength);
    if (lgEnabled > 0.0) {
        // Normalize strength (config 0-100 -> shader 0-1)
        float normStrength = clamp(lg_refraction_strength * 0.05, 0.0, 1.0);

        vec4 result = glass_effect(
            v_coords,       // uv_tex
            windowUV,       // window UV [0, 1]
            color,
            winSize,        // actual unpadded window size
            corner_radius,  // vec4(TL, TR, BR, BL)
            normStrength,
            lg_power_factor,
            lg_fringing,
            lg_refraction_power,
            lg_refraction_power,
            lg_physical_refraction,
            lg_glow_weight,
            lg_edge_lighting
        );
        color = result;
    } else {
        // Fallback when liquid-glass is disabled: apply standard niri corner rounding
        edgeAlpha = niri_rounding_alpha(coords_geo.xy * geo_size, geo_size, corner_radius);
    }

    color = postprocess(color);

    // Apply smooth anti-aliased boundary coverage and surface alpha
    color = color * edgeAlpha * alpha;

#if defined(DEBUG_FLAGS)
    if (tint == 1.0)
        color = vec4(0.0, 0.2, 0.0, 0.2) + color * 0.8;
#endif

    gl_FragColor = color;
}
