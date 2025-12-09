-- Create database
CREATE DATABASE IF NOT EXISTS smart_parenting;
USE smart_parenting;

-- Users table
CREATE TABLE users (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('parent', 'expert', 'admin') NOT NULL,
    gender ENUM('male', 'female', 'other', 'prefer-not-to-say'),
    date_of_birth DATE,
    address TEXT,
    bio TEXT,
    profile_photo VARCHAR(255),
    
    -- Expert specific fields
    qualification VARCHAR(200),
    specialization VARCHAR(200),
    experience_years INT,
    license_number VARCHAR(100),
    
    -- Account status
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_blocked BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_role (role),
    INDEX idx_status (is_active, is_verified, is_blocked)
);

-- Children table
CREATE TABLE children (
    id VARCHAR(50) PRIMARY KEY,
    parent_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    age INT,
    gender ENUM('male', 'female', 'other'),
    birth_date DATE,
    profile_photo VARCHAR(255),
    special_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_parent (parent_id),
    INDEX idx_name (name)
);

-- Activities table
CREATE TABLE activities (
    id VARCHAR(50) PRIMARY KEY,
    child_id VARCHAR(50) NOT NULL,
    type ENUM('study', 'sleep', 'exercise', 'play', 'meal', 'health', 'behavior') NOT NULL,
    description TEXT NOT NULL,
    duration_minutes INT,
    date DATE NOT NULL,
    time TIME,
    notes TEXT,
    status ENUM('completed', 'pending', 'overdue') DEFAULT 'pending',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    INDEX idx_child_date (child_id, date),
    INDEX idx_type (type)
);

-- Expert assignments table
CREATE TABLE expert_assignments (
    id VARCHAR(50) PRIMARY KEY,
    expert_id VARCHAR(50) NOT NULL,
    child_id VARCHAR(50) NOT NULL,
    assigned_date DATE NOT NULL,
    status ENUM('active', 'completed', 'cancelled') DEFAULT 'active',
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (expert_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    UNIQUE KEY unique_assignment (expert_id, child_id),
    INDEX idx_expert (expert_id),
    INDEX idx_child (child_id)
);

-- Messages table
CREATE TABLE messages (
    id VARCHAR(50) PRIMARY KEY,
    sender_id VARCHAR(50) NOT NULL,
    receiver_id VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    chat_id VARCHAR(100) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_chat (chat_id),
    INDEX idx_sender_receiver (sender_id, receiver_id),
    INDEX idx_created_at (created_at)
);

-- Notifications table
CREATE TABLE notifications (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('message', 'system', 'suggestion', 'admin') NOT NULL,
    data JSON,
    is_read BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_user_read (user_id, is_read)
);

-- Complaints table
CREATE TABLE complaints (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(100),
    status ENUM('pending', 'in_progress', 'resolved', 'closed') DEFAULT 'pending',
    assigned_to VARCHAR(50),
    resolution TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_status (status),
    INDEX idx_user (user_id)
);

-- Suggestions table (Expert to Parent)
CREATE TABLE suggestions (
    id VARCHAR(50) PRIMARY KEY,
    expert_id VARCHAR(50) NOT NULL,
    child_id VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(100),
    priority ENUM('low', 'medium', 'high') DEFAULT 'medium',
    status ENUM('pending', 'reviewed', 'implemented') DEFAULT 'pending',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (expert_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    INDEX idx_expert_child (expert_id, child_id)
);

-- Development milestones table
CREATE TABLE milestones (
    id VARCHAR(50) PRIMARY KEY,
    child_id VARCHAR(50) NOT NULL,
    milestone_type VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    achieved_date DATE NOT NULL,
    notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
    INDEX idx_child (child_id),
    INDEX idx_type (milestone_type)
);

-- Login history table
CREATE TABLE login_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id VARCHAR(50) NOT NULL,
    login_method ENUM('email', 'phone', 'facebook') NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Timestamps
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_login (user_id, login_time)
);

-- Insert initial admin user
INSERT INTO users (id, name, email, phone, password, role, is_verified, is_active) 
VALUES (
    'admin_001',
    'System Administrator',
    'admin@smartparenting.com',
    '+1234567890',
    '$2a$10$YourHashedPasswordHere', -- Hash of 'admin123'
    'admin',
    TRUE,
    TRUE
);

-- Create triggers for updated_at
DELIMITER //
CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

CREATE TRIGGER update_children_timestamp
BEFORE UPDATE ON children
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

CREATE TRIGGER update_complaints_timestamp
BEFORE UPDATE ON complaints
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//

CREATE TRIGGER update_suggestions_timestamp
BEFORE UPDATE ON suggestions
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END//
DELIMITER ;