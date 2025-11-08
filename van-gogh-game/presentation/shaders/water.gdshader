shader_type spatial;
render_mode unshaded;

// MODIFICADO: Adicionamos 'repeat_enable'
// Isso garante que a textura possa se repetir
uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D distortion_map : filter_linear_mipmap, repeat_enable;

uniform float speed = 0.5;
uniform float strength = 0.05;

// NOVO: Uma variável para passar a coordenada do vertex para o fragment
varying vec2 world_xz_coords;


// NOVA FUNÇÃO: Isso roda para cada vértice do seu QuadMesh
void vertex() {
	// (MODEL_MATRIX * vec4(VERTEX, 1.0)) nos dá a posição exata no mundo 3D
	// .xz pega apenas as coordenadas do "chão" (X e Z)
	// Isso faz com que 'world_xz_coords' tenha valores em metros (ex: 0.0, 1.0, 2.0...)
	world_xz_coords = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}


// FUNÇÃO MODIFICADA
void fragment() {
	// 1. MODIFICADO: Usamos 'world_xz_coords' em vez de 'UV'
	// Isso faz o mapa de distorção rolar no espaço do mundo
	vec2 distortion_uv = world_xz_coords + (TIME * speed);
	float distortion_value = texture(distortion_map, distortion_uv).r - 0.5;

	// 2. MODIFICADO: A distorção também é baseada nas coordenadas do mundo
	vec2 distorted_uv = world_xz_coords + (distortion_value * strength);

	// 3. Pega a cor da textura da água
	// Como 'distorted_uv' agora está em metros, a textura vai se repetir
	// automaticamente a cada 1.0 unidade (1 metro)
	vec4 color = texture(water_texture, distorted_uv);

	ALBEDO = color.rgb;
	ALPHA = color.a;
}