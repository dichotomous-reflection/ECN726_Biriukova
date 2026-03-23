/******************************************************************************
* Prepare bilateral distance dataset
* Source: Handcoded file with distances between ISO-3 country pairs
******************************************************************************/

* Load hand-coded distance file
import delimited "${DIR_DATA_RAW}/handcoded/distances.csv", clear

* Rename variables
rename iso3_a iso1
rename iso3_b iso2
rename distance dist

* Drop invalid or redundant entries
drop if dist == .
drop if iso1 == iso2

* Keep only required variables
keep iso1 iso2 dist

* Collapse to minimum distance per dyad
collapse (min) dist, by(iso1 iso2)

* Save to processed directory
save "${DIR_DATA_PROCESSED}/distances.dta", replace
