-- ============================================================
-- 7_campaign_performance.sql
-- ============================================================
-- PURPOSE:
-- Compare user activity and e-commerce behaviour across
-- campaign-attributed sessions.
--
-- BUSINESS QUESTIONS:
-- 1. How much activity is associated with each campaign?
-- 2. How many users and sessions are associated with each
--    campaign?
-- 3. How does recorded activity differ across campaigns?
-- 4. How does purchase conversion differ across campaigns?
--
-- METHODOLOGY:
-- Sessions are reconstructed using a 30-minute inactivity
-- threshold.
--
-- Each session is attributed to the first non-null campaign
-- recorded chronologically within that session.
--
-- Sessions containing no campaign information are classified
-- as "No Recorded Campaign".
--
-- E-COMMERCE METRICS:
-- Product view, add-to-cart, checkout and purchase are measured
-- at the session level.
--
-- PURCHASE CONVERSION:
-- Purchase sessions / campaign-attributed sessions.
--
-- IMPORTANT:
-- Purchase events, purchase sessions and purchasing users are
-- different metrics.
--
-- POWER BI:
-- Recommended visuals:
--
-- 1. Sessions by Campaign
--    Visual: Horizontal bar chart
--    Purpose: Compare campaign-associated session volume.
--
-- 2. Purchase Conversion Rate by Campaign
--    Visual: Horizontal bar chart
--    Purpose: Compare observed purchase conversion across
--    campaign groups.
--
-- 3. Average Recorded Events per Session
--    Visual: Supporting bar chart or table
--    Purpose: Compare recorded activity depth across campaigns.
--
-- Small campaigns should be interpreted cautiously because
-- their rates are based on very small numbers of sessions.
-- ============================================================


WITH event_gaps AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
    campaign,

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

session_campaigns AS (
  SELECT
    user_pseudo_id,
    session_number,

    ARRAY_AGG(
      campaign IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_non_null_campaign

  FROM sessionized_events

  GROUP BY
    user_pseudo_id,
    session_number
),

attributed_events AS (
  SELECT
    e.user_pseudo_id,
    e.session_number,
    e.event_name,

    COALESCE(
      s.first_non_null_campaign,
      'No Recorded Campaign'
    ) AS campaign

  FROM sessionized_events e

  JOIN session_campaigns s
    USING (user_pseudo_id, session_number)
),

session_summary AS (
  SELECT
    campaign,
    user_pseudo_id,
    session_number,

    COUNT(*) AS events_in_session,

    MAX(
      CASE
        WHEN event_name = 'view_item' THEN 1
        ELSE 0
      END
    ) AS product_view,

    MAX(
      CASE
        WHEN event_name = 'add_to_cart' THEN 1
        ELSE 0
      END
    ) AS add_to_cart,

    MAX(
      CASE
        WHEN event_name = 'begin_checkout' THEN 1
        ELSE 0
      END
    ) AS checkout,

    MAX(
      CASE
        WHEN event_name = 'purchase' THEN 1
        ELSE 0
      END
    ) AS purchase,

    COUNTIF(event_name = 'purchase') AS purchase_events

  FROM attributed_events

  GROUP BY
    campaign,
    user_pseudo_id,
    session_number
)

SELECT
  campaign,

  COUNT(*) AS sessions,

  COUNT(DISTINCT user_pseudo_id) AS unique_users,

  SUM(events_in_session) AS total_events,

  ROUND(
    AVG(events_in_session),
    2
  ) AS average_events_per_session,

  SUM(product_view) AS product_view_sessions,

  SUM(add_to_cart) AS add_to_cart_sessions,

  SUM(checkout) AS checkout_sessions,

  SUM(purchase) AS purchase_sessions,

  SUM(purchase_events) AS purchase_events,

  ROUND(
    SAFE_DIVIDE(
      SUM(purchase),
      COUNT(*)
    ) * 100,
    2
  ) AS purchase_conversion_rate

FROM session_summary

GROUP BY campaign

ORDER BY sessions DESC;
