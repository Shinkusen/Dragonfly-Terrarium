#----------------------------
#DRAGONFLY'S BODY
#----------------------------

class_name DragonflyBody
extends CharacterBody2D

#Define velocity (float)
@export var speed: float = 100.0

#Dictates if the hunt state is allowed (Default is true)
@export var hunt_mode: bool = true

#Vision reference
@onready var vision = $Vision/RayCast2D

#To manage multiple prey that are close and check first layer of detection
var close_prey: Array[CharacterBody2D] = []
var smelling: bool = false

#Signal a function in the Stalk State
signal prey_found(prey)
signal prey_lost(prey)

func _ready() -> void:
	print("[REPORT]: Dragonfly's Body is Running")

#If prey is nearby, stay alert to sight it with RayCast
func prey_nearby() -> void:
	if smelling:
		for prey in close_prey:
			vision.target_position = prey.global_position - global_position
			vision.force_raycast_update()

			if vision.get_collider() == prey:
				prey_found.emit(prey)

#Handles basic movement and recieves a Vector2 as a parameter
func move_body(velocity_vector: Vector2) -> void:
	
	self.velocity = velocity_vector
	move_and_slide()

#If a prey enters the detection area, smelling is turned on
func _on_vision_body_entered(body: Node2D) -> void:
	if body.is_in_group("prey"):
		print("Smelling...")
		smelling = true
		close_prey.append(body)

#If a prey leaves the detection area, its droped and smelling is turned off if no other prey are inside
func _on_vision_body_exited(body: Node2D) -> void:
	if body.is_in_group("prey"):
		close_prey.erase(body)
		
		if close_prey.is_empty():
			smelling = false
			prey_lost.emit(body)
