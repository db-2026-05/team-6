-- ================================================================
-- FUNCTIONS & STORED PROCEDURES TEMPLATE (TOPIC 12)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
--
-- FUNCTIONS (at least 3):
--   - Each function should encapsulate reusable logic or a
--     calculation relevant to your project domain.
--   - Use CREATE OR REPLACE FUNCTION ... RETURNS ...
--
-- STORED PROCEDURES — SELECT / INSERT (at least 2):
--   - Procedures that retrieve data or insert new records.
--   - Use CREATE OR REPLACE PROCEDURE ...
--
-- STORED PROCEDURES — UPDATE (at least 2):
--   - Procedures that modify existing records.
--
-- FOR EACH FUNCTION / PROCEDURE, ADD COMMENTS EXPLAINING:
--   - Purpose: what it does
--   - Parameters: name, type, meaning
--   - Expected behavior / return value
--
-- TEST CALLS:
--   - Include at least one example call per function/procedure
--     (SELECT my_function(...) or CALL my_procedure(...))
--
-- OPTIONAL:
--   - EXCEPTION blocks for error handling
--   - Transaction management with BEGIN / COMMIT / ROLLBACK
--
-- RECOMMENDED ORDER:
-- 1) Functions
-- 2) SELECT / INSERT procedures
-- 3) UPDATE procedures
-- 4) Test calls
--
-- IMPORTANT:
-- - All routines must execute in PostgreSQL without errors.
-- - Logic must be relevant to your project domain.
-- - Submit everything in this single SQL file.
-- ================================================================

-- Add your functions and procedures below this line

-- =========================================================
-- 1) FUNCTIONS
-- =========================================================

-- ---------------------------------------------------------
-- Function: gym.get_member_attendance_rate
-- ---------------------------------------------------------
-- Purpose:
--   Calculates the attendance rate for a given member as a
--   percentage of non-cancelled bookings where the member
--   actually showed up (status = 'attended').
--
-- Parameters:
--   p_member_id  BIGINT  — the ID of the member to evaluate
--
-- Returns:
--   NUMERIC — attendance rate as a percentage (0.00–100.00).
--   Returns 0.00 if the member has no non-cancelled bookings.
--
-- Example: SELECT gym.get_member_attendance_rate(1);
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION gym.get_member_attendance_rate(p_member_id BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total    INTEGER;
    v_attended INTEGER;
BEGIN
    -- Count all non-cancelled attendance records for this member
    SELECT COUNT(*)
    INTO v_total
    FROM gym.attendance
    WHERE member_id = p_member_id
      AND status <> 'cancelled';

    IF v_total = 0 THEN
        RETURN 0.00;
    END IF;

    -- Count how many of those were actually attended
    SELECT COUNT(*)
    INTO v_attended
    FROM gym.attendance
    WHERE member_id = p_member_id
      AND status = 'attended';

    RETURN ROUND((v_attended::NUMERIC / v_total) * 100, 2);
END;
$$;


-- =========================================================
-- 2) STORED PROCEDURES — SELECT / INSERT
-- =========================================================

-- ---------------------------------------------------------
-- Procedure: gym.book_class_session
-- ---------------------------------------------------------
-- Purpose:
--   Books a member into a scheduled class session. Validates
--   that the member has an active membership, the session is
--   scheduled, and there is remaining capacity before inserting
--   an attendance record with status 'booked'.
--
-- Parameters:
--   p_member_id          BIGINT — the member to book
--   p_class_schedule_id  BIGINT — the class session to book into
--
-- Expected behavior:
--   - Raises an exception if the member has no active membership.
--   - Raises an exception if the session does not exist or is not 'scheduled'.
--   - Raises an exception if the session is full.
--   - Raises an exception if the member is already booked (unique violation).
--   - On success, inserts one row into gym.attendance.
--
-- Example: CALL gym.book_class_session(1, 1);
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.book_class_session(
    p_member_id         BIGINT,
    p_class_schedule_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_membership BOOLEAN;
    v_session_status gym.class_schedule_status;
    v_class_id       BIGINT;
    v_room_id        BIGINT;
    v_capacity       INTEGER;
    v_current_count  INTEGER;
BEGIN
    -- 1. Check active membership
    SELECT EXISTS (
        SELECT 1
        FROM gym.members_memberships
        WHERE member_id = p_member_id
          AND (end_date IS NULL OR end_date >= CURRENT_DATE)
    ) INTO v_has_membership;

    IF NOT v_has_membership THEN
        RAISE EXCEPTION 'Member % does not have an active membership', p_member_id;
    END IF;

    -- 2. Check session exists and is scheduled
    SELECT cs.status, cs.class_id, cs.room_id
    INTO v_session_status, v_class_id, v_room_id
    FROM gym.class_schedule cs
    WHERE cs.class_schedule_id = p_class_schedule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Class session % does not exist', p_class_schedule_id;
    END IF;

    IF v_session_status <> 'scheduled' THEN
        RAISE EXCEPTION 'Class session % is not open for booking (status: %)',
            p_class_schedule_id, v_session_status;
    END IF;

    -- 3. Check capacity (class_templates.capacity overrides rooms.capacity)
    SELECT COALESCE(ct.capacity, r.capacity)
    INTO v_capacity
    FROM gym.class_templates ct
    JOIN gym.rooms r ON r.room_id = v_room_id
    WHERE ct.class_id = v_class_id;

    IF v_capacity IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_current_count
        FROM gym.attendance
        WHERE class_schedule_id = p_class_schedule_id
          AND status IN ('booked', 'attended');

        IF v_current_count >= v_capacity THEN
            RAISE EXCEPTION 'Class session % is full (% / % spots taken)',
                p_class_schedule_id, v_current_count, v_capacity;
        END IF;
    END IF;

    -- 4. Insert booking
    INSERT INTO gym.attendance (member_id, class_schedule_id, check_in_time, status)
    VALUES (p_member_id, p_class_schedule_id, NULL, 'booked');

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Member % is already booked for session %',
            p_member_id, p_class_schedule_id;
END;
$$;


-- =========================================================
-- 3) STORED PROCEDURES — UPDATE
-- =========================================================

-- ---------------------------------------------------------
-- Procedure: gym.check_in_member
-- ---------------------------------------------------------
-- Purpose:
--   Records a member's physical arrival at a booked class
--   session by updating the attendance status from 'booked'
--   to 'attended' and setting the check-in timestamp.
--   Validates that check-in happens within a reasonable time
--   window: no earlier than 30 minutes before the session
--   starts and no later than the session end time.
--
-- Parameters:
--   p_member_id          BIGINT — the member checking in
--   p_class_schedule_id  BIGINT — the class session
--
-- Expected behavior:
--   - Raises an exception if check-in is too early (>30 min before start).
--   - Raises an exception if check-in is too late (after session ends).
--   - Updates the attendance row where status = 'booked'.
--   - Sets status to 'attended' and check_in_time to NOW().
--   - Raises an exception if no matching booking is found
--     (member not booked, already checked in, or cancelled).
--
-- Example: CALL gym.check_in_member(1, 1);
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.check_in_member(
    p_member_id         BIGINT,
    p_class_schedule_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMPTZ;
    v_end   TIMESTAMPTZ;
    v_now   TIMESTAMPTZ := NOW();
BEGIN
    -- Fetch session time window
    SELECT start_datetime, end_datetime
    INTO v_start, v_end
    FROM gym.class_schedule
    WHERE class_schedule_id = p_class_schedule_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Class session % does not exist', p_class_schedule_id;
    END IF;

    -- Allow check-in no earlier than 30 minutes before session start
    IF v_now < v_start - INTERVAL '30 minutes' THEN
        RAISE EXCEPTION 'Too early to check in for session % (opens at %)',
            p_class_schedule_id, (v_start - INTERVAL '30 minutes');
    END IF;

    -- Disallow check-in after session has ended
    IF v_now > v_end THEN
        RAISE EXCEPTION 'Session % has already ended at %',
            p_class_schedule_id, v_end;
    END IF;

    -- Update booking to attended
    UPDATE gym.attendance
    SET status        = 'attended',
        check_in_time = v_now
    WHERE member_id         = p_member_id
      AND class_schedule_id = p_class_schedule_id
      AND status            = 'booked';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active booking found for member % in session % (not booked, already checked in, or cancelled)',
            p_member_id, p_class_schedule_id;
    END IF;
END;
$$;


-- =========================================================
-- 4) TEST CALLS
-- =========================================================

-- Test: get_member_attendance_rate
-- Returns the attendance rate for member 1 (0.00 if no records exist)
-- SELECT gym.get_member_attendance_rate(1) AS attendance_rate;

-- Test: book_class_session
-- Books member 1 into class session 1 (requires valid data in the DB)
-- CALL gym.book_class_session(1, 1);

-- Test: check_in_member
-- Checks in member 1 for class session 1 (requires the booking above)
-- CALL gym.check_in_member(1, 1);

-- Verify: attendance rate should now reflect the check-in
-- SELECT gym.get_member_attendance_rate(1) AS attendance_rate_after_checkin;


--Andrew Chernuha
-- FUNCTIONS
-- =========================================================
 
 
-- ---------------------------------------------------------
-- FUNCTION 1: gym.fn_count_trainer_sessions
--
-- Purpose  : Returns total number of sessions for a trainer.
-- Parameter: p_trainer_id — trainer to query
-- Returns  : INTEGER — session count
--
-- Example:
--   SELECT gym.fn_count_trainer_sessions(1);
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION gym.fn_count_trainer_sessions(
    p_trainer_id BIGINT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM gym.personal_training
    WHERE trainer_id = p_trainer_id;
 
    RETURN v_count;
END;
$$;
 
 
-- ---------------------------------------------------------
-- FUNCTION 2: gym.fn_is_trainer_available
--
-- Purpose  : Checks if a trainer has no session at a given time.
-- Parameters:
--   p_trainer_id    — trainer to check
--   p_training_date — proposed datetime
-- Returns  : BOOLEAN — TRUE if available, FALSE if not
--
-- Example:
--   SELECT gym.fn_is_trainer_available(1, '2024-07-01 10:00:00+00');
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION gym.fn_is_trainer_available(
    p_trainer_id    BIGINT,
    p_training_date TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM gym.personal_training
    WHERE trainer_id    = p_trainer_id
      AND training_date = p_training_date
      AND status        = 'scheduled';
 
    RETURN v_count = 0;
END;
$$;
 
 
-- ---------------------------------------------------------
-- FUNCTION 3: gym.fn_trainer_weekly_hours
--
-- Purpose  : Calculates total active working hours per week.
-- Parameter: p_trainer_id — trainer to calculate for
-- Returns  : NUMERIC — total hours (e.g. 45.00)
--
-- Example:
--   SELECT gym.fn_trainer_weekly_hours(1);
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION gym.fn_trainer_weekly_hours(
    p_trainer_id BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_hours NUMERIC;
BEGIN
    SELECT COALESCE(
        SUM(EXTRACT(EPOCH FROM (end_time - start_time)) / 3600),
        0
    )
    INTO v_hours
    FROM gym.trainer_work_schedule
    WHERE trainer_id = p_trainer_id
      AND is_active  = TRUE;
 
    RETURN ROUND(v_hours, 2);
END;
$$;
 
 
-- =========================================================
-- STORED PROCEDURES — SELECT
-- =========================================================
 
 
-- ---------------------------------------------------------
-- PROCEDURE 1: gym.sp_get_trainer_sessions
--
-- Purpose  : Prints a notice with session count for a trainer.
-- Parameter: p_trainer_id — trainer to query
--
-- Example:
--   CALL gym.sp_get_trainer_sessions(1);
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_get_trainer_sessions(
    p_trainer_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM gym.personal_training
    WHERE trainer_id = p_trainer_id;
 
    RAISE NOTICE 'Trainer % has % session(s).', p_trainer_id, v_count;
END;
$$;
 
 
-- ---------------------------------------------------------
-- PROCEDURE 2: gym.sp_get_pending_leaves
--
-- Purpose  : Prints a notice with count of pending leave requests.
--
-- Example:
--   CALL gym.sp_get_pending_leaves();
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_get_pending_leaves()
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM gym.trainer_leaves
    WHERE status = 'pending';
 
    RAISE NOTICE 'Pending leave requests: %', v_count;
END;
$$;
 
 
-- =========================================================
-- STORED PROCEDURES — INSERT
-- =========================================================
 
 
-- ---------------------------------------------------------
-- PROCEDURE 3: gym.sp_book_session
--
-- Purpose  : Books a new personal training session.
-- Parameters:
--   p_member_id     — member booking the session
--   p_trainer_id    — trainer for the session
--   p_training_date — date and time of the session
--
-- Example:
--   CALL gym.sp_book_session(1, 2, '2024-07-01 10:00:00+00');
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_book_session(
    p_member_id     BIGINT,
    p_trainer_id    BIGINT,
    p_training_date TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO gym.personal_training (member_id, trainer_id, training_date, status)
    VALUES (p_member_id, p_trainer_id, p_training_date, 'scheduled');
 
    RAISE NOTICE 'Session booked for member % with trainer % on %.',
        p_member_id, p_trainer_id, p_training_date;
END;
$$;
 
 
-- ---------------------------------------------------------
-- PROCEDURE 4: gym.sp_submit_leave
--
-- Purpose  : Submits a new leave request with status 'pending'.
-- Parameters:
--   p_trainer_id — trainer requesting leave
--   p_leave_type — 'sick', 'vacation', or 'personal'
--   p_start_date — first day of leave
--   p_end_date   — last day of leave
--
-- Example:
--   CALL gym.sp_submit_leave(1, 'vacation', '2024-08-01', '2024-08-10');
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_submit_leave(
    p_trainer_id BIGINT,
    p_leave_type TEXT,
    p_start_date DATE,
    p_end_date   DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO gym.trainer_leaves (trainer_id, leave_type, start_date, end_date, status)
    VALUES (
        p_trainer_id,
        p_leave_type::gym.leave_type,
        p_start_date,
        p_end_date,
        'pending'
    );
 
    RAISE NOTICE 'Leave request submitted for trainer % (% to %).',
        p_trainer_id, p_start_date, p_end_date;
END;
$$;
 
 
-- =========================================================
-- STORED PROCEDURES — UPDATE
-- =========================================================
 
 
-- ---------------------------------------------------------
-- PROCEDURE 5: gym.sp_cancel_session
--
-- Purpose  : Cancels a personal training session by ID.
-- Parameter: p_session_id — session to cancel
--
-- Example:
--   CALL gym.sp_cancel_session(1);
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_cancel_session(
    p_session_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE gym.personal_training
    SET status = 'cancelled'
    WHERE session_id = p_session_id;
 
    RAISE NOTICE 'Session % has been cancelled.', p_session_id;
END;
$$;
 
 
-- ---------------------------------------------------------
-- PROCEDURE 6: gym.sp_approve_leave
--
-- Purpose  : Approves a leave request by ID.
-- Parameter: p_leave_id — leave request to approve
--
-- Example:
--   CALL gym.sp_approve_leave(1);
-- ---------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_approve_leave(
    p_leave_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE gym.trainer_leaves
    SET status = 'approved'
    WHERE leave_id = p_leave_id;
 
    RAISE NOTICE 'Leave request % has been approved.', p_leave_id;
END;
$$;
--End Andrew Chernuha

-- ================================================================
-- FUNCTIONS & PROCEDURES FOR MEMBERSHIP MANAGEMENT
-- Responsible: Oleh Svyrydenko
-- ================================================================

-- ----------------------------------------------------------------
-- FUNCTION: gym.fn_calculate_membership_revenue
-- Purpose  : Calculates total revenue from a membership type based on valid_from date
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION gym.fn_calculate_membership_revenue(
    p_membership_type gym.membership_type,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_revenue NUMERIC := 0.00;
BEGIN
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Start date (%) cannot be later than end date (%)', p_start_date, p_end_date;
    END IF;

    SELECT COALESCE(SUM(price), 0.00)
    INTO v_total_revenue
    FROM gym.memberships
    WHERE type = p_membership_type
      AND valid_from BETWEEN p_start_date AND p_end_date;

    RETURN v_total_revenue;
END;
$$;

-- ----------------------------------------------------------------
-- PROCEDURE: gym.sp_purchase_membership
-- Purpose  : Registers a new membership enrollment for a member
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_purchase_membership(
    p_member_id BIGINT,
    p_membership_id BIGINT,
    p_discount INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_discount < 0 OR p_discount > 100 THEN
        RAISE EXCEPTION 'Discount must be between 0 and 100 percent.';
    END IF;

    INSERT INTO gym.members_memberships (
        membership_id,
        member_id, 
        start_date, 
        end_date, 
        discount
    )
    VALUES (
        p_membership_id,
        p_member_id, 
        CURRENT_DATE, 
        NULL, 
        p_discount
    );

    RAISE NOTICE 'Membership ID % successfully purchased for member ID %.', p_membership_id, p_member_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Error: Member ID % or Membership ID % does not exist.', p_member_id, p_membership_id;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An unexpected error occurred: %', SQLERRM;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE: gym.sp_terminate_membership
-- Purpose  : Closes an active membership by setting its end_date
-- ----------------------------------------------------------------
CREATE OR REPLACE PROCEDURE gym.sp_terminate_membership(
    p_members_membership_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_updated INT;
BEGIN
    UPDATE gym.members_memberships
    SET end_date = CURRENT_DATE
    WHERE members_membership_id = p_members_membership_id
      AND end_date IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RAISE NOTICE 'No active enrollment found with ID % or it is already closed.', p_members_membership_id;
    ELSE
        RAISE NOTICE 'Enrollment % has been successfully terminated.', p_members_membership_id;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred while terminating enrollment %: %', p_members_membership_id, SQLERRM;
END;
$$;

-- ================================================================
-- TEST CALLS FOR MEMBERSHIP MANAGEMENT (OLEH SVYRYDENKO)
-- ================================================================

-- STEP 1: Test Purchasing a Membership (Successful Scenario)
-- Expected behavior: Inserts a new active record into gym.members_memberships for member_id = 1 and membership_id = 3.
-- CALL gym.sp_purchase_membership(1, 3, 0);

-- STEP 2: Test Revenue Calculation Function
-- Expected behavior: Returns the total revenue for 'monthly' membership type within the specified period, including the newly purchased one.
--- SELECT gym.fn_calculate_membership_revenue('monthly', '2023-01-01', '2026-12-31') AS total_revenue;

-- STEP 3: Test Purchasing a Membership (Error Scenario - Non-existent Member)
-- Expected behavior: Catches foreign_key_violation and raises a custom exception.
-- CALL gym.sp_purchase_membership(99999, 3, 0);

-- STEP 4: Test Terminating a Membership (Soft Delete Scenario)
-- Expected behavior: Updates the end_date to CURRENT_DATE for the specified enrollment record (members_membership_id = 1).
-- CALL gym.sp_terminate_membership(1);

-- ================================================================
-- FUNCTIONS & STORED PROCEDURES for Equipment and Goal Tracking
-- Author:   Dmytro
-- Tables:   equipment, goals, progress

-- ================================================================
-- SECTION 1: FUNCTIONS
-- ================================================================

-- ----------------------------------------------------------------
-- FUNCTION 1: Count total equipment by status
-- Purpose: Get count of equipment with specific status
-- Parameter: status_filter - equipment status (e.g., 'available')
-- Returns: Number of equipment items with that status
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION gym.count_equipment_by_status(status_filter VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count
    FROM gym.equipment
    WHERE status = status_filter::gym.equipment_status;
    
    RETURN total_count;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------
-- FUNCTION 2: Get goal progress percentage
-- Purpose: Calculate how close a goal is to completion (0-100%)
-- Parameter: goal_id - ID of the goal
-- Returns: Progress percentage (0-100), or 0 if no progress/error
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION gym.get_goal_progress_percentage(goal_id_param BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_latest_state_raw TEXT;
    v_target_value_raw TEXT;
    v_latest_state_numeric NUMERIC := 0;
    v_target_value_numeric NUMERIC := 0;
    v_percentage NUMERIC;
BEGIN
    
    SELECT p.current_state
    INTO v_latest_state_raw
    FROM gym.progress p
    WHERE p.goal_id = goal_id_param
    ORDER BY p.check_date DESC
    LIMIT 1;

    SELECT target_value 
    INTO v_target_value_raw
    FROM gym.goals
    WHERE goal_id = goal_id_param;

    IF v_latest_state_raw IS NOT NULL THEN
        BEGIN
            v_latest_state_numeric := regexp_replace(
                replace(v_latest_state_raw, ',', '.'), 
                '[^0-9.]', '', 'g'
            )::NUMERIC;
        EXCEPTION WHEN invalid_text_representation THEN
            v_latest_state_numeric := 0;
        END;
    END IF;

    IF v_target_value_raw IS NOT NULL THEN
        BEGIN
            v_target_value_numeric := regexp_replace(
                replace(v_target_value_raw, ',', '.'), 
                '[^0-9.]', '', 'g'
            )::NUMERIC;
        EXCEPTION WHEN invalid_text_representation THEN
            v_target_value_numeric := 0;
        END;
    END IF;

    IF v_target_value_numeric = 0 OR v_latest_state_numeric IS NULL THEN
        RETURN 0;
    ELSE
        v_percentage := (v_latest_state_numeric / v_target_value_numeric) * 100;
        RETURN ROUND(v_percentage, 2);
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ----------------------------------------------------------------
-- FUNCTION 3: Get equipment maintenance status
-- Purpose: Check if equipment needs maintenance (last_maintenance > 6 months ago)
-- Parameter: equipment_id - ID of equipment
-- Returns: 'MAINTENANCE NEEDED' or 'OK'
-- ----------------------------------------------------------------

CREATE OR REPLACE FUNCTION gym.check_equipment_maintenance(equipment_id_param BIGINT)
RETURNS VARCHAR AS $$
DECLARE
    last_maintenance_date DATE;
BEGIN
    SELECT last_maintenance INTO last_maintenance_date
    FROM gym.equipment
    WHERE equipment_id = equipment_id_param;
    
    IF last_maintenance_date IS NULL THEN
        RETURN 'MAINTENANCE NEEDED';
    ELSIF last_maintenance_date < CURRENT_DATE - INTERVAL '180 days' THEN
        RETURN 'MAINTENANCE NEEDED';
    ELSE
        RETURN 'OK';
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ================================================================
-- SECTION 2: STORED PROCEDURES 
-- ================================================================

-- ----------------------------------------------------------------
-- PROCEDURE 1: Add new equipment (INSERT)
-- Purpose: Insert new equipment into inventory
-- Parameters: equipment_name, equipment_status, maintenance_date
-- ----------------------------------------------------------------

CREATE OR REPLACE PROCEDURE gym.add_equipment(
    p_name VARCHAR,
    p_status VARCHAR,
    p_last_maintenance DATE DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO gym.equipment (name, status, last_maintenance)
    VALUES (p_name, p_status::gym.equipment_status, p_last_maintenance);
    
    RAISE NOTICE 'Equipment "%" added successfully.', p_name;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 2: Add progress record (INSERT)
-- Purpose: Log a new progress check-in for a goal
-- Parameters: goal_id, current_value, notes (optional)
-- ----------------------------------------------------------------

CREATE OR REPLACE PROCEDURE gym.add_progress_record(
    p_goal_id BIGINT, -- Изменено на BIGINT для консистентности
    p_current_state VARCHAR,
    p_notes TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO gym.progress (goal_id, current_state, notes, check_date)
    VALUES (p_goal_id, p_current_state, p_notes, CURRENT_DATE);
    
    RAISE NOTICE 'Progress record added for goal %.', p_goal_id;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 3: Update equipment status (UPDATE)
-- Purpose: Change status of equipment (e.g., after repair)
-- Parameters: equipment_id, new_status
-- ----------------------------------------------------------------

CREATE OR REPLACE PROCEDURE gym.update_equipment_status(
    p_equipment_id BIGINT, -- Изменено на BIGINT для консистентности
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE gym.equipment
    SET status = p_new_status::gym.equipment_status
    WHERE equipment_id = p_equipment_id;
    
    RAISE NOTICE 'Equipment % status updated to %.', p_equipment_id, p_new_status;
END;
$$;


-- ----------------------------------------------------------------
-- PROCEDURE 4: Update goal status (UPDATE)
-- Purpose: Change status of a goal (e.g., mark as completed)
-- Parameters: goal_id, new_status
-- ----------------------------------------------------------------

CREATE OR REPLACE PROCEDURE gym.update_goal_status(
    p_goal_id BIGINT, -- Изменено на BIGINT для консистентности
    p_new_status VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE gym.goals
    SET status = p_new_status::gym.goal_status
    WHERE goal_id = p_goal_id;
    
    RAISE NOTICE 'Goal % status updated to %.', p_goal_id, p_new_status;
END;
$$;


-- ================================================================
-- SECTION 3: TEST CALLS
-- ================================================================

-- Test Functions:
-- SELECT gym.count_equipment_by_status('available');
-- SELECT gym.get_goal_progress_percentage(1);
-- SELECT gym.check_equipment_maintenance(1);

-- Test Procedures:
-- CALL gym.add_equipment('Test Treadmill', 'available', '2026-01-01');
-- CALL gym.add_progress_record(1, '74.5 kg', 'Good progress');
-- CALL gym.update_equipment_status(1, 'under_repair');
-- CALL gym.update_goal_status(1, 'completed');

-- ================================================================
-- END OF Dmytro SCRIPT
-- ================================================================
