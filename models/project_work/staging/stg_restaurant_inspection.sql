WITH source AS (
   SELECT * FROM {{ source('raw', 'dohmh_restaurant_inspection_data') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            camis,
            dba,
            cuisine_description,
            inspection_date,
            grade_date,
            record_date,
            longitude,
            latitude,
            community_board,
            zipcode,
            boro,            
            grade,
            critical_flag
        ),
        -- Renaming columns 
        CAST(camis AS STRING) AS restaurant_id,
        CAST(dba AS STRING) AS restaurant_name,

        -- Cleaning cuising_tupe (NULL, blank, and Not Listed to become "Unknown")
        CASE
            WHEN cuisine_description IS NULL
                OR TRIM(cuisine_description) = ''
                OR TRIM(cuisine_description) = 'Not Listed/Not Applicable'
            THEN 'Unknown'
            ELSE TRIM(CAST(cuisine_description AS STRING))
        END AS cuisine_type,
        
        -- Time/date columns
        CAST(inspection_date AS TIMESTAMP) AS inspection_date,
        CAST(grade_date AS TIMESTAMP) AS grade_date,
        CAST(record_date AS TIMESTAMP) AS record_date,

        -- Lat/long
        CAST(latitude AS DECIMAL) AS latitude,
        CAST(longitude AS DECIMAL) AS longitude,

        -- Community_board
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(community_board AS STRING)), r'^\d{3}$')
                THEN TRIM(CAST(community_board AS STRING))
            ELSE NULL
        END AS community_board,

        -- Cleaning Zip (only contains zipcode of length 5 so not much needed)
        CASE
            WHEN UPPER(TRIM(CAST(zipcode AS STRING))) IN ('N/A', 'NA') THEN NULL
            WHEN LENGTH(CAST(zipcode AS STRING)) = 5 THEN CAST(zipcode AS STRING)
            -- handle future zips
            WHEN LENGTH(CAST(zipcode AS STRING)) = 9 THEN CAST(zipcode AS STRING)
            WHEN LENGTH(CAST(zipcode AS STRING)) = 10
                AND REGEXP_CONTAINS(CAST(zipcode AS STRING), r'^\d{5}-\d{4}')
            THEN CAST(zipcode AS STRING)            
            ELSE NULL
        END AS zip, -- consistent name for confomred dim

        -- Cleaning borough
        CASE
            WHEN UPPER(TRIM(boro)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(boro)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(boro)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(boro)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(boro)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Metrics
        UPPER(TRIM(CAST(grade AS STRING))) AS grade,
        UPPER(TRIM(CAST(critical_flag AS STRING))) AS critical_flag,

        CASE
            WHEN UPPER(TRIM(critical_flag)) = 'CRITICAL' THEN TRUE
            WHEN UPPER(TRIM(critical_flag)) = 'NOT CRITICAL' THEN FALSE
            ELSE NULL
        END AS is_critical,

        -- Shortening phrases in action variable
        CASE
            WHEN LOWER(action) LIKE '%re-opened%' THEN 'REOPENED BY DOHMH'
            WHEN LOWER(action) LIKE '%re-closed%' THEN 'RECLOSED BY DOHMH'
            WHEN LOWER(action) LIKE '%closed by dohmh%' THEN 'CLOSED BY DOHMH WITH VIOLATIONS CITED'
            WHEN LOWER(action) LIKE '%no violations%' THEN 'NO VIOLATIONS RECORDED AT INSPECTION'
            WHEN LOWER(action) LIKE '%violations were cited%' THEN 'VIOLATIONS CITED IN SPECIFIC AREAS'
            ELSE 'OTHER'
        END AS action_taken,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE camis IS NOT NULL
    AND inspection_date IS NOT NULL
    AND boro IS NOT NULL

    -- Deduplicate
    -- All drops rows appear to be actual duplicates (around 6,900 rows dropped)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY camis, inspection_date, violation_code, inspection_type ORDER BY record_date DESC) = 1
),


 -- Grouping similar cuisine types (using CLEANED cuisine_type) so every "Unknown" gets the same group
 with_cuisine_group AS(
    SELECT *,
        CASE
            WHEN cuisine_type IN ('Creole', 'Cajun', 'Creole/Cajun') THEN 'Creole/Cajun'
            WHEN cuisine_type IN ('Hotdogs', 'Hotdogs/Pretzels') THEN 'Hotdogs'
            WHEN cuisine_type IN ('Sandwiches', 'Salads', 'Soups',
                'Sandwiches/Salads/Mixed Buffet', 'Soups/Salads/Sandwiches') THEN 'Sandwiches/Salads/Soups'
            WHEN cuisine_type IN ('French', 'New French', 'Haute Cuisine') THEN 'French'
            WHEN cuisine_type IN ('Vegan', 'Vegetarian') THEN 'Vegetarian/Vegan'
            WHEN cuisine_type IN ('Bakery Products/Desserts', 'Frozen Desserts', 'Donuts',
                'Bagels/Pretzels', 'Pancakes/Waffles', 'Nuts/Confectionary') THEN 'Bakery/Desserts'
            WHEN cuisine_type IN ('Coffee/Tea', 'Juice, Smoothies, Fruit Salads',
                'Bottled Beverages') THEN 'Beverages'
            WHEN cuisine_type IN ('Polish', 'Russian', 'Czech', 'Eastern European') THEN 'Eastern European'
            WHEN cuisine_type IN ('Lebanese', 'Egyptian', 'Iranian', 'Turkish',
                'Armenian', 'Middle Eastern') THEN 'Middle Eastern'
            ELSE cuisine_type
        END AS cuisine_group
    FROM cleaned
 )

SELECT * FROM with_cuisine_group