-- ============================================================
-- SESSION-LEVEL DATASET
-- Purpose:
-- Reconstruct sessions using a 30-minute inactivity threshold
-- and create one row per session with its observed duration.
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
)

SELECT
  user_pseudo_id,
  session_number,

  MIN(event_timestamp) AS session_start,

  MAX(event_timestamp) AS session_end,

  TIMESTAMP_DIFF(
    TIMESTAMP_MICROS(MAX(event_timestamp)),
    TIMESTAMP_MICROS(MIN(event_timestamp)),
    SECOND
  ) AS session_duration_seconds

FROM sessionized_events

GROUP BY
  user_pseudo_id,
  session_number

ORDER BY
  user_pseudo_id,
  session_number;



-- ============================================================
-- SESSION DURATION DISTRIBUTION
-- ============================================================
--Understanding the distribution of durations--

SELECT
  COUNT(*) AS total_sessions,
  COUNTIF(session_duration_seconds = 0) AS zero_second_sessions,
  ROUND(
    COUNTIF(session_duration_seconds = 0) / COUNT(*) * 100,
    2
  ) AS zero_second_percentage,
  ROUND(AVG(session_duration_seconds), 2) AS average_duration_seconds,
  ROUND(APPROX_QUANTILES(session_duration_seconds, 100)[OFFSET(50)], 2) AS median_duration_seconds,
  MAX(session_duration_seconds) AS maximum_duration_seconds
FROM (
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
)

SELECT
  user_pseudo_id,
  session_number,
  MIN(event_timestamp) AS session_start,
  MAX(event_timestamp) AS session_end,

  TIMESTAMP_DIFF(
    TIMESTAMP_MICROS(MAX(event_timestamp)),
    TIMESTAMP_MICROS(MIN(event_timestamp)),
    SECOND
  ) AS session_duration_seconds

FROM sessionized_events

GROUP BY
  user_pseudo_id,
  session_number

ORDER BY
  user_pseudo_id,
  session_number
);
-- Result:
-- 355,592 reconstructed sessions were identified.
-- 55,901 sessions (15.72%) have a duration of 0 seconds.
-- Mean duration = 212.21 seconds (~3.5 minutes).
-- Median duration = 14 seconds.
-- Maximum duration = 18,064 seconds (~5 hours).
--
-- Interpretation:
-- Session duration is strongly right-skewed, with the mean
-- substantially higher than the median. A notable proportion
-- of sessions have only one observed event and therefore a
-- measured duration of 0 seconds.
--
-- Implication:
-- Median duration should be considered alongside the mean
-- when comparing session duration across weekdays and campaigns.
-- Zero-duration sessions should not automatically be removed,
-- because they represent sessions for which observed duration
-- cannot be measured beyond the event timestamp.
