-- Cuisine dimension for DOHMH restaurant inspections.
-- Grain: one row per distinct cuisine type.

WITH stg_restaurant AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

distinct_cuisine AS (

    SELECT DISTINCT
        cuisine_type,
        cuisine_group
    FROM stg_restaurant
    WHERE cuisine_type IS NOT NULL
    AND cuisine_type <> 'Unknown'

),

dim_cuisine AS (

    SELECT
     {{ dbt_utils.generate_surrogate_key(['cuisine_type']) }}
            AS cuisine_key,
        cuisine_type,
        cuisine_group

    FROM distinct_cuisine
),

-- Null placeholder: inspections with no cuisine recorded
null_placeholder AS (

    SELECT
        '-1' AS cuisine_key,
        'Unknown' AS cuisine_type,
        'Unknown' AS cuisine_group
)

SELECT * FROM dim_cuisine
UNION ALL
SELECT * FROM null_placeholder
