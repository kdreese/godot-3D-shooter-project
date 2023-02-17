extends Control


onready var main_menu: CenterContainer = $"%MainMenu"
onready var credits_menu: Control = $"%CreditsMenu"
onready var lobby: Control = $"%Lobby"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_menu.connect("change_menu", self, "show_menu")
	credits_menu.connect("change_menu", self, "show_menu")
	lobby.connect("change_menu", self, "show_menu")
	show_menu(Global.menu_to_load)


func show_menu(menu: String) -> void:
	main_menu.hide()
	credits_menu.hide()
	lobby.hide()
	if menu == "main_menu":
		main_menu.show()
	elif menu == "credits_menu":
		credits_menu.show()
	elif menu == "lobby":
		lobby.show()
		lobby.show_menu()
	else:
		push_warning("Invalid menu string %s" % menu)
	Global.menu_to_load = menu



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
