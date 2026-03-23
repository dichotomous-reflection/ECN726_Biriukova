/******************************************************************************
* WORLD MAP OF WAR SITES DISTRIBUTION
*
* This program creates a world map visualization showing the geographic
* distribution of war sites by country. Countries are color-coded based on
* the total number of wars they have experienced.
*
* MAIN OUTPUTS:
* 1. PDF world map with countries colored by war frequency
* 2. CSV file with country-level war counts for further analysis
*
* DATA SOURCES:
* - Processed war sites data for conflict counts by country
* - Natural Earth shapefile for country boundaries and geographic data
*
* COLOR SCHEME:
* - Gray: 0 wars
* - Light purple: 1-2 wars
* - Medium purple: 3-5 wars
* - Dark purple: >5 wars
******************************************************************************/

* ==============================================================================
* STEP 1: PREPARE WAR SITES COUNT DATA
* ==============================================================================
* Count the total number of wars experienced by each country and prepare
* the data for merging with geographic boundaries
* ==============================================================================

* Load processed war sites data
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear

* Count total number of wars per country
collapse (count) start, by(iso)

* Standardize country code variable name for merging with shapefile
rename iso ISO_A3_EH      // Match Natural Earth shapefile convention
rename start n_sites      // Rename to more descriptive variable name

* Save war counts data for merging with geographic data
tempfile sites_count
save `sites_count', replace

* ==============================================================================
* STEP 2: LOAD AND PREPARE GEOGRAPHIC DATA
* ==============================================================================
* Load Natural Earth shapefile containing country boundaries and geographic
* information, then merge with war sites count data
* ==============================================================================

* Clear memory for loading geographic data
clear

* Convert Natural Earth shapefile to Stata format
* This creates a geographic dataset with country boundaries and attributes
spshape2dta "${DIR_RESSOURCES}/ne_50m_admin_0_countries/ne_50m_admin_0_countries.shp", replace saving(countries)

* Create geoframe for mapping functionality
geoframe create countries, replace

* Switch to the countries frame for data manipulation
frame change countries

* ==============================================================================
* STEP 3: MERGE WAR DATA WITH GEOGRAPHIC DATA
* ==============================================================================

* Merge war sites count with country geographic data
merge m:1 ISO_A3_EH using `sites_count', keep(master matched)

* Set countries with no wars to zero (missing values become 0)
replace n_sites = 0 if n_sites == .

* ==============================================================================
* STEP 4: CREATE WAR FREQUENCY CATEGORIES
* ==============================================================================
gen color = "purple"

* Sort by number of wars for processing
sort n_sites

* Create discrete categories for war frequency
replace n_sites = 2 if n_sites < 3 & n_sites > 0
replace n_sites = 3 if n_sites <= 5 & n_sites >= 3
replace n_sites = 4 if n_sites > 5

* ==============================================================================
* STEP 5: CREATE WORLD MAP VISUALIZATION
* ==============================================================================
* Remove Antarctica (not relevant for war analysis and clutters map)
drop if REGION_WB == "Antarctica"

* Generate a choropleth map showing war frequency by country using different shades of purple, with appropriate legend and formatting
geoplot ///
    (area countries n_sites, ///                                           // Plot country areas colored by war count
        color("gray%30" "purple%55" "purple%70" "purple%85" "purple%100") ///
        discrete) ///                                                      // Use discrete color categories
    , ///
    tight ///                                                              // Tight layout (minimal margins)
    legend(order(1 "0 wars" 2 "1-2 wars" 3 "3-5 wars" 4 ">5 wars") ///     // Legend labels for categories
        position(sw) ///                                                   // Legend position (southwest)
        bplacement(neast) ///                                              // Legend box placement
        region(lcolor(gray%50) lwidth(vthin))) ///                         // Legend border styling
    scale(*2) ///                                                          // Overall scale factor
    graphregion(lstyle(solid) ///                                          // Graph region border style
        lcolor("gray%90") ///                                              // Graph border color
        lwidth(vvvthin) ///                                                // Graph border width
        margin(0.2 1 2 0.3))                                               // Graph margins (top right bottom left)

* ==============================================================================
* STEP 7: EXPORT RESULTS
* ==============================================================================

* Export world map as PDF
graph export "${DIR_DATA_EXPORTS}/figures/descriptives/worldmap.pdf", as(pdf) replace
graph close

* Export country-level war counts as CSV for further analysis
export delimited "${DIR_DATA_EXPORTS}/figures/descriptives/worldmap.csv", replace
