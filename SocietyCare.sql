-- SocietyCare: database and table creation script
-- Matches the logical schema in SocietyCare_ERD_and_Schema.pdf.
-- Target: MySQL 8.0.16+; check your installed engine with SELECT VERSION();
-- Run once in a new/empty societycare database. This script does not drop data.
-- Includes 18 tables, 30 foreign keys, constraints, 7 additional indexes,
-- and a fictional Dhaka society dataset with rows in every table.
-- Cross-row workflow rules (role permissions, duplicate-link consistency,
-- estimate approval before spending, original-reporter verification,
-- and valid status transitions) require the PHP service layer or the
-- additional triggers/routines provided in SocietyCare_Schema.sql.
-- Create an Issue and its initial OPEN ProgressUpdate in one PHP transaction.
-- Current issue status is the latest ProgressUpdate, not a column in Issue.
-- All monetary amounts are BDT. utf8mb4 supports Bangla descriptions.

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS societycare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE societycare;

CREATE TABLE `Account` (
  `user_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `full_name` VARCHAR(100) NOT NULL,
  `phone` VARCHAR(20) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `house_flat` VARCHAR(80) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `uq_Account_1` UNIQUE (`phone`),
  CONSTRAINT `ck_Account_1` CHECK (is_active IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Role` (
  `role_code` VARCHAR(16) NOT NULL,
  `role_name` VARCHAR(40) NOT NULL,
  PRIMARY KEY (`role_code`),
  CONSTRAINT `uq_Role_1` UNIQUE (`role_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `AccountRole` (
  `user_id` BIGINT UNSIGNED NOT NULL,
  `role_code` VARCHAR(16) NOT NULL,
  `granted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`, `role_code`),
  CONSTRAINT `fk_AccountRole_user_id` FOREIGN KEY (`user_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_AccountRole_role_code` FOREIGN KEY (`role_code`) REFERENCES `Role` (`role_code`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Location` (
  `location_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `block_name` VARCHAR(60) NOT NULL,
  `road_name` VARCHAR(80) NOT NULL,
  `landmark` VARCHAR(160) NULL,
  PRIMARY KEY (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Category` (
  `category_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `category_name` VARCHAR(60) NOT NULL,
  `description` VARCHAR(255) NULL,
  PRIMARY KEY (`category_id`),
  CONSTRAINT `uq_Category_1` UNIQUE (`category_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Issue` (
  `issue_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tracking_no` VARCHAR(32) NOT NULL,
  `title` VARCHAR(160) NOT NULL,
  `description` TEXT NOT NULL,
  `reporter_id` BIGINT UNSIGNED NOT NULL,
  `location_id` BIGINT UNSIGNED NOT NULL,
  `category_id` BIGINT UNSIGNED NOT NULL,
  `priority` VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
  `photo_path` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `duplicate_of_id` BIGINT UNSIGNED NULL,
  `duplicate_linked_by` BIGINT UNSIGNED NULL,
  `duplicate_linked_at` DATETIME NULL,
  PRIMARY KEY (`issue_id`),
  CONSTRAINT `uq_Issue_1` UNIQUE (`tracking_no`),
  CONSTRAINT `fk_Issue_reporter_id` FOREIGN KEY (`reporter_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Issue_location_id` FOREIGN KEY (`location_id`) REFERENCES `Location` (`location_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Issue_category_id` FOREIGN KEY (`category_id`) REFERENCES `Category` (`category_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Issue_duplicate_of_id` FOREIGN KEY (`duplicate_of_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Issue_duplicate_linked_by` FOREIGN KEY (`duplicate_linked_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_Issue_1` CHECK (priority IN ('LOW','MEDIUM','HIGH','URGENT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `IssueSupport` (
  `issue_id` BIGINT UNSIGNED NOT NULL,
  `resident_id` BIGINT UNSIGNED NOT NULL,
  `supported_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`issue_id`, `resident_id`),
  CONSTRAINT `fk_IssueSupport_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_IssueSupport_resident_id` FOREIGN KEY (`resident_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Assignment` (
  `assignment_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `issue_id` BIGINT UNSIGNED NOT NULL,
  `worker_id` BIGINT UNSIGNED NOT NULL,
  `assigned_by` BIGINT UNSIGNED NOT NULL,
  `assigned_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `due_at` DATETIME NOT NULL,
  `ended_at` DATETIME NULL,
  PRIMARY KEY (`assignment_id`),
  CONSTRAINT `fk_Assignment_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Assignment_worker_id` FOREIGN KEY (`worker_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Assignment_assigned_by` FOREIGN KEY (`assigned_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_Assignment_1` CHECK (due_at >= assigned_at),
  CONSTRAINT `ck_Assignment_2` CHECK (ended_at IS NULL OR ended_at >= assigned_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ProgressUpdate` (
  `update_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `issue_id` BIGINT UNSIGNED NOT NULL,
  `updated_by` BIGINT UNSIGNED NOT NULL,
  `status_code` VARCHAR(24) NOT NULL,
  `note` TEXT NULL,
  `photo_path` VARCHAR(255) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`update_id`),
  CONSTRAINT `fk_ProgressUpdate_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_ProgressUpdate_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_ProgressUpdate_1` CHECK (status_code IN ('OPEN','ASSIGNED','IN_PROGRESS','AWAITING_VERIFICATION','CLOSED','REOPENED','DUPLICATE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ResolutionReview` (
  `review_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `completion_update_id` BIGINT UNSIGNED NOT NULL,
  `reporter_id` BIGINT UNSIGNED NOT NULL,
  `decision` VARCHAR(10) NOT NULL,
  `reason` VARCHAR(500) NULL,
  `reviewed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`review_id`),
  CONSTRAINT `uq_ResolutionReview_1` UNIQUE (`completion_update_id`),
  CONSTRAINT `fk_ResolutionReview_completion_update_id` FOREIGN KEY (`completion_update_id`) REFERENCES `ProgressUpdate` (`update_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_ResolutionReview_reporter_id` FOREIGN KEY (`reporter_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_ResolutionReview_1` CHECK (decision IN ('ACCEPT','REOPEN')),
  CONSTRAINT `ck_ResolutionReview_2` CHECK (decision <> 'REOPEN' OR (reason IS NOT NULL AND CHAR_LENGTH(TRIM(reason)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `DeadlineChange` (
  `change_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `assignment_id` BIGINT UNSIGNED NOT NULL,
  `changed_by` BIGINT UNSIGNED NOT NULL,
  `old_due_at` DATETIME NOT NULL,
  `new_due_at` DATETIME NOT NULL,
  `reason` VARCHAR(500) NOT NULL,
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`change_id`),
  CONSTRAINT `fk_DeadlineChange_assignment_id` FOREIGN KEY (`assignment_id`) REFERENCES `Assignment` (`assignment_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_DeadlineChange_changed_by` FOREIGN KEY (`changed_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_DeadlineChange_1` CHECK (new_due_at > old_due_at),
  CONSTRAINT `ck_DeadlineChange_2` CHECK (CHAR_LENGTH(TRIM(reason)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Escalation` (
  `escalation_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `assignment_id` BIGINT UNSIGNED NOT NULL,
  `due_at_snapshot` DATETIME NOT NULL,
  `raised_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolved_at` DATETIME NULL,
  `note` VARCHAR(500) NULL,
  PRIMARY KEY (`escalation_id`),
  CONSTRAINT `uq_Escalation_1` UNIQUE (`assignment_id`, `due_at_snapshot`),
  CONSTRAINT `fk_Escalation_assignment_id` FOREIGN KEY (`assignment_id`) REFERENCES `Assignment` (`assignment_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_Escalation_1` CHECK (raised_at > due_at_snapshot),
  CONSTRAINT `ck_Escalation_2` CHECK (resolved_at IS NULL OR resolved_at >= raised_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Comment` (
  `comment_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `issue_id` BIGINT UNSIGNED NOT NULL,
  `author_id` BIGINT UNSIGNED NOT NULL,
  `body` TEXT NOT NULL,
  `posted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`comment_id`),
  CONSTRAINT `fk_Comment_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Comment_author_id` FOREIGN KEY (`author_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_Comment_1` CHECK (CHAR_LENGTH(TRIM(body)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `Notification` (
  `notification_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `recipient_id` BIGINT UNSIGNED NOT NULL,
  `issue_id` BIGINT UNSIGNED NULL,
  `message` VARCHAR(500) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at` DATETIME NULL,
  PRIMARY KEY (`notification_id`),
  CONSTRAINT `fk_Notification_recipient_id` FOREIGN KEY (`recipient_id`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_Notification_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_Notification_1` CHECK (read_at IS NULL OR read_at >= created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `RepairEstimate` (
  `estimate_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `issue_id` BIGINT UNSIGNED NOT NULL,
  `submitted_by` BIGINT UNSIGNED NOT NULL,
  `purpose` VARCHAR(255) NOT NULL,
  `submitted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`estimate_id`),
  CONSTRAINT `fk_RepairEstimate_issue_id` FOREIGN KEY (`issue_id`) REFERENCES `Issue` (`issue_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_RepairEstimate_submitted_by` FOREIGN KEY (`submitted_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `EstimateLine` (
  `estimate_id` BIGINT UNSIGNED NOT NULL,
  `line_no` SMALLINT UNSIGNED NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_cost` DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (`estimate_id`, `line_no`),
  CONSTRAINT `fk_EstimateLine_estimate_id` FOREIGN KEY (`estimate_id`) REFERENCES `RepairEstimate` (`estimate_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_EstimateLine_1` CHECK (line_no > 0),
  CONSTRAINT `ck_EstimateLine_2` CHECK (quantity > 0),
  CONSTRAINT `ck_EstimateLine_3` CHECK (unit_cost >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `EstimateDecision` (
  `estimate_id` BIGINT UNSIGNED NOT NULL,
  `reviewed_by` BIGINT UNSIGNED NOT NULL,
  `outcome` VARCHAR(10) NOT NULL,
  `reason` VARCHAR(500) NULL,
  `decided_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`estimate_id`),
  CONSTRAINT `fk_EstimateDecision_estimate_id` FOREIGN KEY (`estimate_id`) REFERENCES `RepairEstimate` (`estimate_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_EstimateDecision_reviewed_by` FOREIGN KEY (`reviewed_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_EstimateDecision_1` CHECK (outcome IN ('APPROVED','REJECTED')),
  CONSTRAINT `ck_EstimateDecision_2` CHECK (outcome <> 'REJECTED' OR (reason IS NOT NULL AND CHAR_LENGTH(TRIM(reason)) > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ActualExpense` (
  `expense_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `estimate_id` BIGINT UNSIGNED NOT NULL,
  `recorded_by` BIGINT UNSIGNED NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `spent_on` DATE NOT NULL,
  `receipt_path` VARCHAR(255) NULL,
  `recorded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`expense_id`),
  CONSTRAINT `fk_ActualExpense_estimate_id` FOREIGN KEY (`estimate_id`) REFERENCES `RepairEstimate` (`estimate_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_ActualExpense_recorded_by` FOREIGN KEY (`recorded_by`) REFERENCES `Account` (`user_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `ck_ActualExpense_1` CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO Role(role_code, role_name) VALUES
('RESIDENT','Resident'), ('COMMITTEE','Society committee'), ('WORKER','Maintenance worker');

CREATE INDEX idx_issue_filter ON Issue(category_id, location_id, created_at);
CREATE INDEX idx_issue_reporter ON Issue(reporter_id, created_at);
CREATE INDEX idx_progress_latest ON ProgressUpdate(issue_id, update_id);
CREATE INDEX idx_assignment_queue ON Assignment(worker_id, ended_at, due_at);
CREATE INDEX idx_assignment_due ON Assignment(ended_at, due_at);
CREATE INDEX idx_comment_thread ON Comment(issue_id, posted_at);
CREATE INDEX idx_notification_unread ON Notification(recipient_id, read_at, created_at);

-- Fictional demo data for Lakeview Housing Society, Dhanmondi, Dhaka.
-- All names and phone numbers are placeholders. Every account uses the demo
-- password Demo@12345; replace these credentials before any real deployment.
-- Run this script only against a new/empty societycare database.
START TRANSACTION;

INSERT INTO `Account` (`user_id`, `full_name`, `phone`, `password_hash`, `house_flat`, `created_at`) VALUES
(1, 'Amina Rahman', '01000000001', '$2b$10$.p3xyDz8QZIrd5gt6CqFTOyTp7/w9NZ1Oc1mA8oOQ13E1v3/fmtGa', 'A-302', '2026-10-20 10:00:00'),
(2, 'Farhan Karim', '01000000002', '$2b$10$.p3xyDz8QZIrd5gt6CqFTOyTp7/w9NZ1Oc1mA8oOQ13E1v3/fmtGa', 'B-204', '2026-10-21 11:00:00'),
(3, 'Nusrat Jahan', '01000000003', '$2b$10$.p3xyDz8QZIrd5gt6CqFTOyTp7/w9NZ1Oc1mA8oOQ13E1v3/fmtGa', 'A-101', '2026-10-18 09:00:00'),
(4, 'Rafiq Hasan', '01000000004', '$2b$10$.p3xyDz8QZIrd5gt6CqFTOyTp7/w9NZ1Oc1mA8oOQ13E1v3/fmtGa', NULL, '2026-10-22 09:00:00'),
(5, 'Salma Akter', '01000000005', '$2b$10$.p3xyDz8QZIrd5gt6CqFTOyTp7/w9NZ1Oc1mA8oOQ13E1v3/fmtGa', NULL, '2026-10-22 09:30:00');

INSERT INTO `AccountRole` (`user_id`, `role_code`, `granted_at`) VALUES
(1, 'RESIDENT', '2026-10-20 10:00:00'),
(2, 'RESIDENT', '2026-10-21 11:00:00'),
(3, 'RESIDENT', '2026-10-18 09:00:00'),
(3, 'COMMITTEE', '2026-10-18 09:00:00'),
(4, 'WORKER', '2026-10-22 09:00:00'),
(5, 'WORKER', '2026-10-22 09:30:00');

INSERT INTO `Location` (`location_id`, `block_name`, `road_name`, `landmark`) VALUES
(1, 'Block A', 'Road 7, Dhanmondi, Dhaka', 'Ground-floor water pump room'),
(2, 'Block B', 'Road 8, Dhanmondi, Dhaka', 'Main entrance gate');

INSERT INTO `Category` (`category_id`, `category_name`, `description`) VALUES
(1, 'Plumbing', 'Water supply and drainage repairs'),
(2, 'Electrical', 'Lighting and electrical maintenance');

INSERT INTO `Issue` (`issue_id`, `tracking_no`, `title`, `description`, `reporter_id`, `location_id`, `category_id`, `priority`, `created_at`, `duplicate_of_id`, `duplicate_linked_by`, `duplicate_linked_at`) VALUES
(1, 'SC-2026-001', 'Water leak beside pump room', 'Water is leaking from a pipe beside the Block A pump room.', 1, 1, 1, 'HIGH', '2026-11-01 08:30:00', NULL, NULL, NULL),
(2, 'SC-2026-002', 'Entrance light is out', 'The Block B entrance light is not working after dark.', 2, 2, 2, 'HIGH', '2026-11-03 19:15:00', NULL, NULL, NULL),
(3, 'SC-2026-003', 'Dark entrance at Block B', 'The main gate light is still off.', 1, 2, 2, 'MEDIUM', '2026-11-04 12:00:00', 2, 3, '2026-11-04 14:00:00');

INSERT INTO `IssueSupport` (`issue_id`, `resident_id`, `supported_at`) VALUES
(1, 2, '2026-11-01 10:00:00'),
(2, 1, '2026-11-04 08:00:00');

INSERT INTO `Assignment` (`assignment_id`, `issue_id`, `worker_id`, `assigned_by`, `assigned_at`, `due_at`, `ended_at`) VALUES
(1, 1, 4, 3, '2026-11-02 09:00:00', '2026-11-05 18:00:00', '2026-11-04 18:00:00'),
(2, 2, 5, 3, '2026-11-04 09:00:00', '2026-11-08 18:00:00', NULL);

INSERT INTO `ProgressUpdate` (`update_id`, `issue_id`, `updated_by`, `status_code`, `note`, `created_at`) VALUES
(1, 1, 1, 'OPEN', 'Leak reported by resident.', '2026-11-01 08:30:00'),
(2, 1, 3, 'ASSIGNED', 'Plumber assigned.', '2026-11-02 09:00:00'),
(3, 1, 4, 'IN_PROGRESS', 'Replacement pipe section identified.', '2026-11-03 10:00:00'),
(4, 1, 4, 'AWAITING_VERIFICATION', 'Pipe replaced and leak checked.', '2026-11-04 18:00:00'),
(5, 1, 3, 'CLOSED', 'Reporter accepted the repair.', '2026-11-05 10:00:00'),
(6, 2, 2, 'OPEN', 'Entrance light reported.', '2026-11-03 19:15:00'),
(7, 2, 3, 'ASSIGNED', 'Electrician assigned.', '2026-11-04 09:00:00'),
(8, 2, 5, 'IN_PROGRESS', 'Replacement fixture requested.', '2026-11-05 11:00:00'),
(9, 3, 1, 'OPEN', 'Second report of entrance light.', '2026-11-04 12:00:00'),
(10, 3, 3, 'DUPLICATE', 'Linked to SC-2026-002.', '2026-11-04 14:00:00');

INSERT INTO `ResolutionReview` (`review_id`, `completion_update_id`, `reporter_id`, `decision`, `reason`, `reviewed_at`) VALUES
(1, 4, 1, 'ACCEPT', 'No further leakage seen.', '2026-11-05 09:30:00');

INSERT INTO `DeadlineChange` (`change_id`, `assignment_id`, `changed_by`, `old_due_at`, `new_due_at`, `reason`, `changed_at`) VALUES
(1, 2, 3, '2026-11-07 18:00:00', '2026-11-08 18:00:00', 'Replacement fixture delivery was delayed.', '2026-11-06 10:00:00');

INSERT INTO `Escalation` (`escalation_id`, `assignment_id`, `due_at_snapshot`, `raised_at`, `note`) VALUES
(1, 2, '2026-11-08 18:00:00', '2026-11-09 09:00:00', 'Entrance remains dark after the extended deadline.');

INSERT INTO `Comment` (`comment_id`, `issue_id`, `author_id`, `body`, `posted_at`) VALUES
(1, 1, 2, 'The water has reached the corridor near the pump room.', '2026-11-01 10:05:00'),
(2, 2, 1, 'Please check this before the evening rush.', '2026-11-04 08:05:00');

INSERT INTO `Notification` (`notification_id`, `recipient_id`, `issue_id`, `message`, `created_at`, `read_at`) VALUES
(1, 4, 1, 'You have been assigned issue SC-2026-001.', '2026-11-02 09:01:00', '2026-11-02 09:15:00'),
(2, 2, 2, 'Issue SC-2026-002 is in progress.', '2026-11-05 11:01:00', NULL),
(3, 3, 2, 'Issue SC-2026-002 has passed its extended deadline.', '2026-11-09 09:01:00', NULL);

INSERT INTO `RepairEstimate` (`estimate_id`, `issue_id`, `submitted_by`, `purpose`, `submitted_at`) VALUES
(1, 1, 4, 'Replace the leaking pump-room pipe section', '2026-11-02 16:00:00');

INSERT INTO `EstimateLine` (`estimate_id`, `line_no`, `description`, `quantity`, `unit_cost`) VALUES
(1, 1, 'PVC pipe section (metres)', 2.00, 450.00),
(1, 2, 'Pipe fittings (pieces)', 2.00, 175.00),
(1, 3, 'Repair labour (job)', 1.00, 800.00);

INSERT INTO `EstimateDecision` (`estimate_id`, `reviewed_by`, `outcome`, `reason`, `decided_at`) VALUES
(1, 3, 'APPROVED', NULL, '2026-11-03 09:00:00');

INSERT INTO `ActualExpense` (`expense_id`, `estimate_id`, `recorded_by`, `description`, `amount`, `spent_on`, `recorded_at`) VALUES
(1, 1, 4, 'Pipe, fittings, and repair labour', 2050.00, '2026-11-04', '2026-11-04 16:00:00');

COMMIT;

-- Confirm creation: 18 base tables should appear.
SHOW TABLES;
