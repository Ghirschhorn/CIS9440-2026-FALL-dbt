-- Violation type dimension for DOHMH restaurant inspections.
-- Grain: one row per distinct (violation_code, critical_flag) combination.

WITH stg_restaurant AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

distinct_violations AS (

    SELECT DISTINCT
        violation_code,
        critical_flag
    FROM stg_restaurant
    WHERE violation_code IS NOT NULL

),

enriched AS (

    SELECT
        violation_code,
        critical_flag,

        -- Derived: TRUE when the inspector flagged the violation as critical
        CASE
            WHEN UPPER(TRIM(critical_flag)) = 'CRITICAL' THEN TRUE
            ELSE FALSE
        END AS is_critical

    FROM distinct_violations

),

dim_violation AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'violation_code', 'critical_flag'
        ]) }} AS violation_key,

        violation_code,
        critical_flag,
        is_critical

    FROM enriched

),

-- Null placeholder: inspections with no violation cited
null_placeholder AS (

    SELECT
        '-1' AS violation_key,
        CAST(NULL AS STRING) AS violation_code,
        CAST(NULL AS STRING) AS critical_flag,
        CAST(NULL AS BOOLEAN) AS is_critical

)

SELECT * FROM dim_violation
UNION ALL
SELECT * FROM null_placeholder

