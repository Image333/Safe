DROP INDEX IF EXISTS idx_contacts_phone_suffix ON contacts;

ALTER TABLE contacts
    DROP COLUMN IF EXISTS phone_suffix;
