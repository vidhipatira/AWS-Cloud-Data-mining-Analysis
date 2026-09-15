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