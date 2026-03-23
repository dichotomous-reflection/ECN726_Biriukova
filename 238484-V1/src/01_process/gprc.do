/******************************************************************************
* This script processes the historical Geopolitical Risk (GPR) data from
* Caldara & Iacoviello (2022) to create a country-year panel dataset.
******************************************************************************/
* The data includes country-specific historical indices (GPRHC_[country]) and a global historical index (GPRH)
import excel "${DIR_DATA_RAW}/caldara/data_gpr_export.xls", clear firstrow

rename GPRH GPRHC_global // Rename global index variable to match country naming convention
keep month GPRHC_*
gen year = year(month)

collapse (mean) GPRHC_*, by(year)

reshape long GPRHC_, i(year) j(iso) string

* "gprc" represents country-specific geopolitical risk
rename GPRHC_ gprc

* Save the reshaped data temporarily for further processing
tempfile orig
save `orig', replace

* Extract global GPRC index and merge with country data
keep if iso == "global"
drop iso
rename gprc gprc_global
merge 1:m year using `orig', nogen
order iso year gprc gprc_global
drop if iso == "global" // Remove duplicate global observation (now included as a variable)

* Standardize country-specific GPRC indices to create z-score deviations from country-specific historical norms.
* Positive values = above-normal geopolitical risk for that country
* Negative values = below-normal geopolitical risk for that country
gen _mean = .
gen _sd = .
levelsof iso, local(isos)
foreach iso in `isos' {
	sum gprc if iso == "`iso'", d
	replace _mean = r(p50) if iso == "`iso'" // Use median (p50) instead of mean for robustness to outliers
	replace _sd = r(sd) if iso == "`iso'"
}
replace gprc = (gprc - _mean) / _sd
drop _mean _sd

* Alternative standardization approach (commented out)
* - use fixed effects regression to remove country means but doesn't account for different volatility levels across countries
*reghdfe gprc, absorb(iso) resid
*drop gprc
*predict gprc, resid

* Save final country-year panel dataset with both country-specific and global GPRC indices
save "${DIR_DATA_PROCESSED}/gprc.dta", replace
