-- ============================================================================
-- Project: Smart EV Charging Network Analytics (PulseCharge Network)
-- Script: 03_Local_Database.sql
-- Description: Schema creation script for 8 normalized tables in 3NF with constraints
-- Database Target: PostgreSQL / AWS RDS PostgreSQL
-- ============================================================================

-- Drop tables if they exist (in reverse order of foreign key dependency)
DROP TABLE IF EXISTS Payments CASCADE;
DROP TABLE IF EXISTS Maintenance_Tickets CASCADE;
DROP TABLE IF EXISTS Charging_Sessions CASCADE;
DROP TABLE IF EXISTS Chargers_Ports CASCADE;
DROP TABLE IF EXISTS Stations CASCADE;
DROP TABLE IF EXISTS Customer_Vehicles CASCADE;
DROP TABLE IF EXISTS Customers CASCADE;
DROP TABLE IF EXISTS EV_Models CASCADE;
DROP TABLE IF EXISTS Tariffs CASCADE;

-- ----------------------------------------------------------------------------
-- 1. EV_Models (Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE EV_Models (
    model_id INT PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    battery_capacity_kwh NUMERIC(5,2) NOT NULL CHECK (battery_capacity_kwh > 0),
    connector_type VARCHAR(20) NOT NULL CHECK (connector_type IN ('CCS', 'CHAdeMO', 'CCS/NACS', 'Type 2'))
);

-- ----------------------------------------------------------------------------
-- 2. Customers (Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(30),
    signup_date DATE NOT NULL DEFAULT CURRENT_DATE,
    membership_type VARCHAR(30) NOT NULL CHECK (membership_type IN ('Pay-As-You-Go', 'Monthly-Pass', 'Premium-Fleet'))
);

-- ----------------------------------------------------------------------------
-- 3. Customer_Vehicles (Bridge/Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE Customer_Vehicles (
    vehicle_id INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES Customers(customer_id) ON DELETE CASCADE,
    model_id INT NOT NULL REFERENCES EV_Models(model_id),
    license_plate VARCHAR(20) NOT NULL,
    vin VARCHAR(17) UNIQUE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 4. Stations (Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE Stations (
    station_id INT PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    category VARCHAR(30) NOT NULL CHECK (category IN ('Highway Corridor', 'Urban Hub', 'Suburban Mall', 'Residential Transit')),
    address VARCHAR(150) NOT NULL,
    city VARCHAR(50) NOT NULL,
    latitude NUMERIC(9,6) NOT NULL,
    longitude NUMERIC(9,6) NOT NULL,
    installation_date DATE NOT NULL
);

-- ----------------------------------------------------------------------------
-- 5. Chargers_Ports (Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE Chargers_Ports (
    charger_id INT PRIMARY KEY,
    station_id INT NOT NULL REFERENCES Stations(station_id) ON DELETE CASCADE,
    serial_number VARCHAR(50) UNIQUE NOT NULL,
    charger_type VARCHAR(30) NOT NULL CHECK (charger_type IN ('Level 2 AC', 'DC Fast 150kW', 'DC Ultra-Fast 350kW')),
    max_power_kw NUMERIC(5,2) NOT NULL CHECK (max_power_kw > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('Available', 'Occupied', 'Offline', 'Maintenance'))
);

-- ----------------------------------------------------------------------------
-- 6. Tariffs (Dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE Tariffs (
    tariff_id INT PRIMARY KEY,
    tariff_name VARCHAR(50) NOT NULL,
    rate_per_kwh NUMERIC(5,2) NOT NULL CHECK (rate_per_kwh >= 0),
    session_fee NUMERIC(5,2) NOT NULL CHECK (session_fee >= 0)
);

-- ----------------------------------------------------------------------------
-- 7. Charging_Sessions (Fact Table)
-- ----------------------------------------------------------------------------
CREATE TABLE Charging_Sessions (
    session_id INT PRIMARY KEY,
    charger_id INT NOT NULL REFERENCES Chargers_Ports(charger_id),
    customer_id INT NOT NULL REFERENCES Customers(customer_id),
    vehicle_id INT NOT NULL REFERENCES Customer_Vehicles(vehicle_id),
    tariff_id INT NOT NULL REFERENCES Tariffs(tariff_id),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    duration_minutes INT NOT NULL CHECK (duration_minutes >= 0),
    energy_kwh NUMERIC(6,2) NOT NULL CHECK (energy_kwh >= 0),
    total_cost NUMERIC(7,2) NOT NULL CHECK (total_cost >= 0),
    CONSTRAINT chk_timestamps CHECK (end_time >= start_time)
);

-- ----------------------------------------------------------------------------
-- 8. Payments (Transaction/Fact Table)
-- ----------------------------------------------------------------------------
CREATE TABLE Payments (
    payment_id INT PRIMARY KEY,
    session_id INT NOT NULL REFERENCES Charging_Sessions(session_id) ON DELETE CASCADE,
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('Credit Card', 'Mobile App Wallet', 'RFID Card', 'Apple Pay')),
    payment_status VARCHAR(20) NOT NULL CHECK (payment_status IN ('Completed', 'Failed', 'Pending', 'Refunded')),
    payment_timestamp TIMESTAMP NOT NULL,
    amount NUMERIC(7,2) NOT NULL CHECK (amount >= 0)
);

-- ----------------------------------------------------------------------------
-- 9. Maintenance_Tickets (Operational Table)
-- ----------------------------------------------------------------------------
CREATE TABLE Maintenance_Tickets (
    ticket_id INT PRIMARY KEY,
    charger_id INT NOT NULL REFERENCES Chargers_Ports(charger_id) ON DELETE CASCADE,
    issue_description VARCHAR(255) NOT NULL,
    reported_date DATE NOT NULL,
    resolved_date DATE,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Open', 'In Progress', 'Resolved')),
    downtime_hours NUMERIC(6,1) NOT NULL DEFAULT 0.0 CHECK (downtime_hours >= 0),
    CONSTRAINT chk_resolved_date CHECK (resolved_date IS NULL OR resolved_date >= reported_date)
);

-- Index creation for query optimization
CREATE INDEX idx_sessions_charger ON Charging_Sessions(charger_id);
CREATE INDEX idx_sessions_customer ON Charging_Sessions(customer_id);
CREATE INDEX idx_sessions_start_time ON Charging_Sessions(start_time);
CREATE INDEX idx_chargers_station ON Chargers_Ports(station_id);