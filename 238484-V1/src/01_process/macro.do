/******************************************************************************
* MACROECONOMIC PANEL DATA CONSTRUCTION
* This script constructs a comprehensive country-year macroeconomic panel dataset
* by combining data from multiple sources:
* - Global Macro Database (GMD): unemployment and interest rates
* - V-Dem: nationalism measures
* - World Bank: GDP, population, inflation (2019+)
* - PLE dataset: long-run GDP, inflation, institutions (pre-2019)
* - JST Macrohistory: equity and capital returns
* - Our World in Data: fertility rates
* - Various processed datasets: trade, military expenditure, mortality
******************************************************************************/

* ==============================================================================
* SECTION 1: Global Macro Database - Interest Rates and Unemployment
* ==============================================================================
use "${DIR_DATA_RAW}/globalmacrodatabase/GMD.dta", clear
rename ISO3 iso
winsor2 cbrate, cuts(0 99) replace  // Winsorize central bank rate
replace cbrate = cbrate / 100       // Central bank rate (convert from percentage)
replace strate = strate / 100       // Short-term rate (convert from percentage)
replace ltrate = ltrate / 100       // Long-term rate (convert from percentage)
replace unemp  = unemp / 100        // Unemployment rate (convert from percentage)

* Keep relevant variables and save as temporary file
keep iso year cons_GDP unemp cbrate strate ltrate CA_GDP HPI govtax_GDP
tempfile gmd
save `gmd', replace

* ==============================================================================
* SECTION 2: V-Dem - Nationalism Index
* ==============================================================================
use "${DIR_DATA_RAW}/vdem/V-Dem-CY-FullOthers-v15_dta/V-Dem-CY-Full+Others-v15.dta", clear
rename v2exl_legitideolcr_0 nationalism
rename country_text_id iso
keep iso year nationalism
tempfile vdem
save `vdem', replace

* ==============================================================================
* SECTION 3: World Bank - GDP per capita (2015 benchmark)
* ==============================================================================
import delimited "${DIR_DATA_RAW}/worldbank/gdppc/API_NY.GDP.PCAP.KD_DS2_en_csv_v2_5871612.csv", clear varnames(4)
foreach var of varlist v* {
    rename `var' y`:var lab `var''
}
drop y
keep countrycode y*
reshape long y, i(countrycode) j(year)
rename y gdppc2015
keep if year == 2015
drop year
rename countrycode iso

* Manual addition: Taiwan not reported in World Bank; use IMF estimate
local N = _N + 1
set obs `N'
replace iso = "TWN" if _n == _N
replace gdppc2015 = 22750 if _n == _N

tempfile gdppc
save `gdppc', replace

* ==============================================================================
* SECTION 4: World Bank recent data (2019+) - GDP, population, inflation
* ==============================================================================
* For recent years (2019+), use World Bank data instead of PLE to ensure up-to-date coverage
import delimited "${DIR_DATA_RAW}/worldbank/gdp/API_NY.GDP.MKTP.KD_DS2_en_csv_v2_740095.csv", clear varnames(4)
foreach var of varlist v* {
    rename `var' y`:var lab `var''
}
drop y
keep countrycode y*
reshape long y, i(countrycode) j(year)
rename y gdp
rename countrycode iso

* Save complete GDP series and extract recent years
save "${DIR_DATA_PROCESSED}/macro_gdp_wb.dta", replace
keep if year >= 2019
tempfile gdp_wb
save `gdp_wb', replace

* Load population data for recent years
use "${DIR_DATA_PROCESSED}/pop.dta", clear
keep if year >= 2019
tempfile pop_wb
save `pop_wb', replace

* Load inflation data (CPI annual percentage change)
import delimited "${DIR_DATA_RAW}/worldbank/inflation/API_FP.CPI.TOTL.ZG_DS2_en_csv_v2_740199.csv", clear varnames(4)
foreach var of varlist v* {
    rename `var' y`:var lab `var''
}
drop y
keep countrycode y*
reshape long y, i(countrycode) j(year)
rename y inflation
replace inflation = inflation / 100
keep if year >= 2019
rename countrycode iso

* Combine all World Bank recent data
merge 1:1 iso year using `gdp_wb', nogen
merge 1:1 iso year using `pop_wb', nogen

tempfile wb_all
save `wb_all'

* ==============================================================================
* SECTION 5: PLE Dataset - Long-run historical data (pre-2019)
* ==============================================================================
* The PLE dataset provides long-run GDP, inflation, and institutional measures
* Use this for historical data and combine with World Bank for recent years
use "${DIR_DATA_RAW}/ple/ple_dataset.dta", clear
keep iso year fstgdp inflation institutions judicial electoral medial

* Convert log inflation to level (PLE stores inflation in logs)
rename inflation linflation
gen inflation = exp(linflation) - 1
drop linflation

* Normalize real GDP per capita index to 2015 = 1, because PLE provides an index and we need to convert it to 2015 USD levels
gen tmp = fstgdp if year == 2015
bysort iso: egen fstgdp2015 = max(tmp)
drop tmp
replace fstgdp = fstgdp / fstgdp2015
drop fstgdp2015

* Convert normalized index to real GDP per capita in 2015 USD
merge m:1 iso using `gdppc', nogen keep(matched)
gen gdppc = fstgdp * gdppc2015
drop gdppc2015 fstgdp

* Convert per capita GDP to total GDP using population
merge m:1 iso year using "${DIR_DATA_PROCESSED}/pop.dta", nogen keep(master matched)
gen gdp = gdppc * pop
drop gdppc

* ==============================================================================
* SECTION 6: Combine historical and recent data
* ==============================================================================
* Replace PLE data with World Bank data for 2019+ to ensure up-to-date coverage
drop if year >= 2019
levelsof iso, local(isos)  // Store list of countries in PLE dataset
append using `wb_all'

* Keep only countries that were in the original PLE dataset
gen inlist = 0
foreach iso in `isos' {
	replace inlist = 1 if iso == "`iso'"
}
keep if inlist == 1
drop inlist
sort iso year

* Clean inflation data by winsorizing extreme values
winsor2 inflation, cuts(1 99) replace

* ==============================================================================
* SECTION 7: Calculate growth rates and country-specific deviations
* ==============================================================================
* Set up panel structure for time series operations
egen cid = group(iso)
xtset cid year

* Calculate GDP growth rate and country-specific deviation from mean
gen gdp_growth = gdp / l1.gdp - 1
bysort iso: egen tmp = mean(gdp_growth)
gen gdp_gap_country = gdp_growth - tmp
drop tmp

* Calculate inflation deviation from country mean
bysort iso: egen tmp = mean(inflation)
gen inflation_gap_country = inflation - tmp
drop tmp

* ==============================================================================
* SECTION 8: Merge additional datasets
* ==============================================================================
* Add capital stock and TFP data from LTP database
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/ltp.dta", nogen keep(master matched)

* Add trade data (imports and exports)
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/trade_national.dta", nogen keep(master matched)

* Add military expenditure data
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/milex.dta", nogen keep(master matched)

* Add world population totals
merge m:1 year using "${DIR_DATA_PROCESSED}/pop_world.dta", nogen keep(master matched)

* ==============================================================================
* SECTION 9: Construct world GDP aggregate
* ==============================================================================
* Create world GDP by summing across countries with complete coverage
* Similar methodology to world population calculation
preserve
tempfile macro
save `macro'

* Step 1: Identify countries with complete GDP coverage
collapse (count) gdp, by(iso)
keep if gdp >= 154   // Require full sample coverage (e.g., 1870–2023 = 154 years)
levelsof iso, local(isos)

* Step 2: Sum GDP for countries with complete coverage
* Build condition string to keep only countries with complete coverage
use `macro', clear
local cond
foreach iso in `isos' {
	local cond `cond' iso == "`iso'" |
}
local cond `cond' iso == "N/A"  // Handle trailing pipe operator
keep if `cond'

gen double gdp2 = round(gdp) // Round GDP values to avoid floating point precision issues in data signatures
collapse (sum) gdp2, by(year)
rename gdp2 gdp_world

save "${DIR_DATA_PROCESSED}/gdp_world.dta", replace
restore

* Merge world GDP back into main dataset
merge m:1 year using "${DIR_DATA_PROCESSED}/gdp_world.dta", nogen keep(master matched)

* ==============================================================================
* SECTION 10: Merge financial market data (JST Macrohistory Database)
* ==============================================================================
* Add equity and capital returns data for financial analysis
merge 1:1 iso year using "${DIR_DATA_RAW}/macrohistory/JSTdatasetR6.dta", nogen ///
	keep(master matched) keepusing(capital_tr eq_tr cpi)
rename cpi cpi_jst
xtset cid year

* Calculate real returns by deflating nominal returns with CPI
gen eq_tr_real = (1 + eq_tr) / (cpi_jst / l.cpi_jst) - 1
gen capital_tr_real = (1 + capital_tr) / (cpi_jst / l.cpi_jst) - 1

* ==============================================================================
* SECTION 11: Add Global Macro Database variables and do transformations
* ==============================================================================
merge 1:1 iso year using `gmd', nogen keep(master matched)

* Convert consumption from GDP ratio to level
gen cons = cons_GDP * gdp / 100
drop cons_GDP

* Convert current account from GDP ratio to level
gen ca = CA_GDP * gdp / 100
drop CA_GDP

* Transform house price index to logs
gen lHPI = log(HPI)

* Convert government taxation from GDP ratio to level
gen govtax = govtax_GDP * gdp / 100

* ==============================================================================
* SECTION 12: Construct CPI series from inflation rates
* ==============================================================================
* Reconstruct CPI index from inflation rates for price level analysis
* Set CPI base to 100 at the first observation with inflation data
* Build CPI series using cumulative inflation
gen cpi_first = 1 if inflation != .
gen _cpi_first = cpi_first
bysort iso (year): replace cpi_first = 0 if _cpi_first[_n-1] == 1
gen cpi = 100 if cpi_first[_n+1] == 1
drop cpi_first _cpi_first
bysort iso (year): replace cpi = cpi[_n-1] * (1 + inflation) if cpi[_n-1] != .

* ==============================================================================
* SECTION 13: Variable Transformations
* ==============================================================================
* Generate log transformations for key variables
gen lcpi = log(cpi)
gen linflation = log(1 + inflation)
gen lcons = log(cons)

* Create log equity returns and cumulative equity return index
gen leq_tr_real = log(eq_tr_real + 1)
gen leq_tr_cum = 0
bysort iso (year): replace leq_tr_cum = leq_tr_cum[_n-1] + leq_tr_real if leq_tr_cum[_n-1] != . & leq_tr_real != .
replace leq_tr_cum = . if leq_tr_real == .

* Rename for consistency with naming conventions
rename leq_tr_real leqrtreal
rename leq_tr_cum leqrtcum

* Create log capital returns and cumulative capital return index
gen lcapital_tr = log(capital_tr_real + 1)
gen lcapital_tr_cum = 0
gen lcapital_tr_imp = lcapital_tr
replace lcapital_tr_imp = 0 if lcapital_tr == .  // Impute missing as zero return

bysort iso (year): replace lcapital_tr_cum = lcapital_tr_cum[_n-1] + lcapital_tr_imp if lcapital_tr_cum[_n-1] != .
replace lcapital_tr_cum = . if lcapital_tr == .

* ==============================================================================
* SECTION 14: Add fertility data (children born per woman) from Our World in Data
* ==============================================================================
preserve
import delimited "${DIR_DATA_RAW}/ourworldindata/children-born-per-woman/children-born-per-woman.csv", clear
rename code iso
gen lfertility = log(fertilityrateperiodhistorical)
keep iso year lfertility
drop if iso == ""
tempfile fertility
save `fertility'
restore
merge 1:1 iso year using `fertility', nogen keep(master matched)

* ==============================================================================
* SECTION 15: Add mortality (military and non-military deaths) data
* ==============================================================================
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/mortality.dta", nogen keep(master matched)

* Create log mortality variables
gen ldeaths_mp = log(deaths_milpop)
gen ldeaths_nmp = log(deaths_nonmilpop)

* Create level mortality variables with cleaner names
gen deaths_mp = deaths_milpop
gen deaths_nmp = deaths_nonmilpop
gen deaths = deaths_milpop + deaths_nonmilpop

drop deaths_milpop deaths_nonmilpop

* Reset panel structure
xtset cid year

* ==============================================================================
* SECTION 16: Detrend key macroeconomic variables
* ==============================================================================
* Apply multiple detrending methods to key variables for time series analysis
* Methods: Linear detrending, Hodrick-Prescott filter, Piecewise linear trend

gen lltrate = ltrate // Do not use logs for ltrate as it includes negative values

* Loop through key variables and apply the three detrending methods
foreach var in gdp cpi cons cs_ppp eqrtcum tfp milex milper ltrate {
	cap gen l`var' = log(`var')
	
	* Method 1: Linear detrending (remove linear time trend)
	levelsof iso, local(isos)
	bysort iso (year): gen t = _n
	gen l`var'_dtrd = .
	foreach iso in `isos' {
		cap reg l`var' t if iso == "`iso'"
		cap predict tmp, residuals
		cap replace l`var'_dtrd = tmp if iso == "`iso'"
		cap drop tmp
	}
	drop t
	
	* Method 2: Hodrick-Prescott filter (smooth=100 for annual data), requires continuous data without gaps
	tempfile data
	save `data'
	drop if l`var' == .
	xtset cid year
	* Check for gaps in time series and exclude countries with gaps
	bysort iso (year): gen gap = year - year[_n-1] - 1
	bysort iso: egen maxgap = max(gap)
	drop if maxgap > 0
	drop gap maxgap
	* Apply HP filter
	tsfilter hp l`var'_dthp = l`var', smooth(100)
	keep iso year l`var'_dthp
	merge 1:1 iso year using `data', keep(using matched) nogen
	
	* Method 3: Piecewise linear trend (break at 1946 - end of WWII)
	levelsof iso, local(isos)
	bysort iso (year): gen t = _n
	gen l`var'_dtpl = .
	foreach iso in `isos' {
		xtset cid year
		
		* Pre-1946 trend (includes WWI and interwar period)
		cap reg l`var' t if iso == "`iso'" & year <= 1946
		cap predict tmp if year <= 1946, residuals
		cap replace l`var'_dtpl = tmp if iso == "`iso'" & year <= 1946
		cap drop tmp
		
		* Post-1946 trend (post-WWII period)
		cap reg l`var' t if iso == "`iso'" & year > 1946
		cap predict tmp if year > 1946, residuals
		cap replace l`var'_dtpl = tmp if iso == "`iso'" & year > 1946
		cap drop tmp
	}
	drop t
}

* Add log population for completeness
gen lpop = log(pop)

* Military variables: Create level variables from HP-filtered log variables
gen milex_dthp = exp(lmilex_dthp)
gen milper_dthp = exp(lmilper_dthp)

* Long-term rate is not in logs, so rename for consistency
rename lltrate_dthp ltrate_dthp
rename lltrate_dtpl ltrate_dtpl

* ==============================================================================
* SECTION 17: Final merges and variable construction
* ==============================================================================
* Add nationalism data from V-Dem
merge 1:1 iso year using `vdem', nogen keep(master matched)

* Calculate trade openness ratio
gen openness = (imports + exports) / gdp

* Save the complete macroeconomic panel dataset
save "${DIR_DATA_PROCESSED}/macro.dta", replace
