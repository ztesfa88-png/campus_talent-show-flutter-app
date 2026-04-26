-- ========================================
-- SUPABASE ROW LEVEL SECURITY POLICIES
-- ========================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE performers ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- ========================================
-- USERS TABLE POLICIES
-- ========================================

-- Users can read all users (public profiles)
CREATE POLICY "Users can read all users" ON users
    FOR SELECT USING (true);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile (registration)
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Admins have full access to users table
CREATE POLICY "Admins full access to users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- PERFORMERS TABLE POLICIES
-- ========================================

-- All authenticated users can read performers (public profiles)
CREATE POLICY "All users can read performers" ON performers
    FOR SELECT USING (true);

-- Performers can update their own performer profile
CREATE POLICY "Performers can update own profile" ON performers
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'performer'
            AND user_id = auth.uid()
        )
    );

-- Performers can insert their own performer profile
CREATE POLICY "Performers can insert own profile" ON performers
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'performer'
            AND user_id = auth.uid()
        )
    );

-- Admins have full access to performers table
CREATE POLICY "Admins full access to performers" ON performers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- EVENTS TABLE POLICIES
-- ========================================

-- All authenticated users can read events
CREATE POLICY "All users can read events" ON events
    FOR SELECT USING (true);

-- Admins have full access to events table
CREATE POLICY "Admins full access to events" ON events
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- VOTES TABLE POLICIES
-- ========================================

-- Users can read their own votes
CREATE POLICY "Users can read own votes" ON votes
    FOR SELECT USING (user_id = auth.uid());

-- Users can insert votes (one vote per performer per user)
CREATE POLICY "Users can insert votes" ON votes
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        -- Ensure one vote per performer per user
        NOT EXISTS (
            SELECT 1 FROM votes 
            WHERE user_id = auth.uid() 
            AND performer_id = NEW.performer_id
            AND event_id = NEW.event_id
        )
    );

-- Users can update their own votes (change rating)
CREATE POLICY "Users can update own votes" ON votes
    FOR UPDATE USING (user_id = auth.uid());

-- Admins have full access to votes table
CREATE POLICY "Admins full access to votes" ON votes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- NOTIFICATIONS TABLE POLICIES
-- ========================================

-- Users can read their own notifications
CREATE POLICY "Users can read own notifications" ON notifications
    FOR SELECT USING (user_id = auth.uid());

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (user_id = auth.uid());

-- System can insert notifications (for targeted notifications)
CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- Admins have full access to notifications table
CREATE POLICY "Admins full access to notifications" ON notifications
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- FEEDBACK TABLE POLICIES
-- ========================================

-- All authenticated users can read feedback (public)
CREATE POLICY "All users can read feedback" ON feedback
    FOR SELECT USING (true);

-- Users can insert their own feedback
CREATE POLICY "Users can insert own feedback" ON feedback
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own feedback
CREATE POLICY "Users can update own feedback" ON feedback
    FOR UPDATE USING (user_id = auth.uid());

-- Admins have full access to feedback table
CREATE POLICY "Admins full access to feedback" ON feedback
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ========================================
-- ADDITIONAL SECURITY MEASURES
-- ========================================

-- Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user owns performer profile
CREATE OR REPLACE FUNCTION owns_performer(performer_id UUID) 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM performers 
        WHERE id = performer_id 
        AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check if user has already voted
CREATE OR REPLACE FUNCTION has_voted_for_performer(performer_id UUID, event_id UUID) 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM votes 
        WHERE user_id = auth.uid() 
        AND performer_id = performer_id
        AND event_id = event_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to prevent duplicate votes
CREATE OR REPLACE FUNCTION prevent_duplicate_votes()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM votes 
        WHERE user_id = NEW.user_id 
        AND performer_id = NEW.performer_id
        AND event_id = NEW.event_id
    ) THEN
        RAISE EXCEPTION 'User has already voted for this performer in this event';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger
CREATE TRIGGER prevent_duplicate_votes_trigger
    BEFORE INSERT OR UPDATE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION prevent_duplicate_votes();

-- ========================================
-- VIEWS FOR COMMON QUERIES
-- ========================================

-- View for performer statistics (public)
CREATE VIEW performer_stats AS
SELECT 
    p.id,
    p.name,
    p.talent_type,
    p.experience_level,
    COUNT(v.id) as total_votes,
    COALESCE(AVG(v.score), 0) as average_score,
    p.created_at,
    p.updated_at
FROM performers p
LEFT JOIN votes v ON p.id = v.performer_id
GROUP BY p.id, p.name, p.talent_type, p.experience_level, p.created_at, p.updated_at;

-- View for event statistics (admin only through RLS)
CREATE VIEW event_stats AS
SELECT 
    e.id,
    e.title,
    e.description,
    e.date,
    e.location,
    e.status,
    COUNT(DISTINCT p.id) as performer_count,
    COUNT(DISTINCT v.user_id) as voter_count,
    COUNT(v.id) as total_votes,
    COALESCE(AVG(v.score), 0) as average_score,
    e.created_at,
    e.updated_at
FROM events e
LEFT JOIN performers p ON e.id = p.event_id
LEFT JOIN votes v ON e.id = v.event_id
GROUP BY e.id, e.title, e.description, e.date, e.location, e.status, e.created_at, e.updated_at;

-- View for user voting history (own votes only through RLS)
CREATE VIEW user_voting_history AS
SELECT 
    v.id,
    v.event_id,
    e.title as event_title,
    v.performer_id,
    p.name as performer_name,
    p.talent_type,
    v.score,
    v.voted_at
FROM votes v
JOIN events e ON v.event_id = e.id
JOIN performers p ON v.performer_id = p.id;

-- ========================================
-- INDEXES FOR PERFORMANCE
-- ========================================

-- Indexes for users table
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);

-- Indexes for performers table
CREATE INDEX idx_performers_user_id ON performers(user_id);
CREATE INDEX idx_performers_talent_type ON performers(talent_type);
CREATE INDEX idx_performers_experience_level ON performers(experience_level);

-- Indexes for votes table
CREATE INDEX idx_votes_user_id ON votes(user_id);
CREATE INDEX idx_votes_performer_id ON votes(performer_id);
CREATE INDEX idx_votes_event_id ON votes(event_id);
CREATE INDEX idx_votes_composite ON votes(user_id, performer_id, event_id);

-- Indexes for notifications table
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Indexes for feedback table
CREATE INDEX idx_feedback_user_id ON feedback(user_id);
CREATE INDEX idx_feedback_created_at ON feedback(created_at);

-- ========================================
-- SAMPLE DATA FOR TESTING
-- ========================================

-- Insert sample admin user (remove in production)
-- INSERT INTO users (id, email, name, role, created_at, updated_at)
-- VALUES (
--     gen_random_uuid(),
--     'admin@campustalentshow.com',
--     'Admin User',
--     'admin',
--     NOW(),
//     NOW()
// );

-- ========================================
-- SECURITY FUNCTIONS
-- ========================================

-- Function to get current user role
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT role FROM users 
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access performer data
CREATE OR REPLACE FUNCTION can_access_performer_data(performer_id UUID, access_type TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    performer_user_id UUID;
BEGIN
    -- Get current user role
    SELECT role INTO user_role FROM users WHERE id = auth.uid();
    
    -- Get performer's user_id
    SELECT user_id INTO performer_user_id FROM performers WHERE id = performer_id;
    
    -- Admins can access all performer data
    IF user_role = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Performers can access their own data
    IF user_role = 'performer' AND performer_user_id = auth.uid() THEN
        RETURN true;
    END IF;
    
    -- Students can read performer data
    IF user_role = 'student' AND access_type = 'read' THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate vote constraints
CREATE OR REPLACE FUNCTION validate_vote_constraints(performer_id UUID, event_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    user_role TEXT;
    event_status TEXT;
BEGIN
    -- Get current user role
    SELECT role INTO user_role FROM users WHERE id = auth.uid();
    
    -- Get event status
    SELECT status INTO event_status FROM events WHERE id = event_id;
    
    -- Only students can vote
    IF user_role != 'student' THEN
        RETURN false;
    END IF;
    
    -- Event must be active for voting
    IF event_status != 'active' THEN
        RETURN false;
    END IF;
    
    -- Check if user hasn't already voted for this performer
    IF EXISTS (
        SELECT 1 FROM votes 
        WHERE user_id = auth.uid() 
        AND performer_id = performer_id
        AND event_id = event_id
    ) THEN
        RETURN false;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- TRIGGERS FOR DATA INTEGRITY
-- ========================================

-- Trigger to update performer stats when vote is inserted
CREATE OR REPLACE FUNCTION update_performer_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- This would typically be handled by materialized views or scheduled jobs
    -- For now, we'll leave this as a placeholder
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_performer_stats_trigger
    AFTER INSERT OR UPDATE OR DELETE ON votes
    FOR EACH ROW
    EXECUTE FUNCTION update_performer_stats();

-- ========================================
-- AUDIT LOGGING
-- ========================================

-- Create audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    user_id UUID REFERENCES users(id),
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS on audit log
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs
CREATE POLICY "Admins can read audit logs" ON audit_log
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() 
            AND role = 'admin'
        )
    );

-- System can insert audit logs
CREATE POLICY "System can insert audit logs" ON audit_log
    FOR INSERT WITH CHECK (true);

-- Trigger to log changes
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, user_id, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, user_id, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, user_id, old_values)
        VALUES (TG_TABLE_NAME, TG_OP, auth.uid(), to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to key tables
CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER performers_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON performers
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER votes_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON votes
    FOR EACH ROW EXECUTE FUNCTION log_changes();

CREATE TRIGGER events_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON events
    FOR EACH ROW EXECUTE FUNCTION log_changes();
