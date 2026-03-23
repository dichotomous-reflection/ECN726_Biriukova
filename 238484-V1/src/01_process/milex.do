/******************************************************************************
* Prepare military expenditure data
* Combines COW NMC dataset with exchange rates and deflators
******************************************************************************/

* Prepare exchange rate data (USD/GBP)
tempfile fx
import excel "${DIR_DATA_RAW}/measuringworth/fx.xlsx", clear cellrange(A3) firstrow
rename USDGBP USD_over_GBP
duplicates drop
save `fx'

* Load military expenditure data from CoW NMC-60
use "${DIR_DATA_RAW}/cow/NMC-60-wsupplementary/NMC-60-wsupplementary.dta", clear
keep ccode year milex milper cinc

* Merge ISO codes
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen
drop ccode
order iso year milex milper cinc

* Clean values and scale units
replace milex = . if milex < 0
replace milper = . if milper < 0

replace milper = milper * 1000      // thousands → units
replace milex  = milex  * 1000

* Collapse to iso-year level
collapse (sum) milex milper (mean) cinc, by(iso year)

* Treat zeros as missing
replace milex  = . if milex  == 0
replace milper = . if milper == 0

* Convert currencies (if year ≤ 1913, convert GBP → USD)
merge m:1 year using `fx', keep(matched) nogen
replace milex = milex * USD_over_GBP if year <= 1913
drop USD_over_GBP

* Adjust to constant 2015 USD using CPI deflator
merge m:1 year using "${DIR_DATA_PROCESSED}/deflator.dta", keep(matched) nogen
replace milex = milex * conv_USD_cur_to_2015
drop conv_USD_cur_to_2015

* Save final dataset
save "${DIR_DATA_PROCESSED}/milex.dta", replace
