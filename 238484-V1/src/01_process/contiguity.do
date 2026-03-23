/******************************************************************************
* Prepare CoW contiguity data (DirectContiguity320)
* This file processes dyadic contiguity information from the COW dataset
******************************************************************************/

* Import original contiguity data
import delimited "${DIR_DATA_RAW}/cow/contiguity/DirectContiguity320/contdird.csv", clear

* Convert country codes to ISO-3 codes for both dyad sides
* Matching on:
* - contdird: state1no, state2no
* - linking_cow_iso.dta: ccode → iso
foreach side in 1 2 {
	gen ccode = state`side'no
	merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) nogen
	rename iso iso`side'
	drop ccode
}

* Drop self-pairs (e.g. iso1 == iso2)
drop if iso1 == iso2

* Keep only the latest year available
sum year
keep if year == r(max)

* Collapse to most direct contiguity type (lower = closer)
collapse (min) conttype, by(iso1 iso2)

* Save processed dataset
save "${DIR_DATA_PROCESSED}/contiguity.dta", replace
