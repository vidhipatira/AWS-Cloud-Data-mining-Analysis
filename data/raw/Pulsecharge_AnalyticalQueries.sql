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