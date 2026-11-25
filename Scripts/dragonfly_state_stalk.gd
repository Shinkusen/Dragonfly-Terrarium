#----------------------------
#DRAGONFLY'S STATE | STALK
#----------------------------

class_name StalkState
extends Node

#Reference to the body so states can move it and controler to signal state changes
@onready var body: DragonflyBody      
@onready var controller: DragonflyController

#Stalk State Variables
var setup_flag: bool = true
var warn_once: bool = true
var trigger: bool = true
var current_prey: CharacterBody2D
var priority_prey: CharacterBody2D
var patience_total: float = 2.0
var patience_left: float = 0.0
var stalked_prey: Array[CharacterBody2D] = []
var studied_prey: Array[CharacterBody2D] = []
var time_to_hunt: bool = false
var hunt_mode: bool

#Setup for this specific State
func setup(dragonfly_body: DragonflyBody, dragonfly_controller: DragonflyController) -> void:
	#Setup references only once
	if setup_flag:
		#Body reference
		body = dragonfly_body
		#Controller reference
		controller = dragonfly_controller
		#Connect prey detection signal to funcion "lost_prey"
		body.prey_lost.connect(drop_prey)
		#Dictates if hunt state is enabled, if enabled collect data normaly and change to hunt
		hunt_mode = body.hunt_mode
		#Makes sure setup runs only once
		setup_flag = false

#Enter process for this specific State
func enter() -> void:
	print("| STATE 2 IS OPERATIONAL |")

#Exit process for this specific State
func exit() -> void:
	print("| STATE 2 BEHAVIOR EXITED |")
	
	#Empty the current prey
	current_prey = null
	#Empty the priority prey
	priority_prey = null
	
	#Change of states depend on the confidence variable
	if controller.current_confidence >= controller.confidence:
		
		print("---DATASET FINAL---")
		for i in controller.database.dataset:
			print(i, "\n")
		
		#Flag that signals that this state will not be used again
		time_to_hunt = true
		
		#Pass all known prey to the controller
		#controller.known_prey = stalked_prey
		print("|REPORT: Known Prey - ", controller.known_prey)
		print("|REPORT: Known Chase Times - ", controller.known_prey_chase_time)
		
		#Disconect function from signal (since the signal will be used by the hunt state)
		body.prey_lost.disconnect(drop_prey)
		
		controller.change_state(controller.hunt)
	else:
		controller.change_state(controller.wander)

#Pursuit the prey with a pursuit curve method and collect it's data
func stalk_prey(prey: CharacterBody2D, delta: float) -> void:
	#If there was no previous prey in sights, make the current one priority
	if priority_prey == null:
		priority_prey = prey
	
	#Check if the prey still needs to be studied (Dataset was never fully filled)
	if prey not in studied_prey and priority_prey == prey:
		#Save and separate found prey by indexed array
		var prey_id
		
		#Save new prey array and connect to bloodlust function in controller
		if prey not in stalked_prey:
			#local known prey array
			stalked_prey.append(prey)
			
			#Main known prey array
			controller.known_prey.append(prey)
			
			#Array for prey chase time
			controller.known_prey_chase_time.append(0)
			
			#Connect with function bloodlust in controller
			prey.prey_death.connect(controller.bloodlust)
			
			print("\n[REPORT]: List of found Prey: ", stalked_prey)
		prey_id = stalked_prey.find(prey)
		
		#Collect data in a time interval defined by a variable "patience"
		patience_left += delta
		if patience_left >= patience_total:
			patience_left = 0
			collect_data(prey_id, prey)
		
		#Find the distance between prey and dragonfly
		var offset = prey.global_position - body.global_position
		
		#Attempt to catch and study prey
		var direction = offset.normalized()
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

#Remembers prey that was completely studied
func remember_prey(prey: CharacterBody2D) -> void:
	#Save in the completely studied prey array, for prey that has had their dataset fully filled at least once
	if prey not in studied_prey:
		studied_prey.append(prey)
		
		# --THIS IS FOR TESTS PURPOSES DELETE LATER--
		var sprite = prey.get_node("Sprite2D")
		sprite.texture = preload("res://Sprite/Bee_spoted[PlaceHolder].png")
	
	#Exit behavior
	exit()

#Function to collect data from stalked prey
func collect_data(id: int, prey: CharacterBody2D) -> void:
	#Only collect data if hunt mode is enabled
	if hunt_mode:
		print("|COLLECTED DATA|: ", prey)
		
		#Add prey information on the dataset
		controller.database.add_data(id, controller.known_prey_chase_time[id], prey.global_position, prey.actual_velocity)
		
		#Increase confidence
		controller.current_confidence += 1
		
		#Feedback for when the Database is full
		if controller.database.dataset[id].size() >= controller.database.size_databundle and prey not in studied_prey and hunt_mode:
			print("\nWARNING: Databundle is full - id: ", controller.database.dataset.size())
			print("\n")
			
			#Remember the completely stalked prey
			remember_prey(prey)
			
			# --TESTS PURPOSES ONLY DELETE LATER--
			#Remove prey to test if the Dragonfly can save multiple
			#print("|DATASET|\n")
			#print("Size: ", controller.database.dataset.size(), "\n")
			#print("Current Samples: ", controller.database.dataset[id], "\n")
			#if controller.database.dataset.size() == 3:
				#print("---DATASET FINAL---")
				#print(controller.database.dataset[0], "\n")
				#print(controller.database.dataset[1], "\n")
				#print(controller.database.dataset[2])
				#print("--------------------\n")

func find_prey_id (prey: CharacterBody2D):
	var prey_id = stalked_prey.find(prey)
	
	return prey_id

#This is the function called by the Dragonfly_controller's physics loop
func state_behavior(delta: float) -> void:
	#Trigger report
	if trigger:
		print("| STATE 2 BEHAVIOR TRIGGERED |")
		trigger = false
	
	#Keep following the prey until line of sight is broken
	if current_prey != null:
		stalk_prey(current_prey, delta)
	else:
		exit()
	
