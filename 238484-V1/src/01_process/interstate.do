/******************************************************************************
* INTERSTATE WAR DATA PROCESSING
* This script constructs comprehensive datasets of interstate war sites and 
* belligerents by combining data from multiple sources:
* - Correlates of War (CoW) Interstate War Data v4.0
* - Hand-coded war sites with detailed battle locations and casualties
* - GPT-identified additional war sites for completeness
* 
* Output datasets:
* 1. interstate_sites.dta - War sites with locations, dates, and casualties
* 2. interstate_belligerents.dta - All countries that participated in interstate wars
******************************************************************************/

* ==============================================================================
* SECTION 1: Load GPT-identified additional war sites
* ==============================================================================
import excel "${DIR_DATA_RAW}/handcoded/gpt.xlsx", clear firstrow
keep if site_revised == 1  // Only keep sites that have been reviewed and approved
tempfile sites_gpt
save `sites_gpt', replace

* ==============================================================================
* SECTION 2: Extract war metadata from CoW Interstate War Data
* ==============================================================================
import delimited "${DIR_DATA_RAW}/cow/wars/Inter-StateWarData_v4.0.csv", clear
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen

* Clean up war start and end dates (some wars have multiple phases)
rename startyear1 war_start
rename endyear1 war_end
replace war_end = endyear2 if endyear2 > 0  // Use second end year if available

* Create country-specific war dates (when each country entered/exited)
collapse (min) war_start (max) war_end, by(warname iso)
tempfile wars
save `wars'

* Create overall war dates (earliest start, latest end across all participants)
collapse (min) war_start (max) war_end, by(warname)
rename war_start start_alt
rename war_end end_alt
tempfile wars_start_alt
save `wars_start_alt'

* ==============================================================================
* SECTION 3: Load hand-coded war sites data containing detailed battle data
* ==============================================================================
local warfile "/handcoded/sites_2025-06-02.xlsx"
import excel "${DIR_DATA_RAW}/`warfile'", clear sheet("Overview") firstrow
keep War
drop if War == ""
rename War warname

* Get list of all wars to loop through (each war has its own sheet)
levelsof warname, local(warnames)

* Initialize progress tracker and battle counter
_dots 0, title(Loop running) reps(77)
local i = 1
local n_battles = 0

* ==============================================================================
* SECTION 4: Extract battle data from each war sheet
* ==============================================================================
* Loop through each war's sheet and extract detailed battle information
foreach warname in `warnames' {
	quietly {
		* Load data from the specific war's sheet
		import excel "${DIR_DATA_RAW}/`warfile'", clear sheet("`warname'") firstrow
		rename war_cow warname
		drop if warname == ""

		* Handle multiple countries per battle (comma-separated ISO codes)
		gen id = _n
		gen nisos = length(iso) - length(subinstr(iso, ",", "", .)) + 1  // Count number of countries
		split iso, p(",")  // Split comma-separated country codes
		drop iso
		reshape long iso, i(id)  // Create one observation per country-battle
		drop if iso == ""

		* Distribute casualties equally among participating countries
		replace number = number / nisos

		* Track total number of battles for reporting
		levelsof level_detail, local(levels_cur)
		local n_battles_cur: word count `levels_cur'
		local n_battles = `n_battles' + `n_battles_cur'

		* Keep relevant variables and exclude remote/naval battles
		keep warname iso level start end number remote
		drop if remote == 1

		* Prioritize disaggregated battle data over total estimates
		preserve
		keep if level == "battle"
		local hasbattles = (_N > 0)
		restore

		* If we have individual battle data, drop total estimates to avoid double-counting
		if "`hasbattles'" == "1" {
			drop if level == "total"
		}
		drop if level == "total_entire"  // Always drop entire war totals

		* Aggregate to country-war level
		collapse (min) start (max) end (sum) number, by(warname iso)
		rename number casualties

		* Save as temporary file
		tempfile war_`i'
		save `war_`i'', replace
	}
	local i = `i' + 1
	_dots `i' 0
}

* ==============================================================================
* SECTION 5: Combine all war datasets
* ==============================================================================
* Append all individual war datasets into one comprehensive dataset
local i = 1
foreach warname in `warnames' {
	if `i' == 1 {
		use `war_`i'', clear
	}
	else {
		append using `war_`i''
	}
	local i = `i' + 1
}

* Display total number of battles processed
nois disp `n_battles'

* ==============================================================================
* SECTION 6: Add GPT-identified war sites
* ==============================================================================
* Process and append GPT-identified sites that weren't in hand-coded data
preserve
merge 1:1 warname iso using `sites_gpt', keep(using) keepusing(start casualties) nogen
keep warname iso start casualties
* Add war end dates from CoW data
merge m:1 warname using `wars_start_alt', keep(master matched) keepusing(end_alt) nogen
rename end_alt end
save "${DIR_DATA_PROCESSED}/interstate_sites_gpt.dta", replace
restore

* Append GPT sites to main dataset
append using "${DIR_DATA_PROCESSED}/interstate_sites_gpt.dta"
*keep if casualties != .

* ==============================================================================
* SECTION 7: Complete missing dates using CoW war data
* ==============================================================================
merge m:1 warname iso using `wars', keep(master matched)
replace start = war_start if start == .  // Use country-specific war start if missing
replace end   = war_end if end == .      // Use country-specific war end if missing
replace end   = start if end == .        // If still missing, assume single-year war
keep warname iso start end casualties

* Add alternative start dates for robustness checks
merge m:1 warname using `wars_start_alt', nogen keep(master matched)
replace start_alt = 2022 if warname == "Russo-Ukrainian"  // Manual correction for recent war
gen type = "inter"                                        // Mark as interstate war

* Use alternative start date if primary is still missing
replace start = start_alt if start == .

* Save the complete interstate war sites dataset
save "${DIR_DATA_PROCESSED}/interstate_sites.dta", replace


/******************************************************************************
* BELLIGERENT IDENTIFICATION
* This section creates a comprehensive list of all countries that participated
* in interstate wars by combining CoW official belligerent data with countries
* identified in hand-coded and GPT war sites data.
******************************************************************************/

* ==============================================================================
* SECTION 8: Extract official belligerents from CoW data
* ==============================================================================
import delimited "${DIR_DATA_RAW}/cow/wars/Inter-StateWarData_v4.0.csv", clear
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen

* Handle countries with multiple war outcomes (e.g., changed sides)
egen ndistinct = nvals(outcome), by(warname iso)

* Mark countries with multiple distinct outcomes as "unclear" (outcome = 6)
replace outcome = 6 if ndistinct > 1

* Keep the last recorded initiator and outcome status for each country-war
collapse (lastnm) initiator outcome, by(warname iso)
tempfile cow
save `cow', replace

* ==============================================================================
* SECTION 9: Combine all sources to create comprehensive belligerent list
* ==============================================================================
* Start with countries identified in war sites data
use "${DIR_DATA_PROCESSED}/interstate_sites.dta", clear
keep warname iso

* Manual addition: Add Russia as belligerent to Russo-Ukrainian war
* (may not be captured in sites data if battles are ongoing/classified)
set obs `=_N+1'
replace warname = "Russo-Ukrainian" if _n == _N
replace iso = "RUS" if _n == _N

* Combine with official CoW belligerents
append using `cow'

* Resolve duplicates by prioritizing CoW data (which has outcome information)
duplicates tag warname iso, gen(dup)
drop if dup > 0 & outcome == .  // Drop site-only entries if CoW data exists
duplicates drop
sort warname iso
drop dup

* Mark all as belligerents and interstate wars
gen belligerent = 1
gen type = "inter"

* Save the comprehensive interstate war belligerents dataset
save "${DIR_DATA_PROCESSED}/interstate_belligerents.dta", replace
