#----------------------------
#TERRARIUM
#----------------------------

class_name Terrarium
extends Node2D

#[SEED MANUAL]
#Experiment_id, Agent, Action/Purpose, Increment(optional)

#Exports for nameing convention of experiment
@export var experiment_id: int = 2
@export var experiment_name: String = "Test"
@export var experiment_time_step: float = 0.01

#References for terrarium agents and components
@onready var dragonfly_body = $DragonflyBody
@onready var dragonfly_controller = dragonfly_body.get_node("DragonflyController")
@onready var database = dragonfly_controller.database
@onready var prey1 = $Prey1
@onready var prey2 = $Prey2
@onready var prey3 = $Prey3
@onready var logger = $"/root/LoggerGlobal"

#Save some of the agent's atributes
@onready var prey1_pos = prey1.global_position
@onready var prey2_pos = prey2.global_position
@onready var prey3_pos = prey3.global_position

#Registration
var registrations: Array = []

#Total time elapsed
var experiment_time_elapsed: float = 0.0

#Flag for triggering the start of the experiment and registrations report
var trigger: bool = true

#Marks the start of the experiment for the other components
var start_experiment: bool = false

#--- OLD FEATURE ---
#Instancieate Data Logger
#var logger := DataLogger.new()

#Give dependencies to entities outside the Dragonfly
func _ready() -> void:
	print("Prey1 Spawn - ", prey1_pos)
	print("Prey2 Spawn - ", prey2_pos)
	print("Prey3 Spawn - ", prey3_pos)
	
	#--- OLD FEATURE ---
	#Data Logger dependencies
	#logger = $"/root/LoggerGlobal"
	
	#Check if there was a experiment id in the past
	if logger.experiment_id_past != -1:
		#Increment id for next test
		experiment_id = logger.experiment_id_past + 1
	
	#Data Logger dependencies
	logger.experiment_id = experiment_id
	logger.experiment_name = experiment_name
	logger.hunt_mode = dragonfly_body.hunt_mode
	logger.dragonfly = dragonfly_body
	logger.dataset = database.dataset
	logger.prey1 = prey1
	logger.prey2 = prey2
	logger.prey3 = prey3
	
	#Prey dependencies
	prey1.pursuer = dragonfly_body
	prey2.pursuer = dragonfly_body
	prey3.pursuer = dragonfly_body

#Constantly update the Data Logger
func _physics_process(delta: float) -> void:
	#Makes sure all components have registered
	if registrations.size() == 4:
		if trigger:
			print("[Terrarium Report]: All agents registered | Begin ", experiment_name + str(experiment_id))
			
			#So this section only triggers once
			trigger = false
			
			#Begin recording
			logger.start_recording()
			
			#Begin the experiment
			start_experiment = true
		
		#Processes for each component
		if is_instance_valid(dragonfly_controller):
			dragonfly_controller.controller_process(delta)
		if is_instance_valid(prey1):
			prey1.prey_process(delta)
		if is_instance_valid(prey2):
			prey2.prey_process(delta)
		if is_instance_valid(prey3):
			prey3.prey_process(delta)
		
		#Keeps recording until logger timer has run out
		if logger.recording:
			#OBS: Use either delta or experiment_time_step 
			logger.update(delta)
		
		#Close down the terrarium when logger timer ruuns out
		else:
			if logger.elapsed_time >= logger.experiment_timer:
				print("\n[TERRARIUM REPORT]: Dragonfly Experiment has finished - ", experiment_time_elapsed, "s")
				print("...Closing Terrarium")
				get_tree().quit()
				
				#print("\n[TERRARIUM REPORT]: Dragonfly Experiment has finished")
				#print("...Restarting Terrarium")
				#get_tree().reload_current_scene()
			
		#Count elapsed time
		experiment_time_elapsed += experiment_time_step
