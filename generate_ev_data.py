import os
import random
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from faker import Faker

# Initialize Faker and seed for reproducibility
fake = Faker()
Faker.seed(42)
np.random.seed(42)
random.seed(42)

# Create output directory
os.makedirs("data/raw", exist_ok=True)

# Configuration settings
NUM_CUSTOMERS = 300
NUM_MODELS = 12
NUM_STATIONS = 25
NUM_CHARGERS = 100
NUM_TARIFFS = 4
NUM_VEHICLES = 400
NUM_SESSIONS = 1200  # Exceeds the 1,000+ total rows requirement
NUM_MAINTENANCE = 80

print("Generating synthetic dataset for Smart EV Charging Network...")

# ---------------------------------------------------------
# 1. EV_Models Table
# ---------------------------------------------------------
makes_models = [
    ("Tesla", "Model 3", 60, "CCS/NACS"),
    ("Tesla", "Model Y", 75, "CCS/NACS"),
    ("Hyundai", "Ioniq 5", 77, "CCS"),
    ("Kia", "EV6", 77, "CCS"),
    ("Ford", "Mustang Mach-E", 88, "CCS"),
    ("Ford", "F-150 Lightning", 131, "CCS"),
    ("Chevrolet", "Bolt EV", 65, "CCS"),
    ("Nissan", "Leaf", 60, "CHAdeMO"),
    ("BMW", "i4", 81, "CCS"),
    ("Volkswagen", "ID.4", 82, "CCS"),
    ("Rivian", "R1T", 135, "CCS"),
    ("Porsche", "Taycan", 93, "CCS")
]

models_data = []
for i, (make, model, cap, conn) in enumerate(makes_models, start=1):
    models_data.append({
        "model_id": i,
        "make": make,
        "model": model,
        "battery_capacity_kwh": cap,
        "connector_type": conn
    })
df_models = pd.DataFrame(models_data)
df_models.to_csv("data/raw/ev_models.csv", index=False)

# ---------------------------------------------------------
# 2. Customers Table
# ---------------------------------------------------------
customers_data = []
for i in range(1, NUM_CUSTOMERS + 1):
    join_date = fake.date_between(start_date="-2y", end_date="today")
    customers_data.append({
        "customer_id": i,
        "first_name": fake.first_name(),
        "last_name": fake.last_name(),
        "email": fake.unique.email(),
        "phone": fake.phone_number(),
        "signup_date": join_date,
        "membership_type": random.choice(["Pay-As-You-Go", "Monthly-Pass", "Premium-Fleet"])
    })
df_customers = pd.DataFrame(customers_data)
df_customers.to_csv("data/raw/customers.csv", index=False)

# ---------------------------------------------------------
# 3. Customer_Vehicles Table
# ---------------------------------------------------------
vehicles_data = []
for i in range(1, NUM_VEHICLES + 1):
    vehicles_data.append({
        "vehicle_id": i,
        "customer_id": random.randint(1, NUM_CUSTOMERS),
        "model_id": random.randint(1, NUM_MODELS),
        "license_plate": fake.license_plate(),
        "vin": fake.unique.vin()
    })
df_vehicles = pd.DataFrame(vehicles_data)
df_vehicles.to_csv("data/raw/customer_vehicles.csv", index=False)

# ---------------------------------------------------------
# 4. Stations Table
# ---------------------------------------------------------
stations_data = []
categories = ["Highway Corridor", "Urban Hub", "Suburban Mall", "Residential Transit"]
cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Seattle", "Toronto", "Vancouver"]

for i in range(1, NUM_STATIONS + 1):
    stations_data.append({
        "station_id": i,
        "station_name": f"PulseCharge - {fake.street_name()}",
        "category": random.choice(categories),
        "address": fake.street_address(),
        "city": random.choice(cities),
        "latitude": round(float(fake.latitude()), 6),
        "longitude": round(float(fake.longitude()), 6),
        "installation_date": fake.date_between(start_date="-3y", end_date="-6m")
    })
df_stations = pd.DataFrame(stations_data)
df_stations.to_csv("data/raw/stations.csv", index=False)

# ---------------------------------------------------------
# 5. Chargers_Ports Table
# ---------------------------------------------------------
chargers_data = []
for i in range(1, NUM_CHARGERS + 1):
    charger_type = random.choice(["Level 2 AC", "DC Fast 150kW", "DC Ultra-Fast 350kW"])
    max_kw = 22 if "Level 2" in charger_type else (150 if "150kW" in charger_type else 350)
    
    chargers_data.append({
        "charger_id": i,
        "station_id": random.randint(1, NUM_STATIONS),
        "serial_number": f"SN-{fake.unique.hexify(text='^^^^^^^^')}",
        "charger_type": charger_type,
        "max_power_kw": max_kw,
        "status": random.choice(["Available", "Occupied", "Offline", "Maintenance"])
    })
df_chargers = pd.DataFrame(chargers_data)
df_chargers.to_csv("data/raw/chargers_ports.csv", index=False)

# ---------------------------------------------------------
# 6. Tariffs Table
# ---------------------------------------------------------
tariffs_data = [
    {"tariff_id": 1, "tariff_name": "Standard Off-Peak", "rate_per_kwh": 0.22, "session_fee": 1.00},
    {"tariff_id": 2, "tariff_name": "Peak Demand", "rate_per_kwh": 0.48, "session_fee": 2.50},
    {"tariff_id": 3, "tariff_name": "Highway Superfast", "rate_per_kwh": 0.55, "session_fee": 3.00},
    {"tariff_id": 4, "tariff_name": "Subscriber Discount", "rate_per_kwh": 0.18, "session_fee": 0.00}
]
df_tariffs = pd.DataFrame(tariffs_data)
df_tariffs.to_csv("data/raw/tariffs.csv", index=False)

# ---------------------------------------------------------
# 7. Charging_Sessions & Payments Tables (Fact Data)
# ---------------------------------------------------------
sessions_data = []
payments_data = []

start_base = datetime.now() - timedelta(days=90)

for i in range(1, NUM_SESSIONS + 1):
    charger_id = random.randint(1, NUM_CHARGERS)
    vehicle_id = random.randint(1, NUM_VEHICLES)
    vehicle_row = df_vehicles[df_vehicles['vehicle_id'] == vehicle_id].iloc[0]
    customer_id = vehicle_row['customer_id']
    
    # Generate timestamp within last 90 days
    start_time = start_base + timedelta(
        days=random.randint(0, 89),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59)
    )
    
    duration_minutes = random.randint(15, 180)
    end_time = start_time + timedelta(minutes=duration_minutes)
    
    # Calculate realistic kWh based on duration
    kwh_delivered = round(random.uniform(10.0, 85.0), 2)
    tariff_id = random.choice([1, 2, 3, 4])
    tariff_row = df_tariffs[df_tariffs['tariff_id'] == tariff_id].iloc[0]
    
    # Cost calculation
    total_cost = round((kwh_delivered * tariff_row['rate_per_kwh']) + tariff_row['session_fee'], 2)
    
    sessions_data.append({
        "session_id": i,
        "charger_id": charger_id,
        "customer_id": customer_id,
        "vehicle_id": vehicle_id,
        "tariff_id": tariff_id,
        "start_time": start_time.strftime("%Y-%m-%d %H:%M:%S"),
        "end_time": end_time.strftime("%Y-%m-%d %H:%M:%S"),
        "duration_minutes": duration_minutes,
        "energy_kwh": kwh_delivered,
        "total_cost": total_cost
    })
    
    # Payment record
    payments_data.append({
        "payment_id": i,
        "session_id": i,
        "payment_method": random.choice(["Credit Card", "Mobile App Wallet", "RFID Card", "Apple Pay"]),
        "payment_status": random.choice(["Completed", "Completed", "Completed", "Failed"]),
        "payment_timestamp": end_time.strftime("%Y-%m-%d %H:%M:%S"),
        "amount": total_cost
    })

df_sessions = pd.DataFrame(sessions_data)
df_sessions.to_csv("data/raw/charging_sessions.csv", index=False)

df_payments = pd.DataFrame(payments_data)
df_payments.to_csv("data/raw/payments.csv", index=False)

# ---------------------------------------------------------
# 8. Maintenance_Tickets Table
# ---------------------------------------------------------
maintenance_data = []
issues = [
    "Connector Lock Malfunction", "Screen Unresponsive", "Power Inverter Fault",
    "Payment Terminal Offline", "Overheating Warning", "Cable Wear and Tear"
]

for i in range(1, NUM_MAINTENANCE + 1):
    report_date = fake.date_between(start_date="-90d", end_date="today")
    status = random.choice(["Open", "In Progress", "Resolved"])
    resolved_date = report_date + timedelta(days=random.randint(1, 5)) if status == "Resolved" else None
    
    maintenance_data.append({
        "ticket_id": i,
        "charger_id": random.randint(1, NUM_CHARGERS),
        "issue_description": random.choice(issues),
        "reported_date": report_date,
        "resolved_date": resolved_date,
        "status": status,
        "downtime_hours": round(random.uniform(2.0, 48.0), 1) if status == "Resolved" else 0.0
    })

df_maintenance = pd.DataFrame(maintenance_data)
df_maintenance.to_csv("data/raw/maintenance_tickets.csv", index=False)

print(f"Data generation complete! Saved 8 CSV files into 'data/raw/'. Total session rows: {len(df_sessions)}.")