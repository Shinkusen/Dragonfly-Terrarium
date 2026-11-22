#----------------------------
#PREY
#----------------------------

class_name Prey
extends CharacterBody2D

@export var speed: float = 100.0
@export var timer: float = 10.0
@export var flee_interval: float = 0.25
@export var allow_rest : bool
#--- OLD FEATURE ---
#@export var configuration: int = 0

#Terrarium reference
var terrarium: Terrarium

#Components reference
@onready var agent = $NavigationAgent2D
@onready var vision = $Vision/RayCast2D

#Main vars
var pursuer: CharacterBody2D
var direction := Vector2.ZERO
var direction_timer : float = 0.0
var resting : bool = false

#Seed reference
var seed: String

#time step
var time_step: float

#Flee function vars
var fleeing : bool = false
var flee_direction := Vector2.ZERO
var flee_timer : float = 0.0

#Stuck function var
var stuck: bool = false
var stuck_timer: float = 0.0
var stuck_check_interval: float = 0.25
var minimum_movement: float = 10.0
var stuck_sample_timer: float = 0.0
var sample_position: Vector2

#Avoid function var
var avoidance_direction := Vector2.ZERO

#Create instance of a Random Number Generator to account for seed
var rng = RandomNumberGenerator.new()

#Signals
signal prey_death

#--- OLD FEATURE VARS ---
#var previous_position: Vector2
#var circle_radius: float = 220.0
#var circle_speed: float = 2.0
#var circle_center: Vector2 = Vector2(1532.0, 275.0)
#var circle_angle: float = randf_range(0.0, 2.0 * PI)
#var steps : float =  0.0
#var steps_max : float = 300.0
#var direction_flag : bool = false

func _ready():
	#Navegation agent variables
	sample_position = global_position
	agent.avoidance_enabled = true
	agent.velocity_computed.connect(_on_velocity_computed)
	
	#Get terrarium reference
	terrarium = get_parent()
	
	#Get time step
	time_step = terrarium.experiment_time_step
	
	#Register that its ready to run
	terrarium.registrations.append(self)
	print("[REPORT]: ", name, " is Running")

func build_seed() -> void:
	#Build seed
	seed = terrarium.experiment_name + "_" + str(terrarium.experiment_id) + "_" + name + "_Move"
	print(name, " Seed: ", seed)
	
	#Apply seed
	rng.seed = hash(seed)

#Detect if the Prey is stuck in geometry
func check_stuck(delta: float) -> void:
	stuck_sample_timer += delta
	
	if stuck_sample_timer < stuck_check_interval:
		return
	
	var distance = global_position.distance_to(sample_position)
	
	if velocity.length() > 10.0 and distance < minimum_movement:
		stuck_timer += stuck_check_interval
	else:
		stuck_timer = 0.0
	
	sample_position = global_position
	stuck_sample_timer = 0.0
	
	if stuck_timer >= 1.0:
		stuck_timer = 0.0
		stuck = true
		print(name, ": Stuck...")
		
		#Attempt to unstuck
		if get_slide_collision_count() > 0:
			var collision = get_slide_collision(0)
			var normal = collision.get_normal()
			direction = direction.slerp(normal, 8.0 * delta).normalized()
	else:
		stuck = false

#Choose Random Direction
func choose_random_direction() -> void:
	#Reset resting flag
	resting = false
	
	#Random movement
	var random_angle := rng.randf_range(0.0, 2.0 * PI)

	direction = Vector2(cos(random_angle),sin(random_angle))

	# 20% chance of resting
	if allow_rest and rng.randf() < 0.05:
		direction = Vector2.ZERO
		resting = true
		print("Resting...")

#Uses raycast query to avoid obstacles
func avoid_obstacle(delta: float) -> void:
	#Update raycast to follow current direction
	vision.target_position = direction * 200.0
	vision.force_raycast_update()
	
	#Attempt to reroute any possible collisions
	if vision.get_collider() != null:
		
		#Reset avoidance vector
		avoidance_direction = Vector2.ZERO
		
		#Test 16 possible directions
		for i in range(16):
			#First angle is saved without mirroring
			var offset = 0.0
			
			#Avoid Zero
			if i > 0:
				#Calculate the current angle and rounds it UP
				var step = ceil(float(i) / 2.0) * TAU / 16.0
				
				#Alternate between mirrored versions of the angles
				if i % 2 == 1:
					offset = step
				else:
					offset = -step
				
			#Save calculation of current query
			var angle = direction.angle() + offset
			var direction_aux = Vector2(cos(angle), sin(angle))
			
			vision.target_position = (direction_aux * 200)
			vision.force_raycast_update()

			if vision.get_collider() == null:
				#Calculate candidate
				var candidate_position = global_position + direction_aux * 200.0

				#Check proximity to pursuer
				if fleeing and pursuer != null:
					var closest_point = Geometry2D.get_closest_point_to_segment(pursuer.global_position, global_position, candidate_position)
					var distance_to_pursuer = closest_point.distance_to(pursuer.global_position)
					
					#If too close to Pursuer, ignore it (Distance of 100 or less pixels is ideal)
					if distance_to_pursuer < 90.0:
						continue
				
				#Aply the calculated direction if not fleeing
				if not fleeing:
					direction = direction_aux
					direction_timer = timer
				#Let the flee function aply the calculated direction
				else:
					avoidance_direction = direction_aux
				return
	#Reset Avoidance vector
	else:
		avoidance_direction = Vector2.ZERO

#Functions that handle the fleeing behavior from the pursuer
func flee(delta: float) -> void:
	if pursuer == null:
		return
	
	flee_timer -= delta
	
	#Calculate direction AWAY from pursuer
	var direction_aux = (global_position - pursuer.global_position).normalized()
	
	#Pre-Update raycast to follow current direction
	vision.target_position = direction_aux * 200.0
	vision.force_raycast_update()
	
	#Calculate for RVO in intervals of time
	if flee_timer <= 0.0:
		#Choose a destination
		var map = agent.get_navigation_map()
		var destination = global_position + direction_aux * 200
		destination = NavigationServer2D.map_get_closest_point(map,destination)
		
		#Save direction
		flee_direction = global_position.direction_to(destination)
		
		#Tell navigation where to go
		agent.target_position = destination
		
		#Reset flee timer
		flee_timer = flee_interval
		
	#Find the next waypoint
	var next_position = agent.get_next_path_position()
		
	#Calculate the direction
	var navigation_direction = global_position.direction_to(next_position)
	
	#Combine navigation and obstacle avoidance
	var final_direction = navigation_direction

	if avoidance_direction != Vector2.ZERO:
		var escape_direction = direction_aux.slerp(navigation_direction, 0.5)
		final_direction = escape_direction.slerp(avoidance_direction, 0.6)
	
	#Smooth movement
	direction = direction.slerp(final_direction, 16.0 * delta).normalized()
	direction_timer = timer
	
	#Final Update raycast to follow current direction
	vision.target_position = final_direction * 200.0
	vision.force_raycast_update()
	
	#Request RVO safe velocity
	agent.velocity = direction * speed

#Checks if the prey was caught
func check_pursuer_catch() -> void:
	if pursuer == null:
		return
	
	for i in range(pursuer.get_slide_collision_count()):
		var collision = pursuer.get_slide_collision(i)
		
		if collision.get_collider() == self:
			print(name, ": DIED")
			prey_death.emit(self)
			queue_free()
			return

#--- OLD FEATURE ---
#------------------------------------------------------
#func seek_way_out() -> void:
	#var map = agent.get_navigation_map()
	#var best_destination = global_position
	#var best_score = -INF
	#var away_direction = Vector2.ZERO
	#
	#if pursuer != null:
		#away_direction = (global_position - pursuer.global_position).normalized()
	#
	##Test 16 possible directions
	#for i in range(16):
		##Divide a circle in 16 slices (Native Constant TAU = 2pi) 
		#var angle = TAU * float(i) / 16.0
		#var direction_aux = Vector2(cos(angle), sin(angle))
		#
		##Generate candidate destination
		#var original_candidate = global_position + direction_aux * 150.0
		#
		##Project onto navigation map
		#var candidate = NavigationServer2D.map_get_closest_point(map, original_candidate)
		#
		##Check navigation path
		#var path = NavigationServer2D.map_get_path(map, global_position, candidate, true)
		#
		##Reject small paths
		#if path.size() < 1:
			#continue
		#
		##Reject candidates that are too fare
		#if original_candidate.distance_to(candidate) > 20.0:
			#continue
		#
		##Reject candidates that are too close to prey
		#if global_position.distance_to(candidate) < 50.0:
			#continue
#
		##Score candidate
		#var score = global_position.distance_to(candidate) * 0.1
		#
		#if fleeing and pursuer != null:
			#var actual_direction = global_position.direction_to(candidate)
			#score += actual_direction.dot(away_direction) * 100.0
		#
		#if score > best_score:
			#best_score = score
			#best_destination = candidate
			#
	##Set new destination
	#if best_score > -INF:
		#agent.target_position = best_destination
		#print(self.name, ": Fount a way -", best_destination)
	#else:
		#print(self.name, ": IS PANICING")
	#
	#direction = best_destination.normalized()

##Move to the right for an arbitrary amount of steps
#func choose_right_direction(force: bool):
	#if steps <= steps_max or force:
		#direction = Vector2(1, 0)
		#return true
	#else:
		#return false
#
##Move to the left for an arbitrary amount of steps
#func choose_left_direction(force: bool):
	#if steps <= steps_max or force:
		#direction = Vector2(-1, 0)
		#return true
	#else:
		#return false
#
##Move to down for an arbitrary amount of steps
#func choose_down_direction(force: bool):
	#if steps <= steps_max or force:
		#direction = Vector2(0, 1)
		#return true
	#else:
		#return false
#
##Move to up for an arbitrary amount of steps
#func choose_up_direction(force: bool):
	#if steps <= steps_max or force:
		#direction = Vector2(0, -1)
		#return true
	#else:
		#return false
#
##Move in a circular motion
#func move_in_circle(delta: float) -> void:
	#var offset := global_position - circle_center
	#
	##Prevent division by zero if the prey is at the center
	#if offset.length_squared() < 0.001:
		#offset = Vector2.RIGHT * circle_radius
		#global_position = circle_center + offset
	#
	##Tangent direction around the circle
	#direction = Vector2(-offset.y, offset.x).normalized()
	#
	##Correct radial deviation to keep the prey on the circle
	#var target_position := circle_center + offset.normalized() * circle_radius
	#global_position = target_position
#------------------------------------------------------

#Physics loop for Prey
func prey_process(delta: float) -> void:
	#Only begin when all agents have registered
	if terrarium.start_experiment:
		#OBS: Used to subract either delta or experiment_time_step (direction_timer -= delta)
		direction_timer -= delta
		
		#Fleeing behavior
		#------------------------------------------------------------------
		if fleeing:
			flee(delta)
		#------------------------------------------------------------------
		
		#Random movement
		#------------------------------------------------------------------
		elif not fleeing and direction_timer <= 0.0:
			choose_random_direction()
			direction_timer = timer
		#------------------------------------------------------------------
		
		#Base behavior
		#------------------------------------------------------------------
		elif not fleeing:
			velocity = direction * speed
			move_and_slide()
		
		#Always check if prey is stuck
		if not resting:
			check_stuck(delta)
		
		avoid_obstacle(delta)
		check_pursuer_catch()
		#------------------------------------------------------------------

#Signal Functions
#------------------------------------------------------------
#GODOT's RVO system for avoiding obstacles
func _on_velocity_computed(safe_velocity):
	if fleeing:
		velocity = safe_velocity
		move_and_slide()

func _on_vision_body_entered(body: Node2D) -> void:
	if body == pursuer:
		print(name, ": Is scared...")
		vision.target_position = pursuer.global_position - global_position
		vision.force_raycast_update()
		
		if vision.get_collider() == pursuer:
			print(name, ": FLEE")
			fleeing = true

func _on_vision_body_exited(body: Node2D) -> void:
	if body == pursuer:
		print(self.name, ": SAFE")
		agent.velocity = Vector2.ZERO
		direction_timer = 0
		fleeing = false
#------------------------------------------------------------
