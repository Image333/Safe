-- Store the digits used to match a shared phone number, so the webhook can do
-- an indexed lookup instead of scanning every unlinked contact in Go.
--
-- The value is the last nine digits of the number (or all of them when shorter),
-- which mirrors the matching rule applied until now. Phone numbers are stored
-- verbatim: only this derived column is normalized.
ALTER TABLE contacts
    ADD COLUMN IF NOT EXISTS phone_suffix VARCHAR(16) NULL AFTER phone_number;

-- Backfill existing rows (digits only, last nine characters).
UPDATE contacts
SET phone_suffix = RIGHT(REGEXP_REPLACE(phone_number, '[^0-9]', ''), 9)
WHERE phone_suffix IS NULL;

CREATE INDEX IF NOT EXISTS idx_contacts_phone_suffix ON contacts (phone_suffix);
