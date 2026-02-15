extends Node2D

# --- Переменные ---
var score: float = 0.0
var click_power: float = 1.0
var auto_click_power: float = 0.0
var radiation_level: float = 0.0
var game_over: bool = false
var upgrades : Array = []
var music_volume := 0.8
var sfx_volume := 0.8

const SAVE_PATH := "user://save.json"

var main_font = preload("res://DwarvenStonecraftCyr.otf") 

@onready var settings_panel = $CanvasLayer/SettingsPanel
@onready var stone_btn = $CanvasLayer/Control/CenterContainer/Stone
@onready var score_label = $CanvasLayer/Control/Label
@onready var bg_gradient = $CanvasLayer/TextureRect
@onready var upgrade_container = $CanvasLayer/Control/ScrollContainer/VBoxContainer
@onready var env = $WorldEnvironment.environment
@onready var white_fade := $CanvasLayer/WhiteFade
@onready var choice_panel = $CanvasLayer/FinalChoicePanel
@onready var confirm_delete = $CanvasLayer/SettingsPanel/ConfirmationDialog

var current_lang = "en" # По умолчанию

var translations = {
	"ru": {
		"score": "КАМНИ",
		"price": "Цена"
	},
	"en": {
		"score": "STONES",
		"price": "Price"
	}
}
var translationsSet = {
	"ru": {
		"score": "КАМНИ",
		"price": "Цена",
		"solar": "СОЛНЦЕ!",
		"music": "Музыка",
		"sfx": "Звуки",
		"delete": "Удалить сохранение"
	},
	"en": {
		"score": "STONES",
		"price": "Price",
		"solar": "SOLAR!",
		"music": "Music",
		"sfx": "SFX",
		"delete": "Delete Save"
	}
}

var upgrade_names = {
	"ru": [
		"Треснутая кирка", "Тень помощника", "Тяжелый молот", "Механический шепот",
		"Бур бездны", "Солнечный улавливатель", "Призма искажения", "Ритуал пепла",
		"Кинетический резонанс", "Осколок сверхновой", "Глаз пустоты", "Световая лихорадка",
		"Монолит безумия", "Звёздный потрошитель", "Радиоактивный туман", "Сердце карлика",
		"Фотонный распад", "Голос солнца", "Сингулярность света", "Апофеоз"
	],
	"en": [
		"Cracked Pickaxe", "Assistant's Shadow", "Heavy Hammer", "Mechanical Whisper",
		"Abyss Drill", "Solar Catcher", "Distortion Prism", "Ash Ritual",
		"Kinetic Resonance", "Supernova Shard", "Void Eye", "Light Fever",
		"Monolith of Madness", "Star Ripper", "Radioactive Fog", "Dwarf Heart",
		"Photonic Decay", "Voice of the Sun", "Light Singularity", "Apotheosis"
	]
}


func _ready():
	load_game()
	create_upgrade_buttons()
	apply_audio()

	
	$AutoClickTimer.timeout.connect(_on_auto_click)
	
	choice_panel.visible = false
	if has_node("Music"): $Music.play()
	
	


func _on_music_slider_value_changed(value):
	music_volume = value / 100
	apply_audio()
	save_game()

func toggle_settings():
	if settings_panel.visible:
		var t = create_tween()
		t.tween_property(settings_panel, "modulate:a", 0.0, 0.25)
		t.finished.connect(func():
			settings_panel.visible = false
		)
	else:
		settings_panel.visible = true
		settings_panel.modulate.a = 0
		create_tween().tween_property(settings_panel, "modulate:a", 1.0, 0.25)

func _on_sfx_slider_value_changed(value):
	sfx_volume = value / 100
	apply_audio()
	save_game()
	
func ending_white_out():
	game_over = true
	white_fade.visible = true 
	white_fade.modulate.a = 0.0
	
	var t = create_tween()
	t.tween_property(white_fade, "modulate:a", 1.0, 3.0)
	
	t.finished.connect(func():
		save_game()
		await get_tree().create_timer(1.0).timeout
		delete_save() 
		get_tree().reload_current_scene() 
	)

	
func _process(_delta):
	if game_over:
		if white_fade.modulate.a > 0:
			env.glow_strength += 0.1
			env.adjustment_brightness += 0.05
		return
	if int(Time.get_ticks_msec()) % 2000 < 16:
		save_game()
	stone_btn.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.02)
	score_label.text = "%s: %s" % [translations[current_lang].score, format_num(score)]
	score_label.modulate = Color(1, 1, 1).lerp(Color(1, 0.5, 0), radiation_level)
	score_label.rotation = sin(Time.get_ticks_msec() * 0.01) * radiation_level * 0.05
	var t = Time.get_ticks_msec() * 0.00005
	bg_gradient.material.set_shader_parameter("offset", t)
	
	var time = Time.get_ticks_msec() * 0.001
	var rad = clamp(radiation_level, 0.0, 1.5) 
	var toxic_color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.7, 0.0), clamp(rad, 0, 1))
	var pulse = sin(time * 2.0) * (0.1 * rad) 
	bg_gradient.modulate = toxic_color * (1.0 + rad + pulse)
	var shader_speed = time * 0.05 * (1.0 + rad * 10.0) 
	bg_gradient.material.set_shader_parameter("offset", shader_speed)
	env.adjustment_brightness = 1.0 + (rad * 2.0)
	env.adjustment_saturation = 1.0 - (rad * 0.5) 
	env.adjustment_color_correction = null 
	env.glow_strength = 0.5 + (rad * 2.0)
	env.glow_bloom = rad * 0.5

func format_num(value: float) -> String:
	var s = str(int(value))
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count == 3 and i != 0:
			result = " " + result
			count = 0
	return result



func ending_reset():
	delete_save()
	choice_panel.visible = false
	
	

func _on_stone_pressed():
	if game_over: return
	
	var tween = create_tween()
	stone_btn.pivot_offset = stone_btn.size / 2
	tween.tween_property(stone_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(stone_btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	var rot_tween = create_tween()
	stone_btn.pivot_offset = stone_btn.size / 2
	var random_rot = randf_range(-0.1, 0.1)
	rot_tween.tween_property(stone_btn, "rotation", random_rot, 0.05)
	rot_tween.tween_property(stone_btn, "rotation", 0.0, 0.1)
	var flash = create_tween()
	flash.tween_property(bg_gradient, "self_modulate", Color(5, 5, 2), 0.1) # Вспышка
	flash.tween_property(bg_gradient, "self_modulate", Color.WHITE, 0.3)
	
	var gain = click_power
	var is_solar = randf() < 0.05 + (radiation_level * 0.1)
	
	if is_solar:
		gain *= 10
		radiation_level += 0.002
		play_sound("SoundSolar")
		screen_shake(0.3, 15) 
		spawn_click_effect(translationsSet[current_lang].solar, true)
	else:
		play_sound("SoundClick")
		spawn_click_effect("+" + format_num(gain), false)

	
	score += gain
func apply_audio():
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(music_volume)
	)
	
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(sfx_volume)
	)
	
func _on_confirm_delete_dialog_confirmed():
	delete_save()
	
func screen_shake(duration, intensity):
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", offset, duration / 10)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)
	
func spawn_click_effect(txt, is_solar):
	var l = Label.new()
	l.text = txt
	l.z_index = 10 
	if main_font: l.add_theme_font_override("font", main_font)
	l.add_theme_font_size_override("font_size", 45 if is_solar else 26)
	l.add_theme_color_override("font_color", Color(1, 0.8, 0) if is_solar else Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_outline_size", 4)
	$CanvasLayer.add_child(l) 
	l.global_position = get_global_mouse_position() + Vector2(randf_range(-30, 30), -30)
	var t = create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 100, 0.8) 
	t.tween_property(l, "modulate:a", 0, 0.8)
	t.tween_property(l, "scale", Vector2(1.2, 1.2), 0.8)
	t.finished.connect(l.queue_free)
	
	

func create_upgrade_buttons():
	for i in range(upgrades.size()):
		var btn = Button.new() 
		btn.add_theme_constant_override("outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		btn.add_theme_color_override("font_color", Color.WHITE)
		if main_font: btn.add_theme_font_override("font", main_font)
		update_button_text(btn, i)
		btn.pressed.connect(func(): buy_upgrade(i, btn))
		upgrade_container.add_child(btn)

func spawn_auto_visual():
	var sprite = Label.new()
	sprite.text = "✦"
	sprite.position = Vector2(randi_range(50, 500), 700)
	add_child(sprite)
	
	var t = create_tween()
	t.tween_property(sprite, "position:y", 200, 1.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(sprite, "position:x", sprite.position.x + randi_range(-100, 100), 1.5)
	t.parallel().tween_property(sprite, "modulate:a", 0, 1.5)
	t.finished.connect(sprite.queue_free)

func play_sound(sound_name):
	var player = get_node_or_null(sound_name)
	if player:
		player.pitch_scale = randf_range(0.9, 1.1)
		player.play()

func buy_upgrade(index, btn):
	var data = upgrades[index]
	if score >= data.cost:
		score -= data.cost
		play_sound("SoundBuy")
		save_game()
		if index % 2 == 0: click_power += data.power
		else: auto_click_power += data.power
		
		data.cost *= 2.0
		update_button_text(btn, index)
		
		if index == 19: trigger_ending_choice()

func setups_upgrades():
	for i in range(20):
		var n = upgrade_names[current_lang][i] if i < upgrade_names[current_lang].size() else "Artifact " + str(i)
		upgrades.append({
			"name": n,
			"cost": pow(2.5, i) * 20,
			"power": pow(1.8, i)
		})
		
func switch_language(lang: String):
	current_lang = lang
	
	for i in range(upgrades.size()):
		upgrades[i].name = upgrade_names[current_lang][i]
	
	var buttons = upgrade_container.get_children()
	for i in range(buttons.size()):
		if buttons[i] is Button:
			update_button_text(buttons[i], i)
	
	$CanvasLayer/SettingsPanel/MusicLabel.text = translationsSet[current_lang].music
	$CanvasLayer/SettingsPanel/SfxLabel.text = translationsSet[current_lang].sfx
	$CanvasLayer/SettingsPanel/DeleteButton.text = translationsSet[current_lang].delete
	
	save_game()
	
	
func _on_ru_pressed():
	switch_language("ru")

func _on_en_pressed():
	switch_language("en")

func update_button_text(btn, index):
	var price_text = translations[current_lang].price
	var upgrade_name = upgrades[index].name
	var cost_val = format_num(upgrades[index].cost)
	btn.text = "%s\n%s: %s" % [upgrade_name, price_text, cost_val]


func _on_auto_click():
	if game_over: return
	if auto_click_power > 0:
		score += auto_click_power
		spawn_auto_visual()

func trigger_ending_choice():
	game_over = true
	choice_panel.visible = true
	choice_panel.modulate.a = 0
	create_tween().tween_property(choice_panel, "modulate:a", 1.0, 1.0)


func _on_music_finished():
	$Music.play()
	
	
	
func save_game():
	var data = {
		"score": score,
		"click_power": click_power,
		"auto_click_power": auto_click_power,
		"radiation_level": radiation_level,
		"upgrades": upgrades,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"language": current_lang
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	
func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	get_tree().reload_current_scene()
	
func _on_delete_save_pressed():
	confirm_delete.popup_centered()
	
func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		setups_upgrades()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	current_lang = data.get("language", "ru")
	score = data.score
	click_power = data.click_power
	auto_click_power = data.auto_click_power
	radiation_level = data.radiation_level
	upgrades.clear()
	upgrades = data.upgrades
	music_volume = data.music_volume
	sfx_volume = data.sfx_volume
	apply_audio()
	$CanvasLayer/SettingsPanel/MusicSlider.value = music_volume * 100
	$CanvasLayer/SettingsPanel/SfxSlider.value = sfx_volume * 100
	switch_language(current_lang)
	
