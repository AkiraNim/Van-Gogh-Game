// Define que este é um shader para um objeto 2D
shader_type canvas_item;

// Variáveis que poderemos editar no Inspetor para ajustar o efeito
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Cor para a qual as bordas irão "apagar"
uniform float radius : hint_range(0.0, 1.0) = 0.5; // O raio do círculo nítido (0.5 = metade da tela)
uniform float softness : hint_range(0.0, 1.0) = 0.5; // A suavidade da borda do círculo

void fragment() {
    // Pega a cor original do pixel vinda do SubViewport
    vec4 original_color = texture(TEXTURE, UV);

    // Calcula a distância de cada pixel ao centro da tela (que é 0.5, 0.5)
    float dist = distance(UV, vec2(0.5));

    // Cria a máscara circular suave.
    // smoothstep cria uma transição suave entre dois valores.
    // Isso resulta em 'mask' sendo 1.0 no centro e 0.0 nas bordas.
    float mask = 1.0 - smoothstep(radius - softness, radius + softness, dist);

    // Mistura a cor original com a cor do "fade" usando a máscara como fator.
    // Onde a máscara é 1.0, a cor final é 100% a cor original.
    // Onde a máscara é 0.0, a cor final é 100% a cor do fade.
    COLOR = mix(fade_color, original_color, mask);
}