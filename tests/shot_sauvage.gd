extends SceneTree
func _init() -> void:
	load("res://scripts/pokemon.gd").deterministe = false
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(1, "ASH")
	main.donner_pokemon("salameche", 8)
	main.equipe[0].pv = 14
	main.equipe[0].statut = "brulure"
	var s = load("res://scripts/pokemon.gd").creer("roucool", 4, {"shiny": true, "genre": "f"})
	main.combat.combat_sauvage(main.equipe, s)
	for i in 4:
		await create_timer(0.35).timeout
		main.combat.appuyer("action")
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b8e6c5b6-4da0-50f6-9f78-af2fa025ba13/scratchpad/out3/s_menu.png")
	main.combat.appuyer("bas")
	main.combat.appuyer("action")  # SAC? (index 2 = POKEMON)
	await create_timer(0.4).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b8e6c5b6-4da0-50f6-9f78-af2fa025ba13/scratchpad/out3/s_sous.png")
	quit()
