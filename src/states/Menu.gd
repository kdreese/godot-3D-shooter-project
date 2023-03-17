extends Control


@onready var main_menu: Control = $"%MainMenu"
@onready var credits_menu: Control = $"%CreditsMenu"
@onready var lobby: Control = $"%Lobby"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_menu.change_menu.connect(self.show_menu)
	credits_menu.change_menu.connect(self.show_menu)
	lobby.change_menu.connect(self.show_menu)
	show_menu(Global.menu_to_load)


func show_menu(menu: String) -> void:
	main_menu.hide()
	credits_menu.hide()
	lobby.hide()
	if menu == "main_menu":
		main_menu.show()
		if Global.server_kicked:
			main_menu.show_popup("Server disconnected.")
			Global.server_kicked = false
	elif menu == "credits_menu":
		credits_menu.show()
	elif menu == "lobby":
		lobby.show()
		lobby.show_menu()
	else:
		push_warning("Invalid menu string %s" % menu)
	Global.menu_to_load = menu
