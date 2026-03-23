/******************************************************************************
* TERRITORIAL CHANGES AND POPULATION IMPACTS
* This script processes territorial changes data from the Correlates of War (COW)
* project to create two datasets:
* 1. territory.dta - Simple indicator of which countries experienced territorial changes
* 2. territory_details.dta - Population changes associated with territorial transfers
******************************************************************************/
import delimited "${DIR_DATA_RAW}/cow/terr-changes-v6/tc2018.csv", clear

* ==============================================================================
* SECTION 1: Convert COW country codes to ISO codes for both gainers and losers
* ==============================================================================
* Process the "gainer" country (country that gained territory)
rename gainer ccode
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen
rename iso iso_gainer
drop ccode

* Process the "loser" country (country that lost territory)
rename loser ccode
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen
rename iso iso_loser
drop ccode

* ==============================================================================
* SECTION 2: Filter data to conflict-related territorial changes since 1870
* ==============================================================================
keep if conflict == 1  // Only keep territorial changes due to conflicts
keep if year >= 1870   // Limit to our study period (1870 onwards)

* Save the filtered raw data for later use
tempfile raw
save `raw'

* ==============================================================================
* SECTION 3: Binary indicator of territorial changes
* ==============================================================================
* Create entries for both gainers and losers
expand 2
replace iso_loser = iso_gainer if _n > _N/2
rename iso_loser iso
keep year iso
duplicates drop

* Save the territorial changes indicator dataset
save "${DIR_DATA_PROCESSED}/territory.dta", replace

* ==============================================================================
* SECTION 4: Population changes from territorial transfers
* ==============================================================================
use `raw', clear

* Process gainers: countries that gained territory (and population), i.e. positive population change
keep iso_gainer pop year
rename iso_gainer iso 
tempfile gainers
save `gainers', replace

* Process losers: countries that lost territory (and population), i.e. negative population change
use `raw', clear
keep iso_loser pop year
rename iso_loser iso
replace pop = pop * -1
append using `gainers'

* Rename population variable to be more descriptive
rename pop terrchange_pop

* Aggregate population changes by country-year (in case a country had multiple territorial changes in the same year)
collapse (sum) terrchange_pop, by(iso year)

* ==============================================================================
* SECTION 5: Export final dataset
* ==============================================================================
* Save the detailed territorial changes dataset with population impacts
save "${DIR_DATA_PROCESSED}/territory_details.dta", replace
