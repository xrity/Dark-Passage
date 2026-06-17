extends Area2D
## ============================================================
##  NPC  (пример использования диалогов)
##  Повесьте на Area2D с CollisionShape2D рядом с персонажем.
##  Когда игрок входит в зону — по нажатию "interact"
##  (назначьте клавишу, напр. E) запускается диалог.
## ============================================================

## Портрет говорящего (иконка слева).
@export var portrait: Texture2D
@export var npc_name: String = "Незнайомець"

@export_multiline var lines: Array[String] = [
	"Excuse me, how can I get to the Reservoir?",
	"Йди прямо, потім наліво.",
]

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or DialogueBox.is_active():
		return
	if event.is_action_pressed("interact"):  # назначьте Input Map: "interact"
		_talk()


func _talk() -> void:
	var dialogue: Array = []
	for text in lines:
		dialogue.append({"name": npc_name, "portrait": portrait, "text": text})
	DialogueBox.say(dialogue)
