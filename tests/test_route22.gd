extends SceneTree
# Raccord Jadielle <-> Route 22 et arbustes de Jadielle
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
	ok(carte.dans_carte(Vector2i(-14, -63)), "route 22 chargee a cote de Jadielle")
	# parcours : de Jadielle (x=-12) jusqu'a la case devant la porte de la route 22 (11,6) -> (-52,-63)
	var depart := Vector2i(-12, -63)
	var but := Vector2i(-52, -63)
	var vus := {depart: true}
	var file: Array = [depart]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not vus.has(n) and carte.dans_carte(n) and not carte.solide(n) and carte.symbole(n) != "p":
				vus[n] = true
				file.append(n)
	ok(vus.has(but), "chemin libre de Jadielle jusqu'a la porte de la route 22")
	ok(vus.has(Vector2i(-13, -60)) and vus.has(Vector2i(-13, -63)), "les 4 lignes du raccord sont praticables")
	ok(carte.solide(Vector2i(-13, -64)) , "au dessus du raccord : mur (%s)" % carte.symbole(Vector2i(-13, -64)))
	ok(carte.solide(Vector2i(-13, -59)), "en dessous du raccord : mur (%s)" % carte.symbole(Vector2i(-13, -59)))
	# arbustes de Jadielle
	var n := 0
	for y in range(-79, -40):
		for x in range(-12, 40):
			if carte.est_coupable(Vector2i(x, y)): n += 1
	ok(n == 2, "2 arbustes coupables a Jadielle (%d)" % n)
	print("ERREURS: ", erreurs)
	quit(1 if erreurs > 0 else 0)
