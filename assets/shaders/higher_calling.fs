// Faceted pearl: moving light across a fixed cut-glass surface.
extern vec4 texture_details;
extern vec2 image_details;
extern number phase;
extern number motion;
extern number fade;
extern vec2 mouse_screen_pos;
extern number hovering;
extern number screen_scale;

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords);
    vec2 uv = (texture_coords * image_details - texture_details.xy * texture_details.zw) / texture_details.zw;
    // Split a skewed grid into triangles; facets stay attached to the artwork.
    vec2 grid = vec2(uv.x * 3.0 + uv.y * 1.8, uv.y * 3.8 - uv.x * 0.7);
    vec2 cell = floor(grid);
    vec2 local_uv = fract(grid);
    float triangle = step(local_uv.x, local_uv.y);
    float face = dot(cell, vec2(1.71, 2.39)) + triangle * 2.4;
    vec2 normal = vec2(cos(face), sin(face));
    float light_angle = phase * 0.55 + motion * 1.6;
    float facing = 0.5 + 0.5 * dot(normal, vec2(cos(light_angle), sin(light_angle)));
    float sweep = 0.5 + 0.5 * sin(uv.x * 5.0 - uv.y * 3.0 + phase + motion * 2.0);
    float sheen = pow(facing, 3.0) * (0.35 + 0.65 * sweep);

    // Subpixel refraction cannot sample a neighbouring card in the atlas.
    vec2 inset = vec2(0.5) / texture_details.zw;
    vec2 refracted_uv = clamp(uv + normal * (0.65 * sheen) / texture_details.zw, inset, 1.0 - inset);
    vec2 refracted_coords = (texture_details.xy * texture_details.zw + refracted_uv * texture_details.zw) / image_details;
    vec3 refracted = Texel(texture, refracted_coords).rgb;
    vec3 pearl = mix(vec3(0.64, 0.87, 1.0), vec3(1.0, 0.77, 0.84),
                     0.5 + 0.5 * sin(face + light_angle * 0.7));
    pearl = mix(pearl, vec3(1.0, 0.94, 0.72), sweep * 0.55);
    // A translucent highlight leaves the actual edition visible underneath.
    vec3 finish = mix(refracted, vec3(1.0) - (vec3(1.0) - refracted) * (vec3(1.0) - pearl), 0.75);
    float art = 1.0 - smoothstep(0.80, 0.90, uv.y);
    float opacity = (0.08 + 0.76 * sheen) * art;
    return vec4(finish * colour.rgb, opacity * tex.a * colour.a * fade);
}

#ifdef VERTEX
// Match the host card's hover perspective; no independent card movement.
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vec4 result = transform_projection * vertex_position;
    if (hovering > 0.0) {
        float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
        vec2 offset = (vertex_position.xy - mouse_screen_pos) / screen_scale;
        result.w += 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist))
                    * hovering * dot(offset, offset) / (2.0 - mid_dist);
    }
    return result;
}
#endif
