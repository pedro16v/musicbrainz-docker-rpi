-- MusicBrainz Database Views for ARM64 Replication
-- These views can be useful for common queries and reporting

-- View for recent replication activity
CREATE OR REPLACE VIEW replication_status AS
SELECT 
    COUNT(*) as pending_changes,
    MAX(ts) as latest_timestamp,
    MIN(ts) as oldest_timestamp
FROM dbmirror2.pending_ts;

-- View for replication table statistics
CREATE OR REPLACE VIEW replication_stats AS
SELECT 
    'pending_data' as table_name,
    COUNT(*) as row_count
FROM dbmirror2.pending_data
UNION ALL
SELECT 
    'pending_keys' as table_name,
    COUNT(*) as row_count
FROM dbmirror2.pending_keys
UNION ALL
SELECT 
    'pending_ts' as table_name,
    COUNT(*) as row_count
FROM dbmirror2.pending_ts;

-- View for database size information
CREATE OR REPLACE VIEW database_size AS
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname IN ('musicbrainz', 'dbmirror2')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Grant permissions to musicbrainz user
GRANT SELECT ON replication_status TO musicbrainz;
GRANT SELECT ON replication_stats TO musicbrainz;
GRANT SELECT ON database_size TO musicbrainz;

-- Create indexes for better performance (if they don't exist)
CREATE INDEX IF NOT EXISTS idx_pending_ts_timestamp ON dbmirror2.pending_ts(ts);
CREATE INDEX IF NOT EXISTS idx_pending_data_tablename ON dbmirror2.pending_data(tablename);
CREATE INDEX IF NOT EXISTS idx_pending_keys_tablename ON dbmirror2.pending_keys(tablename);
