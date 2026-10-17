// Тематический значок как на Pixel: из цветного значка остаётся только
// символ, окрашенный в цвет темы.
//  * У значка есть своя подложка (кружок, квадрат) — средняя непрозрачность
//    по мип-уровню высокая: символом считаем светлые малонасыщенные части
//    (белый логотип Discord, Steam, Telegram…).
//  * Подложки нет (папка, маскот) — берём силуэт с лёгкой светотенью.
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec3 rgb = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    // Средний цвет значка (верхний мип-уровень) — это цвет его подложки,
    // если она есть: подложка занимает большую часть площади.
    vec4 avg = textureLod(source, vec2(0.5), 12.0);
    float coverage = avg.a;
    vec3 plate = avg.a > 0.001 ? avg.rgb / avg.a : vec3(0.0);

    // символ — всё, что заметно отличается от подложки по цвету
    // (полупрозрачные края и тени подложки не в счёт)
    float glyph = smoothstep(0.22, 0.42, distance(rgb, plate)) * smoothstep(0.55, 0.95, c.a);
    // силуэт без подложки: тёмные места чуть прозрачнее, чтобы читались детали
    float silhouette = c.a * mix(0.55, 1.0, smoothstep(0.15, 0.7, l));
    float g = mix(silhouette, glyph, smoothstep(0.40, 0.50, coverage));

    fragColor = vec4(tint.rgb, 1.0) * tint.a * g * qt_Opacity;
}
