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

# --- Ссылки на узлы ---
@onready var settings_panel = $CanvasLayer/SettingsPanel
@onready var stone_btn = $CanvasLayer/Control/CenterContainer/Stone
@onready var score_label = $CanvasLayer/Control/Label
@onready var bg_gradient = $CanvasLayer/TextureRect
@onready var upgrade_container = $CanvasLayer/Control/ScrollContainer/VBoxContainer
@onready var env = $WorldEnvironment.environment
@onready var white_fade := $CanvasLayer/WhiteFade
@onready var choice_panel = $CanvasLayer/FinalChoicePanel
@onready var confirm_delete = $CanvasLayer/SettingsPanel/ConfirmationDialog
# Данные апгрейдов (дополни до 20 своими названиями)
var upgrade_names = [
	"Треснутая кирка",        # 1. Начало
	"Тень помощника",        # 2. Первые автоклики
	"Тяжелый молот",         # 3. Усиление клика
	"Механический шепот",    # 4. Ржавые механизмы
	"Бур бездны",            # 5. Глубинная добыча
	"Солнечный улавливатель",# 6. Появление первой радиации
	"Призма искажения",      # 7. Свет начинает менять мир
	"Ритуал пепла",          # 8. Сжигание материи
	"Кинетический резонанс", # 9. Технологии тьмы
	"Осколок сверхновой",    # 10. Половина пути
	"Глаз пустоты",          # 11. Автоклик через порталы
	"Световая лихорадка",    # 12. Радиация растет быстрее
	"Монолит безумия",       # 13. Камень начинает светиться сам
	"Звёздный потрошитель",  # 14. Очень мощный клик
	"Радиоактивный туман",   # 15. Экран становится всё ярче
	"Сердце карлика",        # 16. Невероятная плотность
	"Фотонный распад",       # 17. Материя превращается в свет
	"Голос солнца",          # 18. Ты слышишь сияние
	"Сингулярность света",   # 19. Предпоследний шаг
	"Апофеоз"                # 20. Финальный выбор
]



func _ready():
	load_game()
	create_upgrade_buttons()
	apply_audio()
	
	var g = bg_gradient.texture.gradient
	g.colors = [
	Color(0.02, 0.02, 0.02), # почти чёрный
	Color(0.5, 0.5, 0.5),   # серый
	Color(1.0, 0.9, 0.4),   # жёлтый
	Color(1.0, 1.0, 1.0)    # белый
	]
	g.offsets = [0.0, 0.4, 0.75, 1.0]
	
	$AutoClickTimer.timeout.connect(_on_auto_click)
	
	# Начальная настройка UI
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
	var t = create_tween()
	t.tween_property(white_fade, "modulate:a", 1.0, 3.0)
	t.finished.connect(func():
		save_game()
	)
	
func _process(_delta):
	if game_over: return
	
	if int(Time.get_ticks_msec()) % 2000 < 16:
		save_game()
	stone_btn.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.02)
	# Динамический текст с дрожанием, если радиация высокая
	score_label.text = "КАМНИ: %s" % String.num_int64(int(score)).insert(3, " ")
	score_label.modulate = Color(1, 1, 1).lerp(Color(1, 0.5, 0), radiation_level)
	score_label.rotation = sin(Time.get_ticks_msec() * 0.01) * radiation_level * 0.05
	# Оживляем фон (плавное перетекание цвета)
	var glow = clamp(radiation_level, 0.0, 1.2)
	bg_gradient.modulate = Color(
	1.0 + glow,
	1.0 + glow * 0.9,
	1.0 + glow * 0.5
	)
	var t = Time.get_ticks_msec() * 0.00005
	bg_gradient.material.set_shader_parameter("offset", t)
	# Свечение мира
	env.adjustment_brightness = 1.0 + (radiation_level * 4.0)
	env.glow_strength = 0.5 + (radiation_level * 1.5)

func ending_reset():
	delete_save()
	choice_panel.visible = false
	
	

# --- Логика клика ---
func _on_stone_pressed():
	if game_over: return
	
	# Эффект нажатия (камень сжимается и разжимается)
	var tween = create_tween()
	stone_btn.pivot_offset = stone_btn.size / 2
	tween.tween_property(stone_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(stone_btn, "scale", Vector2(1.0, 1.0), 0.1)
	
	var gain = click_power
	var is_solar = randf() < 0.05 + (radiation_level * 0.1)
	
	if is_solar:
		gain *= 10
		radiation_level += 0.002
		play_sound("SoundSolar")
		screen_shake(0.3, 15) # Тряска экрана при солнечном камне
		spawn_click_effect("СОЛНЦЕ!", true)
	else:
		play_sound("SoundClick")
		spawn_click_effect("+" + str(int(gain)), false)
	
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
	
# --- Анимации и Эффекты ---
func screen_shake(duration, intensity):
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", offset, duration / 10)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func spawn_click_effect(txt, is_solar):
	var l = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 30 if is_solar else 20)
	l.position = get_global_mouse_position() + Vector2(randf_range(-20, 20), -20)
	add_child(l)
	
	var t = create_tween().set_parallel(true)
	t.tween_property(l, "modulate:a", 0, 0.8)
	t.tween_property(l, "scale", Vector2(1.5, 1.5), 0.8)
	t.finished.connect(l.queue_free)

func spawn_auto_visual():
	# Двигающаяся "солнечная искра"
	var sprite = Label.new()
	sprite.text = "✦"
	sprite.position = Vector2(randi_range(50, 500), 700)
	add_child(sprite)
	
	var t = create_tween()
	t.tween_property(sprite, "position:y", 200, 1.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(sprite, "position:x", sprite.position.x + randi_range(-100, 100), 1.5)
	t.parallel().tween_property(sprite, "modulate:a", 0, 1.5)
	t.finished.connect(sprite.queue_free)

# --- Звуки ---
func play_sound(sound_name):
	var player = get_node_or_null(sound_name)
	if player:
		player.pitch_scale = randf_range(0.9, 1.1) # Меняем высоту звука для разнообразия
		player.play()

# --- Покупка и выбор ---
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

# --- Служебное ---
func setups_upgrades():
	for i in range(20):
		var n = upgrade_names[i] if i < upgrade_names.size() else "Забытый артефакт " + str(i)
		upgrades.append({
			"name": n,
			"cost": pow(2.5, i) * 20,
			"power": pow(1.8, i)
		})

func create_upgrade_buttons():
	for i in range(upgrades.size()):
		var btn = Button.new()
		update_button_text(btn, i)
		btn.pressed.connect(func(): buy_upgrade(i, btn))
		upgrade_container.add_child(btn)

func update_button_text(btn, index):
	btn.text = "%s\nЦена: %d" % [upgrades[index].name, int(upgrades[index].cost)]

func _on_auto_click():
	if game_over: return
	if auto_click_power > 0:
		score += auto_click_power
		spawn_auto_visual()

func trigger_ending_choice():
	game_over = true
	choice_panel.visible = true
	# Плавное появление панели выбора
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
		"sfx_volume": sfx_volume
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

	
	
	
