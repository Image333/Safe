-- Extend contacts for Telegram invite linking and optional email.
--
-- Idempotent: each DDL uses IF NOT EXISTS so a replayed or partially applied
-- migration converges instead of failing with "duplicate column/index".
ALTER TABLE contacts
    ADD COLUMN IF NOT EXISTS email VARCHAR(150) NULL AFTER phone_number,
    ADD COLUMN IF NOT EXISTS telegram_chat_id BIGINT NULL AFTER email,
    ADD COLUMN IF NOT EXISTS invite_token VARCHAR(64) NULL AFTER telegram_chat_id,
    ADD COLUMN IF NOT EXISTS telegram_linked_at DATETIME NULL AFTER invite_token;

-- Nullable unique indexes: MySQL/MariaDB allow multiple NULL values, so
-- unlinked contacts (NULL token, NULL chat id) do not collide.
CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_invite_token ON contacts (invite_token);
CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_telegram_chat_id ON contacts (telegram_chat_id);
