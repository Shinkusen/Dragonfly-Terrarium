#----------------------------
#TERRARIUM
#----------------------------

class_name Terrarium
extends Node2D

#[SEED MANUAL]
# Experiment_id, Agent, Action/Purpose, Increment(optional)

#Exports for nameing convention of experiment
@export var experiment_id: int = 1
@export var experiment_name: String = "Test"

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
	prey1.seed = experiment_name + "_" + str(experiment_id) + "_prey1"
	prey2.pursuer = dragonfly_body
	prey2.seed = experiment_name + "_" + str(experiment_id) + "_prey2"
	prey3.pursuer = dragonfly_body
	prey3.seed = experiment_name + "_" + str(experiment_id) + "_prey3"
	
	#Begin recording
	logger.start_recording()

#Constantly update the Data Logger
func _process(delta: float) -> void:
	if logger.recording:
		logger.update(delta)
	
	else:
		if logger.elapsed_time >= logger.experiment_timer:
			print("\n[TERRARIUM REPORT]: Dragonfly Experiment has finished")
			print("...Closing Terrarium")
			get_tree().quit()
			
			#print("\n[TERRARIUM REPORT]: Dragonfly Experiment has finished")
			#print("...Restarting Terrarium")
			#get_tree().reload_current_scene()
