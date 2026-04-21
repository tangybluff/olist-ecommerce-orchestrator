Before starting, make sure `dbt build` has run successfully so the mart tables exist in BigQuery. Then:

---

## Prerequisites

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com) and sign in with the same Google account that has access to your GCP project.
2. Make sure your BigQuery mart tables exist:
   - `olist_analytics_marts.mrt_daily_sales`
   - `olist_analytics_marts.mrt_state_sales`

---

## Step 1 — Create a new report

1. Click **Create → Report**.
2. In the "Add data to report" panel that opens, select **BigQuery**.
3. Authorise Looker Studio to access BigQuery if prompted.

---

## Step 2 — Add the first data source (`mrt_daily_sales`)

1. In the BigQuery connector: select **My Projects → your GCP project → `olist_analytics_marts` → `mrt_daily_sales`**.
2. Click **Add → Add to Report**.

---

## Tile 1 — Daily GMV over Time (temporal distribution)

1. Click **Insert → Time series chart** and draw it on the canvas.
2. In the **Data** panel on the right:
   - **Dimension:** `order_date`
   - **Metric:** `gross_merchandise_value` (rename it to "Gross Merchandise Value (BRL)" by clicking the metric name)
3. Click **+ Add metric** → add `total_orders` as a second metric (it will plot on the right axis).
4. In the **Style** panel:
   - Set line colours to distinguish GMV vs order count clearly.
   - Enable **Data labels** on the peaks if you want callouts.
5. Click the chart title area and set it to: **"Daily Gross Merchandise Value & Order Volume (2016–2018)"**.
6. Add a **Date range control** (Insert → Date range control) and link it to this chart so viewers can filter by period.

---

## Step 3 — Add the second data source (`mrt_state_sales`)

1. Click **Resource → Manage added data sources → Add a data source**.
2. Select **BigQuery → your project → `olist_analytics_marts` → `mrt_state_sales`**.
3. Click **Add → Add to Report**.

---

## Tile 2 — Orders by Brazilian State (categorical distribution)

1. Click **Insert → Bar chart** and draw it on the canvas.
2. In the **Data** panel:
   - **Data source:** `mrt_state_sales`
   - **Dimension:** `customer_state`
   - **Metric:** `total_orders` (rename to "Total Orders")
   - **Sort:** `total_orders` Descending
3. Click **+ Add metric** → add `avg_delivery_days` as a second metric.
4. In the **Style** panel:
   - Set bar colour for `total_orders` (e.g. blue).
   - Enable the **right Y-axis** for `avg_delivery_days` so both metrics are visible without scale clash.
   - Rotate X-axis labels 45° (the state codes are short so this is optional).
5. Set chart title to: **"Order Volume and Average Delivery Days by Brazilian State"**.

---

## Step 4 — Polish and share

1. **Add a report title** at the top: click Insert → Text → type "Olist E-commerce Analytics Dashboard".
2. **Add a subtitle** with the data source note: "Source: Olist Brazilian E-commerce Dataset · Loaded via dlt · Transformed with dbt".
3. **Add a scorecard** (Insert → Scorecard) for a quick headline number — e.g. total GMV from `mrt_daily_sales`, summed across all dates. This makes the report look complete.
4. Click **View** (top right) to preview the finished report.
5. To share: click the **Share** button → "Manage access" → set to "Anyone with the link can view" (or share with specific reviewers).
6. Copy the report URL — paste this into your project README under the Dashboard section.

