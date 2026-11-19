-- Reverse 000002. Idempotent: safe to replay.
DROP INDEX IF EXISTS idx_contacts_telegram_chat_id ON contacts;
DROP INDEX IF EXISTS idx_contacts_invite_token ON contacts;

ALTER TABLE contacts
    DROP COLUMN IF EXISTS telegram_linked_at,
    DROP COLUMN IF EXISTS invite_token,
    DROP COLUMN IF EXISTS telegram_chat_id,
    DROP COLUMN IF EXISTS email;
