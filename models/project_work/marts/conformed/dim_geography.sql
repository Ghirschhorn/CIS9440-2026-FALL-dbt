-- Geography dimension shared by both data sources - 311 DOHMH and restaurant inspections
-- Grain: one row per distinct combination of borough / zipcode/ community_board / council_district

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_nyc_311_dohmh') }}
),

stg_dohmh AS (
    SELECT * FROM {{ ref('stg_restaurant_inspection') }}
),

all_geographies AS (

    SELECT DISTINCT
        CAST(borough AS STRING) AS borough,
        CAST(zip AS STRING) AS zipcode,
        CAST(community_board AS STRING) AS community_board,
        CAST(council_district AS STRING) AS council_district
    FROM stg_311
    WHERE borough IS NOT NULL
       OR zip IS NOT NULL
       OR community_board IS NOT NULL
       OR council_district IS NOT NULL


    UNION DISTINCT

    SELECT DISTINCT
        CAST(borough AS STRING) AS borough,
        CAST(zip AS STRING) AS zipcode,
        CAST(community_board AS STRING) AS community_board,
        CAST(council_district AS STRING) AS council_district
    FROM stg_dohmh
    WHERE borough IS NOT NULL
       OR zip IS NOT NULL
       OR community_board IS NOT NULL
       OR council_district IS NOT NULL


),

geography_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'borough', 'zipcode', 'community_board', 'council_district'
        ]) }} AS geography_key,

        borough,
        zipcode,
        community_board,
        council_district
       

    FROM all_geographies

),

-- Null placeholder row to handle NULL values.

null_placeholder AS (

    SELECT
        '-1' AS geography_key,
        CAST(NULL AS STRING) AS borough,
        CAST(NULL AS STRING) AS zipcode,
        CAST(NULL AS STRING) AS community_board,
        CAST(NULL AS STRING) AS council_district

)

SELECT * FROM geography_dimension
UNION ALL
SELECT * FROM null_placeholder
