/******************************************************************************
* GPT-IDENTIFIED WAR SITES TABLE GENERATOR
*
* This program generates a descriptive table of war sites that were identified
* and validated using GPT-4.
*
* MAIN FUNCTIONALITY:
* - Loads GPT-4 war site identification results
* - Filters to confirmed/revised sites only
* - Sorts by casualty severity (highest first)
* - Standardizes country names using ISO codes
* - Formats casualty numbers
* - Handles missing casualty data appropriately
* - Corrects known data issues (e.g., WWI start date)
*
* OUTPUT:
* - LaTeX table fragment: sites_gpt.tex
* - Contains: War name, Country, Casualties, Start year
* - Sorted by casualty severity (most deadly first)
* - Used to validate GPT-4 performance in war site identification
******************************************************************************/

* Load GPT-4 analysis results from Excel file
import excel "${DIR_DATA_RAW}/handcoded/gpt.xlsx", clear firstrow

* Filter to sites that were confirmed/revised after human validation
keep if site_revised == 1

* Sort by casualties in descending order (most deadly battles first)
gsort -casualties

* Use kountry command to convert ISO3 codes to standardized country names
kountry iso, from(iso3c)

* Format casualties with thousands separators for readability
gen casualties_str = string(casualties, "%13.0fc")

* Handle missing casualty data with appropriate label
replace casualties_str = "N/A" if casualties_str == "."

* Correct missing start year for World War I (known historical date)
replace start = 1914 if start == . & warname == "World War I"

* Keep only essential variables for publication table
keep warname NAMES_STD casualties_str start
order warname NAMES_STD casualties_str start

* Export as LaTeX table fragment (dataonly creates content without table environment)
texsave * using "${DIR_DATA_EXPORTS}/tables/descriptives/sites_gpt.tex", replace dataonly
