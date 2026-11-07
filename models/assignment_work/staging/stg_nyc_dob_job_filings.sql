-- Clean and standardize DOB job application data
-- One row per job application filing

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number,
           filing_status,
           filing_date,
           current_status_date,
           first_permit_date,
           borough,
           house_no,
           street_name,
           apt_condo_no_s,
           applicant_street_name,
           city,
           state,
           zip,
           commmunity_board,
           filing_representative_street_name,
           filing_representative_city,
           filing_representative_state,
           filing_representative_zip,
           latitude,
           longitude,
           postcode,
           bbl,
           nta,
           boiler_equipment_work_type_,
           earth_work_work_type_,
           foundation_work_type_,
           general_construction_work_type_,
           mechanical_systems_work_type_,
           place_of_assembly_work_type_,
           protection_mechanical_methods_work_type_,
           sidewalk_shed_work_type_,
           structural_work_type_,
           support_of_excavation_work_type_,
           temporary_place_of_assembly_work_type_,
           green_roof_work_type_,
           solar_work_type_,
           full_demolition_work_type_,
           suspended_scaffold_work_type_
       ),

       -- Work Types - cleaning up the column names to be more readable and consistent, removing trailing underscores from source names
       CAST(boiler_equipment_work_type_ AS STRING) AS boiler_equipment_work_type,
       CAST(earth_work_work_type_ AS STRING) AS earth_work_type,
       CAST(foundation_work_type_ AS STRING) AS foundation_work_type,
       CAST(general_construction_work_type_ AS STRING) AS general_construction_work_type,
       CAST(mechanical_systems_work_type_ AS STRING) AS mechanical_systems_work_type,
       CAST(place_of_assembly_work_type_ AS STRING) AS place_of_assembly_work_type,
       CAST(protection_mechanical_methods_work_type_ AS STRING) AS protection_mechanical_methods_work_type,
       CAST(sidewalk_shed_work_type_ AS STRING) AS sidewalk_shed_work_type,
       CAST(structural_work_type_ AS STRING) AS structural_work_type,
       CAST(support_of_excavation_work_type_ AS STRING) AS support_of_excavation_work_type,
       CAST(temporary_place_of_assembly_work_type_ AS STRING) AS temporary_place_of_assembly_work_type,
       CAST(green_roof_work_type_ AS STRING) AS green_roof_work_type,
       CAST(solar_work_type_ AS STRING) AS solar_work_type,
       CAST(full_demolition_work_type_ AS STRING) AS full_demolition_work_type,
       CAST(suspended_scaffold_work_type_ AS STRING) AS suspended_scaffold_work_type,

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_number,
       CAST(house_no AS STRING) AS house_no,
       CAST(apt_condo_no_s AS STRING) AS apt_condo_numbers,
       CAST(applicant_street_name AS STRING) AS applicant_street_name,
       CAST(city AS STRING) AS city,
       CAST(state AS STRING) AS state,
       CAST(zip AS STRING) AS applicant_zip,
       CAST(bbl AS STRING) AS bbl,
       CAST(nta AS STRING) AS nta,

       -- Date/Time
        CAST(filing_status AS STRING) AS filing_status,
        CAST(filing_date AS TIMESTAMP) AS filing_date,
        CAST(current_status_date AS TIMESTAMP) AS current_status_date,
        CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,

       -- Filing Representative Request details
        CAST(filing_representative_street_name AS STRING) AS filing_representative_street_name,
        CAST(filing_representative_city AS STRING) AS filing_representative_city,
        CAST(filing_representative_state AS STRING) AS filing_representative_state,
        CAST(filing_representative_zip AS STRING) AS filing_representative_zip,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 9 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(postcode AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(street_name AS STRING) AS street_name,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Correcting Typo from NYC Open Data - DOB Job Applications dataset
       CAST(commmunity_board AS STRING) AS community_board,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicated by filing number, keeping the most recent status date for each filing number
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY current_status_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_dob_job_filings

