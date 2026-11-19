#----------------------------
#DRAGONFLY'S DATABASE
#----------------------------

class_name Database
extends RefCounted

#Full dataset, each index is an array of samples for unique prey
var dataset: Array[Array] = []

#Size for the allowed amount of data samples held for each prey
var size_databundle = 5

#Add data based on the provided index from prey's id
func add_data(id: int, time: float, position: Vector2, velocity: Vector2) -> void:
	#Add another index for new dicovered prey
	while dataset.size() <= id:
		dataset.append([])
	
	#Until the databundle has reached its max
	if dataset[id].size() < size_databundle:
		dataset[id].append({"time": time, "position": position, "velocity": velocity})
	
	#When the databundle reached its max, replace oldest
	else:
		dataset[id].pop_front()
		dataset[id].append({"time": time,"position": position,"velocity": velocity})

#Purge all data
func clear() -> void:
	dataset.clear()

#Return amount (REMEMBER: do not go over 50 samples per target)
func get_count() -> int:
	return dataset.size()
