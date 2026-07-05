-- 002_indexes.sql
--
-- Optimizes:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Rationale (see README.md for the full explanation):
--   * city is filtered by equality  -> put it first in the index.
--   * created_at is filtered by range -> put it second, so Postgres can do
--     a single tight index range scan (city = 'x' AND created_at >= ...).
--   * org_id, status, amount are added via INCLUDE so the index itself
--     carries every column the query needs. This allows an index-only
--     scan (no heap fetch per row) once the visibility map is up to date,
--     which matters here because the query aggregates over a GROUP BY
--     rather than returning a handful of rows.

CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Keep the planner's statistics fresh after bulk seeding so it chooses
-- the new index immediately instead of falling back to a sequential scan.
ANALYZE hotel_bookings;
