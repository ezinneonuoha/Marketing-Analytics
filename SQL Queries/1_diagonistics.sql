-- ============================================================
-- 1. USER IDENTIFICATION(Who can we identify?)
-- Purpose: Determine how many identifiable users are available.
-- This is important because sessions will be reconstructed
-- using user_pseudo_id.
-- ============================================================

SELECT
  COUNT(DISTINCT user_pseudo_id) AS unique_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE user_pseudo_id IS NOT NULL;


-- How to read:
-- Shows the number of distinct users with a recorded
-- user_pseudo_id.
--
-- Result:
-- 270,154 unique users were identified.


-- ============================================================
-- 2. USERS ACTIVE ACROSS MULTIPLE DAYS(Do users return?)
-- ============================================================
-- Purpose:
-- Identify users who have activity on more than one day.
-- This helps determine whether users can be treated as sessions.
-- ============================================================

SELECT
  user_pseudo_id,
  COUNT(DISTINCT event_date) AS active_days
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE user_pseudo_id IS NOT NULL
GROUP BY user_pseudo_id
HAVING COUNT(DISTINCT event_date) > 1
ORDER BY active_days DESC;


-- How to read:
-- Shows users with activity on more than one day and the number
-- of distinct days on which each user was active.
--
-- Result:
-- 29,713 users were active on more than one day, with some users
-- active across as many as 12 days. Therefore user does not equal session.

-- Interpretation:
-- Users can return on different days, so sessions must be
-- determined from the timing of events rather than user identity.


-- ============================================================
-- 3. EVENT GAP ANALYSIS'(How do we reconstruct sessions? What do the gaps suggest?)
-- Purpose: Examine the time gaps between consecutive events
-- for each user to determine whether a 30-minute inactivity
-- threshold is a reasonable basis for defining new sessions.
-- ============================================================

WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(event_timestamp),
      TIMESTAMP_MICROS(
        LAG(event_timestamp) OVER (
          PARTITION BY user_pseudo_id
          ORDER BY event_timestamp
        )
      ),
      MINUTE
    ) AS gap_minutes
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE user_pseudo_id IS NOT NULL
)

SELECT
  COUNT(*) AS total_gaps,
  COUNTIF(gap_minutes <= 30) AS gaps_30_min_or_less,
  COUNTIF(gap_minutes > 30) AS gaps_over_30_min,
  ROUND(
    COUNTIF(gap_minutes > 30) / COUNT(*) * 100,
    2
  ) AS percentage_over_30_min
FROM event_gaps
WHERE gap_minutes IS NOT NULL;

-- How to read:
-- This shows how frequently consecutive events are separated
-- by more than 30 minutes.
--
-- Result:
-- 97.88% of gaps were 30 minutes or less, while 2.12% exceeded
-- 30 minutes. This supports using a 30-minute inactivity threshold
-- for session reconstruction.
--
-- Session rule:
-- Gap <= 30 minutes → same session
-- Gap > 30 minutes  → new session


-- ============================================================
-- 4. CAMPAIGN COMPLETENESS
-- Purpose: Determine how frequently campaign information
-- is available before using campaign in the analysis.
-- ============================================================

SELECT
  COUNT(*) AS total_events,
  COUNTIF(campaign IS NULL) AS null_campaign_events,
  COUNTIF(campaign IS NOT NULL) AS non_null_campaign_events,
  ROUND(
    COUNTIF(campaign IS NULL) / COUNT(*) * 100,
    2
  ) AS null_campaign_percentage
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
-- How to read:
-- Shows how often campaign information is recorded in the dataset.
--
-- Result:
-- 66.5% of events have a NULL campaign value, while 33.5%
-- have a recorded campaign value.
--
-- Interpretation:
-- Campaign data is incomplete, so campaign attribution will need
-- to be examined carefully at the session level.


-- ============================================================
-- 5. CAMPAIGN DISTRIBUTION
-- Purpose: To determine how many events associated to one campaign.
-- ============================================================
SELECT
campaign,
COUNT(*) AS event_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE campaign IS NOT NULL 
GROUP BY campaign
ORDER BY event_count DESC;
--How to read:
-- Shows what is actually contained in the campaign variable and
-- how the events are distributed across them.
--
-- Result: 
--The campaign variable contains a mixture of 12 different campaign structure 
-- with a number of events associated with each of them.
--
-- Interpretation:
-- The events are not evenly distributed- about 5 out of 12 campaigns have 
-- the highest numbers. It is worth noting that event counts are not session counts.
-- That is, a campaign with 844,550 events doesn't necessarily have more sessions 
-- than another campaign; users can generate many events within one session. 



-- ============================================================
-- 6. SESSION VALIDATION
-- ============================================================
-- Purpose:
-- Determine how many sessions the 30-minute inactivity model
-- produces and compare this with the recorded session_start events.
-- ============================================================

WITH ordered_events AS (
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
  FROM ordered_events
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

modeled_sessions AS (
  SELECT
    user_pseudo_id,
    session_number
  FROM sessionized_events
  GROUP BY
    user_pseudo_id,
    session_number
)

SELECT
  (SELECT COUNT(*) FROM modeled_sessions) AS modeled_sessions,
  (
    SELECT COUNT(*)
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE event_name = 'session_start'
  ) AS recorded_session_starts,
  (SELECT COUNT(*) FROM modeled_sessions)
    - (
      SELECT COUNT(*)
      FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
      WHERE event_name = 'session_start'
    ) AS difference;
-- How to read:
-- Compares the number of sessions reconstructed using the
-- 30-minute rule with the number of recorded session_start events.
--
-- Result:
-- The 30-minute sessionization produced 355,592 modeled sessions, 
-- compared with 354,970 recorded session_start events. The close 
-- counts provide a useful consistency check, although the absence 
-- of a session identifier means the modeled session boundaries 
-- cannot be independently verified.


-- ============================================================
-- 7. DATE CONSISTENCY
-- ============================================================
-- Purpose:
-- Check whether event_date is consistent with the date derived
-- from event_timestamp before using it for weekday analysis.
-- ============================================================

SELECT
  COUNT(*) AS total_events,
  COUNTIF(
    event_date != FORMAT_DATE(
      '%Y%m%d',
      DATE(TIMESTAMP_MICROS(event_timestamp))
    )
  ) AS date_mismatches
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_timestamp IS NOT NULL;

-- How to read:
-- Compares the recorded event_date with the date derived
-- independently from event_timestamp.
--
-- Result:
-- 4,295,584 events were checked and 0 date mismatches were found.
--
-- Interpretation:
-- event_date is internally consistent with event_timestamp,
-- supporting its use for weekday analysis.
