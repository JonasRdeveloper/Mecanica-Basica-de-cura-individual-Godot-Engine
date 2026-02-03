shader_type spatial;
render_mode blend_add, cull_back, unshaded; // Aditivo para glow luminoso, sem sombreamento

// Parâmetros manipuláveis (exports no Inspector)
uniform vec4 cor_primaria : source_color = vec4(1.0, 0.9, 0.3, 0.6); // Cor principal (amarelo claro, semi-transparente)
uniform vec4 cor_secundaria : source_color = vec4(1.0, 0.6, 0.1, 0.4); // Cor secundária (laranja/dourado para gradiente)
uniform float intensidade_glow : hint_range(0.0, 5.0) = 2.0; // Intensidade do brilho (mais alto = mais chamativo)
uniform float velocidade_ondas : hint_range(0.1, 5.0) = 1.5; // Velocidade de propagação das ondas de luz
uniform float frequencia_ondas : hint_range(1.0, 15.0) = 8.0; // Frequência das ondas (mais = mais ondulações como luz)
uniform float amplitude_ondas : hint_range(0.0, 1.0) = 0.7; // Amplitude das ondas (mais = ondas mais pronunciadas)
uniform float densidade_ruido : hint_range(0.1, 2.0) = 0.8; // Densidade do ruído (para partículas de luz suaves)
uniform float velocidade_ruido : hint_range(0.1, 3.0) = 0.3; // Velocidade do ruído (lento para efeito etéreo)
uniform float fator_luz : hint_range(0.0, 2.0) = 1.2; // Fator de "refração de luz" para distorção luminosa

// Função simples de ruído Perlin 2D (para partículas de luz orgânicas)
float perlin_noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // Coordenadas UV normalizadas para a esfera (radial do centro)
    vec2 uv = UV * 2.0 - 1.0; // Centro em (0,0)
    float dist = length(uv); // Distância do centro
    
    // Ondas de luz amarela: sin para oscilação suave, TIME para movimento radial
    float ondas = sin(dist * frequencia_ondas - TIME * velocidade_ondas) * amplitude_ondas;
    ondas = (ondas + 1.0) * 0.5; // Normaliza para 0-1, tornando ondas mais luminosas e suaves
    
    // Ruído animado: Perlin com TIME para "partículas de luz" flutuantes
    vec2 ruido_coord = uv * densidade_ruido + vec2(0.0, TIME * velocidade_ruido); // Movimento vertical para "subida"
    float ruido = perlin_noise(ruido_coord) * 0.4; // Suavizado para não dominar as ondas
    
    // Efeito de "refração de luz": Perturba as normais para simular distorção luminosa
    vec3 normal_perturbada = NORMAL + vec3(ondas * fator_luz, ruido * fator_luz, 0.0);
    normal_perturbada = normalize(normal_perturbada);
    
    // Combina ondas + ruído + refração para intensidade
    float intensidade = (ondas + ruido + dot(normal_perturbada, VIEW)) * intensidade_glow;
    
    // Gradiente de cor: lerp entre primária e secundária baseado na distância e ondas
    vec3 cor_final = mix(cor_secundaria.rgb, cor_primaria.rgb, dist * ondas);
    
    // Saída: Albedo com glow amarelo, alpha variando para pulsar e fade
    ALBEDO = cor_final * intensidade;
    ALPHA = cor_primaria.a * (ondas + 0.5); // Alpha dinâmico para brilho pulsante
}