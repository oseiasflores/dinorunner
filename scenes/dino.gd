extends CharacterBody2D
const GRAVITY : int = 4200
const JUMP_SPEED : int = -1800

const DOWN_FORCE = 4000.0  # Ajuste conforme necessário para a força descendente
var is_down_pressed = false  # Variável para rastrear se o botão "ui_down" está pressionado
var is_immunity_active = false  # Variável para rastrear se a imunidade está ativa
const IMMUNITY_DURATION = 2.0  # Duração da imunidade em segundos
var immunity_timer = 0.0  # Temporizador para controlar a duração da imunidade
var remaining_hearts = 4  # Número de vidas restantes do jogador


func _physics_process(delta):
	# Aplica a gravidade
	velocity.y += GRAVITY * delta
	update_immunity(delta)

	# Verifica se o botão "ui_down" está pressionado
	if Input.is_action_pressed("ui_down") or Input.get_action_strength("baixo"):
		is_down_pressed = true
	else:
		is_down_pressed = false

	# Aplica a força descendente gradual se o jogador estiver no ar e o botão "ui_down" estiver pressionado
	if not is_on_floor() and is_down_pressed:
		velocity.y += DOWN_FORCE * delta

	# Lógica de animação e movimento do jogador
	if is_on_floor():
		if not get_parent().game_running:
			$AnimatedSprite2D.play("idle")
		else:
			$RunCol.disabled = false
			if Input.is_action_pressed("ui_accept") or Input.get_action_strength("cima"):
				print("CHAMOU CIMA")
				velocity.y = JUMP_SPEED
				$JumpSound.play()
			elif Input.is_action_pressed("ui_down") or Input.get_action_strength("baixo"):
				$AnimatedSprite2D.play("duck")
				$RunCol.disabled = true

			else:
				if _on_main_player_imune():
					$AnimatedSprite2D.play("hurt")
				else:
					$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("jump")
	move_and_slide()

func _on_main_health_depleted():
	print("RECEBEU SINAL DE HIT")
	var estaColidindo: bool = true
	var temporizadorAnimacao: float = 0.0
	var duracaoAnimacao: float = 5.0
  	# Ativa a imunidade
	is_immunity_active = true
	# Reinicia a animação de colisão
	$AnimatedSprite2D.play("hurt")
	$HurtSound.play()
	# Reinicia o temporizador de imunidade
	immunity_timer = 0.0
	
	if estaColidindo:
		print("ESTA COLIDINDO = TRUE")
	# Verifica se a duração da animação não foi atingida
		if temporizadorAnimacao < duracaoAnimacao:
			# Toca a animação de colisão
			print("Chamou a animação")
			$AnimatedSprite2D.play("hurt")
			$HurtSound.play()
			# Incrementa o temporizador
			temporizadorAnimacao += 1
			print(temporizadorAnimacao)
		else:
			# Duração da animação atingida, volta ao estado de corrida
			print("CHAMOU ANIMA RUN")
			$AnimatedSprite2D.play("run")
			# Reseta as variáveis para a próxima colisão
			estaColidindo = false
			temporizadorAnimacao = 0.0


func _on_main_player_imune():
	return is_immunity_active


func _on_main_player_not_imune():
	return not is_immunity_active

func update_immunity(delta):
	if is_immunity_active:
		immunity_timer += delta
		if immunity_timer >= IMMUNITY_DURATION:
			is_immunity_active = false
