# Olist DWH & BI Project — Technical Documentation

## 1. Background & Purpose
Building a Data Warehouse on the Olist Brazilian E-Commerce dataset (Kaggle), presented as a Power BI dashboard.
Focus: shipping and delays, sellers, geographic segmentation, customer satisfaction, payment behavior.

## 2. Environment
- Source: `olist_db` (OLTP, loaded from Kaggle CSVs via BULK INSERT)
- Staging: `olist_STG` — clean copy, no business logic
- Target: `olist_DWH` — Fact Constellation (Galaxy Schema)
- SQL Server on a virtual machine (macOS host)
- BI: Power BI Desktop, Import mode

## 3. v1 — The Problem Discovered
The initial model (Star Schema, a single `Fact_Sales` at order-item grain) joined order-level Payment and Review
data onto every item row of the same order via LEFT JOIN. Result: **fan-out** — `SUM(Payment_Value)` inflated,
`AVG(Review_Score)` biased toward orders with many items. In addition, `Dim_Customer` conflated `customer_id`
(order-level) with `customer_unique_id` (person-level), inflating the customer count.
→ Decided to rebuild with a staging layer and the correct grain per table. See `05_analytical_flaws.sql` for
query-level proof of the flaws, and `15_self_review_proofs.sql` for a "before/after" comparison against the
corrected model.

## 4. Final Architecture — Three Layers
`olist_db` (OLTP) → `olist_STG` (clean 1:1 copy, no business logic) → `olist_DWH` (Fact Constellation)

### Fact Constellation vs. Single Star — why not the simpler approach
During the project, an alternative was raised: keep a Single Star (a "B+"-grade design) and fix only the
*measures* (e.g. correct `DISTINCTCOUNT`, correct filters) instead of splitting into three fact tables. This
alternative is **technically valid** — a JOIN between `Dim_Customer` and a single Fact can be a correct
one-to-many if the measures are written correctly. But it is **structurally fragile**: it relies on everyone who
asks a new question about the data "remembering" the right usage conventions (`DISTINCTCOUNT`, not `COUNT`;
correct filtering) — one human mistake (`COUNT` instead of `DISTINCTCOUNT`) silently returns a wrong result with
no warning.

**Decision**: Fact Constellation was chosen because it turns the problem structural rather than conventional — a
wrong grain breaks the JOIN outright or biases the measure, instead of being silently forgotten. This isn't
"more correct" in an absolute sense — it's a different point on the trade-off curve between query simplicity
(favoring Single Star) and structural safety (favoring Constellation). For a learning project meant to
demonstrate understanding of grain issues, the Constellation made the lesson sharper.

## 5. Final Data Model — Fact Constellation

| Dimension | Grain | Role |
|---|---|---|
| `Dim_Customer` | `customer_unique_id` | One real person (96,096 rows; was 99,441 with `customer_id` duplicates) |
| **`Dim_Order`** | `order_id` | Shared anchor for all three Facts. Includes Order_Status, shipping address (merged from the former `Dim_Order_Address` — verified 1:1 between order_id and customer_id). **Does not** contain `Delivery_Delay_Days`/`Actual_Delivery_Days` — moved to `Fact_Order_Items`, see "Delivery Timing duplication fix" below |
| `Dim_Seller` | `seller_id` | Seller (grain already correct at source, 3,095 sellers) |
| `Dim_Product` | `product_id` | Product (grain already correct at source) |
| `Dim_Date` | `Date_Key` | Calendar date |

| Fact | Grain | Measures |
|---|---|---|
| `Fact_Order_Items` | `order_id` + `order_item_id` | Price, Freight_Value, Delivery_Delay_Days, Actual_Delivery_Days |
| `Fact_Payments` | `order_id` + `payment_sequential` | Payment_Value, Payment_Type, Payment_Installments |
| `Fact_Reviews` | `review_id` + `order_id` | Review_Score |

All three Facts connect through `Dim_Order` (Order_Key) and through `Dim_Customer` (Customer_Key).
`Fact_Order_Items` also connects to `Dim_Seller` and `Dim_Product`. Every Fact connects directly to `Dim_Date`.

### Key structural fix: circular relationship
Early on, `Dim_Order` also held `Purchase_Date_Key` (FK to `Dim_Date`). This created a closed triangle:
`Dim_Date ↔ Fact ↔ Dim_Order ↔ Dim_Date`. Power BI does not support two active filter paths between the same two
tables and silently disables one — a risk of silently wrong results with no clear warning.
**Fix**: `Purchase_Date_Key` was removed from `Dim_Order` entirely. Date is always reached through one of the
three Facts, which connect directly to `Dim_Date` with no need for a secondary path through `Dim_Order`.

### Start of Week
An additional Power BI calculated column (not in SQL) on `Dim_Date`: `Start of Week = Dim_Date[Full_Date] -
WEEKDAY(Dim_Date[Full_Date], 2) + 1` — returns the Monday of that week for any date (week starts Monday). Built
for weekly-resolution analysis (e.g. `% Late Orders` / delivery-time trends at a finer grain than month but
smoother than a single day).

### Duplication fix: Delivery Timing (Delivery_Delay_Days / Actual_Delivery_Days)
Early on, these two columns existed **both** in `Dim_Order` **and** in `Fact_Order_Items` — two sources for the
same fact that disagreed on NULL coverage (Fact and Dim showed different NULL counts). **Fix**: removed from
`Dim_Order` entirely; `Fact_Order_Items` (at item grain, matching the actual pipeline) is the single source of
truth. Every measure that previously referenced `Dim_Order[Delivery_Delay_Days]` was updated to point to
`Fact_Order_Items[Delivery_Delay_Days]`.

`Fact_Order_Items` also carries a `Delivered_Date_Key` (FK to `Dim_Date`, populated only for delivered orders)
alongside `Purchase_Date_Key`. It is kept as an inactive relationship in the Power BI model and enabled
per-measure via `USERELATIONSHIP` — this is what allows delivery-date time intelligence (e.g. "delivered in
month X") without recreating the circular-relationship problem described above.

### Delivery_Bucket
A calculated column (Power BI, not SQL) on `Dim_Order`, based on `Actual_Delivery_Days`: buckets 0-3 / 4-7 /
8-14 / 15+ / N/A. The formula uses `CALCULATE(MAX(...))` to collapse from item grain to a single order-level
value before bucketing, avoiding bias. **Known issue, resolved**: at one point duplicate copies of
`Delivery_Bucket`/`Delivery_Bucket_Sort` were accidentally created on `Fact_Order_Items` too (a direct row-level
calculation, without `CALCULATE`) — removed, since the page-2 chart relies on `Dim_Order[Delivery_Bucket]` only,
and a duplicate version risked confusion. There is also `Delivery_Bucket_Sort` (a number column, same
grain) for correct axis ordering, since alphabetical sort would put "0-3" after "15+".
**Verified in practice**: the "Avg Review Score by Delivery_Bucket" chart (page 2) must use
`Avg Review Score (All Statuses)`, **not** the regular `Avg Review Score` (filtered to delivered) — because the
chart's purpose is to compare delivered vs. non-delivered orders (the N/A bucket represents mostly non-delivered
orders). Using the filtered version empties the N/A group and misleads (leaving only a few outlier orders with a
coincidentally high score, not representative of the real trend). This is the one place in the dashboard where
the unfiltered version is used deliberately, contrary to the rest of the dashboard's default convention (see
section 9).

## 6. File Inventory — 15 files, end to end

| # | File | Role |
|---|---|---|
| 01 | `01_create_source_db.sql` | Creates olist_db — raw mirror of the CSV files, no business logic |
| 02 | `02_load_source_data.sql` | BULK INSERT from CSV into olist_db |
| 03 | `03_verify_source_load.sql` | Validation: row counts vs. expected, NULLs in critical keys |
| 04 | `04_constraints_and_indexes.sql` | PK/FK and JOIN-supporting indexes on olist_db |
| 05 | `05_analytical_flaws.sql` | Proof of the 3 flaws that drove the move to Fact Constellation (payment/review fan-out, customer_id ≠ unique_id) |
| 06 | `06_charter.sql` | Project charter — background, goals, architecture, success criteria (documentation only) |
| 07 | `07_galaxy_ddl.sql` | DDL for olist_DWH (Dims + Facts), with IF NOT EXISTS guards |
| 08 | `08_layers_ddl.sql` | DDL for olist_STG |
| 09 | `09_etl_mirror.sql` | Re-runnable procedure for the source layer (`usp_RefreshSourceMirror`) |
| 10 | `10_etl_staging.sql` | Truncate & Load from olist_db into olist_STG |
| 11 | `11_etl_dimensions.sql` | Loads all dimension tables (including a one-time `Dim_Date` build) |
| 12 | `12_etl_fact.sql` | Loads the three fact tables, each at its correct grain |
| 13 | `13_run_and_verify.sql` | Sanity checks: counts, sums, customer count vs. source |
| 14 | `14_demo_scd2_and_incremental.sql` | **Demo only** (SCD Type 2 + incremental load) — not part of the main pipeline |
| 14c | `14_cleanup.sql` | Reverts the changes from file 14 — **must run before final submission** if 14 was executed |
| 15 | `15_self_review_proofs.sql` | "Before/after" proof — compares the old model's wrong result against the corrected olist_DWH |

**Additional supporting files** (created for day-to-day work/research, not part of the numbered pipeline):
`06_independent_research_queries.sql` + `_addendum.sql` (independent research, see section 15),
`Olist_Project_Theme_v2.json` (unified Power BI theme, see section 14 — replaces an earlier version),
`Category_Group.dax` (the full `SWITCH` code splitting categories into rollup groups, see section 12.1),
`Olist_Source_to_Target_Mapping.xlsx` and `Olist_Capstone_Presentation.pptx` (see section 17 for full detail
on both).

**Personal scratch files** (`בדיקות1.sql`, `בדיקות_2.sql` in the working folder) — ad-hoc queries used to check
specific details throughout the project (schema, counts, verifications). Not part of the official pipeline or
the documented QA checks; their reusable content was extracted into the independent-research files above.

## 7. Grain Discoveries & Edge Cases Found Along the Way
- **`review_id` is not unique** — the same review can appear under several different order_ids. True grain:
  `review_id` + `order_id`
- **`customer_id` ≠ `customer_unique_id`** — the former at order level, the latter at person level
- **775 orders with a payment but no line items** (R$162,591.95) — mostly `canceled`/`unavailable` status. Items
  were removed from order_items at the source after a failure/cancellation, but the payment record remained. The
  gap is fully explained: payment-without-items + Items Revenue + Freight ≈ Total Revenue Paid (a negligible
  ~0.02% residual)
- **7 canceled orders with an actual delivery date** — a genuine contradiction in the source, negligible volume,
  not corrected
- **2 payment rows with Installments = 0** on credit card — negligible, not corrected
- **3 payment records with Payment_Type = 'not_defined'** — excluded from the dashboard's payment-type breakdown
  chart (negligible, does not affect Total Payments)
- **Documentation fix in `Fact_Reviews`**: files 05/07/12/13/15 document the grain as "Review_ID" alone — should
  be corrected to "Review_ID + Order_ID" (the original discovery that led to this decision). Verified no actual
  duplicates in the pair (see verification query in section 17).
- **File 14 (SCD Type 2 + incremental load demo) was never run** — remains documentation/demo only, as planned.
  The live olist_DWH schema is clean of anything related to it.

## 8. Critical Modeling Decisions (to prevent incorrect calculations)
- **Gross vs. Net Revenue**: `Gross Revenue` = all Payment_Value, including canceled/unavailable orders.
  `Net Revenue` = filtered to `Order_Status NOT IN ('canceled','unavailable')`. Net is the dashboard default.
- **Avg Review Score — filtered to delivered only**: a dramatic difference in average by status was found
  (delivered = 4.16, other statuses 1.28–2.5). A low score on a non-delivered order reflects frustration at
  never receiving it, not judgment of the product. Default for the satisfaction metric:
  `Order_Status = 'delivered'` only. The Review Score by Delivery_Bucket chart (dashboard page 2) is the visual
  proof of this.
- **Revenue by seller/product**: uses `Price` (from `Fact_Order_Items`, item grain) rather than `Payment_Value`,
  because Payment is computed at the whole-order level and may span multiple sellers/products — there is no
  correct way to split it between Seller/Product.
- **Unbiased Avg Delivery Days**: `Actual_Delivery_Days` sits at item grain (`Fact_Order_Items`), but the measure
  uses `AVERAGEX(SUMMARIZE(Fact_Order_Items, Order_ID), CALCULATE(MAX(Actual_Delivery_Days)))` — collapsing to
  one value per order (MAX returns the same constant value for every item in the order) before averaging across
  orders. This way an order with many items doesn't "weigh" more in the average. `% Late Orders` is safe for the
  same reason: the `Delivery_Delay_Days > 0` filter filters item rows, but the value is constant within each
  order, so there's no bias, and only `DISTINCTCOUNT`/`[Delivered Orders]` count each order once.
  `Delivered Orders` itself:
  `CALCULATE(DISTINCTCOUNT(Fact_Order_Items[Order_ID]), KEEPFILTERS(Dim_Order[Order_Status]="delivered"))`
  — this is also the denominator of `% Late Orders` (Delivered Orders, not Total Orders (Items) — i.e. the
  percentage is computed out of orders that were actually delivered, not out of all orders including
  canceled/unavailable ones for which "late" isn't meaningful).

## 9. Naming Convention
- **"(Paid)"** suffix on a measure/card name = based on `Fact_Payments` (e.g. Net Revenue (Paid),
  Total Orders (Paid))
- **"(Items)"** = based on `Fact_Order_Items`
- **"(Delivered)"** vs. **"(All Statuses)"** = filtered to `Order_Status = 'delivered'` vs. unfiltered
- This convention is kept consistent across every card in the dashboard — it prevents confusion about the
  source/population behind each KPI

### Reconciling the three "revenue" figures — Gross / Net / Paid
Three different dashboard cards show "revenue", with three deliberately different numbers — spelled out
explicitly here so it doesn't look like an inconsistency:

| # | Dashboard name | Page | Source (Fact) | Filter | Formula |
|---|---|---|---|---|---|
| 1 | `Items Revenue (Gross)` | 3 — Sellers & Geography | Fact_Order_Items | None (includes canceled/unavailable) | `SUM(Fact_Order_Items[Price])` |
| 2 | `Items Revenue (Net)` | 1 — Overview | Fact_Order_Items | Excludes canceled/unavailable | `CALCULATE([Items Revenue (Gross)], Order_Status<>"canceled", Order_Status<>"unavailable")` |
| 3 | `Net Revenue (Paid)` | 4 — Payments & Customer Voice | Fact_Payments | Excludes canceled/unavailable | `CALCULATE(SUM(Fact_Payments[Payment_Value]), Order_Status<>"canceled", Order_Status<>"unavailable")` |

**#1 vs. #2** — same table, same column (`Price`), only a different status filter. The small gap between them =
the value of items sold on orders that were ultimately canceled/unavailable.

**#3 vs. #2** — **not** the same measure with a different filter, but an entirely different source:
`Payment_Value` also includes Freight and installment surcharges, not just item price. The gap (#3 − #2) is
close to total Freight.

**Rule of thumb**: "(Gross)" vs. "(Net)" = same source, different filter — close to each other. "(Paid)" vs. any
other name = different source (Fact_Payments includes freight) — a large gap between them is expected and
correct, not a sign of a bug.

## 10. Data Quality Checks
See `13_run_and_verify.sql`. Results:
- Row counts, `Payment_Value` sum, and `Review_Score` average match exactly between STG and Fact (0
  inflation/bias)
- 0 missing FKs in any Fact, across every order status
- 0 duplicates in the grain of any Fact
- 0 negative delivery days
- External validation: States Represented = 27 (matches Brazil's known state count), Seller Count = 3,095
  (matches the known public dataset)

## 11. Analysis Directions & KPIs

| Direction | KPI |
|---|---|
| Shipping | % Late Orders, Avg Delivery Days |
| Shipping → Reviews | Avg Review Score by Delivery_Bucket (0-3 / 4-7 / 8-14 / 15+) |
| Sellers | Top Sellers by Items Revenue |
| Geography | Revenue by State (customer location), bubble map |
| Reviews | Review Score distribution (1-5), Avg Review Score (Delivered vs. All Statuses) |
| Payments | Breakdown by Payment_Type (% of revenue), Avg Installments |
| Revenue | Gross Revenue vs. Net Revenue |

## 12. Dashboard Structure — 5 Pages

| Page | Content | Question it answers |
|---|---|---|
| **1. Overview** | Slicer: `Category_Group`. Cards: `% of Net Revenue`, `Total Orders (Category)`, `Item Revenue (Net)`. "Categories Details" table: Category_Name_English, Items Sold, Items Revenue (Net) — **no** % Late Orders column (moved to page 2, not relevant here). Dual-axis "Item Revenue Over Time" chart: Item Revenue (Net) vs. % Late Orders, monthly resolution | "What's driving revenue, by product category" |
| **2. Where the Time Goes** *(formerly Fulfillment & Delivery)* | Cards: % Late Orders, Avg Delivery Days, Total Orders (Items). Chart: % Late Orders by State (Top 10, full width). New chart: **Handling vs. Transit by Seller State** (stacked bar, Top 10 by Total Orders, sorted by Handling Share) — see section 12.3. **Removed**: Avg Review Score by Delivery_Bucket chart (duplicated on page 5 at higher resolution) | "Not just *that* there's a delay — exactly where the time is lost, and who's responsible (seller vs. carrier)" |
| **3. Sellers & Geography** | Bookmark toggle between a customer view and a seller view — see section 12.4, unchanged from the previous round | "Where and with whom business happens — customers and sellers separately" |
| **4. Payments & Customer Voice** | Cards: Net Revenue (Paid), Avg Installments, **% Multi-Payment Orders** (new). Charts: Revenue Share by Payment_Type (bar), **Overall Satisfaction Distribution** *(formerly "Number of Reviews by Score")* — Review Score distribution 1-5. **Removed**: Avg Review Score card (moved to page 5) | "How did they pay, and what did they say" |
| **5. Delivery Promise & Satisfaction** *(new page)* | Cards: `Points Lost to Lateness`, `Delivered Orders`, `% Late (of Delivered)`. "The Delivery Cliff" chart (scatter, single day on the X axis). "Same Wait, Different Promise" chart (Duration_Band × Promise_Status). "Promise vs. Reality, Weekly" chart (3 series by Start of Week) — see section 12.5 | "What exactly happens between the delivery promise and reality, and what it costs in satisfaction" |

**Custom tooltip pages** (`Customer Map Tooltip`, `Seller Map Tooltip`, `Customer bar chart`, `Sellers Bar
Chart`) — hidden from navigation, used as hover content on page 3 only.

## 12.1 Category Rollups (Category_Group)
`Dim_Product[Category_Name_English]` holds around 70 raw values — too many for a direct chart/slicer. Added
`Category_Group` (Power BI calculated column, explicit `SWITCH`): **8 rollup groups** — Home & Furniture,
Electronics & Appliances, Fashion & Accessories (including cool_stuff/watches_gifts), Health/Beauty & Baby,
Sports/Leisure & Pets, Home Improvement & Auto, Books/Stationery & Art, Food/Industry & Other — plus
`Unclassified` as a fallback for any unmatched category (including the original `Unknown`).

```dax
% of Net Revenue =
DIVIDE(
    [Items Revenue (Net)],
    CALCULATE([Items Revenue (Net)], ALL(Dim_Product))
)
```

**Design decision**: the "Categories Details" table shows Items Sold and Items Revenue (Net) — without % Late
Orders, which moved to page 2 (where it belongs conceptually). Revenue is also shown in the `Item Revenue (Net)`
card, which responds dynamically to the user's selection.

**Why there's no Avg Review Score card on page 1**: review scores aren't uniquely tied to category, and all
satisfaction content is now consolidated on page 5.

## 12.2 New Column: Start of Week (Dim_Date)
A Power BI calculated column: `Start of Week = Dim_Date[Full_Date] - WEEKDAY(Dim_Date[Full_Date], 2) + 1` —
returns the Monday of that week for any date. Built for the "Promise vs. Reality, Weekly" chart on page 5, at a
finer resolution than month but smoother than a single day.

## 12.3 Handling vs. Transit — Page 2
Splits delivery time into two separate stages: **Handling** (from purchase to carrier hand-off — seller's
responsibility) vs. **Transit** (from carrier to customer — carrier's responsibility).

```dax
-- New column on Fact_Order_Items:
Handling Days =
DATEDIFF(Fact_Order_Items[Purchase_Timestamp], Fact_Order_Items[Delivered_Carrier_Date], MINUTE) / 1440.0

-- Measure, unbiased (same technique as Avg Delivery Days):
Avg Handling Days =
AVERAGEX(
    SUMMARIZE(Fact_Order_Items, Fact_Order_Items[Order_ID]),
    CALCULATE(MAX(Fact_Order_Items[Handling Days]))
)
```
Chart: stacked bar, axis = `Dim_Seller[State]` (**not** customer state — Handling responsibility belongs to the
seller), values = `Avg Handling Days` + `Avg Transit Days`. Top 10 by Total Orders, sorted by Handling Share
(`DIVIDE([Avg Handling Days], [Avg Handling Days]+[Avg Transit Days])`) via a helper ranking measure
(`RANKX(ALL(Dim_Seller[State]), ...)` to keep a global Top 10 while the axis is sorted by an internal ratio).

## 12.4 Customer/Seller Toggle (Bookmarks) — Page 3
In the initial version, the single slicer on page 3 ("State") sat on `Dim_Order[State]` — meaning it always
filtered by **customer state**, even when the viewer thought they were filtering by seller location.
**Solution**: the map, slicer, and chart were duplicated into two parallel pairs — one based on `Dim_Order`
(customers), one based on `Dim_Seller` (sellers) — with two buttons that swap the view using **Bookmarks +
Selection pane** ("Selected visuals" only, so as not to reset other slicers on the page). The top cards are
shared between both views.

**Additional display field**: `Dim_Customer[Customer_Label] = "Customer #" & Customer_Key` — parallel to
`City + Seller_Key`, which already exists on `Dim_Seller` (section 14).

### Recurring lesson: the Dynamic Value (NLQ) trap in text-box tooltips
While building the custom tooltips, **two** cases were found where a free-text description ("number of
sellers", "customer id") silently bound to the wrong field/context. **Rule established**: every Dynamic Value
must be typed as the **exact measure/column name**, never a free natural-language description, and the result
must be verified to change between two different points/columns before moving on.

## 12.5 New Page: Delivery Promise & Satisfaction
Built following an external tutorial ("Promise Cliff") that assumed an incorrect schema (columns on `Dim_Order`
that actually live on `Fact_Order_Items`) — fixed using the same "mirror column" technique already developed for
`Delivery_Bucket` (`CALCULATE(MAX(...))` on `Dim_Order` to create a valid "dimension attribute" for drill-across
between the two Facts without a direct join between them).

**New calculated columns on Dim_Order**:
```dax
Delivery_Delay_Days = CALCULATE(MAX(Fact_Order_Items[Delivery_Delay_Days]))
Actual_Delivery_Days = CALCULATE(MAX(Fact_Order_Items[Actual_Delivery_Days]))
Promised_Days = Dim_Order[Actual_Delivery_Days] - Dim_Order[Delivery_Delay_Days]

Duration_Band =
SWITCH(TRUE(),
    ISBLANK(Dim_Order[Actual_Delivery_Days]), BLANK(),
    Dim_Order[Actual_Delivery_Days] <= 4, BLANK(),
    Dim_Order[Actual_Delivery_Days] <= 9, "5-9d",
    Dim_Order[Actual_Delivery_Days] <= 14, "10-14d",
    Dim_Order[Actual_Delivery_Days] <= 19, "15-19d",
    Dim_Order[Actual_Delivery_Days] <= 24, "20-24d",
    Dim_Order[Actual_Delivery_Days] <= 29, "25-29d",
    BLANK())

Duration_Band_Sort =  -- a constant per band (1-5), not the raw days - otherwise Sort by column fails
SWITCH(TRUE(),
    ISBLANK(Dim_Order[Actual_Delivery_Days]), BLANK(),
    Dim_Order[Actual_Delivery_Days] <= 4, BLANK(),
    Dim_Order[Actual_Delivery_Days] <= 9, 1,
    Dim_Order[Actual_Delivery_Days] <= 14, 2,
    Dim_Order[Actual_Delivery_Days] <= 19, 3,
    Dim_Order[Actual_Delivery_Days] <= 24, 4,
    Dim_Order[Actual_Delivery_Days] <= 29, 5,
    BLANK())

Promise_Status = IF(Dim_Order[Delivery_Delay_Days] > 0, "Broken", "Kept")
```

**Measures**:
```dax
Delivered Orders =
CALCULATE(DISTINCTCOUNT(Fact_Order_Items[Order_ID]), KEEPFILTERS(Dim_Order[Order_Status]="delivered"))

Points Lost to Lateness =
CALCULATE([Avg Review Score], KEEPFILTERS(Dim_Order[Delivery_Delay_Days] <= 0))
- CALCULATE([Avg Review Score], KEEPFILTERS(Dim_Order[Delivery_Delay_Days] > 0))
```

**The three charts**:
1. **The Delivery Cliff** — scatter, X = `Delivery_Delay_Days` (don't summarize), Y = `Avg Review Score`,
   Size = `Delivered Orders`, X filtered to ±25 and Delivered Orders ≥ 30
2. **Same Wait, Different Promise** — clustered column, X = `Duration_Band` (sort by `Duration_Band_Sort`),
   Legend = `Promise_Status`, Y = `Avg Review Score`
3. **Promise vs. Reality, Weekly** — line chart, X = `Start of Week`, 3 series: `Avg Promised Days`,
   `Avg Transit Days`, `% Late Orders` (secondary axis)

**Known issue, resolved along the way**: "Sort by column" failed twice on `Duration_Band_Sort` — the first cause
was returning raw days instead of a constant per band (fixed in the formula above); the second cause was Power
BI "remembering" a previously failed sort attempt even after the formula was fixed — resolved by fully deleting
both columns and rebuilding them (`Duration_Band_Sort` before `Duration_Band`), rather than editing the existing
ones.

## 13. Edit Interactions — Preventing Tautological Interactions
On page 2, the interaction between the Review Score by Delivery_Bucket chart and the cards was disabled (Edit
Interactions → None), because clicking a single column would "filter" the card down to that same group and
return a tautological result (the average of a uniform group = that group's own value, not an insight). Rule of
thumb: before enabling an interaction between visuals, check whether the mutual filtering gives real information
or a trivial result.

## 14. Design
- **Theme v2** (`Olist_Project_Theme_v2.json`) — a unified version replacing the initial theme, after
  inconsistency was found between chart styling and cards/slicers (some had been built/styled manually before
  the theme was fully applied). Spec: 13pt visual titles (Arial, bold, white on `#005B99` background), 9pt
  subtitle (gray), dark navy canvas background `#0A2540`, a 2px glowing `#81D9FF` border around every visual,
  rounded corners (radius 14-16), white background inside every visual/card/slicer. Applied via View → Themes →
  Browse for themes — uniformly replacing all manual styling previously done on pages 1-4
- The computed display field `City + Seller_Key` is used as the Y-axis label on the Top Sellers chart (instead
  of the raw Seller_ID, 20+ random characters) — stays uniquely 1:1 with the seller thanks to Seller_Key
  (IDENTITY), but **is not** the seller's real name. The customer-side equivalent —
  `Customer_Label = "Customer #" & Customer_Key` (see section 12.4) — exists because `Dim_Customer` has no fixed
  address to combine the same way

## 15. Independent Research — Findings (not built into the dashboard)
See `06_independent_research_queries.sql` and `_addendum.sql`. Purpose: deeper familiarity with the data beyond
what the dashboard requires.

- **Repeat customers**: 3.12% of customers placed more than one order. Time between first and second order:
  **median 28 days, mean 80 days** — the gap between the two points to a right-skewed distribution (a minority
  of customers with especially long gaps pull the mean up; most repeat customers in practice return within about
  a month)
- **Seller concentration (Pareto)**: the top 20% of sellers (by Items Revenue) account for **82.7%** of total
  revenue — almost exactly matching the classic 80/20 principle
- **Freight as a percentage of price, by category**: categories with cheap/heavy products absorb a
  significantly higher freight-to-price ratio than categories with expensive/light products — a potential
  insight into sales difficulty in certain categories
- **Same State vs. Cross State**: intra-state orders (customer and seller in the same state) show a
  significantly lower average delivery time than cross-state orders
- **Brazilian "Mother's Day" check — tested, not confirmed**: 2018 showed a 57% increase in the two weeks before
  the holiday compared to the rest of the month, but 2017 actually showed a slight decrease over the same
  period. **Methodological conclusion**: a single supporting year isn't enough to establish a consistent finding
  (unlike Black Friday, which showed a sharp, clear spike in the year examined) — the theory was tested and not
  confirmed, and documented as such rather than left as an unverified finding
- **Delay severity vs. Review Score (raised by a mentor's question)**: among orders that **actually ran late**
  (`Delivery_Delay_Days > 0` only), splitting into 4 severity levels shows a sharp score drop between 1-3 delay
  days (3.23) and 8-14 days (1.69), but near-stagnation between 8-14 and 15+ (1.69 → 1.71) — a "frustration
  floor": beyond about two weeks of delay, satisfaction is already at its minimum and doesn't keep falling.
  **Important distinction from the existing dashboard chart** (Avg Review Score by Delivery_Bucket, page 2):
  that chart measures `Actual_Delivery_Days` — **absolute transit time from purchase to arrival**, across all
  orders including ones that arrived earlier than promised. This query measures `Delivery_Delay_Days` —
  **deviation from the promised date only**, and only among orders that actually ran late. An order that took 20
  days but was promised within 30 (early, negative delay) would land in the "15+" bucket on the existing chart
  but wouldn't appear at all in the severity query — this explains why the "15+" bucket on the chart (3.68) is
  significantly higher than the "15+ delay days" group here (1.71): the former is "diluted" by slow-but-on-time
  orders, the latter is fully cleaned of them. Both metrics are valid and complementary — "absolute speed" vs.
  "meeting the promise" — not contradictory.

## 16. Additional Findings from Designing the Overview Page
- **Black Friday identified in the data**: 24/11/2017 shows a sharp spike in daily revenue (R$178,450, about 3x
  the following day) — matching Brazil's official Black Friday date exactly. Confirms the model correctly
  captures real business events, not noise.
- **Display bounds on the Net Revenue Over Time chart**: the chart is shown for the range 01/2017–08/2018 only.
  - Leading edge (09–12/2016) removed: a pilot period with negligible order volume (a handful per day, sometimes
    just 1)
  - Trailing edge (09/2018) removed: the month is partial in the source data (ends mid-month)
  - Both cutoffs are documented openly in a footnote on the page itself, not hidden

## 17. Companion Deliverables (outside the 15 numbered files)
| Deliverable | Content |
|---|---|
| `Olist_Source_to_Target_Mapping.xlsx` | 4 sheets: **(1) Grain** — verified grain and row count per table; **(2) Column Mapping** — 68 rows, every target column with its STG source, transform type, and handling of failed FKs; **(3) Transform Types** — 6 transform types (GENERATED/DIRECT/LOOKUP/DERIVED/DEDUPLICATED/SEED) with counts; **(4) Data Quality Rules** — 10 DQ findings (DQ01–DQ10) with how the model handles each. **Notable findings there not otherwise highlighted here**: Order_Status is not modeled as a separate Dim — every DAX measure hard-codes the strings 'delivered'/'canceled' (a documented trade-off, not an oversight); `Freight_Value` on `Fact_Order_Items` exists but **is not used in any measure** (R$2.25M, about 16.6% of revenue, untouched); DQ10 explicitly documents the Delivery Timing duplication fix (see section 5) |
| `Category_Group.dax` | The full `SWITCH` code splitting the 74 categories into 8 rollup groups (see section 12.1) |
| `Olist_Capstone_Presentation.pptx` | Final presentation deck, 14 slides: opening → 5 business questions → architecture → SQL code (3 layers) → Fact Constellation vs. Star → data quality findings → dashboard pages (with real screenshots) → insights and recommendations → challenges + Q&A |

## 18. Final Status
- [x] STG + DWH v2 (Fact Constellation, no circular relationships) — 15 numbered files, 01–15
- [x] Sanity checks and edge cases completed in full (see section 10)
- [x] Power BI model + DAX measures completed
- [x] Dashboard — **5 pages** (added the "Delivery Promise & Satisfaction" page; page 2 upgraded with a
      Handling/Transit breakdown; page 4 gained % Multi-Payment Orders; page 1 simplified by removing
      % Late Orders from its table)
- [x] Unified Theme v2 — consistent titles/subtitles/glowing borders across all pages (see section 14)
- [x] Independent research — 7 directions investigated, findings documented (section 15)
- [x] Verified: no duplicates in the Review_ID + Order_ID grain
