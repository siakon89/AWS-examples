-- Sample Athena Queries for AWS CUR 2.0 Data

-- 1. Total cost by service for the current month
SELECT
    bill_billing_period_start_date AS billing_period,
    line_item_product_code AS service,
    SUM(line_item_unblended_cost) AS total_cost
FROM cur_data
WHERE
    bill_billing_period_start_date = DATE '2025-05-01'
    AND line_item_line_item_type != 'Credit'
    AND line_item_line_item_type != 'Refund'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 10;

-- 2. EC2 instance costs by instance type
SELECT
    bill_billing_period_start_date AS billing_period,
    line_item_usage_type AS usage_type,
    product_instance_type AS instance_type,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    line_item_product_code = 'AmazonEC2' AND
    product_instance_type <> '' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 20;

-- 3. S3 costs by bucket and usage type
SELECT
    line_item_resource_id AS bucket_name,
    line_item_usage_type AS usage_type,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    line_item_product_code = 'AmazonS3' AND
    line_item_resource_id <> '' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;

-- 4. Daily costs for the last 30 days
SELECT
    CAST(line_item_usage_start_date AS DATE) AS usage_date,
    SUM(line_item_unblended_cost) AS daily_cost
FROM cur_data
WHERE
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1
ORDER BY 1 DESC;

-- 5. Costs by region
SELECT
    product_region_code AS region,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1
ORDER BY 2 DESC;

-- 6. Savings from Reserved Instances
SELECT
    bill_billing_period_start_date AS billing_period,
    reservation_reservation_a_r_n AS reservation_arn,
    SUM(reservation_effective_cost) AS effective_cost,
    SUM(reservation_unused_amortized_upfront_fee_for_billing_period) AS unused_upfront_fee,
    SUM(reservation_unused_recurring_fee) AS unused_recurring_fee
FROM cur_data
WHERE
    reservation_reservation_a_r_n <> '' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- 7. Cost by tag (example for 'Environment' tag)
SELECT
    resource_tags['user_creator'] AS environment,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    resource_tags['user_creator'] IS NOT NULL AND
    resource_tags['user_creator'] <> '' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1
ORDER BY 2 DESC;

-- 8. Identify untagged resources
SELECT
    line_item_product_code AS service,
    line_item_resource_id AS resource_id,
    product_region_code AS region,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    CARDINALITY(MAP_KEYS(resource_tags)) = 0 AND
    line_item_resource_id <> '' AND
    line_item_line_item_type = 'Usage' AND
    bill_billing_period_start_date = DATE '2025-05-01'
GROUP BY 1, 2, 3
HAVING SUM(line_item_unblended_cost) > 0
ORDER BY 4 DESC
LIMIT 50;

-- 9. Monthly cost trend for the year
SELECT
    '2025-05' AS current_month,
    '2025-04' AS previous_month,
    SUM(CASE WHEN bill_billing_period_start_date = DATE '2025-05-01' AND line_item_line_item_type NOT IN ('Credit', 'Refund') THEN line_item_unblended_cost ELSE 0 END) AS may_cost,
    SUM(CASE WHEN bill_billing_period_start_date = DATE '2025-04-01' AND line_item_line_item_type NOT IN ('Credit', 'Refund') THEN line_item_unblended_cost ELSE 0 END) AS april_cost,
    SUM(CASE WHEN bill_billing_period_start_date = DATE '2025-05-01' AND line_item_line_item_type NOT IN ('Credit', 'Refund') THEN line_item_unblended_cost ELSE 0 END) - 
    SUM(CASE WHEN bill_billing_period_start_date = DATE '2025-04-01' AND line_item_line_item_type NOT IN ('Credit', 'Refund') THEN line_item_unblended_cost ELSE 0 END) AS cost_difference
FROM cur_data
WHERE
    bill_billing_period_start_date IN (DATE '2025-05-01', DATE '2025-04-01');

-- 10. Identify resources with highest cost increase (Weekly analysis for last 2 weeks)
-- Parameters - change these dates to analyze different weeks
WITH current_week_costs AS (
    SELECT
        line_item_resource_id AS resource_id,
        SUM(line_item_unblended_cost) AS cost
    FROM cur_data
    WHERE
        line_item_usage_start_date BETWEEN DATE('2025-05-12') AND DATE('2025-05-18') AND
        line_item_resource_id <> '' AND
        line_item_line_item_type != 'Credit' AND
        line_item_line_item_type != 'Refund'
    GROUP BY 1
),
prev_week_costs AS (
    SELECT
        line_item_resource_id AS resource_id,
        SUM(line_item_unblended_cost) AS cost
    FROM cur_data
    WHERE
        line_item_usage_start_date BETWEEN DATE('2025-05-05') AND DATE('2025-05-11') AND
        line_item_resource_id <> '' AND
        line_item_line_item_type != 'Credit' AND
        line_item_line_item_type != 'Refund'
    GROUP BY 1
),
resource_details AS (
    SELECT DISTINCT
        line_item_resource_id AS resource_id,
        line_item_product_code AS service,
        product_region_code AS region
    FROM cur_data
    WHERE
        line_item_resource_id <> '' AND
        line_item_usage_start_date BETWEEN DATE('2025-05-05') AND DATE('2025-05-18')
)
SELECT
    r.resource_id,
    r.service,
    r.region,
    -- Week costs
    COALESCE(p.cost, 0) AS prev_week_cost,
    COALESCE(c.cost, 0) AS current_week_cost,
    COALESCE(c.cost, 0) - COALESCE(p.cost, 0) AS week_over_week_change,
    
    -- Percentage change
    CASE 
        WHEN COALESCE(p.cost, 0) > 0 
        THEN ROUND(((COALESCE(c.cost, 0) - COALESCE(p.cost, 0)) / COALESCE(p.cost, 0)) * 100, 2)
        WHEN COALESCE(p.cost, 0) = 0 AND COALESCE(c.cost, 0) > 0
        THEN NULL
        ELSE 0
    END AS percentage_change,
    
    -- Growth classification
    CASE
        WHEN COALESCE(p.cost, 0) = 0 AND COALESCE(c.cost, 0) > 0 
        THEN 'New Resource'
        WHEN COALESCE(c.cost, 0) - COALESCE(p.cost, 0) > 0 
        THEN 'Increasing'
        WHEN COALESCE(c.cost, 0) - COALESCE(p.cost, 0) < 0 
        THEN 'Decreasing'
        ELSE 'Stable'
    END AS cost_trend
FROM resource_details r
LEFT JOIN current_week_costs c ON r.resource_id = c.resource_id
LEFT JOIN prev_week_costs p ON r.resource_id = p.resource_id
WHERE 
    -- Show resources with costs in either week
    COALESCE(c.cost, 0) > 0 OR COALESCE(p.cost, 0) > 0
ORDER BY week_over_week_change DESC
LIMIT 20;

-- 11. Athena usage and cost
SELECT
    CAST(line_item_usage_start_date AS DATE) AS usage_date,
    line_item_operation AS operation,
    line_item_resource_id AS workgroup,
    SUM(line_item_usage_amount) AS data_scanned_bytes,
    SUM(line_item_unblended_cost) AS cost
FROM cur_data
WHERE
    line_item_product_code = 'AmazonAthena' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 5 DESC;

-- 12. Savings Plan utilization
SELECT
    bill_billing_period_start_date AS billing_period,
    savings_plan_savings_plan_a_r_n AS savings_plan_arn,
    SUM(savings_plan_savings_plan_effective_cost) AS savings_plan_cost,
    SUM(savings_plan_total_commitment_to_date) AS commitment,
    SUM(savings_plan_used_commitment) AS used_commitment,
    SUM(savings_plan_savings_plan_rate) AS savings_plan_rate,
    SUM(savings_plan_amortized_upfront_commitment_for_billing_period) AS amortized_upfront
FROM cur_data
WHERE
    savings_plan_savings_plan_a_r_n <> '' AND
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- 13. List all tags with their associated costs and resource counts
WITH flattened_tags AS (
  SELECT
    line_item_resource_id,
    line_item_unblended_cost,
    k AS tag_key,
    resource_tags[k] AS tag_value
  FROM cur_data
  CROSS JOIN UNNEST(MAP_KEYS(resource_tags)) AS t(k)
  WHERE
    bill_billing_period_start_date = DATE '2025-05-01' AND
    line_item_line_item_type != 'Credit' AND
    line_item_line_item_type != 'Refund' AND
    line_item_resource_id <> '' AND
    resource_tags[k] <> ''
)
SELECT
  tag_key,
  tag_value,
  COUNT(DISTINCT line_item_resource_id) AS resource_count,
  SUM(line_item_unblended_cost) AS total_cost
FROM flattened_tags
GROUP BY 1, 2
ORDER BY 1, 4 DESC;

-- 14. Tagged vs. Untagged Resources by Service with Tag Key Analysis
-- Replace 'your_tag_key' with the specific tag key you want to search for (e.g., 'Environment', 'Project', 'Owner')
WITH tag_key_to_search AS (
    SELECT 'user_creator' AS key -- Change this to your desired tag key
),
resource_tagging AS (
    SELECT
        line_item_product_code AS service,
        line_item_resource_id,
        line_item_unblended_cost,
        CASE 
            WHEN CARDINALITY(MAP_KEYS(resource_tags)) > 0 THEN 'Tagged'
            ELSE 'Untagged'
        END AS general_tagging_status,
        CASE
            WHEN resource_tags[(SELECT key FROM tag_key_to_search)] IS NOT NULL 
                 AND resource_tags[(SELECT key FROM tag_key_to_search)] <> '' THEN 'Has Tag Key'
            ELSE 'Missing Tag Key'
        END AS specific_tag_status
    FROM cur_data
    WHERE
        line_item_resource_id <> '' AND
        bill_billing_period_start_date = DATE '2025-05-01' AND
        line_item_line_item_type != 'Credit' AND
        line_item_line_item_type != 'Refund' AND
        line_item_line_item_type = 'Usage'
)
SELECT
    service,
    general_tagging_status,
    specific_tag_status,
    COUNT(DISTINCT line_item_resource_id) AS resource_count,
    SUM(line_item_unblended_cost) AS total_cost
FROM resource_tagging
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT line_item_resource_id) > 0
ORDER BY 1, 2, 3;

-- 15. Tagged vs. Untagged Resource Distribution by Service (Single Line, Taggable Resources Only)
-- Replace 'your_tag_key' with the specific tag key you want to analyze
WITH tag_key_to_search AS (
    SELECT 'user_creator' AS key -- Change this to your desired tag key
),
resource_counts AS (
    SELECT
        line_item_product_code AS service,
        line_item_resource_id AS resource_id,
        MAX(CASE WHEN CARDINALITY(MAP_KEYS(resource_tags)) > 0 THEN 1 ELSE 0 END) AS is_tagged,
        MAX(CASE WHEN resource_tags[(SELECT key FROM tag_key_to_search)] IS NOT NULL 
                 AND resource_tags[(SELECT key FROM tag_key_to_search)] <> '' 
                 THEN 1 ELSE 0 END) AS has_specific_tag,
        SUM(line_item_unblended_cost) AS resource_cost
    FROM cur_data
    WHERE
        line_item_resource_id <> '' AND
        bill_billing_period_start_date = DATE '2025-05-01' AND
        line_item_line_item_type != 'Credit' AND
        line_item_line_item_type != 'Refund' AND
        line_item_line_item_type = 'Usage' AND
        line_item_resource_id NOT LIKE '%management%' AND
        line_item_resource_id NOT LIKE '%overhead%'
    GROUP BY 1, 2
)
SELECT
    service,
    COUNT(DISTINCT resource_id) AS total_resources,
    SUM(resource_cost) AS total_cost,
    
    -- Tagged resources metrics
    SUM(CASE WHEN is_tagged = 1 THEN 1 ELSE 0 END) AS tagged_resources,
    ROUND(100.0 * SUM(CASE WHEN is_tagged = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS tagged_resources_percent,
    SUM(CASE WHEN is_tagged = 1 THEN resource_cost ELSE 0 END) AS tagged_cost,
    ROUND(100.0 * SUM(CASE WHEN is_tagged = 1 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS tagged_cost_percent,
    
    -- Untagged resources metrics
    SUM(CASE WHEN is_tagged = 0 THEN 1 ELSE 0 END) AS untagged_resources,
    ROUND(100.0 * SUM(CASE WHEN is_tagged = 0 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS untagged_resources_percent,
    SUM(CASE WHEN is_tagged = 0 THEN resource_cost ELSE 0 END) AS untagged_cost,
    ROUND(100.0 * SUM(CASE WHEN is_tagged = 0 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS untagged_cost_percent,
    
    -- Specific tag metrics
    SUM(CASE WHEN has_specific_tag = 1 THEN 1 ELSE 0 END) AS resources_with_specific_tag,
    ROUND(100.0 * SUM(CASE WHEN has_specific_tag = 1 THEN 1 ELSE 0 END) / COUNT(DISTINCT resource_id), 2) AS specific_tag_resources_percent,
    SUM(CASE WHEN has_specific_tag = 1 THEN resource_cost ELSE 0 END) AS specific_tag_cost,
    ROUND(100.0 * SUM(CASE WHEN has_specific_tag = 1 THEN resource_cost ELSE 0 END) / SUM(resource_cost), 2) AS specific_tag_cost_percent
FROM resource_counts
GROUP BY 1
HAVING COUNT(DISTINCT resource_id) > 0
ORDER BY total_cost DESC;

-- 16. Detailed List of Tagged and Untagged Resources for a Specific Service
-- Replace 'AmazonRDS' with your desired service (e.g., 'AmazonEC2', 'AmazonS3', etc.)
WITH service_to_analyze AS (
    SELECT 'AmazonRDS' AS service_name -- Change this to your desired service
),
tag_key_to_search AS (
    SELECT 'user_creator' AS key -- Change this to your desired tag key
),
service_resources AS (
    SELECT DISTINCT
        line_item_resource_id AS resource_id,
        line_item_usage_type AS usage_type,
        product['product_name'] AS product_name,
        resource_tags as tags,
        product['instance_type'] AS instance_type,
        product['region'] AS region,
        CARDINALITY(MAP_KEYS(resource_tags)) AS tag_count,
        CASE 
            WHEN CARDINALITY(MAP_KEYS(resource_tags)) > 0 THEN 'Tagged'
            ELSE 'Untagged'
        END AS tagging_status,
        CASE
            WHEN resource_tags[(SELECT key FROM tag_key_to_search)] IS NOT NULL 
                 AND resource_tags[(SELECT key FROM tag_key_to_search)] <> '' THEN 'Yes'
            ELSE 'No'
        END AS has_specific_tag,
        resource_tags[(SELECT key FROM tag_key_to_search)] AS specific_tag_value,
        SUM(line_item_unblended_cost) AS monthly_cost
    FROM cur_data
    WHERE
        line_item_product_code = (SELECT service_name FROM service_to_analyze) AND
        line_item_resource_id <> '' AND
        bill_billing_period_start_date = DATE '2025-05-01' AND
        line_item_line_item_type != 'Credit' AND
        line_item_line_item_type != 'Refund' AND
        line_item_line_item_type = 'Usage' AND
        line_item_resource_id NOT LIKE '%management%' AND
        line_item_resource_id NOT LIKE '%overhead%'
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
)
SELECT
    resource_id,
    product_name,
    tags,
    instance_type,
    region,
    tagging_status,
    tag_count,
    has_specific_tag,
    specific_tag_value,
    monthly_cost
FROM service_resources
ORDER BY tagging_status, monthly_cost DESC; 

# Todo create SQL queries to find the cost split by the tags above
# Todo create EC2 instances with tags for platform and split cost by analogy
