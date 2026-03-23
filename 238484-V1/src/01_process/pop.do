/******************************************************************************
* Construct historical population panel (ISO-year level)
* Combines:
* - Georg Roesel's custom-coded population estimates
* - Our World in Data historical population
* - World Bank population (post-2019)
* - Maddison Project (long-run baseline)
******************************************************************************/

* ==============================================================================
* SECTION 1: Load custom-coded data complementing pre-war population for missing interstate sites
* ==============================================================================
import excel "${DIR_DATA_RAW}/roesel/population_matched.xlsx", clear sheet("population") firstrow
rename population pop_cc
keep iso year pop_cc
tempfile pop_cc
save `pop_cc', replace

* ==============================================================================
* SECTION 2: Load Our World in Data population series
* ==============================================================================
import delimited "${DIR_DATA_RAW}/ourworldindata/population/population.csv", clear
rename code iso
rename populationhistorical pop_owd
keep iso pop year
drop if iso == ""
tempfile pop_owd
save `pop_owd', replace

* ==============================================================================
* SECTION 3: Load World Bank population data (2019+)
* ==============================================================================
import delimited "${DIR_DATA_RAW}/worldbank/pop/API_SP.POP.TOTL_DS2_en_csv_v2_739890.csv", clear varnames(4)
foreach var of varlist v* {
    rename `var' y`:var lab `var''
}
drop y
keep countrycode y*
reshape long y, i(countrycode) j(year)
rename y pop
rename countrycode iso
keep if year >= 2019
tempfile pop_wb
save `pop_wb', replace

* ==============================================================================
* SECTION 4: Load Maddison population data and combine with World Bank
* ==============================================================================
use "${DIR_DATA_RAW}/maddison/mpd2020.dta", clear
rename countrycode iso
replace pop = pop * 1000
keep iso year pop
append using `pop_wb'
sort iso year

* ==============================================================================
* SECTION 5: Merge in custom-coded population
* ==============================================================================
merge 1:1 iso year using `pop_cc', nogen keep(master matched using)
replace pop = pop_cc if pop == .
drop pop_cc

* ==============================================================================
* SECTION 6: Merge in Our World in Data population
* ==============================================================================
merge 1:1 iso year using `pop_owd', nogen keep(master matched using)
replace pop = pop_owd if pop == .
drop pop_owd

* ==============================================================================
* SECTION 7: Export final population panel
* ==============================================================================
save "${DIR_DATA_PROCESSED}/pop.dta", replace
