#----------------------------
#DATA LOGGER
#----------------------------

class_name DataLogger
extends Node

#Configuration
var experiment_id: int
var experiment_id_past: int = 0
var experiment_name: String
var experiment_amount: int = 0
var hunt_mode: bool = true
var sample_interval: float = 0.5
var experiment_timer: float = 600

#Storage
var logger_data: Array[Dictionary] = []

#Data
var elapsed_time: float = 0.0
var sample_timer: float = 0.0
var recording: bool = false

#References
var dragonfly: DragonflyBody
var state: String
var dataset: Array[Array]
var prey1: CharacterBody2D
var prey2: CharacterBody2D
var prey3: CharacterBody2D

#Starts recording samples
func start_recording():
	#Reset variables
	logger_data.clear()
	elapsed_time = 0.0
	sample_timer = 0.0
	
	#Update state
	state = dragonfly.get_node("DragonflyController").current_state.name
	
	#Flag start of recording
	recording = true
	
	print("[DataLogger Report]: Recording Experiment - ON")
	
	if hunt_mode:
		print("HUNT MODE - Enabled")
	else:
		print("HUNT MODE - Disabled")

#Stops recording samples
func stop_recording():
	recording = false
	print("[DataLogger Report]: Recording Experiment - OFF")
	print("Samples collected: ", logger_data.size())


func update(delta: float) -> void:
	#Only runs code if recording
	if recording:
		#If the experiment's timer run out, end experiment and record findings
		if elapsed_time >= experiment_timer:
			stop_recording()
			export_csv()
			return
		
		elapsed_time += delta
		sample_timer += delta
		
	#Preserve accumulated time
	while sample_timer >= sample_interval:
		sample_timer -= sample_interval
		record_sample()

#Records new sample
func record_sample():
	#Update state
	state = dragonfly.get_node("DragonflyController").current_state.name
	
	#Auxiliary data variables
	var hunt_type
	var predicting
	var prey1_status
	var prey1_pos_x
	var prey1_pos_y
	var prey1_vel_x
	var prey1_vel_y
	var prey2_status
	var prey2_pos_x
	var prey2_pos_y
	var prey2_vel_x
	var prey2_vel_y
	var prey3_status
	var prey3_pos_x
	var prey3_pos_y
	var prey3_vel_x
	var prey3_vel_y
	
	#Handle hunter mode var
	if hunt_mode:
		hunt_type = "ON"
	else:
		hunt_type = "OFF"
	
	if state == "DragonflyStateHunt":
		predicting = dragonfly.get_node("DragonflyController").current_state.predicting
	else:
		predicting = false
	
	#Handle information for alive and dead prey
	if is_instance_valid(prey1) and not prey1.is_queued_for_deletion():
		prey1_status = "Alive"
		prey1_pos_x = (prey1.global_position.x)
		prey1_pos_y = (prey1.global_position.y)
		prey1_vel_x = (prey1.velocity.x)
		prey1_vel_y = (prey1.velocity.y)
	else:
		prey1_status = "Dead"
		prey1_pos_x = null
		prey1_pos_y = null
		prey1_vel_x = null
		prey1_vel_y = null
	
	if is_instance_valid(prey2) and not prey2.is_queued_for_deletion():
		prey2_status = "Alive"
		prey2_pos_x = (prey2.global_position.x)
		prey2_pos_y = (prey2.global_position.y)
		prey2_vel_x = (prey2.velocity.x)
		prey2_vel_y = (prey2.velocity.y)
	else:
		prey2_status = "Dead"
		prey2_pos_x = null
		prey2_pos_y = null
		prey2_vel_x = null
		prey2_vel_y = null
	
	if is_instance_valid(prey3) and not prey3.is_queued_for_deletion():
		prey3_status = "Alive"
		prey3_pos_x = (prey3.global_position.x)
		prey3_pos_y = (prey3.global_position.y)
		prey3_vel_x = (prey3.velocity.x)
		prey3_vel_y = (prey3.velocity.y)
	else:
		prey3_status = "Dead"
		prey3_pos_x = null
		prey3_pos_y = null
		prey3_vel_x = null
		prey3_vel_y = null
	
	var sample = {
		"experiment": experiment_name,
		"elapsed_seconds": elapsed_time,
		"hunt_mode": hunt_type,
		"dragonfly_state": state,
		"dragonfly_predicting": predicting,
		"dragonfly_position_x": (dragonfly.global_position.x),
		"dragonfly_position_y": (dragonfly.global_position.y),
		"dragonfly_velocity_x": (dragonfly.velocity.x),
		"dragonfly_velocity_y": (dragonfly.velocity.y),
		"prey1_status": prey1_status,
		"prey1_position_x": prey1_pos_x,
		"prey1_position_y": prey1_pos_y,
		"prey1_velocity_x": prey1_vel_x,
		"prey1_velocity_y": prey1_vel_y,
		"prey2_status": prey2_status,
		"prey2_position_x": prey2_pos_x,
		"prey2_position_y": prey2_pos_y,
		"prey2_velocity_x": prey2_vel_x,
		"prey2_velocity_y": prey2_vel_y,
		"prey3_status": prey3_status,
		"prey3_position_x": prey3_pos_x,
		"prey3_position_y": prey3_pos_y,
		"prey3_velocity_x": prey3_vel_x,
		"prey3_velocity_y": prey3_vel_y
	}
	
	#Add to the data logger array
	logger_data.append(sample)

#Export current logger data array into csv file format
func export_csv():
	var file_path = "user://" + experiment_name + "_" + str(experiment_id) + ".csv"

	var file = FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error("Could not create CSV file")
		return

	#CSV header
	file.store_csv_line(PackedStringArray([
		"Experiment",
		"Elapsed (s)",
		"Hunt Mode (ON/OFF)",
		"Dragonfly's State",
		"Predicting",
		"X",
		"Y",
		"Xv",
		"Yv",
		"Prey 1's Status",
		"X",
		"Y",
		"Xv",
		"Yv",
		"Prey 2's Status",
		"X",
		"Y",
		"Xv",
		"Yv",
		"Prey 3's Status",
		"X",
		"Y",
		"Xv",
		"Yv",
	]))

	#Write measurements
	for sample in logger_data:
		file.store_csv_line(PackedStringArray([
			str(sample["experiment"]),
			str(sample["elapsed_seconds"]),
			str(sample["hunt_mode"]),
			str(sample["dragonfly_state"]),
			str(sample["dragonfly_predicting"]),
			str(sample["dragonfly_position_x"]),
			str(sample["dragonfly_position_y"]),
			str(sample["dragonfly_velocity_x"]),
			str(sample["dragonfly_velocity_y"]),
			str(sample["prey1_status"]),
			str(sample["prey1_position_x"]),
			str(sample["prey1_position_y"]),
			str(sample["prey1_velocity_x"]),
			str(sample["prey1_velocity_y"]),
			str(sample["prey2_status"]),
			str(sample["prey2_position_x"]),
			str(sample["prey2_position_y"]),
			str(sample["prey2_velocity_x"]),
			str(sample["prey2_velocity_y"]),
			str(sample["prey3_status"]),
			str(sample["prey3_position_x"]),
			str(sample["prey3_position_y"]),
			str(sample["prey3_velocity_x"]),
			str(sample["prey3_velocity_y"])
		]))
	
	file.close()
	
	print("\n...exporting data")
	print("CSV exported to: ", file_path)
	print(OS.get_user_data_dir())
	
	#Remember last experiment id
	experiment_id_past = experiment_id
	
	#Save the amount of exeperiments done
	experiment_amount += 1
