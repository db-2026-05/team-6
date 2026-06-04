-- ================================================================
-- SQL VIEWS TEMPLATE (TOPIC 10)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) CREATE VIEW scripts for required view types:
--    - Horizontal view (select specific columns)
--    - Vertical view (filter specific rows)
--    - Mixed view (columns + row filters)
--    - Join-based view (multiple tables)
--    - Subquery-based view
--    - UNION-based view
--    - View based on another view
--    - Updatable view with WITH CHECK OPTION
--
-- 2) Comments before each view explaining:
--    - Purpose of the view
--    - How it supports your project design
--
-- 3) Optional demo SELECT statements to show view output.
--
-- RECOMMENDED ORDER:
-- 1) Simple views (horizontal / vertical / mixed)
-- 2) Join and subquery views
-- 3) UNION and layered views
-- 4) CHECK OPTION view
--
-- IMPORTANT:
-- - Script must execute in PostgreSQL without errors.
-- - Keep naming consistent and readable.
-- - Submit all views in this single SQL file.
-- ================================================================

-- Add your CREATE VIEW statements below this line

-- ================================================================
-- SQL VIEWS FOR CLASS & SCHEDULING MANAGEMENT
-- Author: Oleksandr Chura
-- ================================================================
-- Views built on top of the scheduling subsystem tables:
--   gym.rooms, gym.class_templates, gym.class_recurrence_rules,
--   gym.rule_week_days, gym.rule_month_days, gym.class_schedule
-- ================================================================


-- ================================================================
-- 1. HORIZONTAL VIEW — select specific columns
-- ================================================================
-- Purpose: Provides a simplified catalogue of class templates,
-- exposing only the name and duration. Useful for public-facing
-- timetable displays where internal IDs and capacity details
-- are irrelevant.
-- Relates to: gym.class_templates — strips implementation columns.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_class_catalogue AS
SELECT
    class_name,
    duration_minutes
FROM gym.class_templates;

-- Demo:
-- SELECT * FROM gym.v_class_catalogue;


-- ================================================================
-- 2. VERTICAL VIEW — filter specific rows
-- ================================================================
-- Purpose: Shows only class sessions that have been cancelled.
-- Operations staff use this to audit cancellation rates and
-- identify patterns (e.g. a trainer or room that causes frequent
-- cancellations).
-- Relates to: gym.class_schedule — filters rows by status.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_cancelled_sessions AS
SELECT *
FROM gym.class_schedule
WHERE status = 'cancelled';

-- Demo:
-- SELECT * FROM gym.v_cancelled_sessions;


-- ================================================================
-- 3. MIXED VIEW — column selection + row filtering
-- ================================================================
-- Purpose: Lists upcoming scheduled sessions with only the columns
-- relevant for a member-facing timetable: when and where.
-- Filters out cancelled and completed sessions so members only see
-- sessions they can still book.
-- Relates to: gym.class_schedule — combines column projection with
-- a status + date filter.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_upcoming_sessions AS
SELECT
    class_schedule_id,
    class_id,
    room_id,
    start_datetime,
    end_datetime
FROM gym.class_schedule
WHERE status = 'scheduled'
  AND start_datetime > NOW();

-- Demo:
-- SELECT * FROM gym.v_upcoming_sessions;


-- ================================================================
-- 4. JOIN VIEW — multiple tables
-- ================================================================
-- Purpose: Produces a human-readable timetable by joining
-- class_schedule with class_templates (for the class name),
-- rooms (for the room name), and trainers + persons (for the
-- trainer's full name). This is the primary query behind
-- the gym's public schedule display.
-- Relates to: gym.class_schedule, gym.class_templates, gym.rooms,
-- gym.trainers, gym.persons — combines scheduling data with
-- reference data from other subsystems.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_timetable AS
SELECT
    cs.class_schedule_id,
    ct.class_name,
    r.name AS room_name,
    p.first_name || ' ' || p.last_name AS trainer_name,
    cs.start_datetime,
    cs.end_datetime,
    cs.status
FROM gym.class_schedule cs
JOIN gym.class_templates ct ON ct.class_id   = cs.class_id
JOIN gym.rooms r ON r.room_id     = cs.room_id
JOIN gym.trainers t ON t.trainer_id  = cs.trainer_id
JOIN gym.persons p ON p.person_id   = t.person_id;

-- Demo:
-- SELECT * FROM gym.v_timetable
-- WHERE status = 'scheduled'
-- ORDER BY start_datetime;


-- ================================================================
-- 5. SUBQUERY VIEW — uses a subquery
-- ================================================================
-- Purpose: Shows rooms that are not assigned to any
-- scheduled session. Facility managers use this to identify
-- underutilised spaces that could be repurposed or added to the
-- timetable.
-- Relates to: gym.rooms, gym.class_schedule — the subquery checks
-- for the absence of any class_schedule row referencing the room.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_unused_rooms AS
SELECT
    room_id,
    name,
    capacity
FROM gym.rooms
WHERE room_id NOT IN (
    SELECT DISTINCT room_id
    FROM gym.class_schedule
    WHERE status = 'scheduled' AND start_datetime > NOW()
);

-- Demo:
-- SELECT * FROM gym.v_unused_rooms;


-- ================================================================
-- 6. UNION VIEW — combines two result sets
-- ================================================================
-- Purpose: Provides a single list of all scheduled and completed
-- sessions, tagged by their state. The front desk uses this for
-- a unified session log that covers both future bookings and
-- historical records.
-- Relates to: gym.class_schedule — UNION filters on two different
-- status values and labels them for easy distinction.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_session_log AS
SELECT
    class_schedule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    'upcoming' AS session_category
FROM gym.class_schedule
WHERE status = 'scheduled'

UNION ALL

SELECT
    class_schedule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    'past' AS session_category
FROM gym.class_schedule
WHERE status = 'completed';

-- Demo:
-- SELECT * FROM gym.v_session_log ORDER BY start_datetime DESC;


-- ================================================================
-- 7. VIEW ON VIEW — selects from another view
-- ================================================================
-- Purpose: Builds on v_timetable (view #4) to produce a compact
-- summary of upcoming sessions grouped by class name, showing
-- how many sessions are scheduled and when the next one starts.
-- Used on the gym's dashboard for a quick overview.
-- Relates to: gym.v_timetable — aggregates the detailed timetable
-- into a summary without re-joining the base tables.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_class_schedule_summary AS
SELECT
    class_name,
    COUNT(*)                  AS total_sessions,
    MIN(start_datetime)       AS next_session
FROM gym.v_timetable
WHERE status = 'scheduled' AND start_datetime > NOW()
GROUP BY class_name;

-- Demo:
-- SELECT * FROM gym.v_class_schedule_summary
-- ORDER BY next_session;


-- ================================================================
-- 8. UPDATABLE VIEW WITH CHECK OPTION
-- ================================================================
-- Purpose: Exposes only scheduled (not cancelled/completed) class
-- sessions so that staff can update session details (e.g. swap a
-- room or trainer) directly through the view. The CHECK OPTION
-- prevents an UPDATE from changing the status to anything other
-- than 'scheduled', which would move the row outside the view's
-- scope and bypass the intended workflow.
-- Relates to: gym.class_schedule — wraps a single table with a
-- WHERE filter and enforces it on writes.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_scheduled_sessions AS
SELECT
    class_schedule_id,
    rule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    status
FROM gym.class_schedule
WHERE status = 'scheduled'
WITH CHECK OPTION;

-- Demo:
-- The following UPDATE succeeds because the row stays within the view:
-- UPDATE gym.v_scheduled_sessions
-- SET room_id = 2
-- WHERE class_schedule_id = 1;
--
-- The following UPDATE would fail because changing status to 'cancelled'
-- violates the CHECK OPTION (the row would leave the view):
-- UPDATE gym.v_scheduled_sessions
-- SET status = 'cancelled'
-- WHERE class_schedule_id = 1;
