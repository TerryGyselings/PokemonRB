extends Node2D
# Un personnage non joueur place par le JSON de la carte (liste "pnj").
# Champs : id, nom, x, y, direction ("haut" "bas" "gauche" "droite"), couleur, texte [pages],
#          visible_si (drapeau), cache_si (drapeau), pose (drapeau pose apres le dialogue),
#          evenement (id d'evenement joue a la place du texte quand "si" / "si_pas" sont vrais),
#          objet (true : un objet pose sur une case, dessine en petit rond, pas de PNJ)

var donnees: Dictionary = {}
var case := Vector2i.ZERO
var direction := Vector2i.DOWN

static func vers_direction(nom: String) -> Vector2i:
	match nom:
		"haut": return Vector2i.UP
		"gauche": return Vector2i.LEFT
		"droite": return Vector2i.RIGHT
	return Vector2i.DOWN

func installer(d: Dictionary) -> void:
	donnees = d
	case = Vector2i(int(d["x"]), int(d["y"]))
	direction = vers_direction(String(d.get("direction", "bas")))
	position = Vector2(case * 16)
	z_index = 1
	queue_redraw()

const DUREE_PAS := 0.16

func _nom_direction() -> String:
	if direction == Vector2i.UP: return "haut"
	if direction == Vector2i.LEFT: return "gauche"
	if direction == Vector2i.RIGHT: return "droite"
	return "bas"

# garde la position et la direction dans les donnees (pour qu'un PNJ qui a marche ne revienne pas a sa place)
func sauver() -> void:
	_sauver()

func _sauver() -> void:
	donnees["x"] = case.x
	donnees["y"] = case.y
	donnees["direction"] = _nom_direction()

# un pas vers la case voisine c ; renvoie le tween (a attendre avec await t.finished)
func pas(c: Vector2i) -> Tween:
	var delta: Vector2i = c - case
	if delta != Vector2i.ZERO:
		direction = Vector2i(signi(delta.x), signi(delta.y))
	queue_redraw()
	case = c
	var t := create_tween()
	t.tween_property(self, "position", Vector2(c * 16), DUREE_PAS)
	return t

# marche case par case le long d'un chemin (liste de Vector2i) ; a utiliser avec await
func marcher(cases: Array) -> void:
	for c in cases:
		await pas(c).finished
	_sauver()

# le PNJ se tourne vers le joueur qui lui parle
func tourner_vers(c: Vector2i) -> void:
	var delta := c - case
	if absi(delta.x) >= absi(delta.y):
		direction = Vector2i(signi(delta.x), 0)
	else:
		direction = Vector2i(0, signi(delta.y))
	_sauver()
	queue_redraw()

func _draw() -> void:
	if donnees.get("objet", false):   # un objet pose sur une case (ex : une POKe BALL) : petit rond
		draw_circle(Vector2(8, 8), 5.5, Color.BLACK)
		draw_circle(Vector2(8, 8), 4.5, Color(String(donnees.get("couleur", "#cc3333"))))
		return
	draw_rect(Rect2(2, 2, 12, 12), Color(String(donnees.get("couleur", "#cccccc"))))
	var centre := Vector2(8, 8) + Vector2(direction) * 5
	draw_rect(Rect2(centre - Vector2(2, 2), Vector2(4, 4)), Color.BLACK)
