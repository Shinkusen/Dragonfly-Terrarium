#----------------------------
#DRAGONFLY'S STATE | WANDER
#----------------------------

class_name WanderState
extends Node

@export var allow_rest : bool

#Reference to the body and controller so states can move it and controler to signal state changes
var body: DragonflyBody      
var controller: DragonflyController

#Seed reference
var seed: String

#Timestep reference
var time_step: float

#Wander State Variables
var setup_flag: bool = true
var trigger: bool = true
var patience: float = 10.0
var patience_left: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var resting: bool = false
var stuck_timer: float = 0.0
var stuck_start_pos: Vector2 = Vector2.ZERO
var contact_time: float = 0.0

#Create instance of a Random Number Generator to account for seed
var rng_move = RandomNumberGenerator.new()
var rng_collision = RandomNumberGenerator.new()
var rng_rest = RandomNumberGenerator.new()
var rng_stuck = RandomNumberGenerator.new()
var rng_bounce = RandomNumberGenerator.new()

#Setup for this specific State
func setup(dragonfly_body: DragonflyBody, dragonfly_controller: DragonflyController) -> void:
	#Setup references only once 
	if setup_flag:
		#Body reference
		body = dragonfly_body
		#Controller reference
		controller = dragonfly_controller
		#Build seed
		setup_rngs()
		#Connect prey detection signal to funcion "sighted_prey"
		body.prey_found.connect(sighted_prey)
		#Makes sure setup runs only once
		setup_flag = false

func setup_rngs() -> void:
	#Get seed
	seed = controller.seed
	
	print("Dragonfly Seed: ", seed)
	
	#Set up the Random Number Generators
	rng_move.seed = hash(seed + "_Move")
	rng_collision.seed = hash(seed + "_Collision")
	rng_rest.seed = hash(seed + "_Rest")
	rng_stuck.seed = hash(seed + "_Stuck")
	rng_bounce.seed = hash(seed + "_Bounce")

#Enter process for this specific State
func enter() -> void:
	print("| STATE 1 IS OPERATIONAL |")
	pick_random_direction()

#Exit process for this specific State
func exit(prey: CharacterBody2D) -> void:
	print("| STATE 1 BEHAVIOR EXITED |")
	
	#Change states depending on confidence
	if controller.current_confidence < controller.confidence:
		controller.stalk.current_prey = prey
		controller.change_state(controller.stalk)
	else:
		controller.hunt.current_prey = prey
		controller.change_state(controller.hunt)

#If prey was detected call exit to leave this state
func sighted_prey(prey: CharacterBody2D) -> void:
	#Exit Behavior
	if not controller.check_studied_prey(prey) or controller.current_confidence >= controller.confidence:
		#Which prey was found
		print("PREY FOUND: ", prey.name)
		exit(prey)

#At the end of the timer pick a direction to go or rest
func pick_random_direction() -> void:
	#Reset resting
	resting = false
	
	#Choose a random angle in radians (0 to 360 degrees)
	var random_angle = rng_move.randf_range(0, 2 * PI)
	
	#Convert the angle into a normalized direction vector
	wander_direction = Vector2(cos(random_angle), sin(random_angle)).normalized()
	
	#20% chance of standing still instead of walking
	if allow_rest and rng_rest.randf() < 0.2:
		resting = true
		print("Resting...") 
		wander_direction = Vector2.ZERO

#Collision handler for different collision types
func handle_collision() -> void:	
	#Check if there was in fact a recent collision
	if body.get_slide_collision_count() > 0:
		var collision = body.get_slide_collision(0)
		var wall_normal = collision.get_normal()
		
		#Ensure that its actually pushing into the wall before deflecting
		if wander_direction.dot(wall_normal) < 0:
			var slide_dir = wander_direction.slide(wall_normal)

			if slide_dir.length_squared() < 0.1:
				print("Bounce...")
				#Hit head-on, bounce
				wander_direction = wall_normal.rotated(rng_collision.randf_range(0, PI))
			else:
				print("Slide...")
				#Hit at an angle, slide along wall
				wander_direction = slide_dir.normalized()
				
			#Reset patience
			patience_left = 0.0
			
			#Reset position check
			stuck_start_pos = body.position

#Detect collision and treat prolonged collisions
func check_if_contact(delta: float) -> void:
	#Verify if there was a collision
	if body.get_slide_collision_count() > 0:
		contact_time += delta
		
		#If there is prolonged contact, leave wall
		if contact_time >= 2.0:
			print("Scraping...")
			#Bounce at an angle if there is prolonged contact
			var normal = body.get_slide_collision(0).get_normal()
			var bounce = wander_direction.bounce(normal)
			
			#Small angular variation for bounce
			wander_direction = bounce.rotated(rng_bounce.randf_range(-0.2, 0.2))
			contact_time = 0.0
	else:
		contact_time = 0.0

#Checks stays in the same area for to long and unstucks it
func check_if_stuck(delta: float) -> void:
	#Constantly count time when this function is called
	stuck_timer += delta
	
	#Check if the AI is stuck in the same quadrant after timer
	if stuck_timer >= 1.0 and !resting:
		var distance_moved = stuck_start_pos.distance_to(body.position)

		if distance_moved < 10.0:
			print("Unstuck!")

			#Pick a direction away from the wall
			wander_direction = -wander_direction.rotated(rng_stuck.randf_range(0, PI))

		stuck_timer = 0.0
		stuck_start_pos = body.position

#This is the function called by the Dragonfly_controller's physics loop
func state_behavior(delta: float) -> void:
	#Trigger report
	if trigger:
		print("| STATE 1 BEHAVIOR TRIGGERED |")
		trigger = false
	
	#Check if there is prey nearby
	if body.smelling:
		body.prey_nearby()
	
	#Apply movement first to compensate for frame lag
	body.move_body(wander_direction * body.speed)
	
	#If the body hit something *during* that move_body call, handle it
	if body.is_on_wall():
		handle_collision()
	check_if_stuck(delta) #Check if its stuck after handling failiure
	check_if_contact(delta) #Check if there is prolonged contact
	
	#Track time passed to change directions
	patience_left += delta
	if patience_left >= patience:
		pick_random_direction()
		
		#Reset timer
		patience_left = 0.0
	
