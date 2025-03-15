extends PanelContainer
@onready var world_map = $"../WorldMap"  # Путь к вашей TileMap ноде
@onready var label = $"MarginContainer/Label"
@onready var obvodka = $"Obvodka"
@onready var pressed = $"Pressed"

@export var animation_duration: float = 0.2
@export var max_scale: float = 0.4  # Максимальный масштаб
@export var outline_color: Color = Color.WHITE
@export var outline_width: float = 2.0

var tween: Tween
var outline_tween: Tween  # Отдельный tween для анимации обводки
var current_cell: Vector2i
var selected: bool
var select_sound = preload("res://SoundDesign/Guitar_Pedal_B_6.wav")

signal panel_clicked(cell_position: Vector2i)

func _ready():
	# Инициализируем обводку с прозрачностью 0
	obvodka.visible = true
	obvodka.modulate.a = 0
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func show_context_pos(cell: Vector2i):
	# Останавливаем предыдущий tween, если он еще активен
	current_cell = cell
	
	if tween and tween.is_valid():
		tween.kill()
	
	# Сбрасываем обводку
	if outline_tween and outline_tween.is_valid():
		outline_tween.kill()
	obvodka.modulate.a = 0
	
	# Устанавливаем начальную позицию
	position = world_map.map_to_local(cell)
	position.y -= size.y/2 * max_scale  # Учитываем новый масштаб
	if cell.x >= world_map.Width - 2:
		position.x -= 25
	else:
		position.x += 6
	
	# Устанавливаем начальные значения для анимации
	modulate.a = 0  # Прозрачность
	scale = Vector2(0.2, 0.2)  # Начальный масштаб (половина от максимального)
	visible = true  # Делаем видимым перед началом анимации
	label.text = "Enter"
	
	# Создаем новый tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Анимируем свойства
	tween.parallel().tween_property(self, "modulate:a", 1.0, animation_duration)
	tween.parallel().tween_property(self, "scale", Vector2(max_scale, max_scale), animation_duration)

func hide_context_pos():
	# Останавливаем предыдущий tween, если он еще активен
	if tween and tween.is_valid():
		tween.kill()
	
	# Скрываем обводку плавно
	if outline_tween and outline_tween.is_valid():
		outline_tween.kill()
	
	outline_tween = create_tween()
	outline_tween.tween_property(obvodka, "modulate:a", 0.0, animation_duration / 2)
	
	# Создаем новый tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Анимируем свойства
	tween.parallel().tween_property(self, "modulate:a", 0.0, animation_duration)
	tween.parallel().tween_property(self, "scale", Vector2(0.2, 0.2), animation_duration)
	
	# После завершения анимации скрываем элемент
	tween.tween_callback(func(): visible = false)

func _on_mouse_entered():
	selected = true
	# Создаем анимацию появления обводки
	if outline_tween and outline_tween.is_valid():
		outline_tween.kill()
	
	outline_tween = create_tween()
	outline_tween.set_ease(Tween.EASE_OUT)
	outline_tween.tween_property(obvodka, "modulate:a", 1.0, animation_duration)

func _on_mouse_exited():
	selected = false
	# Создаем анимацию исчезновения обводки
	if outline_tween and outline_tween.is_valid():
		outline_tween.kill()
	
	outline_tween = create_tween()
	outline_tween.set_ease(Tween.EASE_IN)
	outline_tween.tween_property(obvodka, "modulate:a", 0.0, animation_duration)

func _on_gui_input(event: InputEvent) -> void:
	# Проверяем, было ли это нажатие левой кнопки мыши
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_panel_clicked()
		
func _on_panel_clicked() -> void:
	# Анимация нажатия (используем узел pressed)
	if pressed:
		# Показываем эффект нажатия
		pressed.visible = true
		
		# Создаем tween для анимации эффекта нажатия
		var press_tween = create_tween()
		press_tween.set_ease(Tween.EASE_OUT)
		
		# Показываем и скрываем эффект нажатия
		Utils._playSound(select_sound,0.8,1.2,-15)
		press_tween.tween_property(pressed, "modulate:a", 1.0, animation_duration * 0.5)
		press_tween.tween_property(pressed, "modulate:a", 0.0, animation_duration * 0.5)
		
		# После завершения анимации скрываем эффект
		press_tween.tween_callback(func(): pressed.visible = false)
	
	# Эмитируем сигнал с текущей позицией ячейки
	emit_signal("panel_clicked", current_cell)
	
	# Здесь можно добавить любую дополнительную логику, 
	# которая должна выполняться при клике
	print("PanelContainer clicked at cell: ", current_cell)
