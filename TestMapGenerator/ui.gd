class_name GameHUD
extends CanvasLayer

# Ссылки на элементы интерфейса
@onready var ap_label: Label = $APLabel
@onready var turn_label: Label = $TurnLabel
@onready var end_turn_button: Button = $EndTurnButton
@onready var game_state_label: Label = $GameStateLabel



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

# Обновление отображения очков действия
func update_ap_display():
	if character:
		ap_label.text = "Очки действия: %d/%d" % [character.remaining_ap, character.action_points]
	else:
		ap_label.text = "Очки действия: ?/?"

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
