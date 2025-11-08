// Shader para emular o estilo da "Noite Estrelada" de Van Gogh
shader_type canvas_item;

// Parâmetros para ajustar no Inspector do Godot
uniform vec4 sky_color_deep: source_color = vec4(0.0, 0.1, 0.3, 1.0);
uniform vec4 sky_color_bright: source_color = vec4(0.3, 0.5, 0.8, 1.0);
uniform vec4 star_color: source_color = vec4(1.0, 0.9, 0.5, 1.0);

uniform float zoom = 2.0;
uniform float scroll_speed = 0.05;
uniform float swirl_intensity = 0.4;
uniform float brush_stroke_texture = 0.05;


// Função simples para gerar ruído a partir de coordenadas 2D
// Baseada em uma função clássica de ruído procedural
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Função de ruído um pouco mais elaborada (Value Noise)
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}


void fragment() {
    // Coordenadas de tela ajustadas pelo zoom e animação de tempo
    vec2 uv = UV * zoom;
    uv.x += TIME * scroll_speed;

    // --- 1. Criando os Redemoinhos (Domain Warping) ---
    // Usamos uma camada de ruído para distorcer as coordenadas de outra
    vec2 uv_distort = uv + vec2(TIME * 0.02, 0.0);
    float distortion_x = noise(uv_distort) * 2.0 - 1.0;
    float distortion_y = noise(uv_distort + vec2(10.5)) * 2.0 - 1.0;

    vec2 warped_uv = uv + vec2(distortion_x, distortion_y) * swirl_intensity;
    float swirl_pattern = noise(warped_uv);

    // Usa o padrão de redemoinho para misturar as duas cores do céu
    // O smoothstep cria transições mais nítidas, parecidas com pinceladas
    vec3 sky = mix(sky_color_deep.rgb, sky_color_bright.rgb, smoothstep(0.4, 0.6, swirl_pattern));

    // --- 2. Desenhando as Estrelas ---
    vec3 stars = vec3(0.0);
    // Posições pré-definidas para algumas estrelas
    vec2 star_positions[] = vec2[](
        vec2(0.8, 0.2), vec2(1.5, 0.8), vec2(2.5, 0.4),
        vec2(3.5, 0.9), vec2(4.2, 0.1), vec2(0.2, 1.5),
        vec2(1.8, 1.8), vec2(3.0, 1.4)
    );

    for (int i = 0; i < star_positions.length(); i++) {
        vec2 pos = star_positions[i];
        // Anima a posição um pouco para um efeito de cintilação
        pos += vec2(sin(TIME * 0.5 + float(i)), cos(TIME * 0.4 + float(i) * 2.0)) * 0.1;

        // Calcula a distância do pixel atual até a estrela
        float dist = distance(uv, pos);

        // Cria um brilho com halo
        // O núcleo brilhante
        float core = smoothstep(0.15, 0.0, dist);
        // O halo suave ao redor
        float halo = smoothstep(0.4, 0.1, dist) * 0.5;

        stars += (core + halo) * star_color.rgb;
    }

    // --- 3. Textura de Pincelada ---
    // Um ruído de alta frequência e esticado para simular pinceladas
    float strokes = (noise(uv * vec2(5.0, 20.0)) - 0.5) * brush_stroke_texture;

    // --- 4. Combinação Final ---
    // Adiciona as estrelas e a textura de pincelada ao céu
    vec3 final_color = sky + stars + strokes;

    COLOR = vec4(final_color, 1.0);
}