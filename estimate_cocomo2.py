import sys

# Información del proyecto
projectInfo = {
    "totalLinesOfCode": 1500,  # Total de líneas de código estimadas
    "modelFiles": 10,        # Modelos de ActiveRecord
    "migrationFiles": 13,    # Migraciones de base de datos
    "viewFiles": 28,         # Vistas (ERB)
    "controllerFiles": 7,    # Controladores
    "helperFiles": 2,        # Helpers
    "mailerFiles": 1,        # Mailers
    "jobFiles": 7,           # Jobs (Sidekiq)
    "estimatedFunctionPoints": 150,  # Estimación basada en SRS y complejidad
    "complexityFactor": 1.3,  # Factor de complejidad estimado
    "staffSize": 2,         # Tamaño estimado del equipo
}

# Factores de esfuerzo COCOMO II
riskLevel = "E2"  # Riesgo moderado
riskMultipliers = {
    "E1": 1.20,  # Poco riesgo
    "E2": 1.35,  # Riesgo moderado (asumido)
    "E3": 1.60,  # Riesgo alto
    "E4": 1.90,  # Riesgo muy alto
    "E5": 2.30   # Riesgo extremo
}

# Calcular esfuerzo en Function Points
functionPoints = projectInfo["estimatedFunctionPoints"] * projectInfo["complexityFactor"]

# Calcular esfuerzo en Person-Months (Effort) usando COCOMO II
effortMultiplier = riskMultipliers[riskLevel]
effort = functionPoints * effortMultiplier

# Calcular duración estimada en meses
estimatedDuration = effort / projectInfo["staffSize"]

# Calcular presupuesto estimado (asumiendo $60 USD por persona-mes)
costPerPersonMonth = 60
expectedBudget = effort * costPerPersonMonth

# Información de salida
print(f"\n{'='*60}")
print("ESTIMACIÓN DE ESFUERZO COCOMO II PARA DIGITALLAW")
print(f"{'='*60}")
print(f"\nTotal de líneas de código: {projectInfo['totalLinesOfCode']}")
print(f"Líneas de código por tipo:")
print(f"  - Modelos: {projectInfo['modelFiles']} ({projectInfo['modelFiles'] * 100 / projectInfo['totalLinesOfCode']:.1f}%)")
print(f"  - Migraciones: {projectInfo['migrationFiles']} ({projectInfo['migrationFiles'] * 100 / projectInfo['totalLinesOfCode']:.1f}%)")
print(f"  - Vistas: {projectInfo['viewFiles']} ({projectInfo['viewFiles'] * 100 / projectInfo['totalLinesOfCode']:.1f}%)")
print(f"  - Controladores: {projectInfo['controllerFiles']} ({projectInfo['controllerFiles'] * 100 / projectInfo['totalLinesOfCode']:.1f}%)")
print(f"\nEstimación de Function Points: {functionPoints}")
print(f"Riesgo estimado: {riskLevel} ({riskMultipliers[riskLevel]}x)")
print(f"\nEffort estimado (Person-Months): {effort:.2f}")
print(f"Duración estimada (meses): {estimatedDuration:.2f}")
print(f"Presupuesto estimado (USD): ${expectedBudget:.2f}")
print(f"\nTamaño del equipo: {projectInfo['staffSize']} desarrolladores")
print(f"\nNota: Este cálculo es una estimación basada en el SRS, complejidad y riesgo moderado.")
