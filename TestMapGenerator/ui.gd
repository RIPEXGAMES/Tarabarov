class_name GameHUD
extends CanvasLayer

# Ссылки на элементы интерфейса
@onready var ap_label: RichTextLabel = $MarginContainer/PanelContainer/RichTextLabel
@onready var turn_label: Label = $TurnLabel
@onready var end_turn_button: Button = $EndTurnButton
@onready var game_state_label: Label = $GameStateLabel

# Добавляем переменную для хранения текущей стоимости пути
var current_path_cost: int = 0

# Переменные для эффекта печатной машинки
var full_cost_text: String = ""
var current_displayed_text: String = ""
var typing_tween: Tween

# Ссылка на персонажа и контроллер игры
@export var character_path: NodePath = "../Character"
@export var game_controller_path: NodePath = "../GameController"

@onready var character: Node2D = $"../Character"
@onready var game_controller: Node = $"../GameContoller"

func _ready():
	print("GameHUD._ready() started")
	# Проверяем, что ссылки действительны
	if not character:
		push_error("Character not found at path: " + str(character_path))
	else:
		print("Character found")
		# Подключаем сигнал изменения стоимости пути
		character.connect("path_cost_changed", _on_path_cost_changed)
	
	if not game_controller:
		push_error("GameController not found at path: " + str(game_controller_path))
	else:
		print("GameController found")
		# Подключаем сигнал изменения хода
		if game_controller.has_signal("turn_changed"):
			game_controller.connect("turn_changed", _on_game_controller_turn_changed)
			print("Connected to turn_changed signal")
	
	# Подключаем кнопку завершения хода
	if end_turn_button:
		end_turn_button.connect("pressed", _on_end_turn_button_pressed)
		print("Connected end turn button")
	
	# Инициализация UI
	update_ap_display()
	update_turn_display()
	update_game_state()
	print("GameHUD initialized, turn display status:", "ok" if game_controller else "failed")

func _process(_delta):
	# Обновляем информацию на UI
	update_ap_display()
	update_turn_display()
	update_end_turn_button()
	update_game_state()
	
# Добавляем обработчик сигнала изменения стоимости пути
func _on_path_cost_changed(cost: int):
	current_path_cost = cost
	
	# Если есть активная анимация, останавливаем её
	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()
	
	if cost > 0:
		# Создаем полный текст для отображения
		full_cost_text = "(-%d)" % cost
		
		# Запускаем новую анимацию
		start_typing_animation()
	else:
		full_cost_text = ""
		current_displayed_text = ""
		update_ap_display()

# Анимация печатной машинки, ограниченная 0.2 секундами
func start_typing_animation():
	# Сбрасываем текст
	current_displayed_text = ""
	
	# Создаем новый Tween
	typing_tween = create_tween()
	
	# Рассчитываем задержку между символами, чтобы уложиться в 0.2 секунды
	var char_count = full_cost_text.length()
	var delay_per_char = 0.2 / char_count if char_count > 0 else 0.05
	
	# Для каждого символа добавляем шаг анимации
	for i in range(1, char_count + 1):
		var partial_text = full_cost_text.substr(0, i)
		
		typing_tween.tween_callback(func(): 
			current_displayed_text = partial_text
		)
		typing_tween.tween_interval(delay_per_char)

# Обновление отображения очков действия
func update_ap_display():
	if character:
		if current_path_cost > 0:
			if typing_tween and typing_tween.is_valid() and current_displayed_text != "":
				# Отображаем текущий прогресс анимации с красным цветом
				ap_label.bbcode_text = "AP: %d [color=red]%s[/color]" % [character.remaining_ap, current_displayed_text]
			else:
				# Отображаем полный текст, если анимация завершена или не начата
				ap_label.bbcode_text = "AP: %d [color=red](-%d)[/color]" % [character.remaining_ap, current_path_cost]
		else:
			ap_label.bbcode_text = "AP: %d" % character.remaining_ap
	else:
		ap_label.bbcode_text = "AP: ?"

# Обновление отображения текущего хода
func update_turn_display():
	if game_controller:
		turn_label.text = "Ход: %d" % game_controller.current_turn
	else:
		turn_label.text = "Ход: ?"

# Обновление состояния кнопки завершения хода
func update_end_turn_button():
	if end_turn_button and game_controller:
		# Кнопка активна только во время хода игрока
		end_turn_button.disabled = not game_controller.can_player_act()

# Обновление информации о состоянии игры
func update_game_state():
	if game_state_label and game_controller:
		if game_controller.can_player_act():
			game_state_label.text = "Ваш ход"
		else:
			game_state_label.text = "Ход противника"

# Обработчик нажатия на кнопку завершения хода
func _on_end_turn_button_pressed():
	if character:
		print("End turn button pressed")
		character.end_turn()

# Подключаем сигнал изменения хода
func _on_game_controller_turn_changed():
	print("Turn changed signal received in GameHUD")
	update_turn_display()
