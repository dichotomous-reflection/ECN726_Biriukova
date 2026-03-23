/******************************************************************************
* Construct deflator: Convert current USD to constant 2015 USD (USA only)
******************************************************************************/

* Load World Bank inflation data
import delimited "${DIR_DATA_RAW}/worldbank/inflation/API_FP.CPI.TOTL.ZG_DS2_en_csv_v2_740199.csv", ///
    clear varnames(4)

* Rename wide format variables to long format
foreach var of varlist v* {
    rename `var' y`:var lab `var''
}

drop y
keep countrycode y*
reshape long y, i(countrycode) j(year)
rename y inflation

* Convert percentage to decimal
replace inflation = inflation / 100

rename countrycode iso
keep if iso == "USA"
keep if year > 2019

tempfile wb
save `wb'

* Append inflation data from PLE dataset
use "${DIR_DATA_RAW}/ple/ple_dataset.dta", clear
keep if iso == "USA"
keep iso year inflation

* PLE inflation is in logs → convert to level
replace inflation = exp(inflation) - 1

append using `wb'

* Generate CPI index from year-on-year inflation
sort year
gen cpi = 1 if _n == 1
replace cpi = cpi[_n-1] * (1 + inflation) if _n > 1

* Normalize to 2015 CPI = 1
preserve
keep if year == 2015
local cpi_2015 = cpi[1]
restore

gen conv_USD_cur_to_2015 = `cpi_2015' / cpi

* Save conversion factors
keep year conv_USD_cur_to_2015
save "${DIR_DATA_PROCESSED}/deflator.dta", replace
