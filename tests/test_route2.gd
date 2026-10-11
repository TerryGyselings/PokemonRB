extends SceneTree
# Raccord Jadielle <-> Route 2 et portes de la route 2
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.charger_carte("jadielle", Vector2i(-11, -63))
	var carte = main.carte
	ok(carte.dans_carte(Vector2i(5, -156)) and carte.dans_carte(Vector2i(5, -80)), "route 2 chargee au nord de Jadielle")
	# les 5 colonnes de sortie de Jadielle (x=7..11) doivent rejoindre celles de la route 2
	for x in range(7, 12):
		ok(not carte.solide(Vector2i(x, -80)) and not carte.solide(Vector2i(x, -79)), "continuite a x=%d (route 2 / Jadielle)" % x)
	ok(carte.solide(Vector2i(6, -80)) and carte.solide(Vector2i(12, -80)), "murs de part et d'autre du raccord")
	# portes de la route 2 : chaque porte est sur une case 'p'
	var portes := 0
	for y in range(-156, -79):
		for x in range(0, 24):
			if carte.symbole(Vector2i(x, y)) == "p": portes += 1
	ok(portes == 10, "10 cases porte dans la route 2 (%d)" % portes)
	print("ERREURS: ", erreurs)
	quit(1 if erreurs > 0 else 0)
