/******************************************************************************
* WORLD POPULATION CALCULATION
* This script creates a world population dataset by summing population data
* from countries with complete population coverage over the study period.
* Only countries with data for all years from 1869 onwards are included
* to ensure consistent world population estimates across time.
******************************************************************************/
use "${DIR_DATA_PROCESSED}/pop.dta", clear
keep if year >= 1869

* ==============================================================================
* SECTION 1: Identify countries with complete population coverage
* ==============================================================================
* We need to identify countries that have population data for ALL years in our study period to avoid inconsistent world population totals.
* Count the number of years each country has population data and keep only countries with 155+ years of data (1869-2023 = 155 years) to have complete coverage.
collapse (count) pop, by(iso)
keep if pop >= 155
levelsof iso, local(isos)

* ==============================================================================
* SECTION 2: Calculate world population using countries with complete coverage
* ==============================================================================
* Build a condition string to keep only countries with complete coverage
use "${DIR_DATA_PROCESSED}/pop.dta", clear
local cond
foreach iso in `isos' {
	local cond `cond' iso == "`iso'" |
}
local cond `cond' iso == "N/A"
keep if `cond'

* ==============================================================================
* SECTION 3: Sum population across countries and save world totals
* ==============================================================================
* Floating point precision in collapse may lead to non-deterministic data signatures.
* Round population to nearest integer to ensure reproducible results.
gen double pop2 = round(pop)
collapse (sum) pop2, by(year)
rename pop2 pop_world
keep if year >= 1869

* Save the world population dataset
save "${DIR_DATA_PROCESSED}/pop_world.dta", replace
