shader_type canvas_item;

uniform vec4 outfit_primary : source_color = vec4(0.823529, 0.12549, 0.172549, 1.0);
uniform vec4 outfit_secondary : source_color = vec4(0.921569, 0.654902, 0.141176, 1.0);
uniform vec4 outfit_accent : source_color = vec4(0.039216, 0.439216, 0.188235, 1.0);
uniform vec4 outfit_armor_dark : source_color = vec4(0.486275, 0.466667, 0.435294, 1.0);
uniform vec4 outfit_armor_light : source_color = vec4(0.701961, 0.666667, 0.631373, 1.0);
uniform vec4 outfit_highlight : source_color = vec4(0.917647, 0.87451, 0.819608, 1.0);

const vec3 SOURCE_PRIMARY = vec3(0.823529, 0.12549, 0.172549);
const vec3 SOURCE_SECONDARY = vec3(0.921569, 0.654902, 0.141176);
const vec3 SOURCE_ACCENT = vec3(0.039216, 0.439216, 0.188235);
const vec3 SOURCE_ARMOR_DARK = vec3(0.486275, 0.466667, 0.435294);
const vec3 SOURCE_ARMOR_LIGHT = vec3(0.701961, 0.666667, 0.631373);
const vec3 SOURCE_HIGHLIGHT = vec3(0.917647, 0.87451, 0.819608);
const float MATCH_THRESHOLD = 0.035;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a <= 0.0) {
		COLOR = tex;
		return;
	}

	if (distance(tex.rgb, SOURCE_PRIMARY) < MATCH_THRESHOLD) {
		tex.rgb = outfit_primary.rgb;
	} else if (distance(tex.rgb, SOURCE_SECONDARY) < MATCH_THRESHOLD) {
		tex.rgb = outfit_secondary.rgb;
	} else if (distance(tex.rgb, SOURCE_ACCENT) < MATCH_THRESHOLD) {
		tex.rgb = outfit_accent.rgb;
	} else if (distance(tex.rgb, SOURCE_ARMOR_DARK) < MATCH_THRESHOLD) {
		tex.rgb = outfit_armor_dark.rgb;
	} else if (distance(tex.rgb, SOURCE_ARMOR_LIGHT) < MATCH_THRESHOLD) {
		tex.rgb = outfit_armor_light.rgb;
	} else if (distance(tex.rgb, SOURCE_HIGHLIGHT) < MATCH_THRESHOLD) {
		tex.rgb = outfit_highlight.rgb;
	}

	COLOR = tex;
}
