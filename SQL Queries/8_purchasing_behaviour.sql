-- ============================================================
-- 8_purchase_behaviour.sql
-- ============================================================
-- PURPOSE:
-- Examine the relationship between observed session duration
-- and purchasing behaviour.
--
-- BUSINESS QUESTIONS:
-- 1. How does purchase conversion vary across different
--    observed session-duration bands?
-- 2. How does observed session duration differ between
--    purchasing and non-purchasing sessions?
--
-- METHODOLOGY:
-- Sessions are reconstructed using a 30-minute inactivity
-- threshold.
--
-- Observed session duration is calculated as the difference
-- between the first and last recorded event within a
-- reconstructed session.
--
-- IMPORTANT:
-- Session duration represents observed activity between the
-- first and last recorded event. It should not be interpreted
-- as continuous active browsing time.
--
-- The duration bands are analytical groupings chosen to make
-- the strongly right-skewed session-duration distribution
-- easier to interpret.
--
-- PURCHASE CONVERSION:
-- Purchase sessions / total sessions within each duration band.
--
-- INTERPRETATION:
-- These analyses describe an association between observed
-- session duration and purchasing behaviour. They do not
-- establish that longer sessions cause purchases.
--
-- POWER BI:
-- Query 1:
--   Recommended visual: Column/bar chart
--   Title: Purchase Conversion by Observed Session Duration
--   Purpose: Show how observed purchase conversion varies
--   across duration bands.
--
-- Query 2:
--   Recommended visual: Bar chart or supporting table
--   Title: Observed Session Duration by Purchase Status
--   Purpose: Compare the duration distribution of purchasing
--   and non-purchasing sessions.
--
-- Median duration should receive more emphasis than the mean
-- because session duration is strongly right-skewed.
-- ============================================================


-- ============================================================
-- 1. PURCHASE CONVERSION BY SESSION DURATION
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,

    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp

  FROM `turing_data_analytics.raw_events`

  WHERE user_pseudo_id IS NOT NULL
),

session_flags AS (
  SELECT
    *,
    CASE
      WHEN previous_event_timestamp IS NULL THEN 1

      WHEN TIMESTAMP_DIFF(
        TIMESTAMP_MICROS(event_timestamp),
        TIMESTAMP_MICROS(previous_event_timestamp),
        SECOND
      ) > 1800 THEN 1

      ELSE 0
    END AS new_session

  FROM event_gaps
),

sessionized_events AS (
  SELECT
    *,
    SUM(new_session) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_number

  FROM session_flags
),

session_summary AS (
  SELECT
    user_pseudo_id,
    session_number,

    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(MAX(event_timestamp)),
      TIMESTAMP_MICROS(MIN(event_timestamp)),
      SECOND
    ) AS session_duration_seconds,

    COUNTIF(event_name = 'purchase') AS purchase_events

  FROM sessionized_events

  GROUP BY
    user_pseudo_id,
    session_number
),

duration_bands AS (
  SELECT
    *,
    CASE
      WHEN session_duration_seconds <= 30
        THEN '0–30 sec'

      WHEN session_duration_seconds <= 60
        THEN '31–60 sec'

      WHEN session_duration_seconds <= 300
        THEN '1–5 min'

      WHEN session_duration_seconds <= 600
        THEN '5–10 min'

      WHEN session_duration_seconds <= 1800
        THEN '10–30 min'

      ELSE '30+ min'
    END AS duration_band

  FROM session_summary
)

SELECT
  duration_band,

  COUNT(*) AS sessions,

  COUNTIF(purchase_events > 0) AS purchase_sessions,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(purchase_events > 0),
      COUNT(*)
    ) * 100,
    2
  ) AS purchase_conversion_rate

FROM duration_bands

GROUP BY duration_band

ORDER BY
  CASE duration_band
    WHEN '0–30 sec' THEN 1
    WHEN '31–60 sec' THEN 2
    WHEN '1–5 min' THEN 3
    WHEN '5–10 min' THEN 4
    WHEN '10–30 min' THEN 5
    WHEN '30+ min' THEN 6
  END;


-- ============================================================
-- 2. PURCHASING VS NON-PURCHASING SESSIONS
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,

    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp

  FROM `turing_data_analytics.raw_events`

  WHERE user_pseudo_id IS NOT NULL
),

session_flags AS (
  SELECT
    *,
    CASE
      WHEN previous_event_timestamp IS NULL THEN 1

      WHEN TIMESTAMP_DIFF(
        TIMESTAMP_MICROS(event_timestamp),
        TIMESTAMP_MICROS(previous_event_timestamp),
        SECOND
      ) > 1800 THEN 1

      ELSE 0
    END AS new_session

  FROM event_gaps
),

sessionized_events AS (
  SELECT
    *,
    SUM(new_session) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_number

  FROM session_flags
),

session_summary AS (
  SELECT
    user_pseudo_id,
    session_number,

    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(MAX(event_timestamp)),
      TIMESTAMP_MICROS(MIN(event_timestamp)),
      SECOND
    ) AS session_duration_seconds,

    COUNTIF(event_name = 'purchase') AS purchase_events

  FROM sessionized_events

  GROUP BY
    user_pseudo_id,
    session_number
),

purchase_status AS (
  SELECT
    *,
    CASE
      WHEN purchase_events > 0
        THEN 'Purchasing session'
      ELSE 'Non-purchasing session'
    END AS purchase_status

  FROM session_summary
)

SELECT
  purchase_status,

  COUNT(*) AS sessions,

  ROUND(
    AVG(session_duration_seconds),
    2
  ) AS average_duration_seconds,

  APPROX_QUANTILES(
    session_duration_seconds,
    100
  )[OFFSET(50)] AS median_duration_seconds,

  APPROX_QUANTILES(
    session_duration_seconds,
    100
  )[OFFSET(75)] AS p75_duration_seconds,

  APPROX_QUANTILES(
    session_duration_seconds,
    100
  )[OFFSET(90)] AS p90_duration_seconds

FROM purchase_status

GROUP BY purchase_status

ORDER BY
  CASE purchase_status
    WHEN 'Purchasing session' THEN 1
    WHEN 'Non-purchasing session' THEN 2
  END;
