/******************************************************************************
* Construct trade panel using IMF (2015+) and CEPII TRADHIST (historical)
* - Convert currencies (GBP to USD)
* - Deflate to constant 2015 USD
* - Balance panel and impute missing trade flows using gravity estimation
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

* Keep only data from 2015 onwards and save to temporary file
tempfile imf
keep if year > 2014
keep importer exporter trade_value year
save `imf'

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
* SECTION 3: Generate proximity measures from bilateral distances
* ==============================================================================
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear
rename Distw distw

* Collapse to country-pair level (data may have multiple years per pair) and take minimum distance and maximum contiguity (border sharing) indicator
collapse (min) distw (max) Contig, by(iso_o iso_d)
rename iso_o importer
rename iso_d exporter

* Calculate summary statistics for distance and proximity and save to temporary file
sum distw
gen proximity = Contig
tempfile distances
save `distances', replace

* ==============================================================================
* SECTION 4: Process CEPII bilateral trade flows (historical data pre-2015)
* ==============================================================================
use "${DIR_DATA_RAW}/cepii/TRADHIST_v4.dta", clear

* Convert trade values from British Pounds to USD
merge m:1 year using `gbpusd', nogen keep(master matched)
gen trade_value = FLOW * gbp_cur_to_usd_cur

* Inflation adjustment: Convert from current USD to constant 2015 USD
merge m:1 year using "${DIR_DATA_PROCESSED}/deflator.dta", nogen keep(master matched)
replace trade_value = trade_value * conv_USD_cur_to_2015

* Handle "likely zero" trade flows
sum trade_value
replace trade_value = FLOW_0 if FLOW_0 == 0 & FLOW == . // if FLOW is missing but FLOW_0 is zero, this represents actual zero trade flows
sum trade_value

* Rename to match our convention
rename iso_o exporter
rename iso_d importer

* Keep only necessary variables
keep importer exporter year trade_value
keep if year >= 1869

* Append the modern IMF data to historical CEPII data
append using `imf'

* ==============================================================================
* SECTION 5: Balance the panel (create all possible country-pair-year combinations)
* ==============================================================================
* Fill in all possible combinations of importer, exporter, and year
drop if importer == "" | exporter == ""
*egen dyadid = group(impexp)
fillin importer exporter year
sort importer exporter year
drop if importer == exporter // remove self-trade observations

* ==============================================================================
* SECTION 6: Impute missing trade values using gravity model estimation
* ==============================================================================
* Create a unique identifier for each country-pair (i.e. dyad)
gen impexp = importer + exporter

* Create year-specific identifiers for fixed effects
tostring year, gen(year_str)
gen impyear = importer + year_str
gen expyear = exporter + year_str
drop year_str

* Define which fixed effects to use in the final model
*local fes impexp impyear expyear // using dyad, importer-year, and exporter-year fixed effects
local fes impexp year             // using dyad and year fixed effects

* Set random seed for reproducibility (affects estimation algorithms)
set seed 0

* Sort data (can affect some estimation procedures)
sort importer exporter year trade_value

* Clear any stored estimation results
eststo clear

* ==== ESTIMATE SERIES OF GRAVITY MODELS ====
* ppmlhdfe: Poisson Pseudo-Maximum Likelihood (PPML) with High-Dimensional Fixed Effects

* Model 1: Baseline PPML with just a constant (no fixed effects)
eststo: ppmlhdfe trade_value, d
local r2 = round(e(r2_p), 0.01) // pseudo R-squared
estadd scalar r2 `r2'

* Model 2: PPML with year fixed effects
eststo: ppmlhdfe trade_value, absorb(year) d
local r2 = round(e(r2_p), 0.01) // pseudo R-squared
estadd scalar r2 `r2'
estadd local fe_year "\checkmark" // indicator for table that year FE were included

* Model 3: PPML with importer and exporter fixed effects
eststo: ppmlhdfe trade_value, absorb(importer exporter) d
local r2 = round(e(r2_p), 0.01) // pseudo R-squared
estadd scalar r2 `r2'
estadd local fe_importer "\checkmark" // indicator for table that importer FE were included
estadd local fe_exporter "\checkmark" // indicator for table that exporter FE were included

* Model 4: PPML with dyad (country-pair) fixed effects
eststo: ppmlhdfe trade_value, absorb(impexp) d
local r2 = round(e(r2_p), 0.01) // pseudo R-squared
estadd scalar r2 `r2'
estadd local fe_impexp "\checkmark" // indicator for table that dyad FE were included

* Model 5: PPML with dyad and year fixed effects (PREFERRED MODEL), savefe option is used to store the fixed effects
eststo: ppmlhdfe trade_value, absorb(`fes', savefe) d
local r2 = round(e(r2_p), 0.01) // pseudo R-squared
estadd scalar r2 `r2'
estadd local fe_impexp "\checkmark" // indicator for table that dyad FE were included
estadd local fe_year "\checkmark"   // indicator for table that year FE were included

* Generate predictions using the built-in predict function
predict trade_value_pred_builtin

* Aggregate coefficients
gen coeff_agg = r(table)["b", "_cons"]

* Rename the saved fixed effects variables to meaningful names (ppmlhdfe saves FEs as __hdfe1__, __hdfe2__, etc.)
local i = 1
foreach fe in `fes' {
	rename __hdfe`i'__ __hdfe_`fe'__
	local ++i
}

* IMPUTATION STRATEGY
* - For each fixed effect type, fill in missing values within groups; this copies the FE coefficient down within each group
foreach fe in `fes' {
	bysort `fe' (__hdfe_`fe'__): replace __hdfe_`fe'__ = __hdfe_`fe'__[_n-1] if _n > 1
}

* Aggregate fixed effects coefficients
gen fe_agg = 0
foreach fe in `fes' {
	replace fe_agg = fe_agg + __hdfe_`fe'__
	drop __hdfe_`fe'__
}

* Save original trade values before imputation
rename trade_value trade_value_notimp

* Generate imputed trade values using the PPML prediction formula, i.e. exp(sum of fixed effects coefficients + constant)
gen trade_value = exp(fe_agg + coeff_agg)

* Keep only necessary variables
keep importer exporter year trade_value trade_value_notimp

* Use original values where available, imputed values for missing
replace trade_value = trade_value_notimp if trade_value_notimp != .

* ==============================================================================
* SECTION 7: Merge proximity data and export final dataset
* ==============================================================================
* Add distance and proximity measures to the final dataset
merge m:1 importer exporter using `distances', nogen keep(master matched)
save "${DIR_DATA_PROCESSED}/trade_gravity.dta", replace

* ==============================================================================
* SECTION 8: Export regression tables for LaTeX
* ==============================================================================
* Export table body with fixed effects indicators
esttab using "${DIR_DATA_EXPORTS}/tables/trade_gravity_body.tex", ///
    stats(fe_year fe_importer fe_exporter fe_impexp, ///
    labels("Year FE" "Importer FE" "Exporter FE" "Importer \(\times\) Exporter FE") ///
    fmt(1 1 1 1)) ///
    tex fragment nomtitles nonumbers se varlabels(_cons "Constant") posthead("")  replace

* Export table footer with R-squared and sample size
esttab using "${DIR_DATA_EXPORTS}/tables/trade_gravity_footer.tex", ///
    stats(r2 N, labels("Pseudo \(R^2\)" "N") fmt(%9.2fc %15.0fc)) drop(_cons) ///
    tex fragment nomtitles nonumbers replace prefoot("") posthead("")
