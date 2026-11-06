-- SocietyCare: database and table creation script
-- Matches the logical schema in SocietyCare_ERD_and_Schema.pdf.
-- Target: MySQL 8.0.16+; check your installed engine with SELECT VERSION();
-- Run once in a new/empty societycare database. This script does not drop data.
-- Includes 18 tables, 30 foreign keys, constraints, 7 additional indexes,
-- and the three initial user roles. It does not insert personal/sample data.
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

-- Confirm creation: 18 base tables should appear.
SHOW TABLES;
