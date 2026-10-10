extends RefCounted
# Trois emplacements de sauvegarde : user://sauvegardes/slot_1.json ... slot_3.json
# (sous Windows : %APPDATA%\Godot\app_userdata\PokemonRB\sauvegardes)

const NB_SLOTS := 3
const VERSION := 1

static var dossier := "user://sauvegardes"   # change par les tests

static func chemin(slot: int) -> String:
	return "%s/slot_%d.json" % [dossier, slot]

static func existe(slot: int) -> bool:
	return FileAccess.file_exists(chemin(slot))

static func lire(slot: int) -> Dictionary:
	if not existe(slot):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin(slot))) != OK or not (json.data is Dictionary):
		push_warning("Sauvegarde %d illisible" % slot)
		return {}
	return json.data

static func ecrire(slot: int, donnees: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dossier)
	var d := donnees.duplicate(true)
	d["version"] = VERSION
	# ecriture dans un fichier temporaire puis renommage : une coupure ne detruit pas l'ancienne sauvegarde
	var tmp := chemin(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'ecrire la sauvegarde %d (erreur %d)" % [slot, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, chemin(slot)) == OK

static func supprimer(slot: int) -> void:
	if existe(slot):
		DirAccess.remove_absolute(chemin(slot))

static func temps_texte(secondes: float) -> String:
	var s := int(secondes)
	return "%d:%02d" % [s / 3600, (s / 60) % 60]

# ligne de resume affichee dans les listes ("ROUGE  2 badges  Pokedex 3  1:25")
static func resume(slot: int) -> String:
	var d := lire(slot)
	if d.is_empty():
		return "- VIDE -"
	return "%s   %s   Dex %d   %d bad." % [String(d.get("nom", "?")), temps_texte(float(d.get("temps", 0))),
		(d.get("captures", []) as Array).size(), (d.get("badges", []) as Array).size()]
