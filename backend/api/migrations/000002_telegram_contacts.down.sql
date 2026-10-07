DROP INDEX idx_contacts_telegram_chat_id ON contacts;
DROP INDEX idx_contacts_invite_token ON contacts;

ALTER TABLE contacts
    DROP COLUMN telegram_linked_at,
    DROP COLUMN invite_token,
    DROP COLUMN telegram_chat_id,
    DROP COLUMN email;
