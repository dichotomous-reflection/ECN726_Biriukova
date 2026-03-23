/******************************************************************************
* WAR SITES AND ADJACENT COUNTRIES DISTRIBUTION ANALYSIS
*
* This program analyzes the temporal distribution of war sites and countries
* adjacent to war zones. It creates visualizations showing how the number of
* countries experiencing wars and their neighbors varies over time (1870-2024).
*
* MAIN OUTPUTS:
* 1. Bar chart showing war sites and adjacent countries over time
* 2. CSV file with the time series data
* 3. Summary statistics on relative frequency of being a war site or adjacent
*
* DATA SOURCES:
* - CEPII TRADHIST for country list and contiguity information
* - Processed war sites data for conflict locations and timing
******************************************************************************/

* ==============================================================================
* STEP 1: DETERMINE TOTAL NUMBER OF COUNTRIES IN SAMPLE
* ==============================================================================
* Use the most recent year from CEPII trade data to get the complete list
* of countries in the analysis sample
* ==============================================================================

* Load CEPII trade data to get country list
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear

* Find the most recent year in the dataset
sum year
local max_year = r(max)

* Keep only the most recent year to get complete country list
keep if year == `max_year'
drop if iso_o == "" | iso_d == ""  // Remove observations with missing country codes

* Get unique list of origin countries (represents all countries in sample)
duplicates drop iso_o, force
local n_countries = _N  // Store total number of countries for probability calculations

* ==============================================================================
* STEP 2: PREPARE CONTIGUITY DATA
* ==============================================================================
* Extract information about which countries are geographically adjacent
* (share a land border) for identifying countries adjacent to war zones
* ==============================================================================

* Load CEPII trade data again for contiguity information
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear
keep if year == `max_year'
drop if iso_o == "" | iso_d == ""

* Standardize variable names for country pairs
rename iso_o iso1     // Origin country
rename iso_d iso2     // Destination country
rename Contig contig  // Contiguity indicator

* Keep only contiguity information
keep iso1 iso2 contig

* Keep only country pairs that are geographically contiguous (share border)
keep if contig == 1

* Save contiguity data for later use
tempfile contig
save `contig'

* ==============================================================================
* STEP 3: CREATE WAR SITES TIME SERIES
* ==============================================================================
* Process war sites data to create a time series showing the number of
* countries experiencing wars in each year
* ==============================================================================

* Load processed war sites data
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear
keep iso start end
duplicates drop iso start, force  // Remove duplicate war-country combinations

* Prepare data for expansion into annual panel
gen warid = _n                    // Unique identifier for each war-country combination
gen length = end - start + 1      // Duration of each war in years
gen year = start                  // Starting year
drop start end

* Expand dataset to create one observation per country-year during wars
expand length
bysort warid: replace year = year[_n-1] + 1 if _n > 1  // Fill in years for each war
keep iso year

* Clean up and restrict time period
duplicates drop              // Remove duplicate country-year combinations
keep if year <= 2024         // Restrict to analysis period

* Save expanded war sites data
tempfile sites
save `sites', replace

* Count number of war sites per year
gen n_sites = 1
collapse (count) n_sites, by(year)
tempfile sites_count
save `sites_count', replace

* ==============================================================================
* STEP 4: CREATE BALANCED TIME SERIES FOR WAR SITES
* ==============================================================================
* Create a complete time series from 1870-2024 with zeros for years without any war sites
* ==============================================================================

* Create balanced annual panel for analysis period
clear
local start 1870
local end 2024
local nYears = `end' - `start' + 1

* Create observations for each year in the analysis period
set obs `nYears'
gen year = `start' + _n - 1

* Merge with war sites count data
merge 1:1 year using `sites_count', nogen
replace n_sites = 0 if n_sites == .  // Set missing years to zero war sites

* Save balanced war sites time series
save `sites_count', replace

* ==============================================================================
* STEP 5: CREATE ADJACENT COUNTRIES TIME SERIES
* ==============================================================================
* Identify countries that are geographically adjacent to war zones and
* create a time series showing their count over time
* ==============================================================================

* Load war sites data for adjacent countries analysis
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear
rename iso iso1  // Standardize name for joining with contiguity data

* Join with contiguity data to find countries adjacent to war sites
joinby iso1 using `contig'

* Rename variables for clarity
rename iso1 iso_home  // Country where war occurred
rename iso2 iso       // Country adjacent to war site

* Keep only timing and country information
keep start end iso

* Expand war periods into annual observations for adjacent countries
gen warid = _n                    // Unique identifier
gen length = end - start + 1      // War duration
gen year = start                  // Starting year
drop start end

* Create one observation per adjacent country-year during wars
expand length
bysort warid: replace year = year[_n-1] + 1 if _n > 1  // Fill in war years
keep iso year
duplicates drop  // Remove duplicate adjacent country-year combinations

* Count number of adjacent countries per year
gen n_adjacent = 1
collapse (count) n_adjacent, by(year)

* Merge with war sites time series (keep only years with data for both)
merge 1:1 year using `sites_count', keep(matched) nogen

* ==============================================================================
* STEP 6: CREATE DISTRIBUTION VISUALIZATION
* ==============================================================================
* Generate a bar chart showing the temporal distribution of war sites and
* adjacent countries from 1870-2024
* ==============================================================================

* Create overlapping bar chart showing war sites and adjacent countries over time
twoway ///
	(bar n_adjacent year, color(red) barwidth(0.8)) ///        // Adjacent countries (red bars)
	(bar n_sites year, color(purple) barwidth(0.8)), ///       // War sites (purple bars, overlapping)
	xla(1880(20)2020, nogrid) ///                              // X-axis labels every 20 years
	legend(order(2 "War sites" 1 "Adjacent countries") ///     // Legend order and labels
		position(0) bplacement(nwest) ///                        // Legend position (northwest)
		region(lcolor(gray%50))) ///                             // Legend border
	yla(0(20)100) ///                                          // Y-axis labels every 20 units
	ysc(r(0(10)100)) ///                                       // Y-axis scale range
	plotregion(margin(zero)) ///                               // Plot region margins
	xtitle("") ///                                             // No x-axis title
	xsize(8) ysize(3) ///                                      // Graph dimensions
	scale(*1.6) ///                                            // Scale factor
	graphregion(margin(-8 3 -4 3))                             // Graph region margins

* ==============================================================================
* STEP 7: EXPORT RESULTS
* ==============================================================================
* Save the visualization and data, then calculate summary statistics
* ==============================================================================

* Export graph as PDF
graph export "${DIR_DATA_EXPORTS}/figures/descriptives/distribution.pdf", as(pdf) replace
graph close

* Export time series data as CSV
export delimited "${DIR_DATA_EXPORTS}/figures/descriptives/distribution.csv", replace

* ==============================================================================
* STEP 8: CALCULATE RELATIVE FREQUENCY STATISTICS
* ==============================================================================
* Calculate frequency relative to total number of countries
gen prob_site = n_sites / `n_countries'           // Probability of being a war site
gen prob_adjacent = n_adjacent / `n_countries'    // Probability of being adjacent to war

collapse (mean) prob_site prob_adjacent

* Display summary statistics
nois disp "Relative frequency of being site: ", prob_site[1]
nois disp "Relative frequency of being adjacent: ", prob_adjacent[1]

* Export summary statistics to text file (because main.do calls distribution.do quietly)
file open results using "${DIR_DATA_EXPORTS}/figures/descriptives/distribution_numbers_paper.txt", write replace
file write results "WAR DISTRIBUTION SUMMARY STATISTICS" _n
file write results "====================================" _n
file write results "Relative frequency of being site: " %6.4f (prob_site[1]) _n
file write results "Relative frequency of being adjacent: " %6.4f (prob_adjacent[1]) _n
file write results "====================================" _n
file close results
