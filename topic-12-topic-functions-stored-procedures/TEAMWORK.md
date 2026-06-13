# TEAMWORK - Topic 12 (Functions & Stored Procedures)

## Склад команди
- Команда: team 6
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Oleksandr Chura | учасник | Створив функцію `gym.get_member_attendance_rate`, процедуру `gym.book_class_session`, процедуру `gym.check_in_member` | functions_stored_procedures.sql [video](https://drive.google.com/file/d/1YKJf8pqd3zKo7rnRG1wgiKRRSGWNo0q-/view?usp=sharing) |
| Andrew Chernuha | developer | fn_count_trainer_sessions, fn_is_trainer_available, sp_get_trainer_sessions, sp_submit_leave, sp_cancel_session, functions_stored_procedures.sql | [video](https://www.loom.com/share/e9c6342a8ecf4b899e811b94c5f311ce) |
| ... | ... | ... | ... |

## Контекст теми
Oleksandr Chura — функція `get_member_attendance_rate`, процедура `book_class_session` (SELECT/INSERT), процедура `check_in_member` (UPDATE).

## Коротке обґрунтування командного підходу
1. Як ви розподілили функції/процедури між учасниками: виконання завдання відбувалося асинхронно, кожен учасник створював функції/процедури, котрі вважав корисними.
2. Чому ці routines важливі для предметної області: 
- функція відвідуваності є ключовою метрикою для залучення клієнтів; 
- бронювання занять — найчастіша транзакційна операція фітнес-центру; 
- check-in завершує життєвий цикл відвідування (booked → attended) з валідацією часового вікна сесії (не раніше 30 хв до початку, не пізніше закінчення).
3. Як перевіряли коректність параметрів, поведінки та тестових викликів: кожна функція/процедура має тестові виклики в кінці файлу; перевірено послідовність workflow (book → check-in → перевірка attendance rate); EXCEPTION-блоки обробляють edge cases (дублювання бронювання, відсутність членства, переповнення місткості, невалідний час check-in).

