shader_type canvas_item;

// 动态水波纹与晕影噪声背景
uniform vec4 center_color : source_color = vec4(0.08, 0.12, 0.18, 0.95); // 中间稍浅的夜色，保证文字清晰
uniform vec4 edge_color : source_color = vec4(0.02, 0.03, 0.05, 0.98); // 四周深沉的暗色，避免边缘干扰
uniform float vignette_scale = 1.3;

uniform float noise_intensity = 0.04; // 适中噪点，不至于太抢戏
uniform float ripple_speed = 1.2; // 保持流动感但不过快
uniform float ripple_density = 2.5;
uniform float ripple_intensity = 0.09; // 稍微拉高对比度，让 FBM 带来的暗流更清晰

// 经典的伪随机与噪声函数
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// 基于 Hash 的 2D 柏林噪声 (Perlin Noise) 算法
float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // 平滑插值 (Smoothstep)
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    // 混合 4 个角
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 分形布朗运动 (FBM) - 叠加多层噪声产生有机的水墨/云雾感
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    
    // 引入一个固定的旋转矩阵来打乱网格
    // (cos(0.5) ≈ 0.877, sin(0.5) ≈ 0.479)
    mat2 rot = mat2(vec2(0.877, 0.479), vec2(-0.479, 0.877));
    
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise2d(p);
        p *= 2.0;
        // 【关键修复】：每次叠加前，将坐标系旋转一定角度，彻底摧毁 Value Noise 的正交网格感
        p = rot * p;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * ripple_speed;
    
    // 1. 高级有机流体 (Organic Fluid Noise)
    // 使用 FBM 替换生硬的正弦波，结合时间偏移产生类似深海暗流的无序涌动
    vec2 flow_uv = uv * ripple_density + vec2(time * 0.2, time * 0.3);
    float ripple = fbm(flow_uv + fbm(flow_uv * 2.0 - time * 0.5));
    // 将其映射到 -1 到 1 的波动区间
    ripple = (ripple - 0.5) * 2.0;
    
    // 2. 晕影计算 (四周深，中间浅)
    // 计算当前像素到中心点(0.5, 0.5)的距离
    float dist = distance(uv, vec2(0.5, 0.5)) * vignette_scale;
    float vignette = smoothstep(0.0, 1.0, dist);
    
    // 3. 颜色混合
    // 中心部分用较浅的颜色，边缘用深色
    vec4 bg_color = mix(center_color, edge_color, vignette);
    
    // 将水波纹的微弱亮度变化叠加进背景
    bg_color.rgb += vec3(ripple * ripple_intensity);
    
    // 4. 添加胶片级动态颗粒噪声
    float noise = (random(UV + vec2(time)) - 0.5) * noise_intensity;
    bg_color.rgb += vec3(noise);
    
    COLOR = bg_color;
}
