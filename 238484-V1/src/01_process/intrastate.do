/******************************************************************************
* INTRASTATE AND EXTRASTATE WAR DATA PROCESSING
* This script constructs comprehensive datasets of intrastate and extrastate war
* sites and belligerents by combining data from multiple sources:
* - Correlates of War (CoW) Intra-State Wars v5.1 (pre-2008)
* - Correlates of War (CoW) Extra-State Wars v4.0 (colonial/imperial wars)
* - UCDP Georeferenced Event Dataset (post-2008)
* - Hand-coded war sites with detailed battle locations
* 
* Output datasets:
* 1. intrastate_sites.dta - War sites with locations, dates, and casualties
* 2. intrastate_belligerents.dta - All countries that participated in intrastate/extrastate wars
******************************************************************************/


* ==============================================================================
* SECTION 1: Set conversion parameters
* ==============================================================================
* CoW's battle-death to total casualty ratio, see Dixon and Sarkees (2016, p. 16):
* "In many cases, where sources provide only casualty numbers (rather than fatalities),
*  COW has adopted a calculation of fatality estimates by using the historically observed
*  ratio of three wounded for every one killed in combat. Thus if a total casualty figure
*  is available, it is divided by four to estimate battle-deaths."
local batdeath_to_casualties_ratio = 4


* ==============================================================================
* SECTION 2: Process CoW intrastate war sites (pre-2008)
* ==============================================================================
* Load hand-coded war sites for CoW intrastate wars
import excel "${DIR_DATA_RAW}/handcoded/sites_other_geocoding.xlsx", clear firstrow sheet("Intra-State Wars")
drop if WarNum == .
keep if start <= 2007  // CoW data coverage ends in 2007
rename iso3 iso
keep WarNum iso

* Count number of sites per war for casualty distribution
bysort WarNum: gen n_sites = _N
tempfile sites_cur
save `sites_cur', replace

* Load CoW intrastate war data with battle deaths and dates
use "${DIR_DATA_RAW}/cow/Intra-State-Wars-v5.1/INTRA-STATE WARS v5.1.dta", clear
rename WarName warname
rename StartYr1 start
rename EndYr1 end

* Handle wars with multiple phases (use latest end date)
replace end = EndYr2 if EndYr2 > 0
replace end = EndYr3 if EndYr3 > 0
replace end = EndYr4 if EndYr4 > 0

* Create alternative date variables for robustness checks
gen start_alt = start
gen end_alt = end

* Merge with site locations to distribute casualties geographically
merge 1:m WarNum using `sites_cur', nogen keep(matched)

* Convert battle deaths to total casualties and distribute across sites
gen casualties = (TotalBDeaths * `batdeath_to_casualties_ratio') / n_sites
replace casualties = . if casualties < 0

* Clean negative values (data quality issues)
foreach var in start end start_alt end_alt casualties {
	replace `var' = . if `var' < 0
}

keep warname iso start end casualties start_alt end_alt

* Limit to study period (1870-2007 for CoW data)
keep if start >= 1870 & start <= 2007
sort start iso

* Save CoW intrastate war sites
tempfile intra_cow_sites
gen type = "intra"
save `intra_cow_sites', replace


* ==============================================================================
* SECTION 3: Process CoW intrastate war belligerents (pre-2008)
* ==============================================================================
* Load CoW state participants in intrastate wars (external interventions)
use "${DIR_DATA_RAW}/cow/Intra-State-Wars-v5.1/INTRA-STATE_State_participant v5.1.dta", clear
keep if StartYr1 >= 1870 & StartYr1 <= 2007

* Clean variable names
rename CcodeA ccodea
rename CcodeB ccodeb
rename WarName warname

* Convert dyadic data (A vs B) to country list format
keep warname ccodea ccodeb
expand 2  // Duplicate each observation
gen reverse = 1 if _n <= _N/2
replace ccodea = ccodeb if _n > _N/2  // In second half, replace A with B
drop ccodeb reverse
rename ccodea ccode
drop if ccode < 0  // Remove invalid country codes

* Convert CoW codes to ISO codes
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen
keep warname iso

* Save CoW intrastate belligerents
tempfile intra_cow_belligerents
gen type = "intra"
save `intra_cow_belligerents', replace


* ==============================================================================
* SECTION 4: Process CoW extrastate war sites (colonial/imperial wars)
* ==============================================================================
* Load hand-coded war sites for CoW extrastate wars (wars between states and non-state entities)
import excel "${DIR_DATA_RAW}/handcoded/sites_other_geocoding.xlsx", clear firstrow sheet("Extra Wars")
rename iso3 iso
keep if start <= 2007  // CoW data coverage
keep WarNum iso

* Count sites per war for casualty distribution
bysort WarNum: gen n_sites = _N
rename WarNum warnum
tempfile sites_cur
save `sites_cur', replace

* Load CoW extrastate war data
import delimited "${DIR_DATA_RAW}/cow/Extra-StateWarData_v4.0.csv", clear

* Manual corrections for duplicate war names
replace warname = "First Franco-Tunisian" if warnum == 383
replace warname = "Second Franco-Tunisian" if warnum == 463

* Clean date variables
rename startyear1 start
rename endyear1 end
replace end = endyear2 if endyear2 > 0  // Use second end date if available

* Create alternative date variables for robustness
gen start_alt = start
gen end_alt = end

* Aggregate battle deaths by war (some wars have multiple entries)
collapse (sum) batdeath (min) start start_alt (max) end end_alt, by(warname warnum)

* Merge with site locations for geographic distribution
merge 1:m warnum using `sites_cur', nogen keep(matched)

* Convert battle deaths to total casualties and distribute across sites
gen casualties = (batdeath * `batdeath_to_casualties_ratio') / n_sites
replace casualties = . if casualties < 0

* Clean negative values
foreach var in start end start_alt end_alt casualties {
	replace `var' = . if `var' < 0
}

keep warname iso start end casualties start_alt end_alt

* Save CoW extrastate war sites
gen type = "extra"
tempfile extra_cow_sites
save `extra_cow_sites', replace


* ==============================================================================
* SECTION 5: Process CoW extrastate war belligerents
* ==============================================================================
* Load CoW extrastate war participants (states involved in colonial/imperial wars)
import delimited "${DIR_DATA_RAW}/cow/Extra-StateWarData_v4.0.csv", clear
keep if startyear1 <= 2007

* Manual corrections for duplicate war names
replace warname = "First Franco-Tunisian" if warnum == 383
replace warname = "Second Franco-Tunisian" if warnum == 463

* Convert dyadic data to country list
rename ccode1 ccodea
rename ccode2 ccodeb
keep warname ccodea ccodeb
expand 2
gen reverse = 1 if _n <= _N/2
replace ccodea = ccodeb if _n > _N/2
drop ccodeb reverse 
rename ccodea ccode
drop if ccode < 0

* Convert to ISO codes and clean
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen
keep warname iso
duplicates drop

* Save CoW extrastate belligerents
gen type = "extra"
tempfile extra_cow_belligerents
save `extra_cow_belligerents', replace


* ==============================================================================
* SECTION 6: Process UCDP intrastate war sites (post-2008)
* ==============================================================================
* Load UCDP conflict data to extend coverage beyond CoW's 2007 cutoff
use "${DIR_DATA_RAW}/ucdp/UcdpPrioConflict_v24_1.dta", clear
destring year, replace
drop if year < 2008  // UCDP covers post-CoW period

* Filter for high-intensity conflicts only
keep if intensity_level == "2"  // Wars (>1000 battle deaths per year)

* Keep intrastate conflict types (1: Internal armed conflict (purely domestic); 2: Internationalized internal armed conflict (external state involvement); 3: Sub-national armed conflicts)
keep if type_of_conflict == "1" | type_of_conflict == "3" | type_of_conflict == "4"

keep conflict_id
rename conflict_id conflict_new_id
destring conflict_new_id, replace
duplicates drop

* Merge with georeferenced event data to get battle deaths by location
merge 1:m conflict_new_id using "${DIR_DATA_RAW}/ucdp/GEDEvent_v24_1.dta", nogen keep(master matched)
keep conflict_new_id country_id year best conflict_name

* Aggregate to conflict-country level
collapse (sum) best (min) start=year (max) end=year (firstnm) conflict_name, by(conflict_new_id country_id)

* Convert country codes to ISO format
rcallcountrycode country_id, from(gwn) to(iso3c) gen(iso)
drop if iso == ""
drop country_id

* Apply casualty threshold and conversion
keep if best >= 1000  // Only major conflicts
gen casualties = best * `batdeath_to_casualties_ratio'
keep if start >= 2008

* Create alternative date variables and clean names
gen start_alt = start
gen end_alt = end
tostring conflict_new_id, replace
rename conflict_name warname
replace warname = "UCDP - " + warname  // Prefix to distinguish from CoW

drop conflict_new_id best

* Note: UCDP has no extrastate conflicts with intensity_level = 2 since 2008
gen type = "intra"

* Save UCDP intrastate war sites
tempfile intra_ucdp_sites
save `intra_ucdp_sites', replace


* ==============================================================================
* SECTION 7: Combine all war sites datasets
* ==============================================================================
* Combine all intrastate and extrastate war sites from different sources
append using `intra_cow_sites'
append using `extra_cow_sites'
save "${DIR_DATA_PROCESSED}/intrastate_sites.dta", replace


* ==============================================================================
* SECTION 8: Prepare UCDP belligerent identification
* ==============================================================================
* Save UCDP war names for belligerent matching
use `intra_ucdp_sites', clear
keep warname
duplicates drop
tempfile intra_ucdp_ids
save `intra_ucdp_ids', replace


* ==============================================================================
* SECTION 9: Process UCDP belligerents (post-2008)
* ==============================================================================
* Load UCDP conflict data to identify state participants in intrastate wars
use "${DIR_DATA_RAW}/ucdp/UcdpPrioConflict_v24_1.dta", clear
keep if type_of_conflict == "3" | type_of_conflict == "4"  // don't include type "1" conflicts as they are purely internal with no external state participation
keep conflict_id gwno_a gwno_a_2nd gwno_b_2nd

* Handle multiple countries per side (comma-separated values)
foreach gwnovar of varlist gwno_a gwno_a_2nd gwno_b_2nd {
	split `gwnovar', p(", ") gen("split_`gwnovar'_")
}

* Convert to numeric
foreach gwnovar of varlist gwno* {
	destring split_*, replace
}

keep conflict_id split_*
destring conflict_id, replace

* Reshape to long format (one observation per country)
local i = 1
foreach var of varlist split_* {
	rename `var' gwno_`i'
	local ++i
}

* Create unique identifiers for reshape
tostring conflict_id, replace
gen n = _n
tostring n, replace
replace conflict_id = conflict_id + "-" + n

reshape long gwno_, i(conflict_id) j(varnum)
split conflict_id, p("-") gen("split")
drop conflict_id split2 varnum n
rename split1 conflict_id
rename gwno_ gwno
drop if gwno == .

* Convert to war names and ISO codes
gen warname = "UCDP-" + conflict_id
rcallcountrycode gwno, from(gwn) to(iso3c) gen(iso)
drop if iso == ""
keep warname iso

* Keep only wars that appear in sites data
merge m:1 warname using `intra_ucdp_ids', nogen keep(matched)
gen type = "intra"


* ==============================================================================
* SECTION 10: Create comprehensive belligerent dataset
* ==============================================================================
* Combine all belligerent sources
append using `intra_cow_belligerents'
append using `extra_cow_belligerents'
duplicates drop

* Merge with site data to ensure consistency
merge 1:1 iso warname using "${DIR_DATA_PROCESSED}/intrastate_sites.dta", keep(master matched using) keepusing(warname type) nogen

* Create final belligerent dataset
keep iso warname type
duplicates drop
gen belligerent = 1
gen outcome = .      // Outcome not available for intrastate wars
gen initiator = .    // Initiator not available for intrastate wars

* Save comprehensive intrastate/extrastate belligerents dataset
save "${DIR_DATA_PROCESSED}/intrastate_belligerents.dta", replace
