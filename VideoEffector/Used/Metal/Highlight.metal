//
//  Highlight.metal
//  VideoEffector
//
//  Created by Moonbeom KWON on 10/24/25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]]; // clip-space xy
    float2 uv       [[attribute(1)]]; // 0..1
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// 단순 passthrough vertex
vertex VertexOut vs_passthrough(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.uv = in.uv;
    return out;
}

// 유니폼(프래그먼트에서 사용)
struct HighlightUniforms {
    float4 highlightColor; // RGBA (0..1)
    float4 borderColor;    // RGBA
    float4 rect;           // x, y, width, height (normalized 0..1), origin top-left
    float  fillAlpha;      // 0..1 (how much to blend highlight color inside rect)
    float  borderWidth;    // normalized (as fraction of min(width,height)) or absolute normalized thickness
    uint   showFill;       // 0 or 1
    uint   showBorder;     // 0 or 1
    uint   padding0;
    uint   padding1;
};

fragment float4 fs_highlight(VertexOut in [[stage_in]],
                             texture2d<float, access::sample> colorTex [[texture(0)]],
                             sampler samp [[sampler(0)]],
                             constant HighlightUniforms& u [[buffer(0)]])
{
    // sample original color
    float4 src = colorTex.sample(samp, in.uv);

    // compute if uv inside rect
    float2 uv = in.uv;
    float2 rectOrigin = u.rect.xy;
    float2 rectSize = u.rect.zw;

    // check inside
    bool inside = (uv.x >= rectOrigin.x) && (uv.x <= rectOrigin.x + rectSize.x) &&
                  (uv.y >= rectOrigin.y) && (uv.y <= rectOrigin.y + rectSize.y);

    // compute normalized distance to nearest edge (0 at edge, 1 at center)
    // We'll use this to detect border region
    float2 rel = float2( (uv.x - rectOrigin.x) / rectSize.x,
                         (uv.y - rectOrigin.y) / rectSize.y );

    // clamp inside [0,1]
    rel = clamp(rel, 0.0, 1.0);

    float leftDist   = rel.x;          // 0 at left edge -> 1 at right
    float rightDist  = 1.0 - rel.x;
    float topDist    = rel.y;
    float bottomDist = 1.0 - rel.y;
    float edgeDist = min(min(leftDist, rightDist), min(topDist, bottomDist)); // 0 at nearest edge

    // border test: consider borderWidth as fraction of rect min dimension
    float bw = max(0.0, u.borderWidth);
    bool isBorder = false;
    if (u.showBorder != 0 && inside) {
        // convert edgeDist (0..0.5..1) — here edgeDist ranges 0..0.5..1, but since rel 0..1, edgeDist ∈ [0,0.5] for rectangle but this is fine
        // We use threshold: if edgeDist <= bwNormalized then it's border
        // To make bw interpretable: bw is fraction relative to min(rectSize.x,rectSize.y)
        float minDim = min(rectSize.x, rectSize.y);
        // if minDim == 0, avoid div0
        if (minDim > 0.0) {
            float edgeFraction = edgeDist; // relative within [0..0.5]
            // scale optional: treat bw as fraction of half-dimension
            // simple approach: compare edgeDist*1.0 <= bw (works if bw small)
            isBorder = (edgeDist <= bw);
        }
    }

    float4 outColor = src;

    // fill: blend highlight color with src inside rect
    if (u.showFill != 0 && inside && !isBorder) {
        // basic linear blend with fillAlpha
        outColor = mix(src, u.highlightColor, u.fillAlpha * u.highlightColor.a);
    }

    // border: override (or blend) border area
    if (isBorder) {
        // you can choose to fully set border color or blend
        float borderAlpha = u.borderColor.a;
        outColor = mix(src, u.borderColor, borderAlpha);
    }

    return outColor;
}
