extends Node2D
# Le joueur se deplace case par case. Il ne connait pas la carte : il demande a "jeu".

signal arrive(case: Vector2i)

const DUREE_PAS := 0.16

var case := Vector2i.ZERO
var direction := Vector2i.DOWN
var _hauteur := 0.0   # decalage vers le haut pendant un saut
var bloque := false   # vrai pendant un dialogue ou une transition
var _en_marche := false
var _jeu

func installer(jeu) -> void:
	_jeu = jeu

func placer(c: Vector2i) -> void:
	case = c
	position = Vector2(c * 16)

func _process(_delta: float) -> void:
	if _en_marche or bloque:
		return
	var d := Vector2i.ZERO
	if Input.is_action_pressed("haut"): d = Vector2i.UP
	elif Input.is_action_pressed("bas"): d = Vector2i.DOWN
	elif Input.is_action_pressed("gauche"): d = Vector2i.LEFT
	elif Input.is_action_pressed("droite"): d = Vector2i.RIGHT
	if d != Vector2i.ZERO:
		deplacer(d)

# renvoie vrai si le joueur avance d'une case
func deplacer(d: Vector2i) -> bool:
	direction = d
	queue_redraw()
	var cible := case + d
	if _jeu.case_bloquee(cible, d):
		return false
	var saut: bool = _jeu.carte.sens_unique(cible) == d   # rebord franchi dans le bon sens : on saute par-dessus
	if saut:
		cible = case + d * 2
		if _jeu.case_bloquee(cible, d):
			return false
	case = cible
	_en_marche = true
	var tween := create_tween()
	if saut:
		tween.tween_property(self, "position", Vector2(case * 16), DUREE_PAS * 2.0)
		var arc := create_tween()
		arc.tween_method(func(t: float): _hauteur = sin(t * PI) * 8.0; queue_redraw(), 0.0, 1.0, DUREE_PAS * 2.0)
	else:
		tween.tween_property(self, "position", Vector2(case * 16), DUREE_PAS)
	tween.finished.connect(_fin_pas)
	return true

func _fin_pas() -> void:
	_en_marche = false
	arrive.emit(case)

func en_marche() -> bool:
	return _en_marche

func _draw() -> void:
	draw_rect(Rect2(2, 2 - _hauteur, 12, 12), Color("#d23b3b"))
	# petit repere pour voir la direction
	var centre := Vector2(8, 8 - _hauteur) + Vector2(direction) * 5
	draw_rect(Rect2(centre - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
