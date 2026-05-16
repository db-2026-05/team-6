# TEAMWORK - Topic 04 (SQL DDL)

## Склад команди
- Команда: team 6
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Oleksandr Chura | учасник | Відповідав за таблиці та constraints повʼязані з CLASS AND SCHEDULING MANAGEMENT | [video](https://drive.google.com/file/d/1Cu9SCccP8MFf59W7MHuqO9FSjXdEDPG-/view?usp=sharing) |
| Dmytro Tokariev | учасник | Відповідав за таблиці та constraints повʼязані з Equipment and Goal Tracking | [video] (https://drive.google.com/file/d/1ZblTMb1xZBnJSzaSkcflFdnzDG3SY9n_/view?usp=drive_link) |
| ... | ... | ... | ... |

## Контекст теми
Опишіть, хто відповідав за: створення таблиць, PK/FK, constraints, indexes, порядок секцій у `ddl.sql` та перевірку виконання скрипта у PostgreSQL.

Створення таблиць розділили між членами команди, кожен був відповідальний за свою частину та створював indexes та constraints для відповідних таблиць:
| Учасник | Частина БД |
|---|---|
| Bohdan Bohelskyi | Person & Trainer Specializations |
| Oleksandr Chura | Class & Scheduling Management |
| Oleh Svyrydenko | Membership Management збір та перевірка виконання скрипта в Supabase |
| Dmytro Tokariev | Equipment & Goal Tracking |
| Andrew Chernuha | Personal Training Management |


## Коротке обґрунтування командного підходу
1. Як ви розподілили DDL-об'єкти між учасниками: кожен обрав частину таблиці, з якою хотів працювати
2. Чому обрали саме такий поділ роботи: додаткових причин не було
3. Як перевіряли відповідність DDL вашій ER-діаграмі: в DDL є всі таблиці, які є на ER діаграмі, але краще продумані типи та обмеження. Для перевірки скрипта ми завантажили та запустили ddl script в supabase, додали тестові записи та перевірили наявність та правильність звʼязків між таблицями, типи та роботу constraints.
