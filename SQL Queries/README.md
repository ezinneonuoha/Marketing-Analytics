# SQL Analysis

This folder contains the SQL queries used to analyse user activity, reconstructed sessions, e-commerce behaviour, marketing campaigns, weekday patterns, and purchasing behaviour.

All queries use the `turing_data_analytics.raw_events` table in BigQuery.

The analysis follows a step-by-step approach, beginning with data validation and session reconstruction before moving into user behaviour, e-commerce activity, campaign performance, and the main weekday-duration analysis.

---

## SQL Workflow

The queries are numbered in the order in which the analysis was developed:

| File | Analysis | Main Purpose |
|---|---|---|
| `01_diagnostics.sql` | Data Diagnostics | Validate the dataset, identify missing values, inspect campaigns and event types, and assess sessionisation assumptions |
| `02_session_reconstruction.sql` | Session Reconstruction | Convert individual events into reconstructed user sessions using a 30-minute inactivity threshold |
| `03_user_activity.sql` | User Activity | Analyse users, daily activity, repeat behaviour, and recorded events per user |
| `04_session_behaviour.sql` | Session Behaviour | Analyse sessions per user, observed session duration, events per session, and recorded activity levels |
| `05_ecommerce_funnel.sql` | E-commerce Funnel | Analyse product views, add-to-cart, checkout and purchase behaviour within reconstructed sessions |
| `06_campaign_coverage.sql` | Campaign Coverage | Assess how consistently campaign information is recorded across reconstructed sessions |
| `07_campaign_performance.sql` | Campaign Performance | Compare campaign-associated sessions, users, recorded activity and purchase behaviour |
| `08_weekday_duration.sql` | Weekday Session Duration | Compare observed session duration across weekdays and campaign groups |
| `09_purchase_behaviour.sql` | Purchase Behaviour | Examine the relationship between observed session duration and purchasing behaviour |

---

## 1. Data Diagnostics

**File:** `01_diagnostics.sql`

The diagnostic queries establish the quality and structure of the raw event data before analysis begins.

The queries examine:

- Number of unique users
- Total events
- Event types
- Campaign completeness
- Number of distinct campaigns
- Users active across multiple days
- Gaps between consecutive events
- Date consistency
- Recorded `session_start` events
- Validation of the reconstructed session count
- Campaign changes within user activity

These checks were used to understand the limitations of the dataset and inform the session reconstruction and campaign attribution methodology.

---

## 2. Session Reconstruction

**File:** `02_session_reconstruction.sql`

The raw dataset contains individual events rather than a complete session identifier, so sessions were reconstructed using user activity.

### Session definition

A new session begins when the gap between two consecutive events from the same user is greater than **30 minutes**.

The process:

1. Order events chronologically for each user.
2. Compare each event with the user's previous event.
3. Flag a new session when the gap exceeds 30 minutes.
4. Create a cumulative session number for each user.
5. Aggregate events using `user_pseudo_id` and `session_number`.

The resulting session identifier is effectively:

```text
user_pseudo_id + session_number
