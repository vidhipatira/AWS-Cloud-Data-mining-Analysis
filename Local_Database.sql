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
----------------------------------------------------------------------------------------------------------------
----------------------------VIEWS------------------------------------------------------------------------------------------
-- View 1: Daily Station Performance Metrics
CREATE VIEW vw_station_daily_performance AS
SELECT 
    s.station_id,
    s.station_name,
    s.category,
    DATE(cs.start_time) AS session_date,
    COUNT(cs.session_id) AS total_sessions,
    ROUND(SUM(cs.energy_kwh), 2) AS total_kwh_delivered,
    ROUND(SUM(cs.total_cost), 2) AS total_revenue,
    ROUND(AVG(cs.duration_minutes), 1) AS avg_duration_mins
FROM Stations s
JOIN Chargers_Ports cp ON s.station_id = cp.station_id
JOIN Charging_Sessions cs ON cp.charger_id = cs.charger_id
GROUP BY s.station_id, s.station_name, s.category, DATE(cs.start_time);

-- View 2: Active Maintenance Outages and Reliability
CREATE VIEW vw_active_maintenance_issues AS
SELECT 
    s.station_name,
    cp.charger_id,
    cp.charger_type,
    mt.ticket_id,
    mt.issue_description,
    mt.reported_date,
    mt.status,
    mt.downtime_hours
FROM Maintenance_Tickets mt
JOIN Chargers_Ports cp ON mt.charger_id = cp.charger_id
JOIN Stations s ON cp.station_id = s.station_id
WHERE mt.status IN ('Open', 'In Progress');

-- View 3: Customer Lifetime Value & Charging Summary
CREATE VIEW vw_customer_usage_summary AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.membership_type,
    COUNT(cs.session_id) AS total_sessions,
    ROUND(SUM(cs.energy_kwh), 2) AS total_kwh,
    ROUND(SUM(cs.total_cost), 2) AS total_spent,
    MAX(cs.start_time) AS last_charging_session
FROM Customers c
LEFT JOIN Charging_Sessions cs ON c.customer_id = cs.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_type;
----------------------------------------------------------------------------------------------------
---------------------------FUNCTIONS--------------------------------------------------------------------------------------------------
-- Function 1: Calculate dynamic cost for a session based on duration and tariff rate
CREATE OR REPLACE FUNCTION fn_calculate_session_cost(
    p_kwh NUMERIC,
    p_tariff_id INT
)
RETURNS NUMERIC AS $$
DECLARE
    v_rate NUMERIC;
    v_fee NUMERIC;
    v_total NUMERIC;
BEGIN
    SELECT rate_per_kwh, session_fee INTO v_rate, v_fee
    FROM Tariffs WHERE tariff_id = p_tariff_id;
    
    v_total := (p_kwh * v_rate) + v_fee;
    RETURN ROUND(v_total, 2);
END;
$$ LANGUAGE plpgsql;

-- Procedure 2: Log maintenance issue and mark charger as Offline
CREATE OR REPLACE PROCEDURE sp_report_charger_fault(
    p_charger_id INT,
    p_issue VARCHAR
)
AS $$
BEGIN
    -- Insert maintenance ticket
    INSERT INTO Maintenance_Tickets (ticket_id, charger_id, issue_description, reported_date, status, downtime_hours)
    VALUES (
        (SELECT COALESCE(MAX(ticket_id), 0) + 1 FROM Maintenance_Tickets),
        p_charger_id, p_issue, CURRENT_DATE, 'Open', 0.0
    );
    
    -- Update charger status
    UPDATE Chargers_Ports
    SET status = 'Offline'
    WHERE charger_id = p_charger_id;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Identify at-risk churned customers (No session in X days)
CREATE OR REPLACE FUNCTION fn_get_inactive_customers(p_days INT)
RETURNS TABLE (
    customer_id INT,
    customer_name TEXT,
    email VARCHAR,
    days_since_last_charge INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.customer_id,
        (c.first_name || ' ' || c.last_name)::TEXT,
        c.email,
        (CURRENT_DATE - MAX(cs.start_time)::DATE)::INT AS days_since_last_charge
    FROM Customers c
    JOIN Charging_Sessions cs ON c.customer_id = cs.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
    HAVING (CURRENT_DATE - MAX(cs.start_time)::DATE) >= p_days;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------ANALYTICAL QUERIES-------------------------------------------------------------------------------------------------------------------------------
-- Q1: Total Revenue and Energy Delivered by Station Category
SELECT s.category, COUNT(cs.session_id) AS total_sessions, ROUND(SUM(cs.total_cost), 2) AS revenue
FROM Stations s
JOIN Chargers_Ports cp ON s.station_id = cp.station_id
JOIN Charging_Sessions cs ON cp.charger_id = cs.charger_id
GROUP BY s.category ORDER BY revenue DESC;

-- Q2: Top 5 Station Locations by Occupancy Volume
SELECT s.station_name, COUNT(cs.session_id) AS session_count
FROM Stations s
JOIN Chargers_Ports cp ON s.station_id = cp.station_id
JOIN Charging_Sessions cs ON cp.charger_id = cs.charger_id
GROUP BY s.station_name ORDER BY session_count DESC LIMIT 5;

-- Q3: Average Session Duration and kWh per EV Model
SELECT m.make, m.model, ROUND(AVG(cs.duration_minutes), 1) AS avg_duration, ROUND(AVG(cs.energy_kwh), 2) AS avg_kwh
FROM EV_Models m
JOIN Customer_Vehicles cv ON m.model_id = cv.model_id
JOIN Charging_Sessions cs ON cv.vehicle_id = cs.vehicle_id
GROUP BY m.make, m.model ORDER BY avg_kwh DESC;

-- Q4: Peak vs Off-Peak Usage Analysis by Hour
SELECT EXTRACT(HOUR FROM start_time) AS hour_of_day, COUNT(*) AS session_count, ROUND(SUM(energy_kwh), 2) AS total_kwh
FROM Charging_Sessions
GROUP BY hour_of_day ORDER BY hour_of_day;

-- Q5: Revenue Breakdown by Payment Method
SELECT payment_method, COUNT(*) AS transactions, SUM(amount) AS total_revenue
FROM Payments WHERE payment_status = 'Completed'
GROUP BY payment_method;

-- Q6: Stations with the Highest Charger Downtime Hours
SELECT s.station_name, SUM(mt.downtime_hours) AS total_downtime_hours
FROM Maintenance_Tickets mt
JOIN Chargers_Ports cp ON mt.charger_id = cp.charger_id
JOIN Stations s ON cp.station_id = s.station_id
GROUP BY s.station_name ORDER BY total_downtime_hours DESC LIMIT 5;

-- Q7: CTE - Revenue Contribution Per Customer Tier
WITH CustomerSpend AS (
    SELECT c.membership_type, cs.total_cost
    FROM Customers c JOIN Charging_Sessions cs ON c.customer_id = cs.customer_id
)
SELECT membership_type, COUNT(*) AS session_count, ROUND(SUM(total_cost), 2) AS total_revenue
FROM CustomerSpend GROUP BY membership_type;

-- Q8: Window Function - Rank Chargers within Each Station by Revenue
SELECT cp.station_id, cp.charger_id, SUM(cs.total_cost) AS charger_revenue,
       RANK() OVER (PARTITION BY cp.station_id ORDER BY SUM(cs.total_cost) DESC) AS rank_in_station
FROM Chargers_Ports cp
JOIN Charging_Sessions cs ON cp.charger_id = cs.charger_id
GROUP BY cp.station_id, cp.charger_id;

-- Q9: Failed Payment Analysis by Customer
SELECT c.customer_id, c.first_name, c.last_name, COUNT(p.payment_id) AS failed_payments
FROM Customers c
JOIN Charging_Sessions cs ON c.customer_id = cs.customer_id
JOIN Payments p ON cs.session_id = p.session_id
WHERE p.payment_status = 'Failed'
GROUP BY c.customer_id, c.first_name, c.last_name;

-- Q10: Average Rate Paid per kWh Across Different Tariffs
SELECT t.tariff_name, ROUND(AVG(cs.total_cost / NULLIF(cs.energy_kwh, 0)), 2) AS effective_rate_per_kwh
FROM Tariffs t
JOIN Charging_Sessions cs ON t.tariff_id = cs.tariff_id
GROUP BY t.tariff_name;

-- Q11: Unresolved Maintenance Issues grouped by Issue Type
SELECT issue_description, COUNT(*) AS open_tickets
FROM Maintenance_Tickets WHERE status != 'Resolved'
GROUP BY issue_description ORDER BY open_tickets DESC;

-- Q12: Monthly Growth in Energy Delivered (kWh)
SELECT DATE_TRUNC('month', start_time) AS month, ROUND(SUM(energy_kwh), 2) AS monthly_kwh
FROM Charging_Sessions
GROUP BY month ORDER BY month;