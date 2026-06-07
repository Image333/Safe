-- 1. Table Role
CREATE TABLE IF NOT EXISTS roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

-- 2. Table Configuration
CREATE TABLE IF NOT EXISTS configurations (
    config_id INT AUTO_INCREMENT PRIMARY KEY,
    alert_word VARCHAR(100) NOT NULL,
    app_disguise VARCHAR(100) NOT NULL
);

-- 3. Table User
CREATE TABLE IF NOT EXISTS users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    firstname VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    registration_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    role_id INT,
    config_id INT,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE SET NULL,
    FOREIGN KEY (config_id) REFERENCES configurations(config_id) ON DELETE SET NULL
);

-- 4. Table Contact
CREATE TABLE IF NOT EXISTS contacts (
    contact_id INT AUTO_INCREMENT PRIMARY KEY,
    contact_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    contact_type VARCHAR(50),
    priority_order INT DEFAULT 1
);

-- 5. Table d'association User <-> Contact (Relation Many-to-Many)
CREATE TABLE IF NOT EXISTS user_contacts (
    user_id INT,
    contact_id INT,
    PRIMARY KEY (user_id, contact_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON DELETE CASCADE
);

-- 6. Table Alert
CREATE TABLE IF NOT EXISTS alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    user_id INT NOT NULL,
    config_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (config_id) REFERENCES configurations(config_id) ON DELETE CASCADE
);

-- 7. Table Geolocation
CREATE TABLE IF NOT EXISTS geolocations (
    geo_id INT AUTO_INCREMENT PRIMARY KEY,
    latitude DECIMAL(10, 8) NOT NULL,  -- Précision standard pour des coordonnées GPS
    longitude DECIMAL(11, 8) NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    alert_id INT UNIQUE NOT NULL,       -- UNIQUE garantit la relation (1,1)
    FOREIGN KEY (alert_id) REFERENCES alerts(alert_id) ON DELETE CASCADE
);

-- 8. Table AudioRecord
CREATE TABLE IF NOT EXISTS audio_records (
    audio_id INT AUTO_INCREMENT PRIMARY KEY,
    blob_url VARCHAR(512) NOT NULL,    -- URL vers le stockage d'objets (S3/MinIO/etc.)
    duration INT NOT NULL,             -- En secondes
    format VARCHAR(10) NOT NULL,       -- ex: 'mp3'
    alert_id INT UNIQUE NOT NULL,       -- UNIQUE garantit la relation (1,1)
    FOREIGN KEY (alert_id) REFERENCES alerts(alert_id) ON DELETE CASCADE
);