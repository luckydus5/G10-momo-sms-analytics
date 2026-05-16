-- =============================================================================
-- MoMo SMS Analytics  ·  MySQL Database Setup
-- =============================================================================
-- Group 10 · ALU Software Engineering · Week 2 Deliverable
-- Author : Olivier Dusabamahoro  (Database Design)
-- Target : MySQL 8.0+ (uses utf8mb4, InnoDB, CHECK constraints)
--
-- This script:
--   1. (Re)creates the `momo_analytics` schema
--   2. Builds 7 tables modelling MTN Mobile Money SMS transactions
--   3. Adds referential integrity (FKs), CHECK constraints, and indexes
--   4. Inserts at least 5 rows per main table for testing
--   5. Demonstrates CRUD (SELECT / INSERT / UPDATE / DELETE) at the bottom
--
-- Run with:   mysql -u root -p < database/database_setup.sql
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. Schema bootstrap
-- -----------------------------------------------------------------------------
DROP DATABASE IF EXISTS momo_analytics;
CREATE DATABASE momo_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE momo_analytics;


-- -----------------------------------------------------------------------------
-- 1. transaction_categories  (lookup / dimension table)
-- -----------------------------------------------------------------------------
-- Holds the canonical list of MoMo transaction types parsed from SMS bodies.
-- Referenced by `transactions.category_id` (1:M).
CREATE TABLE transaction_categories (
    category_id     INT UNSIGNED        NOT NULL AUTO_INCREMENT
                    COMMENT 'Surrogate primary key',
    code            VARCHAR(40)         NOT NULL
                    COMMENT 'Short machine code, e.g. incoming_money, airtime',
    display_name    VARCHAR(80)         NOT NULL
                    COMMENT 'Human-readable label shown on the dashboard',
    direction       ENUM('in','out','neutral') NOT NULL DEFAULT 'neutral'
                    COMMENT 'Cash-flow direction relative to the account holder',
    description     VARCHAR(255)        NULL
                    COMMENT 'Long-form description of the category',
    is_active       TINYINT(1)          NOT NULL DEFAULT 1
                    COMMENT 'Soft-delete flag; 0 hides the category from reports',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (category_id),
    UNIQUE KEY uq_category_code (code),
    CONSTRAINT chk_category_code_lower
        CHECK (code = LOWER(code))
) ENGINE=InnoDB
  COMMENT='Reference list of MoMo transaction types (payment, transfer, airtime, ...)';


-- -----------------------------------------------------------------------------
-- 2. users  (customer dimension)
-- -----------------------------------------------------------------------------
-- One row per distinct phone number / counterparty observed in the SMS feed.
-- A transaction has a sender and a receiver that both point here.
CREATE TABLE users (
    user_id         INT UNSIGNED        NOT NULL AUTO_INCREMENT
                    COMMENT 'Surrogate primary key',
    phone_number    VARCHAR(20)         NULL
                    COMMENT 'E.164 or local format; NULL for unknown counterparties',
    full_name       VARCHAR(120)        NULL
                    COMMENT 'Display name as it appears in the SMS body',
    user_type       ENUM('customer','agent','merchant','system') NOT NULL DEFAULT 'customer'
                    COMMENT 'Role of the party in the MoMo network',
    is_account_holder TINYINT(1)        NOT NULL DEFAULT 0
                    COMMENT '1 if this row represents the SMS owner, else 0',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                 ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_user_phone (phone_number),
    KEY ix_user_type (user_type),
    CONSTRAINT chk_phone_format
        CHECK (phone_number IS NULL OR phone_number REGEXP '^[+0-9 ]{6,20}$')
) ENGINE=InnoDB
  COMMENT='Distinct senders / receivers / agents seen in the SMS feed';


-- -----------------------------------------------------------------------------
-- 3. raw_messages  (source-of-truth for every SMS)
-- -----------------------------------------------------------------------------
-- Preserves the original SMS body so categorisation can be re-run without
-- losing data. `transactions.raw_message_id` -> raw_messages.raw_message_id.
CREATE TABLE raw_messages (
    raw_message_id  BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT
                    COMMENT 'Surrogate primary key',
    sms_external_id VARCHAR(64)         NULL
                    COMMENT 'Provider-supplied SMS id; UNIQUE when present',
    body            TEXT                NOT NULL
                    COMMENT 'Verbatim SMS body as received from MTN',
    sender_address  VARCHAR(40)         NOT NULL DEFAULT 'M-Money'
                    COMMENT 'SMS short-code that sent the message',
    received_at     DATETIME            NOT NULL
                    COMMENT 'Timestamp at which the phone received the SMS',
    ingested_at     DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                    COMMENT 'Timestamp at which the ETL pipeline loaded the row',
    PRIMARY KEY (raw_message_id),
    UNIQUE KEY uq_sms_external_id (sms_external_id),
    KEY ix_raw_received_at (received_at)
) ENGINE=InnoDB
  COMMENT='Untouched SMS records preserved for re-parsing and audit';


-- -----------------------------------------------------------------------------
-- 4. transactions  (fact table)
-- -----------------------------------------------------------------------------
-- One row per cleaned, categorised MoMo transaction.
-- FKs: raw_message_id, category_id, sender_user_id, receiver_user_id.
CREATE TABLE transactions (
    transaction_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT
                        COMMENT 'Surrogate primary key',
    txn_ref             VARCHAR(64)     NULL
                        COMMENT 'Provider-issued transaction reference (e.g. TxId)',
    raw_message_id      BIGINT UNSIGNED NOT NULL
                        COMMENT 'FK -> raw_messages.raw_message_id',
    category_id         INT UNSIGNED    NOT NULL
                        COMMENT 'FK -> transaction_categories.category_id',
    sender_user_id      INT UNSIGNED    NULL
                        COMMENT 'FK -> users.user_id (party debited)',
    receiver_user_id    INT UNSIGNED    NULL
                        COMMENT 'FK -> users.user_id (party credited)',
    direction           ENUM('in','out') NOT NULL
                        COMMENT 'Cash flow relative to the account holder',
    amount_rwf          DECIMAL(14,2)   NOT NULL
                        COMMENT 'Principal amount in Rwandan Francs',
    fee_rwf             DECIMAL(10,2)   NOT NULL DEFAULT 0.00
                        COMMENT 'MoMo fee charged on the transaction',
    balance_rwf         DECIMAL(14,2)   NULL
                        COMMENT 'Account balance reported after the transaction',
    status              ENUM('completed','failed','pending','reversed')
                        NOT NULL DEFAULT 'completed'
                        COMMENT 'Final state of the transaction',
    occurred_at         DATETIME        NOT NULL
                        COMMENT 'When the transaction occurred (from the SMS)',
    created_at          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id),
    UNIQUE KEY uq_txn_ref (txn_ref),
    KEY ix_txn_occurred_at (occurred_at),
    KEY ix_txn_category    (category_id),
    KEY ix_txn_direction   (direction),
    KEY ix_txn_sender      (sender_user_id),
    KEY ix_txn_receiver    (receiver_user_id),
    KEY ix_txn_amount      (amount_rwf),
    CONSTRAINT fk_txn_raw
        FOREIGN KEY (raw_message_id) REFERENCES raw_messages(raw_message_id)
        ON DELETE CASCADE  ON UPDATE CASCADE,
    CONSTRAINT fk_txn_category
        FOREIGN KEY (category_id)    REFERENCES transaction_categories(category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_txn_sender
        FOREIGN KEY (sender_user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_txn_receiver
        FOREIGN KEY (receiver_user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_amount_nonneg     CHECK (amount_rwf  >= 0),
    CONSTRAINT chk_fee_nonneg        CHECK (fee_rwf     >= 0),
    CONSTRAINT chk_amount_max        CHECK (amount_rwf  <= 10000000),
    CONSTRAINT chk_balance_nonneg    CHECK (balance_rwf IS NULL OR balance_rwf >= 0),
    CONSTRAINT chk_parties_distinct  CHECK (sender_user_id IS NULL
                                         OR receiver_user_id IS NULL
                                         OR sender_user_id <> receiver_user_id)
) ENGINE=InnoDB
  COMMENT='Cleaned, categorised MoMo transactions (the fact table)';


-- -----------------------------------------------------------------------------
-- 5. tags   +   6. transaction_tags  (many-to-many junction)
-- -----------------------------------------------------------------------------
-- A transaction can have many tags (e.g. "recurring", "high-value", "review"),
-- and a tag can label many transactions.  M:N is resolved through the
-- `transaction_tags` junction table below.
CREATE TABLE tags (
    tag_id          INT UNSIGNED        NOT NULL AUTO_INCREMENT
                    COMMENT 'Surrogate primary key',
    label           VARCHAR(40)         NOT NULL
                    COMMENT 'Tag text, e.g. "recurring", "high-value"',
    description     VARCHAR(255)        NULL
                    COMMENT 'Why this tag exists / when to apply it',
    created_at      DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tag_id),
    UNIQUE KEY uq_tag_label (label)
) ENGINE=InnoDB
  COMMENT='Free-form labels attached to transactions';

CREATE TABLE transaction_tags (
    transaction_id  BIGINT UNSIGNED     NOT NULL
                    COMMENT 'FK -> transactions.transaction_id',
    tag_id          INT UNSIGNED        NOT NULL
                    COMMENT 'FK -> tags.tag_id',
    tagged_at       DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                    COMMENT 'When the tag was applied',
    tagged_by       VARCHAR(60)         NULL
                    COMMENT 'Username or ETL stage that applied the tag',
    PRIMARY KEY (transaction_id, tag_id),
    KEY ix_tt_tag (tag_id),
    CONSTRAINT fk_tt_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tt_tag
        FOREIGN KEY (tag_id)         REFERENCES tags(tag_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB
  COMMENT='Junction table resolving the M:N relationship transactions <-> tags';


-- -----------------------------------------------------------------------------
-- 7. system_logs  (ETL / processing audit trail)
-- -----------------------------------------------------------------------------
-- Captures events emitted by the ETL pipeline, the API, and ad-hoc scripts.
-- Optional `transaction_id` ties a log line to the row it produced.
CREATE TABLE system_logs (
    log_id          BIGINT UNSIGNED     NOT NULL AUTO_INCREMENT
                    COMMENT 'Surrogate primary key',
    transaction_id  BIGINT UNSIGNED     NULL
                    COMMENT 'Optional FK -> transactions.transaction_id',
    log_level       ENUM('DEBUG','INFO','WARNING','ERROR','CRITICAL')
                    NOT NULL DEFAULT 'INFO'
                    COMMENT 'Python-style log severity',
    source          VARCHAR(60)         NOT NULL
                    COMMENT 'Module that emitted the event, e.g. etl.parse_xml',
    message         VARCHAR(500)        NOT NULL
                    COMMENT 'Free-text log message',
    run_id          VARCHAR(36)         NULL
                    COMMENT 'UUID grouping rows from one ETL run',
    occurred_at     DATETIME            NOT NULL DEFAULT CURRENT_TIMESTAMP
                    COMMENT 'When the event happened',
    PRIMARY KEY (log_id),
    KEY ix_log_level   (log_level),
    KEY ix_log_run     (run_id),
    KEY ix_log_source  (source),
    KEY ix_log_occurred(occurred_at),
    CONSTRAINT fk_log_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB
  COMMENT='Structured logs from ETL, API, and processing scripts';


-- =============================================================================
-- SAMPLE DATA  (at least 5 rows per main table)
-- =============================================================================

-- 1) transaction_categories  ---------------------------------------------------
INSERT INTO transaction_categories (code, display_name, direction, description) VALUES
 ('incoming_money',       'Incoming Money',         'in',      'Money received from another MoMo user'),
 ('payment_to_code',      'Payment to Code Holder', 'out',     'Payment to a merchant code'),
 ('transfer_to_mobile',   'Transfer to Mobile',     'out',     'P2P transfer to another mobile number'),
 ('bank_deposit',         'Bank Deposit',           'in',      'Deposit from a partner bank account'),
 ('airtime',              'Airtime Purchase',       'out',     'Airtime top-up for self or third party'),
 ('cash_power_bill',      'Cash Power (EUCL)',      'out',     'Electricity (Cash Power) bill payment'),
 ('withdrawal_from_agent','Agent Withdrawal',       'out',     'Cash-out at a MoMo agent'),
 ('internet_bundle',      'Internet Bundle',        'out',     'Mobile internet bundle purchase'),
 ('bank_transfer',        'Bank Transfer',          'out',     'Outgoing transfer to a bank account'),
 ('third_party_initiated','Third-Party Initiated',  'neutral', 'Transaction initiated by an external party');

-- 2) users  --------------------------------------------------------------------
INSERT INTO users (phone_number, full_name, user_type, is_account_holder) VALUES
 ('+250788000001', 'Olivier Dusabamahoro', 'customer',  1),
 ('+250788123456', 'Jane Uwase',           'customer',  0),
 ('+250722987654', 'Eric Mugabo',          'customer',  0),
 ('+250788555000', 'Kigali Agent #4421',   'agent',     0),
 ('+250788777777', 'SuperMart Ltd',        'merchant',  0),
 ('+250799112233', 'Paul Ndayisenga',      'customer',  0),
 (NULL,            'MTN System',           'system',    0);

-- 3) raw_messages  -------------------------------------------------------------
INSERT INTO raw_messages (sms_external_id, body, sender_address, received_at) VALUES
 ('SMS-0001', 'You have received 25000 RWF from Jane Uwase (+250788123456). New balance: 42500 RWF. TxId: 11223344', 'M-Money', '2026-05-01 08:14:00'),
 ('SMS-0002', 'TxId: 22334455. Your payment of 5000 RWF to SuperMart Ltd has been completed. Fee 0 RWF. New balance: 37500 RWF.', 'M-Money', '2026-05-02 10:01:00'),
 ('SMS-0003', 'TxId: 33445566. 10000 RWF transferred to Eric Mugabo (+250722987654). Fee 100 RWF. New balance: 27400 RWF.',     'M-Money', '2026-05-03 17:30:00'),
 ('SMS-0004', 'TxId: 44556677. Airtime purchase of 1000 RWF was successful. Fee 0 RWF. New balance: 26400 RWF.',                'M-Money', '2026-05-04 09:45:00'),
 ('SMS-0005', 'TxId: 55667788. Withdrawal of 15000 RWF at Agent Kigali Agent #4421. Fee 200 RWF. New balance: 11200 RWF.',      'M-Money', '2026-05-05 12:22:00'),
 ('SMS-0006', 'TxId: 66778899. Cash Power token EXAMPLE-1234. 5000 RWF deducted. Fee 0 RWF. New balance: 6200 RWF.',            'M-Money', '2026-05-06 19:05:00');

-- 4) transactions  -------------------------------------------------------------
-- (sender / receiver / category resolved by id from the inserts above)
INSERT INTO transactions
    (txn_ref, raw_message_id, category_id, sender_user_id, receiver_user_id,
     direction, amount_rwf, fee_rwf, balance_rwf, status, occurred_at)
VALUES
 ('11223344', 1,
  (SELECT category_id FROM transaction_categories WHERE code='incoming_money'),
  (SELECT user_id FROM users WHERE phone_number='+250788123456'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  'in',  25000.00,    0.00, 42500.00, 'completed', '2026-05-01 08:14:00'),

 ('22334455', 2,
  (SELECT category_id FROM transaction_categories WHERE code='payment_to_code'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  (SELECT user_id FROM users WHERE phone_number='+250788777777'),
  'out',  5000.00,    0.00, 37500.00, 'completed', '2026-05-02 10:01:00'),

 ('33445566', 3,
  (SELECT category_id FROM transaction_categories WHERE code='transfer_to_mobile'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  (SELECT user_id FROM users WHERE phone_number='+250722987654'),
  'out', 10000.00,  100.00, 27400.00, 'completed', '2026-05-03 17:30:00'),

 ('44556677', 4,
  (SELECT category_id FROM transaction_categories WHERE code='airtime'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  NULL,
  'out',  1000.00,    0.00, 26400.00, 'completed', '2026-05-04 09:45:00'),

 ('55667788', 5,
  (SELECT category_id FROM transaction_categories WHERE code='withdrawal_from_agent'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  (SELECT user_id FROM users WHERE phone_number='+250788555000'),
  'out', 15000.00,  200.00, 11200.00, 'completed', '2026-05-05 12:22:00'),

 ('66778899', 6,
  (SELECT category_id FROM transaction_categories WHERE code='cash_power_bill'),
  (SELECT user_id FROM users WHERE phone_number='+250788000001'),
  NULL,
  'out',  5000.00,    0.00,  6200.00, 'completed', '2026-05-06 19:05:00');

-- 5) tags  ---------------------------------------------------------------------
INSERT INTO tags (label, description) VALUES
 ('recurring',   'Transaction that occurs on a regular cadence (e.g. monthly bills)'),
 ('high-value',  'Amount above 10,000 RWF — flagged for review'),
 ('reviewed',    'Manually inspected and confirmed correct'),
 ('utility',     'Bill payment to a utility provider (water, electricity, internet)'),
 ('merchant',    'Payment to a registered merchant code'),
 ('agent-cashout','Cash-out at a physical agent'),
 ('top-up',      'Airtime or data bundle purchase');

-- 6) transaction_tags  (junction — M:N)  --------------------------------------
INSERT INTO transaction_tags (transaction_id, tag_id, tagged_by) VALUES
 (2, (SELECT tag_id FROM tags WHERE label='merchant'),     'etl.categorize'),
 (3, (SELECT tag_id FROM tags WHERE label='high-value'),   'etl.categorize'),
 (3, (SELECT tag_id FROM tags WHERE label='reviewed'),     'olivier'),
 (4, (SELECT tag_id FROM tags WHERE label='top-up'),       'etl.categorize'),
 (5, (SELECT tag_id FROM tags WHERE label='agent-cashout'),'etl.categorize'),
 (5, (SELECT tag_id FROM tags WHERE label='high-value'),   'etl.categorize'),
 (6, (SELECT tag_id FROM tags WHERE label='utility'),      'etl.categorize'),
 (6, (SELECT tag_id FROM tags WHERE label='recurring'),    'olivier');

-- 7) system_logs  --------------------------------------------------------------
INSERT INTO system_logs (transaction_id, log_level, source, message, run_id) VALUES
 (NULL, 'INFO',    'etl.run',           'ETL run started for momo.xml',           'run-2026-05-01-01'),
 (1,    'INFO',    'etl.load_db',       'Inserted incoming_money transaction',    'run-2026-05-01-01'),
 (3,    'WARNING', 'etl.clean_normalize','Fee 100 RWF higher than expected median','run-2026-05-03-02'),
 (NULL, 'ERROR',   'etl.parse_xml',     'Malformed <sms> element at offset 14820','run-2026-05-03-02'),
 (5,    'INFO',    'api.app',           'Served /api/transactions?limit=50',      'run-2026-05-05-03'),
 (NULL, 'CRITICAL','etl.load_db',       'FK violation: unknown category code',    'run-2026-05-06-04');


-- =============================================================================
-- CRUD SMOKE-TEST QUERIES
-- =============================================================================
-- Run these after the script loads to verify the schema and capture screenshots
-- for the Database Design Document.

-- READ 1: row counts per main table
SELECT 'transaction_categories' AS table_name, COUNT(*) AS rows_ FROM transaction_categories
UNION ALL SELECT 'users',            COUNT(*) FROM users
UNION ALL SELECT 'raw_messages',     COUNT(*) FROM raw_messages
UNION ALL SELECT 'transactions',     COUNT(*) FROM transactions
UNION ALL SELECT 'tags',             COUNT(*) FROM tags
UNION ALL SELECT 'transaction_tags', COUNT(*) FROM transaction_tags
UNION ALL SELECT 'system_logs',      COUNT(*) FROM system_logs;

-- READ 2: full transaction view with joined dimensions
SELECT  t.transaction_id,
        t.txn_ref,
        c.display_name                AS category,
        t.direction,
        t.amount_rwf,
        t.fee_rwf,
        t.balance_rwf,
        s.full_name                   AS sender,
        r.full_name                   AS receiver,
        t.occurred_at
FROM    transactions  t
JOIN    transaction_categories c ON c.category_id = t.category_id
LEFT JOIN users s ON s.user_id = t.sender_user_id
LEFT JOIN users r ON r.user_id = t.receiver_user_id
ORDER BY t.occurred_at;

-- READ 3: monthly totals by category (aggregation)
SELECT  DATE_FORMAT(t.occurred_at,'%Y-%m') AS month,
        c.display_name                     AS category,
        COUNT(*)                           AS txn_count,
        SUM(t.amount_rwf)                  AS total_rwf
FROM    transactions t
JOIN    transaction_categories c ON c.category_id = t.category_id
GROUP BY month, category
ORDER BY month, category;

-- READ 4: transactions and their tags (exercises the M:N junction)
SELECT  t.transaction_id, t.txn_ref,
        GROUP_CONCAT(tg.label ORDER BY tg.label SEPARATOR ', ') AS tags
FROM    transactions      t
JOIN    transaction_tags  tt ON tt.transaction_id = t.transaction_id
JOIN    tags              tg ON tg.tag_id         = tt.tag_id
GROUP BY t.transaction_id, t.txn_ref
ORDER BY t.transaction_id;

-- CREATE: add a new incoming-money transaction
INSERT INTO raw_messages (sms_external_id, body, received_at) VALUES
 ('SMS-0007', 'You have received 8000 RWF from Paul Ndayisenga. New balance 14200 RWF. TxId: 77889900', '2026-05-07 07:10:00');
INSERT INTO transactions
    (txn_ref, raw_message_id, category_id, sender_user_id, receiver_user_id,
     direction, amount_rwf, fee_rwf, balance_rwf, status, occurred_at)
VALUES
 ('77889900',
  (SELECT raw_message_id FROM raw_messages WHERE sms_external_id='SMS-0007'),
  (SELECT category_id    FROM transaction_categories WHERE code='incoming_money'),
  (SELECT user_id        FROM users WHERE phone_number='+250799112233'),
  (SELECT user_id        FROM users WHERE phone_number='+250788000001'),
  'in', 8000.00, 0.00, 14200.00, 'completed', '2026-05-07 07:10:00');

-- UPDATE: reclassify the third-party-initiated transaction status to reversed
UPDATE transactions
SET    status = 'reversed'
WHERE  txn_ref = '44556677';

-- DELETE: remove a stale DEBUG/INFO log line (safe, no FK dependents)
DELETE FROM system_logs
WHERE  log_level = 'INFO'
  AND  source    = 'api.app';

-- Verify CRUD effects
SELECT txn_ref, status FROM transactions WHERE txn_ref IN ('44556677','77889900');
SELECT COUNT(*) AS remaining_logs FROM system_logs;
