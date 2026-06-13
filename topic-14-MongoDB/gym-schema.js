// =========================================================
// MONGODB DOCUMENT SCHEMA
// Fitness Center Management System
// RESPONSIBLE ANDREW CHERNUHA
//
// Tables covered:
//   gym.personal_training      → embedded in persons collection
//   gym.trainer_work_schedule  → embedded in persons collection
//   gym.trainer_leaves         → embedded in persons collection
// =========================================================


// =========================================================
// COLLECTION: persons
// =========================================================

db.persons.insertMany([

  // ----------------------------------------------------------
  // Document 1 — a MEMBER
  // Has personal_training sessions embedded as an array.
  // Members do not have work_schedule or leaves.
  // ----------------------------------------------------------
  {
    _id: ObjectId(),
    role: "member",
    first_name: "Anna",
    last_name: "Kovalenko",
    email: "anna.kovalenko@example.com",
    phone: "+380501234567",
    birth_date: ISODate("1995-03-15"),

    // member-specific data
    member: {
      memberships: [
        {
          type: "yearly",
          price: 6000,
          currency: "UAH",
          start_date: ISODate("2024-01-01"),
          end_date: ISODate("2024-12-31"),
          discount: 10
        }
      ]
    },

    // personal training sessions booked by this member
    personal_training_sessions: [
      {
        session_id: 1,
        trainer_id: 2,                          // references trainer document
        training_date: ISODate("2024-06-10T10:00:00Z"),
        status: "completed"
      },
      {
        session_id: 2,
        trainer_id: 2,
        training_date: ISODate("2024-07-01T10:00:00Z"),
        status: "scheduled"
      }
    ],

    // fitness goals with embedded progress
    goals: [
      {
        goal_description: "Lose 5kg",
        target_value: "70kg",
        deadline: ISODate("2024-09-01"),
        status: "in_progress",
        created_at: ISODate("2024-01-15"),
        progress: [
          {
            current_state: "75kg",
            notes: "Good progress",
            check_date: ISODate("2024-05-01")
          },
          {
            current_state: "73kg",
            notes: "Keeping up",
            check_date: ISODate("2024-06-01")
          }
        ]
      }
    ]
  },

  // ----------------------------------------------------------
  // Document 2 — a TRAINER
  // Has work_schedule and leaves embedded as arrays.
  // Personal training sessions are referenced by member docs.
  // ----------------------------------------------------------
  {
    _id: ObjectId(),
    role: "trainer",
    first_name: "Dmytro",
    last_name: "Petrenko",
    email: "dmytro.petrenko@example.com",
    phone: "+380671234567",
    birth_date: ISODate("1988-07-22"),

    // trainer-specific data
    trainer: {
      hire_date: ISODate("2020-03-01"),

      // specializations embedded as a simple array of strings
      specializations: ["yoga", "strength", "pilates"],

      // regular weekly working hours
      // one object per active working day
      work_schedule: [
        {
          day_of_week: "mon",
          start_time: "09:00",
          end_time: "18:00",
          is_active: true
        },
        {
          day_of_week: "tue",
          start_time: "09:00",
          end_time: "18:00",
          is_active: true
        },
        {
          day_of_week: "wed",
          start_time: "09:00",
          end_time: "18:00",
          is_active: true
        },
        {
          day_of_week: "thu",
          start_time: "09:00",
          end_time: "18:00",
          is_active: true
        },
        {
          day_of_week: "fri",
          start_time: "09:00",
          end_time: "17:00",
          is_active: true
        }
      ],

      // leave requests
      leaves: [
        {
          leave_type: "vacation",
          start_date: ISODate("2024-08-01"),
          end_date: ISODate("2024-08-14"),
          status: "approved",
          notes: "Summer holiday"
        },
        {
          leave_type: "sick",
          start_date: ISODate("2024-05-10"),
          end_date: ISODate("2024-05-12"),
          status: "approved",
          notes: null
        }
      ]
    }
  }

]);


// =========================================================
// COLLECTION: class_schedule

// Trainer is referenced by _id (cross-document reference).
// =========================================================

db.class_schedule.insertMany([

  // Document 1 — a scheduled yoga session
  {
    _id: ObjectId(),
    status: "scheduled",
    start_datetime: ISODate("2024-07-02T10:00:00Z"),
    end_datetime: ISODate("2024-07-02T11:00:00Z"),

    // embedded class template data
    class_template: {
      class_name: "Yoga",
      description: "Morning yoga for all levels",
      duration_minutes: 60,
      capacity: 20
    },

    // embedded room data
    room: {
      name: "Studio A",
      capacity: 25
    },

    // trainer referenced by ID (cross-collection reference)
    trainer_id: ObjectId(),

    // override tracking
    is_override: false,
    override_reason: null,

    // attendance embedded as array of member references + status
    attendance: [
      {
        member_id: ObjectId(),
        check_in_time: null,
        status: "booked"
      },
      {
        member_id: ObjectId(),
        check_in_time: ISODate("2024-07-02T09:55:00Z"),
        status: "attended"
      }
    ]
  },

  // Document 2 — a completed spinning session with override
  {
    _id: ObjectId(),
    status: "completed",
    start_datetime: ISODate("2024-06-25T18:00:00Z"),
    end_datetime: ISODate("2024-06-25T19:00:00Z"),

    class_template: {
      class_name: "Spinning",
      description: "High intensity cycling class",
      duration_minutes: 60,
      capacity: 15
    },

    room: {
      name: "Cycling Room",
      capacity: 15
    },

    trainer_id: ObjectId(),

    // session ran with a substitute trainer
    is_override: true,
    override_reason: "Regular trainer on sick leave — substitute assigned",

    attendance: [
      {
        member_id: ObjectId(),
        check_in_time: ISODate("2024-06-25T17:58:00Z"),
        status: "attended"
      },
      {
        member_id: ObjectId(),
        check_in_time: null,
        status: "no_show"
      }
    ]
  }

]);


// =========================================================
// COLLECTION: equipment
//
// In SQL: gym.equipment is a standalone table.
// In MongoDB: independent collection — no relationships
// to embed. Each document represents one piece of equipment.
// =========================================================

db.equipment.insertMany([

  {
    _id: ObjectId(),
    name: "Treadmill X1",
    status: "available",
    last_maintenance: ISODate("2024-04-15")
  },

  {
    _id: ObjectId(),
    name: "Rowing Machine R3",
    status: "under_repair",
    last_maintenance: ISODate("2024-03-01")
  }

]);