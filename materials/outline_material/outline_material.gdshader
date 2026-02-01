shader_type spatial;

render_mode cull_disabled;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Amarelo
uniform float outline_size = 0.05;

void vertex() {
    // Expande os vértices na direção da normal para criar o contorno
    VERTEX += NORMAL * outline_size;
}

void fragment() {
    ALBEDO = outline_color.rgb;
}
