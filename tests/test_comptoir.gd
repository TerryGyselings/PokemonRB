extends SceneTree
# Parler par-dessus un comptoir : infirmiere (centre) et vendeur (boutique), au clavier et a la souris.
var erreurs := 0
func ok(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c: erreurs += 1
func clic(main, c: Vector2i) -> void:
	var e := InputEventMouseButton.new()
	e.position = main.get_canvas_transform() * (Vector2(c * 16) + Vector2(8, 8))
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	main._input(e)
	await process_frame
func ferme(main) -> void:
	while main.boite.visible:
		var e := InputEventAction.new()
		e.action = "action"
		e.pressed = true
		main._unhandled_input(e)
		await process_frame
func attendre_boite(main) -> void:
	var n := 0
	while not main.boite.visible and n < 80:
		await create_timer(0.05).timeout
		n += 1
func _init() -> void:
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var j = main.joueur
	# --- boutique : vendeur derriere le comptoir en (3,2) ; comptoir en (4,2) et (3,3)
	main.charger_carte("boutique_jadielle", Vector2i(5, 2))
	for i in 3: await process_frame
	var v = main.pnj_a(Vector2i(3, 2))
	ok(v != null and v.donnees["id"] == "boutique_vendeur", "le vendeur est derriere le comptoir")
	j.direction = Vector2i.LEFT
	main._interagir(j.case + j.direction)
	ok(main.boite.visible and main.texte.text == "Bienvenue !", "action face au comptoir (4,2) : le vendeur repond")
	await ferme(main)
	# comptoir sans personne derriere : rien
	j.placer(Vector2i(5, 1))
	j.direction = Vector2i.LEFT
	main._interagir(j.case + j.direction)
	ok(not main.boite.visible, "comptoir (4,1) sans personne derriere : rien")
	# clic sur le vendeur de loin : on marche devant le comptoir et on lui parle
	j.placer(Vector2i(8, 6))
	await clic(main, Vector2i(3, 2))
	await attendre_boite(main)
	ok(main.boite.visible and main.texte.text == "Bienvenue !", "clic sur le vendeur : le joueur vient devant le comptoir (%s)" % j.case)
	await ferme(main)
	# clic sur le comptoir
	j.placer(Vector2i(8, 6))
	await clic(main, Vector2i(4, 2))
	await attendre_boite(main)
	ok(main.boite.visible and main.texte.text == "Bienvenue !", "clic sur le comptoir : meme resultat")
	await ferme(main)
	# --- centre : infirmiere en (8,1), comptoir en (8,2), joueur en (8,3)
	main.poser_drapeau("starter_choisi")
	main.charger_carte("centre_pokemon_jadielle", Vector2i(8, 3))
	for i in 3: await process_frame
	ok(main.pnj_a(Vector2i(8, 1)) != null, "l'infirmiere est derriere le comptoir")
	j.direction = Vector2i.UP
	main._interagir(j.case + j.direction)
	var n := 0
	while main.pnj_a(Vector2i(8, 1)) != null and not main.boite.visible and n < 40:
		await create_timer(0.05).timeout
		n += 1
	ok(main.boite.visible or main.evenement_en_cours, "action face au comptoir : l'infirmiere lance le soin")
	print("=== ERREURS : ", erreurs)
	quit(1 if erreurs > 0 else 0)
