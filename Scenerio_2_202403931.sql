-- 1. Create tables and insert at least three sessions
CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    module_name VARCHAR(100) NOT NULL,
    available_workstations INT NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    workstations_reserved INT NOT NULL CHECK (workstations_reserved > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED' -- 'CONFIRMED', 'CANCELLED'
);

INSERT INTO lab_sessions (module_name, available_workstations) VALUES 
('ICT371 - Databases', 40),
('ICT311 - Networking', 5),
('ICT111 - Programming', 0);

-- 2. IF ELSIF ELSE status report
DO $$
DECLARE
    v_ws INT;
    v_session VARCHAR(100) := 'ICT311 - Networking';
BEGIN
    SELECT available_workstations INTO v_ws FROM lab_sessions WHERE module_name = v_session;
    
    IF v_ws = 0 THEN
        RAISE NOTICE 'Session "%" is FULL.', v_session;
    ELSIF v_ws <= 5 THEN
        RAISE NOTICE 'Session "%" is NEARLY FULL (% workstations left).', v_session, v_ws;
    ELSE
        RAISE NOTICE 'Session "%" HAS ENOUGH WORKSTATIONS (% workstations left).', v_session, v_ws;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    counter INT := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Preparation Reminder #%', counter;
        counter := counter + 1;
    END LOOP;

    FOR chk IN 1..3 LOOP
        RAISE NOTICE 'Workstation Check #%', chk;
    END LOOP;
END $$;

-- 4. Create reserve_workstations procedure
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_lecturer VARCHAR(100),
    p_session_id INT,
    p_qty INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Workstations requested must be greater than 0.';
    END IF;

    SELECT available_workstations INTO v_available FROM lab_sessions WHERE session_id = p_session_id;

    IF v_available < p_qty THEN
        RAISE NOTICE 'Reservation Failed: Requested %, but only % available.', p_qty, v_available;
    ELSE
        UPDATE lab_sessions SET available_workstations = available_workstations - p_qty WHERE session_id = p_session_id;
        INSERT INTO reservations (session_id, lecturer_name, workstations_reserved, status)
        VALUES (p_session_id, p_lecturer, p_qty, 'CONFIRMED');
        RAISE NOTICE 'Reservation confirmed for %!', p_lecturer;
    END IF;
END $$;

-- 5. Call reserve_workstations and query
CALL reserve_workstations('Dr. Banda', 1, 15);
CALL reserve_workstations('Mr. Phiri', 2, 3);
CALL reserve_workstations('Mrs. Tembo', 2, 10); -- Exceeds capacity

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- 6. Create cancel_reservation procedure
CREATE OR REPLACE PROCEDURE cancel_reservation(p_res_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_session_id INT;
    v_qty INT;
BEGIN
    SELECT status, session_id, workstations_reserved INTO v_status, v_session_id, v_qty 
    FROM reservations WHERE reservation_id = p_res_id;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled. No workstations released.', p_res_id;
    ELSIF v_status = 'CONFIRMED' THEN
        UPDATE reservations SET status = 'CANCELLED' WHERE reservation_id = p_res_id;
        UPDATE lab_sessions SET available_workstations = available_workstations + v_qty WHERE session_id = v_session_id;
        RAISE NOTICE 'Reservation % cancelled successfully.', p_res_id;
    END IF;
END $$;

-- Call cancel_reservation twice
CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- 7. Explicit cursor for sessions with few workstations (<= 5)
DO $$
DECLARE
    rec RECORD;
    cur_low CURSOR FOR SELECT module_name, available_workstations FROM lab_sessions WHERE available_workstations <= 5;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Workstations -> Session: %, Remaining: %', rec.module_name, rec.available_workstations;
    END LOOP;
    CLOSE cur_low;
END $$;

-- 8. EXCEPTION handling for 0 workstation request
DO $$
BEGIN
    CALL reserve_workstations('Dr. Mulenga', 1, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- 9. Final Query
SELECT * FROM lab_sessions;
SELECT * FROM reservations;