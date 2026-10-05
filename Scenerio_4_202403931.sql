-- 1. Create tables and insert medicines
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED' -- 'DISPENSED', 'REVERSED'
);

INSERT INTO medicines (name, stock_quantity) VALUES 
('Paracetamol', 100),
('Amoxicillin', 5),
('Ibuprofen', 0);

-- 2. IF ELSIF ELSE stock report
DO $$
DECLARE
    v_qty INT;
    v_med VARCHAR(100) := 'Amoxicillin';
BEGIN
    SELECT stock_quantity INTO v_qty FROM medicines WHERE name = v_med;
    
    IF v_qty = 0 THEN
        RAISE NOTICE 'Medicine % is OUT OF STOCK.', v_med;
    ELSIF v_qty <= 10 THEN
        RAISE NOTICE 'Medicine % is LOW ON STOCK (% remaining).', v_med, v_qty;
    ELSE
        RAISE NOTICE 'Medicine % is SUFFICIENTLY STOCKED (% remaining).', v_med, v_qty;
    END IF;
END $$;

-- 3. WHILE loop and Numeric FOR loop
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Stock Review Day #%', d;
        d := d + 1;
    END LOOP;

    FOR insp IN 1..3 LOOP
        RAISE NOTICE 'Shelf Inspection #%', insp;
    END LOOP;
END $$;

-- 4. Create dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_student_no VARCHAR(20),
    p_medicine_id INT,
    p_qty INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Quantity dispensed must be greater than zero.';
    END IF;

    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = p_medicine_id;

    IF v_stock < p_qty THEN
        RAISE NOTICE 'Dispensing Failed: Insufficient stock for Medicine ID % (Available: %).', p_medicine_id, v_stock;
    ELSE
        UPDATE medicines SET stock_quantity = stock_quantity - p_qty WHERE medicine_id = p_medicine_id;
        INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
        VALUES (p_medicine_id, p_student_no, p_qty, 'DISPENSED');
        RAISE NOTICE 'Dispensing successful for Student %.', p_student_no;
    END IF;
END $$;

-- 5. Call dispense_medicine and query
CALL dispense_medicine('SIN100', 1, 10); -- Valid
CALL dispense_medicine('SIN101', 2, 2);  -- Valid
CALL dispense_medicine('SIN102', 2, 20); -- Exceeds stock

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- 6. Create reverse_dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_med_id INT;
    v_qty INT;
BEGIN
    SELECT status, medicine_id, quantity INTO v_status, v_med_id, v_qty 
    FROM dispensing_records WHERE record_id = p_record_id;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed. Stock not restored again.', p_record_id;
    ELSIF v_status = 'DISPENSED' THEN
        UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
        UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med_id;
        RAISE NOTICE 'Dispensing Record % successfully reversed.', p_record_id;
    END IF;
END $$;

-- Call reverse_dispensing twice for record 1
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- 7. Cursor for low-stock threshold (<= 10)
DO $$
DECLARE
    rec RECORD;
    cur_low_stock CURSOR FOR SELECT name, stock_quantity FROM medicines WHERE stock_quantity <= 10;
BEGIN
    OPEN cur_low_stock;
    LOOP
        FETCH cur_low_stock INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Warning -> Medicine: %, Stock: %', rec.name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_low_stock;
END $$;

-- 8. Negative quantity EXCEPTION handling
DO $$
BEGIN
    CALL dispense_medicine('SIN103', 1, -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Caught Error: %', SQLERRM;
END $$;

-- 9. Final Query
SELECT * FROM medicines;
SELECT * FROM dispensing_records;