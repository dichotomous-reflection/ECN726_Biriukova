/******************************************************************************
* Construct capital stock and TFP series from Long-Term Productivity (LTP) database
* - Extract GDP per capita, labor productivity, capital input, TFP
* - Compute capital stock in 2010 PPP using hours worked
* - Merge with population data
******************************************************************************/

* ==============================================================================
* SECTION 1: Define data series and corresponding Excel sheet names
* ==============================================================================
* The LTP database stores different variables in separate Excel sheets
local vars gdppc_ppp lp_ppp ci_ppp tfp
local sheet_gdppc_ppp "GDP per capita"
local sheet_lp_ppp "Labor Productivity"
local sheet_ci_ppp "KI"
local sheet_tfp "TFP"

* ==============================================================================
* SECTION 2: Import and reshape each data series from wide to long format
* ==============================================================================
* Each sheet contains data in wide format (years as rows, countries as columns); we need to reshape to long format (country-year observations)
foreach var in `vars' {
	import excel "${DIR_DATA_RAW}/ltp/BCLDatabase_online_v2.6.xlsx", clear sheet(`sheet_`var'') firstrow
	
	* Clean up the year variable (sometimes imported as "A" column)
	cap rename A Year
	rename Year year_str
	destring year_str, gen(year)
	
	* Drop unnecessary columns
	drop Y EuroArea year_str

	* Rename country columns to include variable prefix; this prevents name conflicts when merging different variables
	foreach col of varlist _all {
		if "`col'" == "year" {
			continue
		}
		rename `col' `var'`col'
	}
	
	* Reshape from wide to long format
	reshape long `var', i(year) j(iso) string

	* Save as temporary file for later merging
	tempfile `var'
	save ``var'', replace
}

* ==============================================================================
* SECTION 3: Merge all LTP series into a single dataset
* ==============================================================================
* Combine all four variables (GDP per capita, labor productivity, capital stock, TFP) into one dataset with country-year observations
local i = 1
foreach var in `vars' {
	if `i' == 1 {
		use ``var'', clear
	}
	else {
		merge 1:1 iso year using ``var'', nogen
	}
	local i = `i' + 1
}

* ==============================================================================
* SECTION 4: Add population data for capital stock calculations
* ==============================================================================
* Merge with population data needed to convert per capita measures to totals
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/pop.dta", nogen

* ==============================================================================
* SECTION 5: Calculate capital stock and derived variables
* ==============================================================================
* Capital stock calculation follows the methodology:
* 1. GDP (total) = GDP per capita × Population
* 2. Total hours worked = GDP (total) / Labor productivity
* 3. Capital stock = Capital input per hour × Total hours worked
gen gdp_ppp = gdppc_ppp * pop
gen total_hours_worked = gdp_ppp / lp_ppp
gen cs_ppp = ci_ppp * total_hours_worked

* ==============================================================================
* SECTION 6: Save final dataset with capital stock and TFP measures
* ==============================================================================
* Keep only the variables needed for further analysis
keep iso year cs_ppp tfp
* Save the processed LTP dataset
save "${DIR_DATA_PROCESSED}/ltp.dta", replace
