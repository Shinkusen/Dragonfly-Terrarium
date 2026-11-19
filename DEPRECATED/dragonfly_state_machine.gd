class_name StateMachine
extends Node

var body: DragonflyBody
var controller: DragonflyController
var trigger: bool = true
var phase: int = 1

func enter() -> void:
	print("[REPORT]: Dragonfly's State Machine is Running")

func exit() -> void:
	print("[REPORT]: Shutting Down Dragonfly's State Machine")

func run(delta: float) -> void:
	if trigger:
		print("| STATE MACHINE TRIGGERED |")
		trigger = false
	
	for child in get_children():
		if child is WanderState and phase == 1:
			#Give the state the actual BODY
			child.body = body
			
			#Give the state a way to request state changes
			child.controller = controller
			
			child.state_behavior(delta)
