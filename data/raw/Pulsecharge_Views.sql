-- View 1: Daily Station Performance Metrics
CREATE OR REPLACE VIEW vw_station_daily_performance AS
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
CREATE OR REPLACE VIEW vw_active_maintenance_issues AS
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
CREATE OR REPLACE VIEW vw_customer_usage_summary AS
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