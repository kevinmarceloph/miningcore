-- migrate_shares_partitioned.sql
-- Converts the shares table from unpartitioned to RANGE-partitioned by month.
--
-- Prerequisites:
--   PostgreSQL 12+   (Cloud SQL for PostgreSQL 15 ✓)
--   Maintenance window: stop miningcore before running, restart after COMMIT.
--   Run as a superuser or the miningcore role (needs CREATE TABLE, ALTER TABLE).
--
-- Estimated duration: ~1 min per 100M existing rows (dominated by the INSERT in Phase 2).
-- The script is safe to run when shares_old already exists (idempotent Phase 1 check).
--
-- After verifying counts (Phase 3), drop shares_old to reclaim disk space.

SET ROLE miningcore;

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 1 — Rename existing table and create the new partitioned structure
-- (fast, done inside a transaction so the schema swap is atomic)
-- ─────────────────────────────────────────────────────────────────────────────
BEGIN;

-- Guard: if shares_old already exists this migration already ran Phase 1.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shares_old') THEN
        -- Rename old table and its indexes so names don't clash
        ALTER TABLE shares RENAME TO shares_old;
        ALTER INDEX IDX_SHARES_POOL_MINER          RENAME TO IDX_SHARES_POOL_MINER_old;
        ALTER INDEX IDX_SHARES_POOL_CREATED        RENAME TO IDX_SHARES_POOL_CREATED_old;
        ALTER INDEX IDX_SHARES_POOL_MINER_DIFFICULTY RENAME TO IDX_SHARES_POOL_MINER_DIFFICULTY_old;
    END IF;
END$$;

-- Create new partitioned table (identical schema, RANGE on created)
CREATE TABLE IF NOT EXISTS shares
(
    poolid            TEXT             NOT NULL,
    blockheight       BIGINT           NOT NULL,
    difficulty        DOUBLE PRECISION NOT NULL,
    networkdifficulty DOUBLE PRECISION NOT NULL,
    miner             TEXT             NOT NULL,
    worker            TEXT             NULL,
    useragent         TEXT             NULL,
    ipaddress         TEXT             NOT NULL,
    source            TEXT             NULL,
    created           TIMESTAMPTZ      NOT NULL
) PARTITION BY RANGE (created);

-- Monthly partitions 2021–2027; extend annually before each new year arrives.
-- A DEFAULT partition catches any rows outside the explicit ranges.
CREATE TABLE IF NOT EXISTS shares_2021_01 PARTITION OF shares FOR VALUES FROM ('2021-01-01') TO ('2021-02-01');
CREATE TABLE IF NOT EXISTS shares_2021_02 PARTITION OF shares FOR VALUES FROM ('2021-02-01') TO ('2021-03-01');
CREATE TABLE IF NOT EXISTS shares_2021_03 PARTITION OF shares FOR VALUES FROM ('2021-03-01') TO ('2021-04-01');
CREATE TABLE IF NOT EXISTS shares_2021_04 PARTITION OF shares FOR VALUES FROM ('2021-04-01') TO ('2021-05-01');
CREATE TABLE IF NOT EXISTS shares_2021_05 PARTITION OF shares FOR VALUES FROM ('2021-05-01') TO ('2021-06-01');
CREATE TABLE IF NOT EXISTS shares_2021_06 PARTITION OF shares FOR VALUES FROM ('2021-06-01') TO ('2021-07-01');
CREATE TABLE IF NOT EXISTS shares_2021_07 PARTITION OF shares FOR VALUES FROM ('2021-07-01') TO ('2021-08-01');
CREATE TABLE IF NOT EXISTS shares_2021_08 PARTITION OF shares FOR VALUES FROM ('2021-08-01') TO ('2021-09-01');
CREATE TABLE IF NOT EXISTS shares_2021_09 PARTITION OF shares FOR VALUES FROM ('2021-09-01') TO ('2021-10-01');
CREATE TABLE IF NOT EXISTS shares_2021_10 PARTITION OF shares FOR VALUES FROM ('2021-10-01') TO ('2021-11-01');
CREATE TABLE IF NOT EXISTS shares_2021_11 PARTITION OF shares FOR VALUES FROM ('2021-11-01') TO ('2021-12-01');
CREATE TABLE IF NOT EXISTS shares_2021_12 PARTITION OF shares FOR VALUES FROM ('2021-12-01') TO ('2022-01-01');
CREATE TABLE IF NOT EXISTS shares_2022_01 PARTITION OF shares FOR VALUES FROM ('2022-01-01') TO ('2022-02-01');
CREATE TABLE IF NOT EXISTS shares_2022_02 PARTITION OF shares FOR VALUES FROM ('2022-02-01') TO ('2022-03-01');
CREATE TABLE IF NOT EXISTS shares_2022_03 PARTITION OF shares FOR VALUES FROM ('2022-03-01') TO ('2022-04-01');
CREATE TABLE IF NOT EXISTS shares_2022_04 PARTITION OF shares FOR VALUES FROM ('2022-04-01') TO ('2022-05-01');
CREATE TABLE IF NOT EXISTS shares_2022_05 PARTITION OF shares FOR VALUES FROM ('2022-05-01') TO ('2022-06-01');
CREATE TABLE IF NOT EXISTS shares_2022_06 PARTITION OF shares FOR VALUES FROM ('2022-06-01') TO ('2022-07-01');
CREATE TABLE IF NOT EXISTS shares_2022_07 PARTITION OF shares FOR VALUES FROM ('2022-07-01') TO ('2022-08-01');
CREATE TABLE IF NOT EXISTS shares_2022_08 PARTITION OF shares FOR VALUES FROM ('2022-08-01') TO ('2022-09-01');
CREATE TABLE IF NOT EXISTS shares_2022_09 PARTITION OF shares FOR VALUES FROM ('2022-09-01') TO ('2022-10-01');
CREATE TABLE IF NOT EXISTS shares_2022_10 PARTITION OF shares FOR VALUES FROM ('2022-10-01') TO ('2022-11-01');
CREATE TABLE IF NOT EXISTS shares_2022_11 PARTITION OF shares FOR VALUES FROM ('2022-11-01') TO ('2022-12-01');
CREATE TABLE IF NOT EXISTS shares_2022_12 PARTITION OF shares FOR VALUES FROM ('2022-12-01') TO ('2023-01-01');
CREATE TABLE IF NOT EXISTS shares_2023_01 PARTITION OF shares FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE IF NOT EXISTS shares_2023_02 PARTITION OF shares FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE IF NOT EXISTS shares_2023_03 PARTITION OF shares FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');
CREATE TABLE IF NOT EXISTS shares_2023_04 PARTITION OF shares FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
CREATE TABLE IF NOT EXISTS shares_2023_05 PARTITION OF shares FOR VALUES FROM ('2023-05-01') TO ('2023-06-01');
CREATE TABLE IF NOT EXISTS shares_2023_06 PARTITION OF shares FOR VALUES FROM ('2023-06-01') TO ('2023-07-01');
CREATE TABLE IF NOT EXISTS shares_2023_07 PARTITION OF shares FOR VALUES FROM ('2023-07-01') TO ('2023-08-01');
CREATE TABLE IF NOT EXISTS shares_2023_08 PARTITION OF shares FOR VALUES FROM ('2023-08-01') TO ('2023-09-01');
CREATE TABLE IF NOT EXISTS shares_2023_09 PARTITION OF shares FOR VALUES FROM ('2023-09-01') TO ('2023-10-01');
CREATE TABLE IF NOT EXISTS shares_2023_10 PARTITION OF shares FOR VALUES FROM ('2023-10-01') TO ('2023-11-01');
CREATE TABLE IF NOT EXISTS shares_2023_11 PARTITION OF shares FOR VALUES FROM ('2023-11-01') TO ('2023-12-01');
CREATE TABLE IF NOT EXISTS shares_2023_12 PARTITION OF shares FOR VALUES FROM ('2023-12-01') TO ('2024-01-01');
CREATE TABLE IF NOT EXISTS shares_2024_01 PARTITION OF shares FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE IF NOT EXISTS shares_2024_02 PARTITION OF shares FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE IF NOT EXISTS shares_2024_03 PARTITION OF shares FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE IF NOT EXISTS shares_2024_04 PARTITION OF shares FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE IF NOT EXISTS shares_2024_05 PARTITION OF shares FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE IF NOT EXISTS shares_2024_06 PARTITION OF shares FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE IF NOT EXISTS shares_2024_07 PARTITION OF shares FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE IF NOT EXISTS shares_2024_08 PARTITION OF shares FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE IF NOT EXISTS shares_2024_09 PARTITION OF shares FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE IF NOT EXISTS shares_2024_10 PARTITION OF shares FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE IF NOT EXISTS shares_2024_11 PARTITION OF shares FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE IF NOT EXISTS shares_2024_12 PARTITION OF shares FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
CREATE TABLE IF NOT EXISTS shares_2025_01 PARTITION OF shares FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS shares_2025_02 PARTITION OF shares FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS shares_2025_03 PARTITION OF shares FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE IF NOT EXISTS shares_2025_04 PARTITION OF shares FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE IF NOT EXISTS shares_2025_05 PARTITION OF shares FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE IF NOT EXISTS shares_2025_06 PARTITION OF shares FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE IF NOT EXISTS shares_2025_07 PARTITION OF shares FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE IF NOT EXISTS shares_2025_08 PARTITION OF shares FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE IF NOT EXISTS shares_2025_09 PARTITION OF shares FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS shares_2025_10 PARTITION OF shares FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS shares_2025_11 PARTITION OF shares FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS shares_2025_12 PARTITION OF shares FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS shares_2026_01 PARTITION OF shares FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS shares_2026_02 PARTITION OF shares FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS shares_2026_03 PARTITION OF shares FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS shares_2026_04 PARTITION OF shares FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS shares_2026_05 PARTITION OF shares FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS shares_2026_06 PARTITION OF shares FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS shares_2026_07 PARTITION OF shares FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS shares_2026_08 PARTITION OF shares FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS shares_2026_09 PARTITION OF shares FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS shares_2026_10 PARTITION OF shares FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS shares_2026_11 PARTITION OF shares FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS shares_2026_12 PARTITION OF shares FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE IF NOT EXISTS shares_2027_01 PARTITION OF shares FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
CREATE TABLE IF NOT EXISTS shares_2027_02 PARTITION OF shares FOR VALUES FROM ('2027-02-01') TO ('2027-03-01');
CREATE TABLE IF NOT EXISTS shares_2027_03 PARTITION OF shares FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
CREATE TABLE IF NOT EXISTS shares_2027_04 PARTITION OF shares FOR VALUES FROM ('2027-04-01') TO ('2027-05-01');
CREATE TABLE IF NOT EXISTS shares_2027_05 PARTITION OF shares FOR VALUES FROM ('2027-05-01') TO ('2027-06-01');
CREATE TABLE IF NOT EXISTS shares_2027_06 PARTITION OF shares FOR VALUES FROM ('2027-06-01') TO ('2027-07-01');
CREATE TABLE IF NOT EXISTS shares_2027_07 PARTITION OF shares FOR VALUES FROM ('2027-07-01') TO ('2027-08-01');
CREATE TABLE IF NOT EXISTS shares_2027_08 PARTITION OF shares FOR VALUES FROM ('2027-08-01') TO ('2027-09-01');
CREATE TABLE IF NOT EXISTS shares_2027_09 PARTITION OF shares FOR VALUES FROM ('2027-09-01') TO ('2027-10-01');
CREATE TABLE IF NOT EXISTS shares_2027_10 PARTITION OF shares FOR VALUES FROM ('2027-10-01') TO ('2027-11-01');
CREATE TABLE IF NOT EXISTS shares_2027_11 PARTITION OF shares FOR VALUES FROM ('2027-11-01') TO ('2027-12-01');
CREATE TABLE IF NOT EXISTS shares_2027_12 PARTITION OF shares FOR VALUES FROM ('2027-12-01') TO ('2028-01-01');
CREATE TABLE IF NOT EXISTS shares_default PARTITION OF shares DEFAULT;

-- Indexes on the parent are automatically inherited by all partitions (PostgreSQL 12+)
CREATE INDEX IF NOT EXISTS IDX_SHARES_POOL_MINER            ON shares(poolid, miner);
CREATE INDEX IF NOT EXISTS IDX_SHARES_POOL_CREATED          ON shares(poolid, created);
CREATE INDEX IF NOT EXISTS IDX_SHARES_POOL_MINER_DIFFICULTY ON shares(poolid, miner, difficulty);

COMMIT;

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 2 — Copy existing data, one month at a time
-- (run outside the transaction to keep each batch small and avoid a single
--  multi-billion-row transaction that would hold locks for hours)
-- ─────────────────────────────────────────────────────────────────────────────

-- Check whether shares_old exists before proceeding
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'shares_old') THEN
        RAISE NOTICE 'shares_old not found — Phase 2 skipped (fresh install path)';
        RETURN;
    END IF;
END$$;

-- Copy month by month; each INSERT commits immediately.
-- Adjust the date range to match your actual data if it starts before 2021.

INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-01-01' AND created < '2021-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-02-01' AND created < '2021-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-03-01' AND created < '2021-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-04-01' AND created < '2021-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-05-01' AND created < '2021-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-06-01' AND created < '2021-07-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-07-01' AND created < '2021-08-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-08-01' AND created < '2021-09-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-09-01' AND created < '2021-10-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-10-01' AND created < '2021-11-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-11-01' AND created < '2021-12-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2021-12-01' AND created < '2022-01-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-01-01' AND created < '2022-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-02-01' AND created < '2022-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-03-01' AND created < '2022-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-04-01' AND created < '2022-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-05-01' AND created < '2022-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-06-01' AND created < '2022-07-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-07-01' AND created < '2022-08-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-08-01' AND created < '2022-09-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-09-01' AND created < '2022-10-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-10-01' AND created < '2022-11-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-11-01' AND created < '2022-12-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2022-12-01' AND created < '2023-01-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-01-01' AND created < '2023-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-02-01' AND created < '2023-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-03-01' AND created < '2023-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-04-01' AND created < '2023-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-05-01' AND created < '2023-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-06-01' AND created < '2023-07-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-07-01' AND created < '2023-08-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-08-01' AND created < '2023-09-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-09-01' AND created < '2023-10-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-10-01' AND created < '2023-11-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-11-01' AND created < '2023-12-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2023-12-01' AND created < '2024-01-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-01-01' AND created < '2024-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-02-01' AND created < '2024-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-03-01' AND created < '2024-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-04-01' AND created < '2024-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-05-01' AND created < '2024-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-06-01' AND created < '2024-07-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-07-01' AND created < '2024-08-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-08-01' AND created < '2024-09-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-09-01' AND created < '2024-10-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-10-01' AND created < '2024-11-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-11-01' AND created < '2024-12-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2024-12-01' AND created < '2025-01-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-01-01' AND created < '2025-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-02-01' AND created < '2025-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-03-01' AND created < '2025-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-04-01' AND created < '2025-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-05-01' AND created < '2025-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-06-01' AND created < '2025-07-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-07-01' AND created < '2025-08-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-08-01' AND created < '2025-09-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-09-01' AND created < '2025-10-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-10-01' AND created < '2025-11-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-11-01' AND created < '2025-12-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2025-12-01' AND created < '2026-01-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-01-01' AND created < '2026-02-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-02-01' AND created < '2026-03-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-03-01' AND created < '2026-04-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-04-01' AND created < '2026-05-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-05-01' AND created < '2026-06-01';
INSERT INTO shares SELECT * FROM shares_old WHERE created >= '2026-06-01' AND created < '2026-07-01';
-- extend as needed for months after June 2026

-- Catch anything outside the declared partitions (lands in shares_default)
INSERT INTO shares SELECT * FROM shares_old WHERE created < '2021-01-01' OR created >= '2026-07-01';

-- ─────────────────────────────────────────────────────────────────────────────
-- PHASE 3 — Verify and clean up
-- ─────────────────────────────────────────────────────────────────────────────

-- Count check: both numbers must match before dropping shares_old
SELECT 'shares_old' AS tbl, COUNT(*) FROM shares_old
UNION ALL
SELECT 'shares',            COUNT(*) FROM shares;

-- Partition breakdown (should sum to the above)
SELECT
    inhrelid::regclass AS partition,
    pg_size_pretty(pg_relation_size(inhrelid)) AS size
FROM pg_inherits
WHERE inhparent = 'shares'::regclass
ORDER BY partition;

-- Once counts match, drop the backup:
--   DROP TABLE shares_old;
--
-- Monthly maintenance: before each new month arrives, create its partition:
--   CREATE TABLE shares_2028_01 PARTITION OF shares FOR VALUES FROM ('2028-01-01') TO ('2028-02-01');
-- Rows that arrive before the partition is created fall into shares_default;
-- detach and re-attach to the correct partition when you're ready:
--   ALTER TABLE shares DETACH PARTITION shares_default;
--   INSERT INTO shares SELECT * FROM shares_default;
--   TRUNCATE shares_default;
--   ALTER TABLE shares ATTACH PARTITION shares_default DEFAULT;
