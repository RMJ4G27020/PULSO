shader_type canvas_item;
// Aberracion cromatica radial: separa los canales hacia fuera desde el centro.
// Se usa un instante al morir y se disuelve sola.
uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float fuerza : hint_range(0.0, 0.05) = 0.0;
uniform float vineta : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float d = length(c);
	vec2 off = c * fuerza * (0.35 + d);
	float r = texture(pantalla, uv + off).r;
	vec4 g = texture(pantalla, uv);
	float b = texture(pantalla, uv - off).b;
	vec3 col = vec3(r, g.g, b);
	col *= 1.0 - vineta * smoothstep(0.25, 0.75, d);
	COLOR = vec4(col, 1.0);
}
