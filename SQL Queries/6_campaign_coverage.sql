-- ============================================================
-- 5_ecommerce_funnel.sql
-- ============================================================
-- Purpose:
-- Analyse e-commerce activity and the progression of users
-- through the product-view, add-to-cart, checkout and purchase
-- stages.
--
-- This file contains two levels of analysis:
--
-- 1. Raw event/user metrics
--    - Product views
--    - Add-to-cart activity
--    - Checkout starts
--    - Purchases
--
-- 2. Session-based e-commerce funnel
--    - Product view
--    - Product view → Add to cart
--    - Product view → Add to cart → Checkout
--    - Product view → Add to cart → Checkout → Purchase
--
-- Important:
-- Raw event counts measure recorded event volume, while the
-- funnel measures reconstructed sessions progressing through
-- the e-commerce journey.
--
-- Session methodology:
-- - Sessions are reconstructed using a 30-minute inactivity
--   threshold.
-- - Funnel stages must occur chronologically within the same
--   reconstructed session.
-- ============================================================


-- ============================================================
-- 1. Product View Activity
-- ============================================================
-- Purpose:
-- Count product-view events and the number of distinct users
-- who generated at least one product-view event.
--
-- Analytical use:
-- Establish the volume of product-view activity and the number
-- of users participating in this stage of the e-commerce journey.
--
-- Power BI:
-- KPI/card visual.
-- Recommended metrics:
-- - Product View Events
-- - Users Viewing Products
--
-- Note:
-- Product-view events are not distinct product views. A user
-- may view the same or different products multiple times.
-- ============================================================

SELECT
  COUNT(*) AS product_view_events,
  COUNT(DISTINCT user_pseudo_id) AS users_viewing_products
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name = 'view_item'
  AND user_pseudo_id IS NOT NULL;


-- ============================================================
-- 2. Add-to-Cart Activity
-- ============================================================
-- Purpose:
-- Count add-to-cart events and the number of distinct users
-- who generated at least one add-to-cart event.
--
-- Analytical use:
-- Establish the volume of cart activity and the number of
-- users reaching the add-to-cart stage.
--
-- Power BI:
-- KPI/card visual.
-- Recommended metrics:
-- - Add-to-Cart Events
-- - Users Adding to Cart
--
-- Note:
-- Event count is not the number of unique products added to cart.
-- A user may generate multiple add-to-cart events.
-- ============================================================

SELECT
  COUNT(*) AS add_to_cart_events,
  COUNT(DISTINCT user_pseudo_id) AS users_adding_to_cart
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name = 'add_to_cart'
  AND user_pseudo_id IS NOT NULL;


-- ============================================================
-- 3. Checkout Activity
-- ============================================================
-- Purpose:
-- Count checkout-start events and the number of distinct users
-- who generated at least one checkout-start event.
--
-- Analytical use:
-- Establish the volume of users reaching the checkout stage.
--
-- Power BI:
-- KPI/card visual.
-- Recommended metrics:
-- - Checkout Start Events
-- - Users Starting Checkout
-- ============================================================

SELECT
  COUNT(*) AS checkout_start_events,
  COUNT(DISTINCT user_pseudo_id) AS users_starting_checkout
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name = 'begin_checkout'
  AND user_pseudo_id IS NOT NULL;


-- ============================================================
-- 4. Purchase Activity
-- ============================================================
-- Purpose:
-- Count purchase events and the number of distinct users who
-- generated at least one purchase event.
--
-- Analytical use:
-- Establish the recorded purchase volume and number of
-- purchasing users.
--
-- Power BI:
-- KPI/card visual.
-- Recommended metrics:
-- - Purchase Events
-- - Purchasing Users
--
-- Important:
-- Purchase events, purchasing users and purchase sessions are
-- different measures and should not be treated as interchangeable.
-- ============================================================

SELECT
  COUNT(*) AS purchase_events,
  COUNT(DISTINCT user_pseudo_id) AS purchasing_users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE event_name = 'purchase'
  AND user_pseudo_id IS NOT NULL;


-- ============================================================
-- 5. Session-Based E-commerce Funnel
-- ============================================================
-- Purpose:
-- Analyse progression through the e-commerce journey within
-- reconstructed sessions.
--
-- Funnel stages:
-- Product view
--       ↓
-- Add to cart
--       ↓
-- Checkout
--       ↓
-- Purchase
--
-- Analytical use:
-- Determine how many reconstructed sessions progressed through
-- each stage in chronological order.
--
-- Power BI:
-- Funnel chart.
--
-- Recommended visual:
-- E-commerce Journey Across Reconstructed Sessions
--
-- Funnel stages:
-- - Product View
-- - Add to Cart
-- - Checkout
-- - Purchase
--
-- Important:
-- This is a SESSION-BASED funnel, not a user-based funnel.
-- The same user may contribute multiple sessions.
--
-- Chronological requirement:
-- Each stage must occur after the preceding stage within the
-- same reconstructed session. Strict ">" comparisons are used
-- so that events with exactly identical timestamps are not
-- assigned an artificial order.
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

session_events AS (
  SELECT
    user_pseudo_id,
    session_number,

    ARRAY_AGG(
      IF(event_name = 'view_item', event_timestamp, NULL)
      IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_product_view,

    ARRAY_AGG(
      IF(event_name = 'add_to_cart', event_timestamp, NULL)
      IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_add_to_cart,

    ARRAY_AGG(
      IF(event_name = 'begin_checkout', event_timestamp, NULL)
      IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_checkout,

    ARRAY_AGG(
      IF(event_name = 'purchase', event_timestamp, NULL)
      IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_purchase

  FROM sessionized_events
  GROUP BY user_pseudo_id, session_number
),

funnel AS (
  SELECT
    *,

    -- Product view → Add to cart
    CASE
      WHEN first_product_view IS NOT NULL
       AND first_add_to_cart IS NOT NULL
       AND first_add_to_cart > first_product_view
      THEN 1
      ELSE 0
    END AS view_to_cart,

    -- Product view → Add to cart → Checkout
    CASE
      WHEN first_product_view IS NOT NULL
       AND first_add_to_cart IS NOT NULL
       AND first_checkout IS NOT NULL
       AND first_add_to_cart > first_product_view
       AND first_checkout > first_add_to_cart
      THEN 1
      ELSE 0
    END AS view_to_checkout,

    -- Product view → Add to cart → Checkout → Purchase
    CASE
      WHEN first_product_view IS NOT NULL
       AND first_add_to_cart IS NOT NULL
       AND first_checkout IS NOT NULL
       AND first_purchase IS NOT NULL
       AND first_add_to_cart > first_product_view
       AND first_checkout > first_add_to_cart
       AND first_purchase > first_checkout
      THEN 1
      ELSE 0
    END AS completed_funnel

  FROM session_events
)

SELECT
  COUNTIF(first_product_view IS NOT NULL) AS product_view_sessions,

  SUM(view_to_cart) AS add_to_cart_sessions,

  SUM(view_to_checkout) AS checkout_sessions,

  SUM(completed_funnel) AS purchase_sessions,

  ROUND(
    SAFE_DIVIDE(
      SUM(view_to_cart),
      COUNTIF(first_product_view IS NOT NULL)
    ) * 100,
    2
  ) AS view_to_cart_rate,

  ROUND(
    SAFE_DIVIDE(
      SUM(view_to_checkout),
      SUM(view_to_cart)
    ) * 100,
    2
  ) AS cart_to_checkout_rate,

  ROUND(
    SAFE_DIVIDE(
      SUM(completed_funnel),
      SUM(view_to_checkout)
    ) * 100,
    2
  ) AS checkout_to_purchase_rate,

  ROUND(
    SAFE_DIVIDE(
      SUM(completed_funnel),
      COUNTIF(first_product_view IS NOT NULL)
    ) * 100,
    2
  ) AS view_to_purchase_rate

FROM funnel;
