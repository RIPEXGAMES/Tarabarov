extends PanelContainer

@onready var label: Label = $MarginContainer/Label


func update(minutes: int):
	var HHMM = Utils._minutesToHHMM(minutes)
	label.text = HHMM
