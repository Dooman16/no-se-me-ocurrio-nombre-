extends Node

@export var MAX_LIFE : int 
@export var MAX_CORE_HIT_AMOUNT : int 
const GOLPE = preload("res://src/Assets/Sounds/Sonidos/Golpe.mp3")
var life : int
var core_hit_amount : int
var managable_entity : Node2D
signal Hitted

func _ready():
	life = MAX_LIFE
	core_hit_amount = MAX_CORE_HIT_AMOUNT
	actualizarBarra()

func what_to_do_if_you_get_hit(type, damage, origin):
	#COMMENT IMPORTANTE En relación con el diseño: En un principio hablamos de la idea de que el jugador pudiera hacer un parry. Al final nos decantamos por la precisión.
	# En este caso, habría que penalizar al jugador por no ser preciso, pero tampoco tanto. 
	# Al arrojar la lanza: Tiene sentido que no sea golpe crítico cuando no le da al cuadrado hiperpequeño, pero debería hacer algún daño significativo si pega en la cabeza, no lo sé, un tercio de la vida. También se puede usar la potencia de la lanza para decidir el daño, aunque en este caso haría que el jugador se mueva mucho más lento mientras está cargando.
	# Melee: Estaría bueno que empuje significativamente a los enemigos, ya que los queremos a distancia para poder golpearlos arrojando. Y que no haga daño o haga mucho menos daño tiene mucho sentido, para que el jugador se centre en la mecánica que queremos que use.
	var x_diference = managable_entity.global_position.x - origin.x
	var knockback_direction = x_diference / abs(x_diference)
	managable_entity.disable_hitbox(knockback_direction)

	if type == Enums.type.CORE:
		managable_entity.get_node("Explosion").activate()
		core_hit_amount -= 1
		life -= int(MAX_LIFE / MAX_CORE_HIT_AMOUNT)
	else:
		life -= damage
		var sound := AudioStreamPlayer.new()
		sound.stream = GOLPE
		add_child(sound)
		sound.play()
		await sound.finished
	actualizarBarra()
	
	if life <= 0 or core_hit_amount <= 0:
		kill()

func kill():
	managable_entity.kill()

func actualizarBarra():
	$ProgressBar.value=float(life)/float(MAX_LIFE)
