extends Node3D

@export_file("*.dtl") var dialog_timeline_path: String

var player_in_area: bool = false
var is_chatting: bool = false


func _process(_delta: float) -> void:
	if not player_in_area:
		return

	if is_chatting:
		return

	if Input.is_action_just_pressed("dialogic_default_action"):
		_start_dialog()


func _start_dialog() -> void:
	if dialog_timeline_path == "":
		push_warning("NPC %s no tiene dialog_timeline_path asignado" % name)
		return

	is_chatting = true
	Dialogic.start(dialog_timeline_path)


func _on_area_3d_body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.name == "Player":
		player_in_area = true


func _on_area_3d_body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.name == "Player":
		player_in_area = false
		is_chatting = false  # opcional: permitir hablar otra vez al alejarse
