# TEAMWORK - Topic 10 (SQL Views)

## Склад команди
- Команда: team 6
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Oleksandr Chura | Учасник | Views для class and schedule management | views.sql, [video](https://drive.google.com/file/d/15fmN5qjdmjrHmfZQ1TbDd4wz2qs_Zwfv/view?usp=sharing) |
| Andrew Chernuha | Developer | Views implementation | views.sql |
| Dmytro Tokariev | Учасник | Views implementation | views.sql |
| Bohdan Bohelskyi | Учасник | Views for persons, trainers, specializations and trainer_specializations | views.sql |
| Oleh Svyrydenko | Учасник | Views для Membership Management (members, memberships, members_memberships, attendance) | views.sql [video](https://drive.google.com/file/d/1G0f0sNVe98xcdi8nBMFDdXgnCBKc1FSN/view?usp=sharing) |

## Контекст теми
Кожен учасник працював з конкретними сутностями відповідно до розподілу з Topic 04 (DDL) та відповідав за Views повʼязані з його сутностями.

## Коротке обгрунтування командного підходу
1. Як ви розподілили типи views між учасниками: кожен учасник створював views повʼязані зі своїми сутностями.
2. Чому ці views важливі для предметної області: views спрощують доступ до даних для різних ролей — клієнти бачать лише розклад, менеджери отримують аналітику, а персонал може безпечно редагувати updatable view із захистом бізнес-правил.
3. Як перевіряли практичну цінність і коректність кожного view: запускали SQL-скрипт на тестовій базі з наявними DML-даними, перевіряли відсутність помилок та коректність результатів SELECT-запитів до кожного view.