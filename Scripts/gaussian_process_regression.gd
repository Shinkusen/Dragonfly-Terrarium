#----------------------------
#GAUSSIAN PROCESS REGRESSION
#----------------------------

class_name GaussianProcessRegression
extends RefCounted

#RBF kernel parameters.
var length_scale: float = 3.0
var signal_variance: float = 100.0
var noise_variance: float = 0.1

var trained := false
var latest_time: float = 0.0
var latest_position: Vector2 = Vector2.ZERO
var latest_velocity: Vector2 = Vector2.ZERO

var times: Array[float] = []
var alpha_x: Array[float] = []
var alpha_y: Array[float] = []

#Cholesky factor of K + noise * I.
var lower: Array = []

#Kernel function
func kernel(a: float, b: float) -> float:
	var d := (a - b) / length_scale
	return signal_variance * exp(-0.5 * d * d)

#Train model with the current dataset = [{"time": float, "position": Vector2, "velocity": Vector2}]
func train(dataset: Array) -> bool:
	trained = false

	var n := dataset.size()
	if n < 3:
		return false

	if length_scale <= 0.0:
		return false
	if signal_variance <= 0.0 or noise_variance <= 0.0:
		return false

	times.clear()

	#Dataset must be ordered oldest to newest.
	latest_time = float(dataset[n - 1]["time"])
	latest_position = dataset[n - 1]["position"]
	latest_velocity = dataset[n - 1]["velocity"]

	#Use relative timestamps for numerical stability.
	for sample in dataset:
		times.append(float(sample["time"]) - latest_time)

	var matrix: Array = []

	for i in range(n):
		var row: Array[float] = []
		row.resize(n)
		
		#Add noise to the diagonal of the Kernel matrix
		for j in range(n):
			row[j] = kernel(times[i], times[j])

			if i == j:
				row[j] += noise_variance

		matrix.append(row)

	#Cholesky: K = L * transpose(L).
	lower = cholesky(matrix)

	if lower.is_empty():
		return false
	
	#Residual
	var residual_x: Array[float] = []
	var residual_y: Array[float] = []
	
	#Actual_Historical_Position = Baseline_Position + Residual
	for i in range(n):
		var sample: Dictionary = dataset[i]
		var dt: float = times[i]

		var baseline: Vector2 = (latest_position + latest_velocity * dt)

		var residual: Vector2 = (sample["position"] - baseline)
		
		#Save Residual
		residual_x.append(residual.x)
		residual_y.append(residual.y)

	alpha_x = solve_cholesky(lower, residual_x)
	alpha_y = solve_cholesky(lower, residual_y)

	if alpha_x.size() != n or alpha_y.size() != n:
		return false

	trained = true
	return true

#Cholesky decomposition
func cholesky(matrix: Array) -> Array:
	var n := matrix.size()
	var l: Array = []

	for i in range(n):
		var row: Array[float] = []
		row.resize(n)
		row.fill(0.0)
		l.append(row)

	for i in range(n):
		for j in range(i + 1):
			var s: float = matrix[i][j]

			for k in range(j):
				s -= l[i][k] * l[j][k]

			if i == j:
				if s <= 0.000000001:
					return []
				l[i][j] = sqrt(s)
			else:
				l[i][j] = s / l[j][j]

	return l

#Solve from cholesky: (L * L^T) * x = b.
func solve_cholesky(l: Array, b: Array[float]) -> Array[float]:
	var n := b.size()
	var z: Array[float] = []
	var x: Array[float] = []

	z.resize(n)
	z.fill(0.0)
	x.resize(n)
	x.fill(0.0)

	#Forward substitution: L * z = b.
	for i in range(n):
		var s: float = b[i]

		for j in range(i):
			s -= l[i][j] * z[j]

		z[i] = s / l[i][i]

	#Back substitution: transpose(L) * x = z.
	for i in range(n - 1, -1, -1):
		var s: float = z[i]

		for j in range(i + 1, n):
			s -= l[j][i] * x[j]

		x[i] = s / l[i][i]

	return x

#Predict horizon seconds after the newest observation.
func gaussian_predict(horizon: float) -> Dictionary:
	if not trained:
		return {"position": Vector2.ZERO, "variance": -1.0, "valid": false}

	var n := times.size()
	var query_time := horizon
	var k_star: Array[float] = []
	var correction := Vector2.ZERO

	for i in range(n):
		var k := kernel(query_time, times[i])
		k_star.append(k)

		correction.x += k * alpha_x[i]
		correction.y += k * alpha_y[i]

	#Posterior variance: k** - k*^T K^-1 k*.
	#Solve L * z = k*, then z^T * z = k*^T K^-1 k*.
	var z: Array[float] = []
	z.resize(n)
	z.fill(0.0)

	for i in range(n):
		var s: float = k_star[i]

		for j in range(i):
			s -= lower[i][j] * z[j]

		z[i] = s / lower[i][i]

	var variance := signal_variance

	for value in z:
		variance -= value * value

	variance = maxf(variance, 0.0)
	
	#Calculate prediction without uncertanty
	#Calculate baseline
	#var baseline: Vector2 = (latest_position + latest_velocity * horizon)
	#
	#print("BASELINE: ", baseline)
	#print("CORRECTION: ", correction)
	#
	#return {"position": baseline + correction,"variance": variance,"valid": true}
	
	#Calculate prediction with uncertanty
	#Calculate baseline
	var baseline: Vector2 = latest_position + latest_velocity * horizon

	#Normalize uncertainty.
	var uncertainty := clampf(variance / signal_variance, 0.0, 1.0)

	#Confidence determines how much we trust the GP correction.
	var confidence := 1.0 - uncertainty

	#Apply confidence to the correction.
	var final_position := baseline + correction * confidence

	print("BASELINE: ", baseline)
	print("CORRECTION: ", correction)
	print("VARIANCE: ", variance)
	print("CONFIDENCE: ", confidence)
	print("FINAL POSITION: ", final_position)

	return {
		"position": final_position,
		"variance": variance,
		"valid": true
	}

#The final prediction based on the current time (horizon), OBS: Its doesn't need to be trained always
func predict(dataset: Array, horizon: float) -> Vector2:
	#Train using the external dataset.
	if not train(dataset):
		return Vector2(-1, -1)

	#Predict future position.
	var result: Dictionary = gaussian_predict(horizon)

	if not result["valid"]:
		return Vector2(-1, -1)

	return result["position"]

func predict_with_uncertainty(dataset: Array, horizon: float) -> Dictionary:
	if not train(dataset):
		return {
			"position": Vector2.ZERO,
			"variance": -1.0,
			"uncertainty": 1.0,
			"confidence": 0.0,
			"valid": false}
	var result := gaussian_predict(horizon)
	
	if not result["valid"]:
		return result
	
	#Normalize posterior variance.
	var uncertainty: float = clampf(result["variance"] / signal_variance, 0.0, 1.0)
	
	result["uncertainty"] = uncertainty
	result["confidence"] = 1.0 - uncertainty
	
	return result
