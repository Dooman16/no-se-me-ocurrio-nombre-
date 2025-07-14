extends CharacterBody2D

const velocidad = 100
const velocidadSalto = -200
const KNOCKBACK_SPEED = Vector2(40,-100)
const DAMAGE = 20
var dirMov := Enums.direction.RIGHT
var estaVivo:bool = true
var attacking:bool = false
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var raycast2dDerecho: RayCast2D = $RayCast2DDerecho
@onready var raycast2dIzuierdo: RayCast2D = $RayCast2DIzuierdo
@onready var animation := $AnimatedSprite2D
@onready var explosion := $Explosion
const MUERTE_ENEMIGO = preload("res://src/Assets/Sounds/Sonidos/MuerteEnemigo.mp3")

func _ready() -> void:
	animation.play("default")
	$HitManager.managable_entity = self


	
func _physics_process(delta):
	if estaVivo and not attacking:
		if not is_on_floor():
			velocity += get_gravity()*delta
		if $iFrames.is_stopped():
			#COMMENT esto causa un brrrrrr en los bordes. Faltaría una forma de detectar que acaba de rebotar en el borde para que no lo haga indefinidamente.
			#	debería haber un flag en la clase "var can_flip:bool = true" que te permita detectar si acaba de darse vuelta (cuando el raycast deja de colisionar y pega la vuelta le ponés false), y en ese caso habría que detectar cuando el raycast vuelve a colisionar para ponerlo en true. Luego se usaría como condición. Ejemplifico en comentarios
			if dirMov == Enums.direction.RIGHT:
				velocity.x = velocidad
				if not raycast2dDerecho.is_colliding() and is_on_floor(): #and can_flip == true
					change_direction()
				#if raycast2dDerecho.is_colliding():
					#can_flip = true
			else:
				velocity.x = -1 * velocidad
				if not raycast2dIzuierdo.is_colliding() and is_on_floor(): #and can_flip == true
					change_direction()
				#if raycast2dIzuierdo.is_colliding():
					#can_flip = true
		if is_on_floor():
			if $wall.is_colliding() and not $jump_check.is_colliding():
				animation.play("jump")
				velocity.y += velocidadSalto
			elif $wall.is_colliding():
				change_direction()
		move_and_slide()
		if velocity.x != 0 and is_on_floor():
			animation.play("walk")
		if $range.is_colliding():
			attack()

func disable_hitbox(x_direction):
	$core/CollisionShape2D.disabled = true
	$CollisionShape2D.disabled = true
	velocity = KNOCKBACK_SPEED
	if x_direction == 1 and dirMov == Enums.direction.LEFT:
		animation.play("hit_front")
	else:
		animation.play("hit_back")
	velocity.x *= x_direction
	$iFrames.start()

func attack():
	attacking = true
	animation.position.y -= 3 
	$attack_hitbox.start()
	animation.play("attack")
	$cooldown.start()
	await  get_tree().create_timer(0.6).timeout
	if estaVivo:
		animation.position.y += 3 

func change_direction():
	#COMMENT Ejemplo de lo explicado arriba
	#if not can_flip:
		#return
	#can_flip = false
	if dirMov == Enums.direction.LEFT:
		dirMov = Enums.direction.RIGHT
	else:
		dirMov = Enums.direction.LEFT
	scale.x *= -1

func kill():
	#COMMENT: No era necesario armar todo este tema de guardar las posiciones. Solo tenían que desactivar los colliders, utilizar estaVivo para validar que no se mueva más ni ataque y listo.
	# Uno de los síntomas de este mal approach en el juego es que el personaje sigue siendo colisionable hasta que el sound se termina.
	estaVivo = false
	animation.play("death")
	await  get_tree().create_timer(1).timeout
	var pos_save = animation.global_position
	var pos_explosion_save = explosion.global_position
	remove_child(animation)
	remove_child(explosion)
	get_tree().current_scene.add_child(explosion)
	get_tree().current_scene.add_child(animation)
	animation.global_position = pos_save
	explosion.global_position = pos_explosion_save
	animation.global_scale = Vector2(1.5,1.5)
	
	#COMMENT Otro ejemplo de que se tiene que enviar un evento para que otro objeto haga lo que tiene que hacer. Le pedimos a otra cosa que reproduzca el sonido y nos olvidamos del await sound.finished.
	#	Además aclarar que unas lineas más arriba entendieron que un objeto hijo de knight se eliminaría ejecutando queue_free(), pero acá parecieron olvidarse de eso, si hubiesen hecho lo mismo que arriba no necesitaban el awake. 
	var sound := AudioStreamPlayer.new()
	sound.stream = MUERTE_ENEMIGO
	add_child(sound)
	sound.play()
	await sound.finished
	
	queue_free()


func _on_i_frames_timeout() -> void:
	$core/CollisionShape2D.disabled = false
	$CollisionShape2D.disabled = false


func _on_cooldown_timeout() -> void:
	attacking = false
	$Ataque/CollisionShape2D.disabled = true


func _on_animated_sprite_2d_animation_finished() -> void:
	if estaVivo:
		animation.play("default")
	


func _on_ataque_body_entered(body: Node2D) -> void:
	#COMMENT Lo mismo que en la lanza, esto no va acá, va en el jugador.
	if estaVivo:
		body.get_node("HitManager").what_to_do_if_you_get_hit(Enums.type.BODY,DAMAGE,global_position)


func _on_attack_hitbox_timeout() -> void:
	$Ataque/CollisionShape2D.disabled = false


func _on_radio_detection_body_entered(body: Node2D) -> void:
	#COMMENT: Ahora entiendo que no haya AGRO como tal.
	# Esta función debería setear una propiedad de clase llamada target con la referencia al jugador, que sería body en este caso.
	# Luego ejecutaríamos este mismo código pero todos los frames. No me queda claro porqué no preguntaron esto porque funciona obviamente mal en el juego.
	var posistion_diference = body.global_position.x - global_position.x
	if (posistion_diference < 0 and dirMov == Enums.direction.RIGHT) or (posistion_diference > 0 and dirMov == Enums.direction.LEFT):
		change_direction()
