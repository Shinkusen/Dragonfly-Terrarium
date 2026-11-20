#----------------------------
#DRAGONFLY'S CONTROLLER
#----------------------------

class_name DragonflyController
extends Node

#Reference to the Body
var body: DragonflyBody

#Reference to the Terrarium
var terrarium: Terrarium

#References to States and Define first Current State
@onready var wander = $DragonflyStateWander
@onready var stalk = $DragonflyStateStalk
@onready var hunt = $DragonflyStateHunt
@onready var current_state = wander

#Create the instance of both Database and Prediction Method
var database := Database.new()
var gaussian := GaussianProcessRegression.new()

#Seed reference
var seed: String

#time step
var time_step: float

#Confidence is checked by wanderer and needs to be onready and different default values until initialized
var confidence: int = database.size_databundle * 3
var current_confidence: int = 0

#Information about known prey: Id (by index) and time in chase
var known_prey: Array[CharacterBody2D] = []
var known_prey_chase_time: Array[float] = []

#Flag for setup
var setup_flag : bool = true

#Setup for this specific State
func setup(dragonfly_body: DragonflyBody, dragonfly_controller: DragonflyController) -> void:
	#Setup references only once
	if setup_flag:
		#Connect prey detection signal to funcion "bloodlust"
		body.prey_death.connect(bloodlust)
		#Makes sure setup runs only once
		setup_flag = false

#Run first reports and enter first state
func _ready() -> void:
	#Get body reference(Body is parent)
	if get_parent() is DragonflyBody:
		body = get_parent() as DragonflyBody
	
	#Get terrarium reference(Terrarium is grandparent)
	if get_parent().get_parent() is Terrarium:
		terrarium = get_parent().get_parent() as Terrarium
		
		#Get time step
		time_step = terrarium.experiment_time_step
		
		#Get seed from terrarium
		seed = terrarium.experiment_name + "_" + str(terrarium.experiment_id) + "_dragonfly"
	
	if current_state:
		print("[REPORT]: Dragonfly has a State")
		
		#Give state its dependencies
		fill_state()
		
		#Enter the state
		current_state.enter()
	
	else:
		print("[REPORT]: Dragonfly does NOT has a State")
	
	#Register that its ready to run
	terrarium.registrations.append(self)
	print("[REPORT]: Dragonfly's Controller is Running")

func check_studied_prey(prey: CharacterBody2D):
	if prey in stalk.studied_prey:
		return true
	return false

#Change state, recieve the new state's name ref as in controller.STATE
func change_state(new_state) -> void:
	# --THIS IS FOR TESTS PURPOSES DELETE LATER--
	#if(new_state == wander):
		#print("[REPORT]: Dragonfly has finished all states...")
		#print("\n...Closing Terrarium")
		#breakpoint
	
	#Change state by using node paths as a parameter
	current_state = new_state
	
	#Give state its dependencies
	fill_state()
	
	#Enter the state
	current_state.enter()

#Give all depencencies to current state
func fill_state() -> void:
	#Pass actual body and a way to request state changes
	current_state.setup(body, self)

#Check current state and runs it
func controller_process(delta: float) -> void:
	#Only begin when all agents have registered
	if terrarium.start_experiment:
		if current_state:
			#Call the state machine loop
			#OBS: Use either delta or experiment_time_step 
			current_state.state_behavior(delta)
	

#Called by signal, for the case were the prey dies in the stalk state, the confidence must increasse and the database needs to remove the dead prey's data
func bloodlust(prey: CharacterBody2D) -> void:
	print("|REPORT|: Bloodlust activated")
	
	#Make sure the stalked prey array isn't empty
	if not stalk.stalked_prey.is_empty():
		#Pick id reference for the prey
		var prey_id = stalk.stalked_prey.find(prey)
		var num_samples = 0.0
		
		#--- OLD FEATURE ---
		##Remove the data of the dead prey
		#if prey_id != -1:
			##Ensure the index exists in the database array before removing
			#if prey_id < database.dataset.size():
				##--- [Its causing problems on id location] ---
				##database.dataset.remove_at(prey_id)
				#current_confidence += database.size_databundle
		
		#For prey that exists and was somewhat studied
		if prey_id != -1:
			#Ensure the index exists in the database array before access
			if prey_id < database.dataset.size():
				#Save amount of samples that we already have
				num_samples = database.dataset[prey_id].size() 
			
		#Only increasses in case the prey was not fully studied
		if prey not in stalk.studied_prey:
			current_confidence += database.size_databundle - num_samples
			print("Confidence Added - ", database.size_databundle - num_samples)
