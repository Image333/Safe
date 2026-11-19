-- Upgrade all text columns to utf8mb4.
--
-- The schema was created with utf8mb3 (see 000001), which cannot store 4-byte
-- characters. With STRICT_TRANS_TABLES a contact name containing an emoji
-- fails with "ERROR 1366 Incorrect string value", which is a normal input for
-- a feature built on phone-book and Telegram contact names.
--
-- Only the tables holding text columns are converted; the collation is left to
-- the charset default so the migration stays portable across MySQL/MariaDB.
--
-- Idempotent: converting an already utf8mb4 table is a no-op.
ALTER TABLE users          CONVERT TO CHARACTER SET utf8mb4;
ALTER TABLE roles          CONVERT TO CHARACTER SET utf8mb4;
ALTER TABLE configurations CONVERT TO CHARACTER SET utf8mb4;
ALTER TABLE contacts       CONVERT TO CHARACTER SET utf8mb4;
ALTER TABLE alerts         CONVERT TO CHARACTER SET utf8mb4;
ALTER TABLE audio_records  CONVERT TO CHARACTER SET utf8mb4;
