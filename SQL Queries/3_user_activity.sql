-- ============================================================
-- 3_user_activity.sql
-- ============================================================
-- Purpose:
-- Analyse overall user activity during the three-month
-- observation period.
--
-- This file examines:
-- 1. Average recorded events per user
-- 2. Daily active users
-- 3. One-time vs repeat users
--
-- Business purpose:
-- Establish the overall level and pattern of user activity
-- before analysing reconstructed sessions, campaign behaviour,
-- and e-commerce activity.
--
-- Important definitions:
-- - An "event" is an individual recorded interaction in the
--   raw event data.
-- - A "daily active user" is a distinct user with at least
--   one recorded event on a given date.
-- - A "one-time user" was observed on one calendar day during
--   the analysis period.
-- - A "repeat user" was observed on two or more calendar days.
--
-- Important limitation:
-- One-time user does NOT mean that the user visited only once.
-- A user may have generated multiple sessions on the same day.
-- It only means the user was observed on one distinct calendar
-- day during the three-month observation period.
-- ============================================================


-- ============================================================
-- 1. Average Events per User
-- ============================================================
-- Purpose:
-- Calculate the average number of recorded events associated
-- with each observed user.
--
-- Analytical use:
-- Provides a high-level measure of recorded activity volume
-- per user.
--
-- Power BI:
-- KPI/card visual.
-- Recommended display: Average Events per User.
-- ============================================================

SELECT
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  ROUND(
    COUNT(*) / COUNT(DISTINCT user_pseudo_id),
    2
  ) AS average_events_per_user
FROM `turing_data_analytics.raw_events`
WHERE user_pseudo_id IS NOT NULL;


-- ============================================================
-- 2. Daily Active Users
-- ============================================================
-- Purpose:
-- Calculate the number of distinct users generating at least
-- one event on each calendar day.
--
-- Analytical use:
-- Shows how website traffic volume changed throughout the
-- three-month observation period.
--
-- Power BI:
-- Line chart.
-- X-axis: event_date
-- Y-axis: active_users
-- Analytical purpose: Identify changes, peaks and lower-activity
-- periods in daily user volume.
--
-- Note:
-- Active users measure traffic volume, not engagement depth.
-- ============================================================

SELECT
  event_date,
  COUNT(DISTINCT user_pseudo_id) AS active_users
FROM `turing_data_analytics.raw_events`
WHERE user_pseudo_id IS NOT NULL
GROUP BY event_date
ORDER BY event_date;


-- ============================================================
-- 3. One-Time vs Repeat Users
-- ============================================================
-- Purpose:
-- Classify users according to the number of distinct calendar
-- days on which they generated events during the analysis
-- period.
--
-- Analytical use:
-- Provides context on whether observed users appeared on one
-- or multiple days during the three-month observation period.
--
-- Power BI:
-- Donut or pie chart.
-- Category: user_type
-- Value: percentage_of_users
-- Analytical purpose: Show the proportion of one-time observed
-- users versus users observed across multiple days.
--
-- Important:
-- This is NOT a retention or loyalty measure.
-- A "one-time user" may have generated multiple sessions on
-- the same day.
-- ============================================================

WITH user_activity AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT event_date) AS active_days
  FROM `turing_data_analytics.raw_events`
  WHERE user_pseudo_id IS NOT NULL
  GROUP BY user_pseudo_id
)

SELECT
  CASE
    WHEN active_days = 1 THEN 'One-time user'
    WHEN active_days > 1 THEN 'Repeat user'
  END AS user_type,
  COUNT(*) AS user_count,
  ROUND(
    COUNT(*) / SUM(COUNT(*)) OVER () * 100,
    2
  ) AS percentage_of_users
FROM user_activity
GROUP BY user_type
ORDER BY
  CASE user_type
    WHEN 'One-time user' THEN 1
    WHEN 'Repeat user' THEN 2
  END;
