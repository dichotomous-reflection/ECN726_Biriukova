/******************************************************************************
* BATTLE NUMBERS AND GPT-4 VALIDATION ANALYSIS
*
* This program generates descriptive statistics and validation metrics used
* throughout the text of the paper.
*
* DATA SOURCES:
* - CoW Inter-State War Data for war information
* - Hand-coded sites Excel file with detailed battle information
* - GPT-4 identification results from automated analysis
* - Processed interstate sites data for validation
*
* OUTPUT:
* - Battle casualty rankings (displayed in console)
* - GPT-4 false positive counts (displayed in console)
* - Correlation statistics between identification methods
******************************************************************************/

local warfile "/handcoded/sites_2025-06-02.xlsx"

* Load CoW interstate war data and merge with ISO country codes
import delimited "${DIR_DATA_RAW}/cow/wars/Inter-StateWarData_v4.0.csv", clear
merge m:1 ccode using "${DIR_DATA_PROCESSED}/linking_cow_iso.dta", keepusing(iso) keep(matched) nogen

* Standardize variable names for consistency
rename startyear1 war_start
rename endyear1 war_end

* Create country-specific war timing (min start, max end for each country)
collapse (min) war_start (max) war_end, by(warname iso)
tempfile wars
save `wars'

* Create overall war timing (across all countries)
collapse (min) war_start (max) war_end, by(warname)
rename war_start start_alt
rename war_end end_alt
tempfile wars_start_alt
save `wars_start_alt'

* Get list of all wars from the overview sheet to process individual war sheets
import excel "${DIR_DATA_RAW}/`warfile'", clear sheet("Overview") firstrow
keep War
drop if War == ""
rename War warname

* Create list of war names for processing
levelsof warname, local(warnames)

* ==============================================================================
* PROCESS BATTLE DATA FOR EACH WAR
* ==============================================================================
* Loop through each war sheet to extract and process battle casualty data
* ==============================================================================

* Initialize progress indicator and counters
_dots 0, title(Loop running) reps(77)               // Progress dots display
local i = 1                                         // War counter
local n_battles = 0                                 // Total battle counter

foreach warname in `warnames' {
	quietly {
		* Each war has its own sheet with detailed battle information
		import excel "${DIR_DATA_RAW}/`warfile'", clear sheet("`warname'") firstrow
		rename war_cow warname
		drop if warname == ""

		* Some battles involve multiple countries (listed as "ISO1,ISO2,ISO3"), divide casualties equally among all countries involved
		gen id = _n                                                      // Create unique identifier
		gen nisos = length(iso) - length(subinstr(iso, ",", "", .)) + 1  // Count countries (commas + 1)
		split iso, p(",")                                                // Split comma-separated ISO codes

		* Reshape from wide to long format (one observation per country)
		drop iso
		reshape long iso, i(id)
		drop if iso == ""
		
		* Allocate casualties equally across countries, divide casualties by number of countries
		replace number = number / nisos
		
		* Count total battles and filter for relevant battle-level data
		levelsof level_detail, local(levels_cur)         // Get unique battle identifiers
		local n_battles_cur: word count `levels_cur'     // Count battles in current war
		local n_battles = `n_battles' + `n_battles_cur'  // Add to total battle count
		
		* Keep only relevant variables for analysis
		keep warname iso level level_detail start end number remote 
		drop if remote == 1
		keep if level == "battle"
		
		* Sum casualties across countries for each specific battle
		keep number warname level_detail            // Keep only variables needed for aggregation
		if _N > 0 {
			collapse (sum) number, by(warname level_detail)
		}
		
		* Save processed data for current war
		tempfile war_`i'
		save `war_`i'', replace
	}
	local i = `i' + 1                               // Increment war counter
	_dots `i' 0                                     // Update progress display
}

* Append all individual war datasets and rank battles by casualty numbers
local i = 1
foreach warname in `warnames' {
	if `i' == 1 {
		use `war_`i'', clear
	}
	else {
		append using `war_`i'', force
	}	
	local i = `i' + 1
}

* Rank battles by casualty numbers (highest first)
gsort -number

* Display bloodiest battles (output will show in console)
list warname level_detail number in 1/100, clean

* Save 100 bloodiest battles to text file
capture file close battlefile
file open battlefile using "${DIR_DATA_EXPORTS}/bloodiest_battles.txt", write replace
file write battlefile "Top 100 Bloodiest Battles by Casualty Numbers" _n
file write battlefile "=============================================" _n
file write battlefile _n
file write battlefile "War Name" _tab "Battle Detail" _tab "Casualties" _n
file write battlefile "--------" _tab "-------------" _tab "---------" _n
forvalues i = 1/100 {
	if `i' <= _N {
		local war = warname[`i']
		local battle = level_detail[`i']
		local casualties = number[`i']
		file write battlefile "`war'" _tab "`battle'" _tab %12.0fc (`casualties') _n
	}
}
file close battlefile

* ==============================================================================
* Compare GPT-4-identified war sites with hand-coded sites to assess accuracy
* ==============================================================================

* Load processed interstate sites data as the "ground truth"
use "${DIR_DATA_PROCESSED}/sites_interstate.dta", clear
keep warname iso
tempfile sites
gen site_handcoded = 1
save `sites', replace

* Identify sites that GPT flagged but were not hand-coded; these represent potential false positive identifications
import excel "${DIR_DATA_RAW}/handcoded/gpt.xlsx", clear firstrow
keep if site_gpt == 1
keep warname iso

* Find GPT sites that are NOT in hand-coded sites (false positives)
merge 1:1 warname iso using `sites', keep(master)   // Keep only unmatched (GPT-only) sites

* Display false positive count
display "Number of false positive by GPT: ", _N

* ==============================================================================
* Compute correlation between GPT and hand-coded site identification
* ==============================================================================

* Create dataset with both GPT and hand-coded indicators for all sites
import excel "${DIR_DATA_RAW}/handcoded/gpt.xlsx", clear firstrow
keep warname iso start_alt site_gpt
merge 1:1 warname iso using `sites', keep(master matched)
replace site_handcoded = 0 if site_handcoded == .

* Compute correlation coefficient
pwcorr site_gpt site_handcoded, star(0.001)

* Save correlation results to text file
capture file close corrfile
file open corrfile using "${DIR_DATA_EXPORTS}/gpt_handcoded_correlation.txt", write replace
file write corrfile "Correlation between GPT and hand-coded site identification" _n
file write corrfile "============================================================" _n
quietly pwcorr site_gpt site_handcoded
local corr = r(C)[2,1]
file write corrfile "Correlation coefficient: " %9.4f (`corr') _n
file write corrfile "Number of observations: " (r(N)) _n
file close corrfile
