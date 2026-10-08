# Marketing Analytics: User Behaviour, Campaigns & E-commerce Activity

## Project Overview

This project analyses user behaviour on an e-commerce website between **1 November 2020 and 31 January 2021**.

The analysis was designed to answer two main business questions:

1. **When do users spend more time on the website?**
2. **Does this pattern change depending on the marketing campaign through which they arrived?**

The analysis also explores how user activity relates to e-commerce behaviour and purchasing.

---

## Business Questions

The project focuses on:

- How user activity varies over time
- How website sessions can be reconstructed from raw event data
- How session duration varies across weekdays
- Whether weekday behaviour differs across campaign groups
- How campaign groups differ in recorded activity and purchasing behaviour
- Whether observed session duration is associated with purchase conversion

---

## Dataset

The dataset contains approximately:

- **4.3 million recorded events**
- **270,000 unique users**
- **355,600 reconstructed sessions**
- Analysis period: **1 November 2020 – 31 January 2021**

The dataset includes information about:

- User activity
- Event types
- Campaigns
- Traffic sources
- Devices and platforms
- Product interactions
- Checkout activity
- Purchases
- Purchase revenue

The analysis was conducted using the BigQuery table:

`turing_data_analytics.raw_events`

---

## Methodology

### 1. Session Reconstruction

The raw dataset records individual events rather than complete website visits.

To analyse session-level behaviour, sessions were reconstructed using a **30-minute inactivity threshold**.

A new session was created when:

> The gap between consecutive events for the same user was greater than 30 minutes.

This produced approximately **355,600 reconstructed sessions**.

Session duration was calculated as:

> Last recorded event timestamp − first recorded event timestamp

Therefore, session duration represents **observed session duration**, rather than continuous active browsing time.

---

### 2. Campaign Attribution

Campaign information was not consistently present for every event.

For sessions containing campaign information, the session was attributed to the **first non-null campaign recorded chronologically within the session**.

Sessions without recorded campaign information were classified as:

**No Recorded Campaign**

This approach provided a consistent attribution rule while retaining campaign information when it appeared shortly after the beginning of a session.

However, approximately **15% of reconstructed sessions contained multiple campaign values**, so the first recorded campaign does not necessarily represent every campaign exposure within a session.

---

### 3. E-commerce Analysis

The analysis examined the following key e-commerce events:

- Product view
- Add to cart
- Checkout
- Purchase

For the session-level funnel, events were required to occur in chronological order within the same reconstructed session.

---

### 4. Session Duration Analysis

Because session duration was strongly right-skewed, both mean and median measures were considered.

The median was given greater emphasis when describing typical session behaviour because a relatively small number of very long sessions substantially increased the mean.

---

## Key Findings

### Weekday Session Behaviour

Users generally had **slightly longer observed sessions during weekdays**, particularly Tuesday to Thursday, than during the weekend.

The overall differences were modest, but the weekday pattern became more noticeable when sessions were broken down by campaign.

### Campaign Differences

The weekday pattern varied across campaign groups.

For example, **Referral** showed the clearest weekday variation, with median observed session duration increasing from approximately **36 seconds on Sunday to 54 seconds on Wednesday**, before decreasing again towards the weekend.

Organic showed a similar but smaller pattern, while Direct and Other were comparatively stable.

### Campaign Activity

Campaign groups also differed in their level of recorded activity.

For example:

- Organic had the largest number of reconstructed sessions.
- Referral averaged approximately **17 recorded events per session**.
- Organic averaged approximately **14 recorded events per session**.
- Direct averaged approximately **13 recorded events per session**.

These figures describe recorded activity within reconstructed sessions and should not be interpreted automatically as meaningful engagement.

### Purchasing Behaviour

Observed session duration was strongly associated with purchasing behaviour.

Purchase conversion increased as observed session duration increased:

| Observed Session Duration | Purchase Conversion |
|---|---:|
| 0–30 sec | ~0% |
| 31–60 sec | ~0% |
| 1–5 min | 0.57% |
| 5–10 min | 4.29% |
| 10–30 min | 7.56% |
| 30+ min | 16.84% |

Purchasing sessions also had substantially longer observed durations than non-purchasing sessions.

The median observed duration was approximately:

- **18.7 minutes** for purchasing sessions
- **13 seconds** for non-purchasing sessions

This represents an association rather than evidence that spending more time on the website causes a purchase.

---

## Dashboard

### Weekday Session Duration & Campaign Patterns

The primary dashboard focuses on the main business question: **when users spend more time on the website and whether the pattern changes across campaign groups.**

<img width="616" height="256" alt="image" src="https://github.com/user-attachments/assets/56194001-9e40-4c4a-aa6e-3ef4ca45bc00" />


### Campaign Behaviour

The campaign performance dashboard examines campaign-associated sessions, recorded activity, users, session behaviour and purchase conversion.

<img width="603" height="341" alt="image" src="https://github.com/user-attachments/assets/32b54743-1c5d-4dc8-839e-cc67ab5895a3" />


---

## Main Business Takeaways

1. Users generally had slightly longer observed sessions during weekdays, particularly Tuesday to Thursday, than during the weekend.
2. The weekday pattern varied by campaign, with Referral showing the clearest variation.
3. Observed session duration was strongly associated with purchasing behaviour.
4. Campaign groups differed substantially in their recorded activity and purchase conversion.
5. Campaign performance should be interpreted alongside campaign volume and attribution limitations.

---

## Limitations

### Session Duration

Session duration was strongly right-skewed. A relatively small number of long sessions increased the mean substantially.

### Campaign Attribution

Campaign information was incomplete for some sessions, while some sessions contained multiple campaign values.

### Small Campaign Samples

Several named promotional campaigns had very small numbers of reconstructed sessions. Their conversion rates can therefore be unstable and should not be treated as directly comparable to the larger campaign groups.

### Observational Analysis

The analysis identifies associations and behavioural patterns. It does not establish that a particular campaign or longer session duration caused a particular outcome.

---

## Further Analysis

### 1. Investigate the relationship between session duration and purchasing

The analysis identified a strong association between observed session duration and purchase conversion. Further analysis could examine the sequence and timing of events to determine whether longer sessions tend to occur before purchases, after purchases, or both.

This could provide a clearer understanding of the relationship between session behaviour and purchasing activity without assuming a causal relationship.

### 2. Test the sensitivity of the session definition

Sessions were reconstructed using a 30-minute inactivity threshold. This is an analytical assumption.

Repeating the analysis using alternative thresholds could determine whether the main findings remain consistent under different session definitions.

This would provide a sensitivity check for the sessionisation methodology.

### 3. Analyse the customer journey across sessions

The current e-commerce funnel analyses events occurring in chronological order within the same reconstructed session.

However, users may interact with the website across multiple sessions before completing a purchase. A user-level journey analysis could therefore examine sequences such as:

`Product View → Return Visit → Add to Cart → Checkout → Purchase`

across multiple sessions.

This would provide a more complete view of the customer journey than the current session-level funnel.
---

## Tools & Technologies

- **SQL**
- **Google BigQuery**
- **Power BI**
- **Google Sheets**
- **GitHub**

### SQL Techniques

The project used:

- Common Table Expressions (CTEs)
- Window functions
- `LAG()`
- `SUM() OVER()`
- `TIMESTAMP_DIFF()`
- Conditional aggregation
- `COUNTIF()`
- `APPROX_QUANTILES()`
- Session reconstruction
- Campaign attribution
- E-commerce funnel analysis

---

## Project Structure

```text
marketing-analytics/
│
├── README.md
│
├── sql/
│   ├── diagnostics.sql
│   ├── session_reconstruction.sql
│   ├── session_behaviour.sql
│   ├── ecommerce_funnel.sql
│   ├── campaign_coverage.sql
│   ├── campaign_performance.sql
│   ├── weekday_duration.sql
│   └── purchase_behaviour.sql
│
├── dashboards/
│   ├── time-patterns-dashboard.png
│   └── campaign-behaviour-dashboard.png
│
└── presentation/
    └── marketing-analytics-presentation.pdf
