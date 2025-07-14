extends Node2D

@onready var body := $Xplosion
@onready var camera := $Camera2D

const RECOVERY_AREA = 10
const RETURN_SPEED = -500
const MAX_RETRACTION_DISTANCE := 20
const MAX_ATTACK_RANGE := 45
const CHARGING_TIME := 1.5
const HOOK_CHARGING_TIME := 3
const MAX_DISTANCE_PER_SPEED := 1
const ATTACK_COOLDOWN := 1.2
const MELEE_ATTACK_CHARGING_TIME := 0.1
const DIRECTION := Vector2(1, 0)
const STARTING_POS = Vector2(0,0)
const DAMAGE = 1

var distance_covered = 0.0
var charge := 0.0
var speed := 0.0
var meleeing := false
var charged := false
var thrown := false
var last_position := Vector2.ZERO
var throwing_direction := Vector2.ZERO

enum state{
	THROWN,
	ATTACH
}

@onready var sonido_cargarLanza := preload("res://src/Assets/Sounds/Sonidos/CargarLanza.mp3")
@onready var sonido_GolpeLanza := preload("res://src/Assets/Sounds/Sonidos/GolpeLanza.mp3")


func _ready():
	# Conectar señales del área de colisión
	body.connect("area_entered", Callable(self, "_on_area_entered"))
	body.connect("body_entered", Callable(self, "_on_body_entered"))
	disable_hitbox()

func _physics_process(delta: float) -> void:
	if speed == 0:
		if Input.is_action_pressed("left_attack") and not meleeing :
			charge_range_attack(delta)
		elif Input.is_action_just_released("left_attack"):
			release_range_attack()
		elif Input.is_action_pressed("right_attack") and charge == 0:
			meleeing = true
	else:
		move(delta)

	if meleeing:
		melee_attack(delta)
		last_position = body.position - STARTING_POS

func charge_range_attack(delta: float):
	if charge <= MAX_RETRACTION_DISTANCE:
		charge += delta * MAX_RETRACTION_DISTANCE / CHARGING_TIME
		body.position = STARTING_POS - charge*DIRECTION
	else:
		charge = MAX_RETRACTION_DISTANCE
		body.position = STARTING_POS - (charge - (randf() * 2 - 1))*DIRECTION
	throwing_direction = get_mouse_vectorial_difference().normalized()
	global_rotation = get_xplosion_rotation(get_mouse_vectorial_difference())

	var sound := AudioStreamPlayer.new()
	sound.stream = sonido_cargarLanza
	add_child(sound)
	sound.play()
	await sound.finished

func release_range_attack():
	if charge / MAX_RETRACTION_DISTANCE >= 0.3:
		transferCamera(state.THROWN)
		distance_covered = 0
		speed = charge * 30
		charge = 0.0
		var pos_save = body.global_position
		var rot_save = body.global_rotation
		remove_child(body)
		get_tree().current_scene.add_child(body)
		body.global_position = pos_save
		body.global_rotation = rot_save
	else:
		charge = 0 
		body.position = STARTING_POS
		

func melee_attack(delta: float):
	const MELEE_SPEED = MAX_RETRACTION_DISTANCE / MELEE_ATTACK_CHARGING_TIME
	global_rotation = get_xplosion_rotation(get_mouse_vectorial_difference())

	var distance_to_start = (body.position - STARTING_POS).length()

	if distance_to_start <= MAX_RETRACTION_DISTANCE / 2 and not charged:
		body.position -= delta * MELEE_SPEED*DIRECTION
	elif distance_to_start <= MAX_ATTACK_RANGE and not thrown:
		charged = true
		activate_hitbox()
		body.position += delta * MELEE_SPEED*DIRECTION
	elif distance_to_start > 1:
		disable_hitbox()
		body.position -= delta * MELEE_SPEED*DIRECTION
		thrown = true
	else:
		body.position = STARTING_POS
		charged = false
		thrown = false
		meleeing = false

func move(delta: float):
	var current_position = global_position - STARTING_POS
	if speed > 0:
		distance_covered += speed * delta
		if distance_covered > MAX_RETRACTION_DISTANCE:
			activate_hitbox()
		body.global_position += throwing_direction * speed * delta
		if distance_covered >= MAX_DISTANCE_PER_SPEED * speed:
			return_lance()
	elif speed < 0:
		distance_covered = get_vectorial_diference(body.global_position).length()
		var speed_multiplayer = 1 + RECOVERY_AREA/distance_covered if distance_covered >= RECOVERY_AREA else 2
		disable_hitbox()
		body.global_rotation = get_xplosion_rotation(get_vectorial_diference(body.global_position-STARTING_POS))
		var return_direction = get_vectorial_diference(body.global_position-STARTING_POS).normalized()
		body.global_position += return_direction*speed*delta/speed_multiplayer
		print(distance_covered)
		if distance_covered < 2:
			transferCamera(state.ATTACH)
			get_tree().current_scene.remove_child(body)
			add_child(body)
			body.position = STARTING_POS
			body.global_rotation = global_rotation
			speed = 0
	last_position = body.global_position - current_position

func return_lance():
	disable_hitbox()
	speed = RETURN_SPEED
	last_position = body.position-STARTING_POS

func get_xplosion_rotation(diference: Vector2) -> float:
	var vectorial_difference = diference
	return atan2(vectorial_difference.y, vectorial_difference.x)

func get_mouse_vectorial_difference() -> Vector2:
	return get_vectorial_diference(get_global_mouse_position())

func get_vectorial_diference(base : Vector2) -> Vector2:
	#COMMENT esta función es literalmente Vector2.distance_to(). Usen F1
	#global_position.distance_to(base)
	return base - global_position

func _on_area_entered(area: Area2D) -> void:
	what_to_do_if_you_hit_something(area)

func _on_body_entered(body_node: Node2D) -> void:
	what_to_do_if_you_hit_something(body_node)
		

func activate_hitbox():
	body.get_node("hitbox").disabled = false

func disable_hitbox():
	body.get_node("hitbox").disabled = true

func what_to_do_if_you_hit_something(something : Node2D):
	#COMMENT: Core y "NoCore" deberían ser Area2D distintos. 
	# 	Para diferenciar meleeing podríamos usar dos colliders en la lanza uno que solo se activa al lanzar, y core solo detectaría colisiones con ese que se prende al lanzar.
	#	El daño lo tiene que manejar una detección en core (en el enemigo), no debería ser la lanza la encargada de comunicar esto
	var type = Enums.type.CORE if something.name == "core" and not meleeing else Enums.type.BODY
	if type != Enums.type.BODY:
		something = something.get_parent()
	if something.is_in_group("enemies"):
		if something.estaVivo:
			something.get_node("HitManager").what_to_do_if_you_get_hit(type,DAMAGE,global_position)
			
			#COMMENT A partir de acá se hace lo único que debería hacerse en esta función
			var sound := AudioStreamPlayer.new()
			sound.stream = sonido_GolpeLanza
			add_child(sound)
			sound.play()
			await sound.finished
	disable_hitbox()
	if speed > 0:
		return_lance()
		
func transferCamera(estado: state):
	if estado == state.THROWN:
		remove_child(camera)
		body.add_child(camera)
		camera.position = STARTING_POS
	else:
		body.remove_child(camera)
		add_child(camera)
		camera.position = STARTING_POS
	
