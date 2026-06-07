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
