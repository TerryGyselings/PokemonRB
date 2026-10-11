extends SceneTree
# Rebords de la Route 1 : franchissables seulement vers le bas (saut par-dessus), jamais dans l'autre sens.
# Verifie aussi que la Route 1 (40 lignes) ne se superpose pas au bourg (data/monde.json).
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = true
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	var o := Vector2i(0, -40)     # coin haut-gauche de la Route 1 dans le monde
	main.charger_carte("bourg_palette", Vector2i(12, 3))
	ok(main.carte.origine.y == -156 and main.carte.hauteur == 178, "monde : hauteur %d (77 + 39 + 40 + 22)" % main.carte.hauteur)
	ok(main.carte.region_id_a(Vector2i(12, -1)) == "route_1" and main.carte.region_id_a(Vector2i(12, 0)) == "bourg_palette", "pas de superposition")
	ok(main.carte.symbole(Vector2i(12, -1)) == "g" or main.carte.symbole(Vector2i(12, -1)) == "", "raccord au bourg (symbole %s)" % main.carte.symbole(Vector2i(12, -1)))
	var rebord := o + Vector2i(3, 5)
	ok(main.carte.symbole(rebord) == "l", "(3,5) de la Route 1 est un rebord")
	ok(main.case_bloquee(rebord, Vector2i.RIGHT) and main.case_bloquee(rebord, Vector2i.LEFT), "rebord bloque de cote")
	ok(main.case_bloquee(rebord, Vector2i.UP), "rebord bloque du bas vers le haut")
	ok(not main.case_bloquee(rebord, Vector2i.DOWN), "rebord franchissable vers le bas")
	main.charger_carte("bourg_palette", o + Vector2i(3, 4))
	j.deplacer(Vector2i.DOWN)
	await create_timer(0.5).timeout
	ok(j.case == o + Vector2i(3, 6), "du haut vers le bas : saut par-dessus le rebord (%s)" % j.case)
	ok(not j.deplacer(Vector2i.UP) and j.case == o + Vector2i(3, 6), "retour impossible")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
