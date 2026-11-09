# SocietyCare

SocietyCare is a MySQL database design for reporting and managing maintenance issues in a residential society. Residents can report and support issues, committee members can assign work and review costs, and maintenance workers can post progress updates. The repository contains the database script and an ER diagram; it does not contain a web application.

## Repository files

| File | Purpose |
| --- | --- |
| [SocietyCare.sql](SocietyCare.sql) | Creates the database, 18 tables, constraints, indexes, and demo records. |
| [ER Diagram.pdf](ER%20Diagram.pdf) | Shows the entity relationships. |

## Requirements

- MySQL 8.0.16 or newer, with a user allowed to create databases and tables.
- A new or empty `societycare` database. The script creates the database if needed, but it does not remove existing data. Run it only once against an empty database.

## Set up the database

Open a terminal in this folder and start the MySQL command-line client:

```text
mysql -u root -p
```

Enter your MySQL password, then run these commands at the `mysql>` prompt:

```sql
SOURCE SocietyCare.sql;
USE societycare;
SHOW TABLES;
SELECT tracking_no, title, priority FROM Issue;
```

Use your own MySQL username in place of `root` if needed. `SHOW TABLES` should list 18 tables, and the final query should return three demo issues.

## Demo data

The script inserts at least one row into **every table**. Its fictional example is Lakeview Housing Society in Dhanmondi, Dhaka. It includes residents, a committee member, maintenance workers, locations, categories, three related issues, assignments, progress updates, a resolution review, a deadline change, an escalation, comments, notifications, and an approved repair estimate with an expense. Amounts are in Bangladeshi taka (BDT).

The account names and phone numbers are placeholders. Each demo account uses the password `Demo@12345`. Change these credentials before using the database outside a local demo.

## Schema notes

- `Account` and `AccountRole` represent users and their roles: `RESIDENT`, `COMMITTEE`, and `WORKER`.
- `Issue` references its reporter, location, and category. An issue may also link to another issue as a duplicate.
- `ProgressUpdate` records status history. The latest update is the issue's current status; `Issue` has no status column.
- `Assignment`, `DeadlineChange`, and `Escalation` track work and deadlines.
- `RepairEstimate`, `EstimateLine`, `EstimateDecision`, and `ActualExpense` track proposed and actual costs.
- `ResolutionReview` records the original reporter's decision on completed work.

The database enforces keys, allowed values, and other row-level checks. Application logic is still needed for workflow rules such as role permissions, valid status transitions, and approval before spending.
