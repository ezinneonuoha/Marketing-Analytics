-- ============================================================
-- 4_session_behaviour.sql
-- ============================================================
-- Purpose:
-- Analyse the behaviour and structure of reconstructed sessions.
--
-- This file examines:
-- 1. Number of reconstructed sessions per user
-- 2. Average observed session duration
-- 3. Average recorded events per session
-- 4. Distribution of recorded activity within sessions
--
-- Session methodology:
-- - Sessions are reconstructed using a 30-minute inactivity
--   threshold.
-- - A new session begins when the gap between consecutive
--   events for the same user is greater than 30 minutes.
-- - Session duration is calculated as the time between the
--   first and last recorded event.
--
-- Important interpretation:
-- Session duration represents observed time between recorded
-- events. It should not be interpreted as continuous active
-- browsing time.
-- ============================================================


-- ============================================================
-- 1. Sessions per User
-- ============================================================
-- Purpose:
-- Determine how many reconstructed sessions each user generated
-- during the analysis period.
--
-- Analytical use:
-- Shows whether users typically generated one session or
-- returned for multiple reconstructed sessions.
--
-- Power BI:
-- Horizontal bar chart.
-- X-axis: percentage_of_users
-- Y-axis: session_frequency
-- Analytical purpose: Show the distribution of reconstructed
-- session frequency across users.
--
-- Important:
-- This is different from the one-time vs repeat user analysis.
-- The earlier analysis classified users by the number of
-- calendar days on which they were active. This analysis counts
-- reconstructed sessions, including multiple sessions occurring
-- on the same day.
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
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

user_sessions AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT session_number) AS session_count_per_user
  FROM sessionized_events
  GROUP BY user_pseudo_id
)

SELECT
  CASE
    WHEN session_count_per_user = 1 THEN '1 session'
    WHEN session_count_per_user = 2 THEN '2 sessions'
    WHEN session_count_per_user = 3 THEN '3 sessions'
    WHEN session_count_per_user = 4 THEN '4 sessions'
    WHEN session_count_per_user BETWEEN 5 AND 10 THEN '5–10 sessions'
    WHEN session_count_per_user BETWEEN 11 AND 20 THEN '11–20 sessions'
    WHEN session_count_per_user BETWEEN 21 AND 50 THEN '21–50 sessions'
    ELSE '51+ sessions'
  END AS session_frequency,

  COUNT(*) AS user_count,

  ROUND(
    COUNT(*) / SUM(COUNT(*)) OVER () * 100,
    2
  ) AS percentage_of_users

FROM user_sessions

GROUP BY session_frequency

ORDER BY
  CASE session_frequency
    WHEN '1 session' THEN 1
    WHEN '2 sessions' THEN 2
    WHEN '3 sessions' THEN 3
    WHEN '4 sessions' THEN 4
    WHEN '5–10 sessions' THEN 5
    WHEN '11–20 sessions' THEN 6
    WHEN '21–50 sessions' THEN 7
    WHEN '51+ sessions' THEN 8
  END;


-- ============================================================
-- 2. Average Observed Session Duration
-- ============================================================
-- Purpose:
-- Calculate the average duration of reconstructed sessions.
--
-- Analytical use:
-- Provides an overall measure of observed session duration.
--
-- Power BI:
-- KPI/card visual.
-- Recommended display: Average Session Duration.
--
-- Important:
-- Session duration is strongly right-skewed. Therefore, the
-- average should not be interpreted as the duration of a
-- typical session. The median is examined separately.
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
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

sessions AS (
  SELECT
    user_pseudo_id,
    session_number,
    MIN(event_timestamp) AS session_start,
    MAX(event_timestamp) AS session_end
  FROM sessionized_events
  GROUP BY user_pseudo_id, session_number
),

session_durations AS (
  SELECT
    user_pseudo_id,
    session_number,
    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(session_end),
      TIMESTAMP_MICROS(session_start),
      SECOND
    ) AS session_duration_seconds
  FROM sessions
)

SELECT
  COUNT(*) AS total_sessions,
  ROUND(AVG(session_duration_seconds), 2)
    AS average_session_duration_seconds,
  ROUND(AVG(session_duration_seconds) / 60, 2)
    AS average_session_duration_minutes
FROM session_durations;


-- ============================================================
-- 3. Average Recorded Events per Session
-- ============================================================
-- Purpose:
-- Calculate the average number of recorded events contained
-- within each reconstructed session.
--
-- Analytical use:
-- Measures the amount of recorded activity generated within
-- a typical reconstructed session.
--
-- Power BI:
-- KPI/card visual.
-- Recommended display: Average Recorded Events per Session.
--
-- Important:
-- Event count is a measure of recorded activity, not a direct
-- measure of meaningful user engagement. The dataset contains
-- different event types, including automated or passive events.
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
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
)

SELECT
  COUNT(*) AS total_events,
  COUNT(DISTINCT CONCAT(
    user_pseudo_id,
    '-',
    CAST(session_number AS STRING)
  )) AS total_sessions,
  ROUND(
    COUNT(*) / COUNT(DISTINCT CONCAT(
      user_pseudo_id,
      '-',
      CAST(session_number AS STRING)
    )),
    2
  ) AS average_events_per_session
FROM sessionized_events;


-- ============================================================
-- 4. Recorded Activity per Reconstructed Session
-- ============================================================
-- Purpose:
-- Examine how many recorded events occurred within each
-- reconstructed session.
--
-- Analytical use:
-- Shows the distribution of recorded activity across sessions
-- rather than only reporting the overall average.
--
-- Power BI:
-- Horizontal bar chart.
-- X-axis: percentage_of_sessions
-- Y-axis: activity_level
-- Analytical purpose: Show whether sessions tend to contain
-- very few or multiple recorded events.
--
-- Key finding from this analysis:
-- Most reconstructed sessions contained at least three recorded
-- events, while a smaller proportion contained 11 or more.
--
-- Important:
-- "Recorded activity" is used instead of "engagement" because
-- event volume alone does not establish the quality or meaning
-- of the interaction.
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    LAG(event_timestamp) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY event_timestamp
    ) AS previous_event_timestamp
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` 
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

session_activity AS (
  SELECT
    user_pseudo_id,
    session_number,
    COUNT(*) AS events_per_session
  FROM sessionized_events
  GROUP BY user_pseudo_id, session_number
)

SELECT
  CASE
    WHEN events_per_session = 1 THEN '1 event'
    WHEN events_per_session = 2 THEN '2 events'
    WHEN events_per_session BETWEEN 3 AND 5 THEN '3–5 events'
    WHEN events_per_session BETWEEN 6 AND 10 THEN '6–10 events'
    WHEN events_per_session BETWEEN 11 AND 20 THEN '11–20 events'
    WHEN events_per_session BETWEEN 21 AND 50 THEN '21–50 events'
    ELSE '51+ events'
  END AS activity_level,

  COUNT(*) AS session_count,

  ROUND(
    COUNT(*) / SUM(COUNT(*)) OVER () * 100,
    2
  ) AS percentage_of_sessions

FROM session_activity

GROUP BY activity_level

ORDER BY
  CASE activity_level
    WHEN '1 event' THEN 1
    WHEN '2 events' THEN 2
    WHEN '3–5 events' THEN 3
    WHEN '6–10 events' THEN 4
    WHEN '11–20 events' THEN 5
    WHEN '21–50 events' THEN 6
    WHEN '51+ events' THEN 7
  END;
