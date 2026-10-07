-- Extend contacts for Telegram invite linking + optional email
ALTER TABLE contacts
    ADD COLUMN email VARCHAR(150) NULL AFTER phone_number,
    ADD COLUMN telegram_chat_id BIGINT NULL AFTER email,
    ADD COLUMN invite_token VARCHAR(64) NULL AFTER telegram_chat_id,
    ADD COLUMN telegram_linked_at DATETIME NULL AFTER invite_token;

CREATE UNIQUE INDEX idx_contacts_invite_token ON contacts (invite_token);
CREATE UNIQUE INDEX idx_contacts_telegram_chat_id ON contacts (telegram_chat_id);
