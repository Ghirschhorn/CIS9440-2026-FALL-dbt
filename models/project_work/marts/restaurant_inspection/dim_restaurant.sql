-- Restaurant dimension for DOHMH restaurant inspections.
-- Grain: one row per distinct (restaurant_name, phone_num) combination.

WITH stg_restaurant AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

distinct_restaurants AS (

    SELECT DISTINCT
        restaurant_name,
        phone AS phone_num
    FROM stg_restaurant
    WHERE restaurant_name IS NOT NULL

),

dim_restaurant AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'restaurant_name', 'phone_num'
        ]) }} AS restaurant_key,

        restaurant_name,
        phone_num

    FROM distinct_restaurants

),

-- Null placeholder: inspections with no restaurant name
null_placeholder AS (

    SELECT
        '-1' AS restaurant_key,
        CAST(NULL AS STRING) AS restaurant_name,
        CAST(NULL AS STRING) AS phone_num
)

SELECT * FROM dim_restaurant
UNION ALL
SELECT * FROM null_placeholder

