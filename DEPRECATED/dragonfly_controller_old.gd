#----------------------------
#DRAGONFLY'S CONTROLLER
#----------------------------

#class_name DragonflyController
extends Node

#@export var state_machine: StateMachine

@onready var wander = $DragonflyStateWander
@onready var stalk = $DragonflyStateStalk
@onready var hunt = $DragonflyStateHunt
@onready var current_state = wander

var body: DragonflyBody

func _ready() -> void:
	print("[REPORT]: Dragonfly's Controller is Running")
	
	#Get body reference(Body is parent)
	if get_parent() is DragonflyBody:
		body = get_parent() as DragonflyBody
	
	#Initialize all child states by giving them references (States are children)
	#for child in get_children():
		#if child is StateMachine:
		#
			##Give the state the actual BODY
			#child.body = body
			#
			##Give the state a way to request state changes
			#child.controller = self
	
	if current_state:
		print("[REPORT]: Dragonfly has a State Machine")
		#Give the state the actual BODY
		current_state.body = body
		
		#Give the state a way to request state changes
		current_state.controller = self
		
		#Enter the state
		current_state.enter()
	
	#if state_machine:
		#print("[REPORT]: Dragonfly has a State Machine")
		#state_machine.enter()

#func change_state(new_state: StateMachine) -> void:
	##Change state by using node paths
	#if current_state:
		#current_state.exit()
	#current_state = new_state
	#current_state.enter()
	
func change_state(new_state) -> void:
	#Change state by using node paths
	current_state = new_state
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		#Call the state machine loop
		current_state.state_behavior(delta)
	
	#if state_machine:
		##Call the state machine loop
		#state_machine.run(delta)
		
