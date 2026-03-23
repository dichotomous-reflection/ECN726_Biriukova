* Generates COW Country code x ISO code linking table
import delimited "${DIR_DATA_RAW}/handcoded/cow_codes_iso.csv", clear

rename iso3 iso
keep ccode iso

save "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", replace
