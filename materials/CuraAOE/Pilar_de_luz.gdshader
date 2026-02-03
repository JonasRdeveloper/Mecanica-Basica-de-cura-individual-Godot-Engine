shader_type spatial;
render_mode blend_add, cull_back, unshaded;

uniform vec4 cor_primaria : source_color = vec4(1.0, 0.95, 0.4, 0.8);
uniform vec4 cor_secundaria : source_color = vec4(1.0, 0.7, 0.2, 0.6);
uniform float intensidade_glow : hint_range(0.0, 6.0) = 3.5;
uniform float velocidade_ondas : hint_range(0.1, 6.0) = 2.0;
uniform float frequencia_ondas : hint_range(1.0, 25.0) = 12.0;
uniform float amplitude_ondas : hint_range(0.0, 1.2) = 1.0;
uniform float densidade_ruido : hint_range(0.1, 3.0) = 1.5;
uniform float velocidade_ruido : hint_range(0.1, 5.0) = 1.2;
uniform float fator_distorcao : hint_range(0.0, 3.0) = 1.8;
uniform float fase_surgimento : hint_range(0.0, 1.0) = 0.0; // NOVO: Controla explosão (0=normal, 1=full power)

float perlin_noise(float p) {
    return fract(sin(p * 12.9898) * 43758.5453);
}

void fragment() {
    float altura = UV.y;
    float radial = length(UV - vec2(0.5));
    
    // Ondas explosivas: MAIS INTENSAS durante surgimento
    float ondas = sin(altura * frequencia_ondas + TIME * velocidade_ondas) * amplitude_ondas * (1.0 + fase_surgimento * 2.0);
    ondas = (ondas + 1.0) * 0.5;
    
    // Ruído TURBULENTO durante surgimento
    float ruido_coord = altura * densidade_ruido + TIME * velocidade_ruido;
    float ruido = perlin_noise(ruido_coord) * (0.7 + fase_surgimento);
    
    // Distorção EXPLOSIVA
    vec3 normal_perturbada = NORMAL + vec3(
        ondas * fator_distorcao * (1.0 + fase_surgimento),
        ruido * fator_distorcao * (1.5 + fase_surgimento),
        radial * fator_distorcao
    );
    normal_perturbada = normalize(normal_perturbada);
    
    float intensidade = (ondas + ruido + dot(normal_perturbada, VIEW)) * intensidade_glow * (1.0 + fase_surgimento);
    
    vec3 cor_final = mix(cor_secundaria.rgb, cor_primaria.rgb, altura + ondas * 0.7 + fase_surgimento);
    
    ALBEDO = cor_final * intensidade;
    ALPHA = cor_primaria.a * (ondas + 0.8 + fase_surgimento * 0.5);
}