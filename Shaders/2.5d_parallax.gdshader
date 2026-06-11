shader_type canvas_item;

// 0: 纯视差追踪模式 (Parallax only)
// 1: 手电筒深度光照模式 (Flashlight Depth)
uniform int effect_mode = 0;

// ============ 视差相关参数 ============
// 深度图纹理
uniform sampler2D depth_map;

// 视差强度，控制移动幅度
uniform float depth_strength : hint_range(0.0, 0.2) = 0.05;



// 鼠标/视口偏移量 (由 GDScript 传入，建议范围在 -1.0 到 1.0)
uniform vec2 mouse_offset = vec2(0.0, 0.0);

// 缩放系数，用于裁剪边缘防止穿帮
uniform float scale : hint_range(1.0, 1.5) = 1.05;

// ============ 手电筒相关参数 ============
// 鼠标相对于图片本身的 UV 坐标 (0.0 到 1.0)
uniform vec2 mouse_uv = vec2(0.5, 0.5);

// 夜间环境底色 (冷色偏暗)
uniform vec4 ambient_color : source_color = vec4(0.05, 0.1, 0.25, 1.0);

// 手电筒灯光颜色 (暖光白)
uniform vec4 light_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);

// 光斑半径
uniform float light_radius : hint_range(0.0, 1.0) = 0.25;

// 光斑边缘柔和度
uniform float light_feather : hint_range(0.01, 0.5) = 0.15;


void fragment() {
    // 1. 缩放 UV 以避免边缘穿帮
    vec2 scaled_uv = (UV - 0.5) / scale + 0.5;
    
    // 2. 读取深度值
    float depth = texture(depth_map, scaled_uv).r;
    
    // ============ 视差位移计算 ============
    // 线性深度映射：将视觉支点推向背景层
    // 映射到 [-0.50, 0.50] 区间
    float depth_factor = depth - 0.50;
    
    // 计算最终的 UV 偏移量
    vec2 final_offset = mouse_offset * depth_strength * depth_factor;
    
    // 将偏移量应用到缩放后的 UV 上
    vec2 final_uv = scaled_uv + final_offset;
    
    // 采样主纹理（即原图）
    vec4 base_color = texture(TEXTURE, final_uv);
    
    if (effect_mode == 0) {
        // 模式 0：仅输出带有视差位移的原图
        COLOR = base_color;
    } else {
        // 模式 1：基于深度的手电筒光照
        
        // 修正纹理宽高比引起的椭圆拉伸形变
        float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
        vec2 corrected_uv = scaled_uv;
        corrected_uv.y /= aspect;
        vec2 corrected_mouse = mouse_uv;
        corrected_mouse.y /= aspect;
        
        // 计算当前像素和手电筒中心(即鼠标点)的2D距离
        float dist = distance(corrected_uv, corrected_mouse);
        
        // 动态光圈半径 (光锥投影效果)：远处的背景光圈极大，近处的物体光圈非常集中，增强对比
        // depth: 0=远, 1=近
        float dynamic_radius = mix(light_radius * 2.5, light_radius * 0.6, depth);
        
        // 动态边缘羽化：跟随半径缩放，保持边缘过渡的比例一致
        float dynamic_feather = mix(light_feather * 2.5, light_feather * 0.6, depth);
        
        // 计算手电筒 2D 遮罩 (平滑过渡光圈边缘)
        float light_mask = smoothstep(dynamic_radius, dynamic_radius - dynamic_feather, dist);
        
        // 计算立体衰减 (远处的 depth 接近0，受光弱；近处的 depth 接近1，受光强)
        float depth_intensity = depth * depth; // 非线性增强立体感
        
        // 最终受光强度 = 2D 遮罩 * 3D 深度强度
        float final_light_intensity = light_mask * depth_intensity;
        
        // 夜间底色混合 (原色叠加暗蓝色)
        vec4 night_base = base_color * ambient_color;
        
        // 被照亮的部分 (原色叠加灯光色，乘以受光强度)
        vec4 lit_color = base_color * light_color * final_light_intensity;
        
        // 将环境暗部和被照亮部分混合
        COLOR = night_base + lit_color;
        
        // 保证透明度正常
        COLOR.a = base_color.a;
    }
}
