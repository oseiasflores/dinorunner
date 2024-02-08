extends Node

#Carrega objetos 
var stump_scene = preload("res://scenes/stump.tscn")
var rock_scene = preload("res://scenes/rock.tscn")
var barrel_scene = preload("res://scenes/barrell.tscn")
var bird_scene = preload("res://scenes/bird.tscn")
var obstacle_types := [stump_scene, rock_scene, barrel_scene]
var obstacles : Array
var bird_heights := [200, 390]

#Variaveis Gerais do jogo
const DINO_START_POS := Vector2i(150,485)
const CAM_START_POS := Vector2i(576,324)
var difficulty
const MAX_DIFFICULTY : int = 2
var score : int
var high_score : int
var SCORE_MODIFIER : int = 10
var speed: float
const START_SPEED : float = 10.0
const MAX_SPEED : int = 25
const SPEED_MODIFIER: int = 5000
var screen_size : Vector2i
var ground_height : int
var game_running : bool
var last_obs
var hearts
var damaged_hurts
var current_heart : int
signal health_depleted
var ground_segments : Array = []
var ground_segment_size : int
const INVULNERABILITY_DURATION = 2.0  # Duração da invulnerabilidade em segundos
var is_invulnerable = false  # Variável para rastrear se o jogador está invulnerável
var invulnerability_timer = 0.0  # Temporizador para controlar a duração da invulnerabilidade
signal player_imune
signal player_not_imune
signal game_restarting  # Sinal para indicar que o jogo está sendo reiniciado
var is_restarting = false  # Variável para controlar se o jogo está sendo reiniciado



func _ready():
	# Obtém o tamanho da tela através do viewport
	var viewport = get_viewport()
	screen_size = viewport.get_visible_rect().size

	# Carrega a altura do chão
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()

	# Conecta o sinal de pressionar o botão de reiniciar ao método new_game
	$GameOver.get_node("Button").pressed.connect(new_game)

	# Obtém o tamanho de um segmento do chão
	ground_segment_size = $Ground.get_node("Sprite2D").texture.get_width()

	# Inicializa o jogo
	player_not_imune.emit()
	new_game()
	
func new_game():
	emit_signal("game_restarting")
	#Reseta os nós para os valores padrão
	game_running = true
	if score > high_score:
		show_high_score()
		high_score = score
	else:
		high_score = 0
		show_high_score()
	score = 0
	hearts = 4
	$Dino/HurtSound.stop()
	$Dino/AnimatedSprite2D.play("idle")
	damaged_hurts = hearts
	$HUD/Life.get_node("Hearts0").show()
	$HUD/Life.get_node("Hearts1").show()
	$HUD/Life.get_node("Hearts2").show()
	$HUD/Life.get_node("Hearts3").show()
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	$Dino.position = DINO_START_POS
	$Dino.velocity = Vector2i(0,0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0,0)
	$Dino/AnimatedSprite2D.play("idle")
	
	#Reseta o HUD para aparecer o botão de iniciar
	$HUD.get_node("StartLabel").show()
	
	#Esconde o botão de reiniciar:
	$GameOver.hide()
	load_initial_ground_segments()
	player_not_imune.emit()
	
#Chamado a cada frame. 'delta' é o tempo decorrido desde o ultimo frame.
func _process(delta):
	update_invulnerability(delta)
	if game_running:
		#Aumenta a velocidade e a dificuldade
		speed = START_SPEED  + score / SPEED_MODIFIER
		if speed > MAX_SPEED:
			speed = MAX_SPEED
		adjust_dificulty()
			
		#Gera os obstaculos
		generate_obs()
		
		#movimentar dino e camera
		$Dino.position.x += speed
		$Camera2D.position.x += speed	
		
		#atualiza as informações de score
		score += speed
		show_score()
		
		#Atualiza a posição do chão
		#if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
				#$Ground.position.x += screen_size.x
		
		for segment in ground_segments:
			if $Camera2D.position.x - segment.position.x > screen_size.x * 1.5:
				segment.position.x += screen_size.x
		
		#deleta objetos que estão fora da tela (economia de memória)
		for obs in obstacles:
			if obs.position.x < ($Camera2D.position.x - screen_size.x):
				remove_obs(obs)
	else:
		if Input.is_action_pressed("ui_accept") or Input.get_action_strength("baixo") or Input.get_action_strength("cima"):
			print("CHAMOU CIMA")
			game_running = true
			$HUD.get_node("StartLabel").hide()

func generate_obs():
	if obstacles.is_empty() or last_obs.position.x < score + randi_range(300, 500):
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs
		var max_obs = difficulty + 1
		for i in range(randi() % max_obs +1):
			obs = obs_type.instantiate()
			var obs_height = obs.get_node("Sprite2D").texture.get_height()
			var obs_scale = obs.get_node("Sprite2D").scale
			var obs_x : int = screen_size.x + score + 100 + (i * 100)
			var obs_y : int = screen_size.y - ground_height - (obs_height * obs_scale.y / 2) + 5 
			last_obs = obs
			add_obs(obs,obs_x, obs_y)
			
		#Chance aleatoria de dar spawn em um passaro
		if difficulty == MAX_DIFFICULTY:
			if (randi() % 2) ==0:
				#gera o obstatuclo passaro
				obs = bird_scene.instantiate()
				var obs_x : int = screen_size.x + score  +100
				var obs_y : int = bird_heights[randi() % bird_heights.size()]
				add_obs(obs,obs_x,obs_y)
		
func add_obs(obs, x, y):
	obs.position = Vector2i(x, y)
	obs.body_entered.connect(hit_obs)
	add_child(obs)
	obstacles.append(obs)

func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)			

func hit_obs(body):
	if body.name == "Dino" and not is_invulnerable:
		player_hit(damaged_hurts)
		damaged_hurts -= 1
		if damaged_hurts == 0:
			game_over()
		else:
			# Ativa o estado de invulnerabilidade
			activate_invulnerability()

func activate_invulnerability():
	print("ENVIOU SINAL DE IMUNIDADE")
	player_imune.emit()
	is_invulnerable = true
	invulnerability_timer = 0.0

func update_invulnerability(delta):
	if is_invulnerable:
		invulnerability_timer += delta
		if invulnerability_timer >= INVULNERABILITY_DURATION:
			is_invulnerable = false
			invulnerability_timer = 0.0
			player_not_imune.emit()
			
func show_score():
	$HUD.get_node("ScoreLabel").text = "PONTUAÇÃO: " + str(score / SCORE_MODIFIER)

func show_high_score():
	$HUD.get_node("HighScoreLabel").text = "RECORDE: " + str(score / SCORE_MODIFIER)
	
func adjust_dificulty():
	difficulty = score / SPEED_MODIFIER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY

func player_hit(hearts):
	health_depleted.emit()
	if hearts <= 0:
		game_over()
	else:
		hearts -=  1
		$HUD/Life.get_node("Hearts"+str(hearts)).hide()

func game_over():
	get_tree().paused = true
	game_running = false
	$GameOver.show()

func load_initial_ground_segments():
	var num_initial_segments = 3  # Defina o número inicial de segmentos de solo

	for i in range(num_initial_segments):
		load_ground_segment(i * ground_segment_size)

func load_ground_segment(x_position):
	var ground_scene = preload("res://scenes/ground.tscn")  # Substitua "ground_segment.tscn" pelo seu segmento de solo
	var ground_instance = ground_scene.instantiate()

	ground_instance.position.x = x_position
	add_child(ground_instance)
	ground_segments.append(ground_instance)
	
