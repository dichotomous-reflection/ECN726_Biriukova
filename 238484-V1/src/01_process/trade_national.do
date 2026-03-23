/******************************************************************************
* Construct trade panel using IMF (2015+) and CEPII TRADHIST (historical)
* - Convert currencies (GBP to USD)
* - Deflate to constant 2015 USD
* - Balance panel and take mean between importer and exporter reported trade flows
******************************************************************************/

* ==============================================================================
* SECTION 1: IMF DOTS (Direction of Trade Statistics) - Recent Data (2015+)
* ==============================================================================
import delimited "${DIR_DATA_RAW}/IMF/DOT_03-09-2025 10-54-48-44_timeSeries.csv", clear // dataset has time series data with generic variable names (v1, v2, ...) for years as column headers

* Restore column names (years) for 2010 to 2023
forvalues i = 8/22 {
	local lab: variable label v`i'
	rename v`i' y`lab'
}
drop y

* Keep only actual trade values, not indices or other metrics
keep if attribute == "Value"
keep if indicatorcode == "TXG_FOB_USD" // Total Exports of Goods, FOB (free on board) basis, in US Dollars
drop attribute indicatorname

* Convert IMF country codes of exporting and importing countries to ISO3 country codes for standardization, remove non-unique matches
rcallcountrycode countrycode, from(imf) to(iso3c) gen(exporter)
rcallcountrycode counterpartcountrycode, from(imf) to(iso3c) gen(importer)
keep if importer != "" & exporter != ""
keep importer exporter y*

* Reshape from wide to long format
reshape long y, i(exporter importer) j(year)
rename y value
destring value, replace

* Merge with deflator data to convert current USD to constant 2015 USD
merge m:1 year using "${DIR_DATA_PROCESSED}/deflator.dta", nogen keep(master matched)
replace value = value * conv_USD_cur_to_2015
rename value trade_value

* Keep only data from 2015 onwards
tempfile imf
keep if year > 2014
keep importer exporter trade_value year

* ==============================================================================
* HANDLE MIRROR TRADE STATISTICS PROBLEM
* Trade data has a fundamental issue: Country A's reported exports to B
* often don't match Country B's reported imports from A (due to timing,
* valuation, coverage differences).
* ==============================================================================

* Duplicate data to create mirror flows; each trade flow will be represented twice:
* 1. As reported by the exporter
* 2. As the mirror of what the importer reported
expand 2 // double the number of observations (each flow appears twice)

* Swap importer and exporter for second copy
gen importer_old = importer
replace importer = exporter if _n > _N/2
replace exporter = importer_old if _n > _N/2

* Aggregate to country-pair-year level
* - Sum trade values for each country-pair-year
* - This combines both reported and mirror statistics
* - Take average of reported and mirror statistics and divide by 2, since each flow appears twice (reported + mirror)
* - This gives us the average of what both countries reported
collapse (sum) trade_value, by(importer exporter year)
replace trade_value = trade_value / 2

* ==============================================================================
* AGGREGATE TO NATIONAL LEVEL - Create country-level import totals
* ==============================================================================
preserve
gen double tv = round(trade_value) // round to avoid floating point precision issues
collapse (sum) tv, by(importer year)
rename tv imports
rename importer iso
tempfile imports
save `imports'
restore

* ==============================================================================
* AGGREGATE TO NATIONAL LEVEL - Create country-level export totals
* ==============================================================================
gen double tv = round(trade_value) // round to avoid floating point precision issues
collapse (sum) tv, by(exporter year)
rename tv exports
rename exporter iso

* Combine imports and exports into single dataset
* data structure:
* - rows: one country-year observation
* - columns: iso | year | imports | exports
merge 1:1 iso year using `imports', nogen keep(master matched using)

* Save to file for later use
tempfile imf
save `imf', replace

* ==============================================================================
* SECTION 2: Exchange rate data - British Pound Sterling to US Dollar conversion
* ==============================================================================
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear
keep if iso_o == "USA"
keep XCH_RATE_o year
duplicates drop
sort year

* Calculate GBP to USD conversion rate
gen gbp_cur_to_usd_cur = 1 / XCH_RATE_o
drop XCH_RATE_o

* Save to temporary file for later use
tempfile gbpusd
save `gbpusd', replace

* ==============================================================================
* SECTION 3: Process CEPII bilateral trade flows (historical data pre-2015)
* ==============================================================================
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear

* Convert national totals from British Pounds to USD
merge m:1 year using `gbpusd', nogen keep(master matched)
gen imports = IPTOT_o * gbp_cur_to_usd_cur // IPTOT_o: total imports for origin country (in GBP)
gen exports = XPTOT_o * gbp_cur_to_usd_cur // XPTOT_o: total exports for origin country (in GBP)

* Inflation adjustment: Convert from current USD to constant 2015 USD
merge m:1 year using "${DIR_DATA_PROCESSED}/deflator.dta", nogen keep(master matched)
replace imports = imports * conv_USD_cur_to_2015
replace exports = exports * conv_USD_cur_to_2015

* Aggregate to country-year level
* - Take mean in case of multiple observations per country-year (shouldn't happen, but just in case)
collapse (mean) imports exports, by(iso_o year)

* Rename to match our convention
rename iso_o iso

* ==============================================================================
* SECTION 4: Append modern IMF data to historical CEPII data and export final dataset
* ==============================================================================
append using `imf'
save "${DIR_DATA_PROCESSED}/trade_national.dta", replace
