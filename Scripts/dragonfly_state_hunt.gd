#----------------------------
#DRAGONFLY'S STATE | HUNT
#----------------------------

class_name HuntState
extends Node

#Reference to the body so states can move it and controler to signal state changes
@onready var body: DragonflyBody      
@onready var controller: DragonflyController

#Hunt State Variables
var vision: Node
var setup_flag: bool = true
var trigger: bool = true
var warn_once: bool = true
var warn_once_prediction: bool = true
var current_prey: CharacterBody2D
var priority_prey: CharacterBody2D
var current_prey_id: CharacterBody2D
var predicted_position: Vector2 = Vector2(-1, -1)
var delta_ref: float = -1.0
var collect_patience_total: float = 2.0
var collect_patience_left: float = 0.0
var prediction_patience: float = 4.0
var prediction_patience_left: float = 0.0
var predicting: bool = false
var prediction_time_max: float = 4.0
var prediction_time: float = 0.0
var direction: Vector2
var predicted_direction: Vector2

#Timer for hunt
var hunt_patience_left: float = 0.0
var hunt_patience_max: float = 60.0

#Setup for this specific State
func setup(dragonfly_body: DragonflyBody, dragonfly_controller: DragonflyController) -> void:
	#Setup references only once 
	if setup_flag:
		#Body reference
		body = dragonfly_body
		#Controller reference
		controller = dragonfly_controller
		#Reference to vision/raycast
		vision = body.vision
		#Connect prey detection signal to funcion "lost_prey"
		body.prey_lost.connect(drop_prey)
		#Makes sure setup runs only once
		setup_flag = false

#Enter process for this specific State
func enter() -> void:
	print("| STATE 3 IS OPERATIONAL |")
	#--Code for entering state--

#Exit process for this specific State
func exit() -> void:
	print("| STATE 3 BEHAVIOR EXITED |")
	
	#Empty the current prey
	current_prey = null
	#Empty the priority prey
	priority_prey = null
	
	#Resets vars
	warn_once = true
	prediction_patience_left = 0.0
	collect_patience_left = 0.0
	predicting = false
	prediction_time = 0
	hunt_patience_left = 0.0
	
	#Change states
	controller.change_state(controller.wander)

#Pursuit the prey with a pursuit curve method
func hunt_prey(prey: CharacterBody2D, delta: float) -> void:
	#Only send report once
	if warn_once:
		print("\n[REPORT]: Dragonfly is Hunting")
		warn_once = false
	
	#If there was no previous prey in sights, make the current one priority
	if priority_prey == null:
		priority_prey = prey
	
	#Check if its there is already a prey being chased
	if priority_prey == prey:
		priority_prey = prey
		
		if predicting:
			prediction_time += delta
			
			if prediction_time_max <= prediction_time:
				prediction_patience_left = 0
				prediction_time = 0
				predicting = false
		
		if prediction_patience_left >= prediction_patience:
			if not predicting:
				predict_prey(prey)
				
				#Attempt to catch prey by prediction
				predicted_direction = (predicted_position - body.global_position).normalized()
				
				predicting = true
		
		#Find the distance between prey and dragonfly
		var offset = prey.global_position - body.global_position
			
		#Attempt to catch
		direction = offset.normalized()
		
		#If there is a prediction, calculate direction with predicted direction
		if predicting and predicted_direction != Vector2(-1, -1):
			#Check if prediction moves pursuer away from the prey
			if predicted_direction.dot(direction) > 0.3:
				#Save the calculation of the direction with the current one
				var predicted_direction_aux = predicted_direction.slerp(direction, 12.0 * delta).normalized()
				
				#--- OLD FEATURE ---
				#var angle = direction.angle_to(predicted_direction)
				#var predicted_direction_aux = predicted_direction.rotated(angle * 0.2).normalized()
				
				#Check if 20 pixels in the direction won't leat to a collision
				vision.target_position = predicted_direction_aux * 20.0
				vision.force_raycast_update()
				
				#Makes sure prediction won't push pursuer into wall
				var collider = vision.get_collider()
				if collider == null or collider is CharacterBody2D:
				
					#Feedback report for when pursuer is using prediction
					if warn_once_prediction:
						print("Cutting path...")
						warn_once_prediction = false
					
					#Adjust direction with prediction
					direction = predicted_direction_aux
			
			#Feedback report for when pursuer decided to not use prediction
			elif warn_once_prediction:
				print("Chasing...")
				#Reset timers
				prediction_patience_left = 0.0
				collect_patience_left = 0.0
				prediction_time = 0.0
				
				#Flag warning report
				warn_once_prediction = false
				
		#Collect data in a time interval defined by a variable "patience"
		collect_patience_left += delta
		if collect_patience_left >= collect_patience_total:
			print("|COLLECTED DATA|: ", prey)
			var id = find_prey_id(prey)
			collect_patience_left = 0
			collect_data(id, prey)
		
		#Always move
		body.move_body(direction * body.speed)
		
		#Elapsed time in chase for prey
		var id = find_prey_id(prey)
		controller.known_prey_chase_time[id] += delta
		
	#Else exit
	else:
		#Exit behavior
		exit()

#Stop chasing prey and enter wander mode
func drop_prey(prey: CharacterBody2D) -> void:
	print("Prey lost...(",prey,")")
	
	#Exit behavior
	exit()

#--- OLD FEATURE ---
#Stay still and let prey escape
#func leave_prey() -> void:
	#direction = -1 * direction
	
#Stop chasing prey and enter wander mode
func predict_prey(prey: CharacterBody2D) -> void:
	#Reset feedback report flag
	warn_once_prediction = true
	
	#Prey id and dataset reference
	var id = find_prey_id(prey)
	var dataset = controller.database.dataset
	
	#If the id exists, calculate prediction
	if id >= 0 and id < dataset.size():
		#Calculates a prediction for a position 0.5 seconds in the future
		var latest_time: float = controller.database.dataset[id][-1]["time"]
		var horizon: float = controller.known_prey_chase_time[id] + delta_ref - latest_time
		print("HORIZON: ",horizon)
		predicted_position = controller.gaussian.predict(dataset[id], horizon)
	
	else:
		print("|ERROR|: Prey is not in database")
		return
	
	if predicted_position != Vector2(-1, -1):
		print("|Predicted Position|: ", predicted_position)
		print("- Current direction: ", direction)
		print("- Predicted direction: ", predicted_direction)
		print("- Angular difference: ", rad_to_deg(direction.angle_to(predicted_direction)))
	else:
		print("|Predicttion Unavailable|: Dropping chase...")
		#drop_prey(prey)

#Function to collect data from stalked prey [WIP]
func collect_data(id: int, prey: CharacterBody2D) -> void:
	print("|Prey' Diagnostics|")
	print("Position: ", prey.global_position)
	print("Actual velocity: ", prey.actual_velocity)
	print("Assigned velocity: ", prey.velocity)
	
	#Add prey information on the dataset
	controller.database.add_data(id, controller.known_prey_chase_time[id], prey.global_position, prey.actual_velocity)

#Finds prey id in the controller
func find_prey_id (prey: CharacterBody2D):
	var prey_id = controller.known_prey.find(prey)
	
	return prey_id

#This is the function called by the Dragonfly_controller's physics loop
func state_behavior(delta: float) -> void:
	#Trigger report
	if trigger:
		print("| STATE 3 BEHAVIOR TRIGGERED |")
		trigger = false
	
	#Save the current delta
	delta_ref = delta
	
	#Keep following the prey until line of sight is broken
	if current_prey != null:
			hunt_prey(current_prey, delta)
	#Else exit
	else:
		#Exit Behavior
		exit()
	
	#Counts patience time for prediction, patience must be reseted in hunt function
	if prediction_patience_left < prediction_patience:
		prediction_patience_left += delta
	
	#Counts hunt patience
	hunt_patience_left += delta
