shader_type canvas_item;
render_mode unshaded, blend_mix;

// Vignette drawn over the finished frame. Godot's Environment has no vignette,
// so the demo scene carries this one-pass overlay instead of a post effect.

uniform float strength : hint_range(0.0, 1.0) = 0.58;   // how dark the corners go
uniform float radius : hint_range(0.0, 1.5) = 0.52;     // where the fall-off starts
uniform float softness : hint_range(0.01, 1.0) = 0.55;  // how soft the edge is
uniform vec3 tint : source_color = vec3(0.0, 0.02, 0.04);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = length(p) * 1.41421356;   // 1.0 at the corner of the frame
	float mask = smoothstep(radius, radius + softness, d);
	COLOR = vec4(tint, mask * strength);
}
