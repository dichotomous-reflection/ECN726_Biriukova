/******************************************************************************
* TEXT NUMBERS GENERATOR FOR PAPER
*
* This program generates various descriptive statistics and specific numbers
* that are referenced throughout the paper text.
*
* OUTPUT:
* - Console display and text files of key numbers and statistics used in paper
* - Numbers used for fact-checking and manuscript preparation
* - Supporting evidence for claims made in the paper
*
* USAGE:
* These numbers are manually incorporated into the paper text
******************************************************************************/

local sample all

* ==============================================================================
* INITIALIZE TEXT FILE FOR OUTPUT
* ==============================================================================
cap file close textnumbers
file open textnumbers using "${DIR_DATA_EXPORTS}/textnumbers.txt", write replace
file write textnumbers "TEXT NUMBERS FOR PAPER" _n
file write textnumbers "==============================" _n _n
* ==============================================================================

use "${DIR_DATA_PROCESSED}/sites_`sample'.dta", clear

* Calculate average casualties as share of local population (all time period)
sum shock_caspop_home
local mean = round(r(mean), 0.01)
nois disp "Average casualties/local pop in `sample' sites: ", `mean'
file write textnumbers "Average casualties/local pop in `sample' sites: " (`mean') _n

* Calculate average casualties as share of local population (post World War II)
sum shock_caspop_home if start >= 1946
local mean = round(r(mean), 0.001)
nois disp "Average casualties/local pop in `sample' sites (1946+): ", `mean'
file write textnumbers "Average casualties/local pop in `sample' sites (1946+): " (`mean') _n

* Calculate average war site population relative to world population
use "${DIR_DATA_PROCESSED}/sites_`sample'.dta", clear
gen year = start
merge m:1 iso year using "${DIR_DATA_PROCESSED}/pop.dta", nogen keep(master matched)
gen size = pop / pop_world
sum size
local mean = round(r(mean), 0.01)
nois disp "Average local pop/world pop in `sample' sites: ", `mean'
file write textnumbers "Average local pop/world pop in `sample' sites: " (`mean') _n

* Calculate average war site population relative to world population (post World War II)
sum size if year >= 1946
local mean = round(r(mean), 0.01)
nois disp "Average local pop/world pop in `sample' sites (1946+): ", `mean'
file write textnumbers "Average local pop/world pop in `sample' sites (1946+): " (`mean') _n

* Calculate average value of alternative destruction measure based on country-specific Geoconomic Risk Indicator (GPRC)
use "${DIR_DATA_PROCESSED}/sites_`sample'.dta", clear
sum destruction
local mean = round(r(mean), 0.001)
nois disp "Average value of alternative destruction measure: ", `mean'
file write textnumbers "Average value of alternative destruction measure: " (`mean') _n

* Number of war sites with data coverage in post-WWII period
build_panel, wars(all)
sum regr_cas_phi_site if regr_cas_phi_site > 0 & year >= 1946
local count = r(N)
nois disp "Total number of war sites with data coverage in post-WWII period: ", `count'
file write textnumbers "Total number of war sites with data coverage in post-WWII period: " (`count') _n

* Count number of belligerents in Gulf War for specific historical context
use "${DIR_DATA_PROCESSED}/interstate_belligerents.dta", clear
keep if warname == "Gulf War"
merge 1:1 iso warname using "${DIR_DATA_PROCESSED}/sites_interstate.dta", keep(master)
local count_incl = _N
nois disp "Total number of belligerents in Gulf War (incl. USA): ", `count_incl'
file write textnumbers "Total number of belligerents in Gulf War (incl. USA): " (`count_incl') _n
drop if iso == "USA"
local count_excl = _N
nois disp "Total number of belligerents in Gulf War (excl. USA): ", `count_excl'
file write textnumbers "Total number of belligerents in Gulf War (excl. USA): " (`count_excl') _n

* Calculate trade integration Germany vis-a-vis France in 2023
use "${DIR_DATA_PROCESSED}/trade_gravity.dta", clear
keep if importer == "DEU" & exporter == "FRA" & year == 2023
rename importer iso
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", nogen keepusing(gdp) keep(matched)
gen share = trade_value_notimp / gdp
sum share
local mean = round(r(mean), 0.001)
nois disp "Imports of Germany from France relative to German GDP: ", `mean'
file write textnumbers "Imports of Germany from France relative to German GDP: " (`mean') _n

* Calculate trade integration Canada vis-a-vis USA in 2023
use "${DIR_DATA_PROCESSED}/trade_gravity.dta", clear
keep if importer == "CAN" & exporter == "USA" & year == 2023
rename importer iso
merge 1:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", nogen keepusing(gdp) keep(matched)
gen share = trade_value_notimp / gdp
sum share
local mean = round(r(mean), 0.001)
nois disp "Imports of Canada from USA relative to Canadian GDP: ", `mean'
file write textnumbers "Imports of Canada from USA relative to Canadian GDP: " (`mean') _n

* Create causality sample and identify war sites with data coverage
build_panel, wars(causality)
* Create war site indicator and check data availability
gen site = 1 if regr_cas_phi_site > 0
sum lcpi if regr_cas_phi_site > 0
* Save causality sample for merging
keep site iso year
tempfile causality
save `causality'

build_panel, wars(interstate)
merge 1:1 iso year using `causality', nogen keep(master matched using)

* Count war sites in causality sample with complete data
sum regr_cas_phi_site if regr_cas_phi_site > 0 & lcpi != . & site == 1
local count = r(N)
nois disp "Total number of war sites in causality sample: ", `count'
file write textnumbers "Total number of war sites in causality sample: " (`count') _n

* Calculate how many different reasons typically drive each war
import excel "${DIR_DATA_RAW}/handcoded/sites_2025-06-02.xlsx", clear sheet("Reason coding") firstrow cellrange(A2)
keep if _n <= 77

* Convert string variables to numeric for summation
destring BorderClashes, replace
destring EconomicCausesLongRun, replace

* Sum all reason categories to get total reasons per war
gen count = BorderClashes + EconomicCausesLongRun + Nationalism + ReligiousorIdeologicalDiffe + EconomicCausesShortRun + DomesticPolitic + PowerTransitionBalanceofPow + RevengeorRetribution

* Calculate average number of reasons per war
sum count
local mean = r(mean)
nois disp "Average number of reasons per war: ", `mean'
file write textnumbers "Average number of reasons per war: " (`mean') _n

* ==============================================================================
* CLOSE TEXT FILE
* ==============================================================================
file write textnumbers _n "==============================" _n
file close textnumbers
* ==============================================================================
