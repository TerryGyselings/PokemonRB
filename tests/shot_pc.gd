extends SceneTree
func _init() -> void:
	var P = load("res://scripts/pokemon.gd")
	var main = load("res://scene/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.nouvelle_partie(1, "ASH")
	main.donner_pokemon("salameche", 12)
	main.recevoir_pokemon(P.creer("pikachu", 7, {"shiny": true}))
	var noms := ["rattata", "roucool", "nidoran_f", "sabelette", "piafabec", "abra", "machoc", "tentacool", "ponyta", "evoli", "magicarpe", "psykokwak"]
	for i in noms.size():
		main.boites[0][i * 2 % 30] = P.creer(noms[i], 3 + i)
	main.pc.ouvrir()
	await create_timer(0.2).timeout
	main.pc.appuyer("gauche")
	await create_timer(0.2).timeout
	main.pc.appuyer("bas")
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b8e6c5b6-4da0-50f6-9f78-af2fa025ba13/scratchpad/out3/pc1.png")
	main.pc.appuyer("action")
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/b8e6c5b6-4da0-50f6-9f78-af2fa025ba13/scratchpad/out3/pc2.png")
	quit()
