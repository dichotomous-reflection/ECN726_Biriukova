*hmddata settings path, value("${DIR_DATA_RAW}/humanmortalitydatabase")
*hmddata convert deaths cohort, grid(1x1) sourcedir("${DIR_DATA_RAW}/humanmortalitydatabase")

/******************************************************************************
* Process cohort mortality data from Human Mortality Database (HMD)
* Constructs total and military-age mortality by iso-year
******************************************************************************/

* Load cohort-based 1x1 mortality data (produced via hmddata commands)
use "${DIR_DATA_RAW}/humanmortalitydatabase/deaths_cohort_1x1.dta", clear

* Adjust age coding and country identifier
replace age = age + 127
decode popname, gen(iso)

* Restore year variable
gen x = year
drop year
rename x year

* Define mortality among military-age population (ages 18–60)
gen deaths_milpop = 0
replace deaths_milpop = male if age >= 18 & age <= 60

* Define non-military-age mortality
gen deaths_nonmilpop = total - deaths_milpop

* Aggregate to iso-year level
collapse (sum) death*, by(iso year)

* Harmonize country codes
replace iso = "DEU" if iso == "DEUTW"
replace iso = "FRA" if iso == "FRATNP"
replace iso = "GBR" if iso == "GBR_NP"
replace iso = "NZL" if iso == "NZL_NP"

* Drop zeroes where data is likely missing
replace deaths_milpop = . if deaths_milpop == 0
replace deaths_nonmilpop = . if deaths_nonmilpop == 0

* Export processed mortality data
save "${DIR_DATA_PROCESSED}/mortality.dta", replace
