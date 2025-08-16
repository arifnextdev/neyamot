-- PostgreSQL initialization script for production
-- This script runs when the container starts for the first time

-- Create additional database user with limited privileges
CREATE USER app_user WITH PASSWORD 'app_user_password';

-- Grant necessary permissions
GRANT CONNECT ON DATABASE alphanet_db TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT CREATE ON SCHEMA public TO app_user;

-- Set up connection limits
ALTER USER app_user CONNECTION LIMIT 20;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone
SET timezone = 'UTC';
