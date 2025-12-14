extends CharacterBody3D

# --- SISTEMA DE STAMINA / RESISTENCIA -------------------------

# Stamina máxima. Con 120 y coste 10/s, el sprint dura aproximadamente 12 segundos continuos.
@export var max_stamina: float = 120.0

# Stamina actual (empieza llena).
@export var stamina: float = max_stamina

# Cuánto consume el sprint por segundo.
@export var stamina_sprint_cost_per_second: float = 10.0

# Cuánto se recupera por segundo cuando ya pasó el cooldown.
# 120 / 24 ≈ 5 segundos para llenarse desde 0 a tope si está en reposo.
@export var stamina_regen_per_second: float = 24.0

# Tiempo que el jugador se queda “cansado” en WALK
# antes de volver automáticamente a RUN (y poder sprintar otra vez).
@export var stamina_cooldown_time: float = 5.0

# Timer interno para controlar el cooldown.
var _stamina_cooldown_timer: float = 0.0

# Indica si el sprint está bloqueado (se quedó sin stamina).
var _sprint_locked: bool = false


signal pressed_jump(jump_state : JumpState)
signal changed_stance(stance : Stance)
signal changed_movement_state(_movement_state: MovementState)
signal changed_movement_direction(_movement_direction: Vector3)

@export var max_air_jump : int = 1
@export var jump_states : Dictionary
@export var stances : Dictionary

var air_jump_counter : int = 0
var movement_direction : Vector3
var current_stance_name : String = "upright"
var current_movement_state_name : String
var stance_antispam_timer : SceneTreeTimer


# -------------------------------------------------------------------
# Procesa la stamina: consumo en sprint, cooldown y recuperación.
# Llama a esta función desde _physics_process(delta).
# -------------------------------------------------------------------
func _process_stamina(delta: float) -> void:
	# ¿Estamos sprintando AHORA MISMO?
	# Usa tu variable de estado actual. Asumo que tienes algo como
	# current_movement_state_name (puedes adaptar el nombre si difiere).
	var is_sprinting_now := current_movement_state_name == "sprint" and is_movement_ongoing()

	# 1) CONSUMO DE STAMINA CUANDO SE ESTÁ SPRINTANDO
	if is_sprinting_now and not _sprint_locked:
		stamina -= stamina_sprint_cost_per_second * delta

		# Reiniciamos el cooldown cada vez que hay sprint
		_stamina_cooldown_timer = stamina_cooldown_time

		# Si se quedó sin stamina, bloqueamos sprint y forzamos WALK
		if stamina <= 0.0:
			stamina = 0.0
			_sprint_locked = true
			# No cambiamos tu lógica general, solo pedimos WALK aquí
			set_movement_state("walk")  # se “cansa” y camina lento

	# 2) SI NO ESTÁ SPRINTANDO: CONTAR COOLDOWN Y LUEGO RECUPERAR
	else:
		# Si todavía hay cooldown activo, contamos hacia atrás
		if _stamina_cooldown_timer > 0.0:
			_stamina_cooldown_timer -= delta
		else:
			# Ya no hay cooldown: empezamos/continuamos recuperación
			if stamina < max_stamina:
				stamina += stamina_regen_per_second * delta

				# Clamp para no pasar de la stamina máxima
				if stamina >= max_stamina:
					stamina = max_stamina

					# Al llenarse, desbloqueamos el sprint
					if _sprint_locked:
						_sprint_locked = false

						# Si el jugador se está moviendo y está en WALK,
						# lo pasamos a RUN automáticamente (ya se recuperó).
						# Esto respeta tu sistema: RUN = listo para volver a sprintar.
						if is_movement_ongoing() and current_movement_state_name == "walk":
							set_movement_state("run")

func _ready():
	stance_antispam_timer = get_tree().create_timer(0.25)
	
	changed_movement_direction.emit(Vector3.BACK)
	set_movement_state("stand")
	set_stance(current_stance_name)


func _input(event):
	if event.is_action_pressed("movement") or event.is_action_released("movement"):
		movement_direction.x = Input.get_action_strength("left") - Input.get_action_strength("right")
		movement_direction.z = Input.get_action_strength("forward") - Input.get_action_strength("back")
		
		if is_movement_ongoing():
			# --- CAPA EXTRA: chequeo de stamina y bloqueo de sprint ------------
			if _sprint_locked or stamina <= 0.0:
				# Si está cansado o sin stamina, forzamos WALK (cansancio).
				set_movement_state("walk")
			else:
				if Input.is_action_pressed("sprint"):
					set_movement_state("sprint")
					if current_stance_name == "stealth":
						set_stance("upright")
				else:
					if Input.is_action_pressed("walk"):
						set_movement_state("walk")
					else:
						set_movement_state("run")
		else:
			set_movement_state("stand")
	
	if event.is_action_pressed("jump"):
		if air_jump_counter <= max_air_jump:
			if is_stance_blocked("upright"):
				return
			
			if current_stance_name != "upright" and current_stance_name != "stealth":
				set_stance("upright")
				return
			
			var jump_name = "ground_jump"
			
			if air_jump_counter > 0:
				jump_name = "air_jump"
			
			pressed_jump.emit(jump_states[jump_name])
			air_jump_counter += 1
	
	if is_on_floor():
		for stance in stances.keys():
			if event.is_action_pressed(stance):
				set_stance(stance)




func _physics_process(_delta):
	if is_movement_ongoing():
		changed_movement_direction.emit(movement_direction)
		
	if is_on_floor():
		air_jump_counter = 0
	elif air_jump_counter == 0:
		air_jump_counter = 1
# Al final del todo, añade esta línea para estamina:
	_process_stamina(_delta)


func is_movement_ongoing() -> bool:
	return abs(movement_direction.x) > 0 or abs(movement_direction.z) > 0


func set_movement_state(state : String):
	var stance = get_node(stances[current_stance_name])
	current_movement_state_name = state
	changed_movement_state.emit(stance.get_movement_state(state))


func set_stance(_stance_name : String):
	if stance_antispam_timer.time_left > 0:
		return
	stance_antispam_timer = get_tree().create_timer(0.25)
	
	var next_stance_name : String
	
	if _stance_name == current_stance_name:
		next_stance_name = "upright"
	else:
		next_stance_name = _stance_name
	
	if is_stance_blocked(next_stance_name):
		return
	
	var current_stance = get_node(stances[current_stance_name])
	current_stance.collider.disabled = true
	
	current_stance_name = next_stance_name
	current_stance = get_node(stances[current_stance_name])
	current_stance.collider.disabled = false
	
	changed_stance.emit(current_stance)
	set_movement_state(current_movement_state_name)


func is_stance_blocked(_stance_name : String) -> bool:
	var stance = get_node(stances[_stance_name])
	return stance.is_blocked()
