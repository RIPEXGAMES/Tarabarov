extends Control

@onready var label: Label = $PanelContainer/MarginContainer/Label


func update(minutes: int):
	var HHMM = Utils._minutesToHHMM(minutes)
	label.text = HHMM
