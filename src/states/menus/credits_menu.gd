extends Control


signal change_menu(to_menu: String)

var main_licenses := [
	["Godot Engine", Engine.get_license_text()],
	["Kenney Assets", "This project uses assets created/distributed by Kenney (www.kenney.nl)\n\nLicensed under CC0:\nhttps://creativecommons.org/publicdomain/zero/1.0/"],
	["Boxfont Round Font", "Boxfont Round designed by mold.\n\nhttps://fontlibrary.org/en/font/boxfont-round\n\nLicensed under CC0:\nhttps://creativecommons.org/publicdomain/zero/1.0/"],
	["Aileron Font", "Aileron designed by Sora Sagano 佐賀野宇宙 from TipoType.\n\nLicensed under CC0:\nhttps://creativecommons.org/publicdomain/zero/1.0/"],
	["DejaVu Markup Font", FileAccess.get_file_as_string("res://assets/fonts/DejaVuMarkup-LICENSE.txt")],
]

@onready var licenses_label: RichTextLabel = %LicensesLabel
@onready var third_party_label: RichTextLabel = %ThirdPartyLabel


func _ready() -> void:
	licenses_label.push_outline_color(Color.BLACK)
	var first := true
	for license in main_licenses:
		if first:
			first = false
		else:
			licenses_label.append_text("\n\n")
		licenses_label.append_text("[center][outline_size=8][b]" + license[0] + "[/b][/outline_size][/center]\n\n")
		licenses_label.append_text(license[1])
	licenses_label.pop()

	# These engine license/copyright functions are not incredibly obvious how to usefully extract information from.
	# This is similar to how it's done in the "About Godot" -> "Third-party Licenses" -> "All Components" screen
	third_party_label.push_outline_color(Color.BLACK)
	first = true
	for info in Engine.get_copyright_info():
		if first:
			first = false
		else:
			third_party_label.append_text("\n\n")
		third_party_label.append_text("[center][outline_size=6][b]" + info.name + "[/b][/outline_size][/center]\n")
		for part: Dictionary in info.parts:
			for copyright: String in part.copyright:
				third_party_label.append_text("\n(c) " + copyright)
			third_party_label.append_text("\nLicense: " + part.license)

	var engine_licenses := Engine.get_license_info()
	for license: String in engine_licenses:
		third_party_label.append_text("\n\n[center][outline_size=6][b]" + license + "[/b][/outline_size][/center]\n\n")
		third_party_label.append_text(engine_licenses[license])
	third_party_label.pop()


func back_to_menu() -> void:
	change_menu.emit("main_menu")
