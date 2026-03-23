/******************************************************************************
* WAR SITES DESCRIPTIVE TABLE GENERATOR
*
* This program generates a comprehensive table of war sites showing casualties,
* countries, war names, start years, and war types.
*
* MAIN FUNCTIONALITY:
* - Loads complete war sites dataset
* - Creates chronological ordering by war start year
* - Sorts sites within wars by casualty severity (highest first)
* - Standardizes country names using ISO codes
* - Cleans war names
* - Categorizes war types
*
* OUTPUT:
* - LaTeX table fragment: sites.tex
* - Contains: War name, Country, Casualties, Start year, War type
* - Sorted chronologically by war, then by casualties within war
* - Used for descriptive overview in Online Appendix Table O-A.1.
******************************************************************************/

* Establish chronological sequence of wars for consistent table presentation
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear
collapse (min) start (firstnm) type, by(warname)
sort start
gen order = _n
tempfile order
save `order', replace

* Apply chronological ordering to full dataset
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear
merge m:1 warname using `order', nogen

* Clean war names by removing year suffixes for better presentation, pattern removes "of YYYY" or "of YYYY-YYYY" or "of YYYY-present"
replace warname = trim(ustrregexra(warname, "of \d{4}(-(\d{4}|present))?", " ",.))

* Order sites chronologically by war, then by casualty count within each war

gsort order -casualties // Sort by war chronology, then by casualties (highest first within each war)
drop if casualties == . // Remove sites with missing casualty data (cannot rank by severity)

* Convert ISO codes to standardized country names for publication
kountry iso, from(iso3c) // Creates NAMES_STD variable

* Manual corrections for countries not handled by kountry
replace NAMES_STD = "Serbia" if iso == "SRB"
replace NAMES_STD = "Kosovo" if iso == "XKX"

* Format casualties with thousands separators for readability
gen casualties_str = string(casualties, "%13.0fc")

* Keep only variables needed for final table
keep warname NAMES_STD casualties_str start type
order warname NAMES_STD casualties_str start type

* Standardize war type labels for publication
replace type = "Interstate" if type == "inter"
replace type = "Other" if type == "extra"
replace type = "Other" if type == "intra"

* Export as LaTeX table fragment (dataonly creates content without table environment)
texsave * using "${DIR_DATA_EXPORTS}/tables/descriptives/sites.tex", replace dataonly
