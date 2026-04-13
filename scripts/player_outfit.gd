class_name PlayerOutfit
extends RefCounted

## Manages outfit/cape recoloring for the player sprite.
## Owns the sprite frame cache and all per-pixel recolor logic,
## keeping that complexity out of player.gd.

const CAPE_PRIMARY_SOURCE   := Color(210.0 / 255.0, 32.0 / 255.0,  44.0 / 255.0, 1.0)
const CAPE_SECONDARY_SOURCE := Color(235.0 / 255.0, 167.0 / 255.0, 36.0 / 255.0, 1.0)
const CAPE_ACCENT_SOURCE    := Color(10.0  / 255.0, 112.0 / 255.0, 48.0 / 255.0, 1.0)
const CAPE_COLOR_TOLERANCE  := 0.01

const OUTFITS := [
	{
		"name": "Classic",
		"cape_primary":   CAPE_PRIMARY_SOURCE,
		"cape_secondary": CAPE_SECONDARY_SOURCE,
		"cape_accent":    CAPE_ACCENT_SOURCE,
	},
	{
		"name": "Frostguard",
		"cape_primary":   Color(52.0  / 255.0, 156.0 / 255.0, 1.0,           1.0),
		"cape_secondary": Color(214.0 / 255.0, 245.0 / 255.0, 1.0,           1.0),
		"cape_accent":    Color(11.0  / 255.0, 67.0  / 255.0, 143.0 / 255.0, 1.0),
	},
	{
		"name": "Royal",
		"cape_primary":   Color(129.0 / 255.0, 45.0  / 255.0, 208.0 / 255.0, 1.0),
		"cape_secondary": Color(1.0,            233.0 / 255.0, 136.0 / 255.0, 1.0),
		"cape_accent":    Color(255.0 / 255.0,  97.0  / 255.0, 211.0 / 255.0, 1.0),
	},
	{
		"name": "Ember",
		"cape_primary":   Color(1.0,            108.0 / 255.0, 46.0  / 255.0, 1.0),
		"cape_secondary": Color(1.0,            224.0 / 255.0, 85.0  / 255.0, 1.0),
		"cape_accent":    Color(168.0 / 255.0,  8.0   / 255.0, 8.0   / 255.0, 1.0),
	},
	{
		"name": "Moss",
		"cape_primary":   Color(55.0  / 255.0, 150.0 / 255.0, 74.0  / 255.0, 1.0),
		"cape_secondary": Color(201.0 / 255.0, 1.0,           112.0 / 255.0, 1.0),
		"cape_accent":    Color(87.0  / 255.0, 56.0  / 255.0, 28.0  / 255.0, 1.0),
	},
	{
		"name": "Night",
		"cape_primary":   Color(48.0 / 255.0, 61.0 / 255.0, 150.0 / 255.0, 1.0),
		"cape_secondary": Color(0.85, 0.93, 1.0, 1.0),
		"cape_accent":    Color(0.0,  213.0 / 255.0, 179.0 / 255.0, 1.0),
	},
]

var _animated_sprite: AnimatedSprite2D
var _base_sprite_frames: SpriteFrames
var _outfit_id: int = 0
var _sprite_frames_cache: Dictionary = {}
var _preview_cache: Dictionary = {}


func setup(animated_sprite: AnimatedSprite2D) -> void:
	_animated_sprite   = animated_sprite
	_base_sprite_frames = animated_sprite.sprite_frames


## Applies the outfit visuals and returns the clamped outfit id.
func apply_visuals(new_outfit_id: int) -> int:
	var clamped_id := clampi(new_outfit_id, 0, OUTFITS.size() - 1)
	_outfit_id = clamped_id
	if _base_sprite_frames == null:
		return clamped_id
	var current_animation: StringName = _animated_sprite.animation
	var current_frame: int            = _animated_sprite.frame
	var current_progress: float       = _animated_sprite.frame_progress
	_animated_sprite.modulate       = Color(1.0, 1.0, 1.0, 1.0)
	_animated_sprite.material       = null
	_animated_sprite.sprite_frames  = _get_sprite_frames(clamped_id)
	if _animated_sprite.sprite_frames.has_animation(current_animation):
		_animated_sprite.play(current_animation)
		_animated_sprite.frame          = mini(current_frame, _animated_sprite.sprite_frames.get_frame_count(current_animation) - 1)
		_animated_sprite.frame_progress = current_progress
	return clamped_id


func get_preview_texture(outfit_index: int) -> Texture2D:
	var clamped_id := clampi(outfit_index, 0, OUTFITS.size() - 1)
	if clamped_id not in _preview_cache:
		_preview_cache[clamped_id] = _recolor_texture(
				_base_sprite_frames.get_frame_texture(&"idle", 0), OUTFITS[clamped_id])
	return _preview_cache[clamped_id]


func get_options() -> Array:
	return OUTFITS


func get_id() -> int:
	return _outfit_id


# ---- private helpers --------------------------------------------------------

func _get_sprite_frames(outfit_index: int) -> SpriteFrames:
	if outfit_index not in _sprite_frames_cache:
		_sprite_frames_cache[outfit_index] = _build_sprite_frames(outfit_index)
	return _sprite_frames_cache[outfit_index]


func _build_sprite_frames(outfit_index: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var outfit: Dictionary = OUTFITS[outfit_index]
	for animation_name in _base_sprite_frames.get_animation_names():
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name,  _base_sprite_frames.get_animation_loop(animation_name))
		frames.set_animation_speed(animation_name, _base_sprite_frames.get_animation_speed(animation_name))
		for frame_idx in range(_base_sprite_frames.get_frame_count(animation_name)):
			frames.add_frame(animation_name,
					_recolor_texture(_base_sprite_frames.get_frame_texture(animation_name, frame_idx), outfit))
	return frames


func _recolor_texture(texture: Texture2D, outfit: Dictionary) -> Texture2D:
	var image: Image
	if texture is AtlasTexture:
		var region := Rect2i((texture as AtlasTexture).region.position, (texture as AtlasTexture).region.size)
		image = (texture as AtlasTexture).atlas.get_image().get_region(region)
	else:
		image = texture.get_image()
	var recolored := image.duplicate() as Image
	for y in range(recolored.get_height()):
		for x in range(recolored.get_width()):
			var pixel := recolored.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if _is_color_match(pixel, CAPE_PRIMARY_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_primary"])
			elif _is_color_match(pixel, CAPE_SECONDARY_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_secondary"])
			elif _is_color_match(pixel, CAPE_ACCENT_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_accent"])
	return ImageTexture.create_from_image(recolored)


func _is_color_match(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= CAPE_COLOR_TOLERANCE \
		and absf(a.g - b.g) <= CAPE_COLOR_TOLERANCE \
		and absf(a.b - b.b) <= CAPE_COLOR_TOLERANCE
