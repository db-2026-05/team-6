# TEAMWORK - Topic 09 (SQL DML)

## Склад команди
- Команда: team 6
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Andrew Chernuha | Developer | Added dml request to fill in propper tables | [dml](./dml.sql) |
| Oleksandr Chura | учасник | INSERT-скрипти для таблиць CLASS AND SCHEDULING MANAGEMENT (rooms, class_templates, class_recurrence_rules, rule_week_days, rule_month_days, class_schedule), валідація constraints (CHECK, UNIQUE, FK, PK) | dml.sql [video](https://drive.google.com/file/d/1-SZiYYvzmxT1N8L9qi7x1BMOlkm4TEdc/view?usp=sharing) |
| ... | ... | ... | ... |

## Контекст теми
Кожен учасник працював з конкретними сутностями відповідно до розподілу з Topic 04 (DDL) та відповідав за INSERT-скрипти та валідацію constraints для таблиць.

## Коротке обґрунтування командного підходу
1. Як ви розподілили таблиці/сценарії наповнення між учасниками: аналогічно до Topic 04 — кожен учасник наповнює таблиці зі своєї частини схеми.
2. Чому вибрані саме такі тестові дані: дані моделюють реалістичну роботу фітнес-центру.
3. Як перевіряли коректність і реалістичність DML-скриптів: скрипт виконується в PostgreSQL(в Supabase) поверх DDL-схеми; секція constraint validation містить INSERT/DELETE-запити, що мають викликати помилки (CHECK, UNIQUE, FK, PK violations), що підтверджує коректність обмежень.
