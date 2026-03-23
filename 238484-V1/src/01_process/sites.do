/******************************************************************************
* WAR SITES DATA CONSTRUCTION AND SHOCK MEASUREMENT
* This script processes war site data to compute various measures of conflict
* intensity and their cross-border propagation effects through trade.
*
* The script creates three main datasets:
* 1. Site-level shock measures (casualties, destruction, buildup)
* 2. Cross-border propagation through bilateral trade relationships
* 3. Unified belligerents datasets for different war samples
*
* War samples processed:
* - "all": Combined interstate and intrastate conflicts
* - "interstate": Wars between sovereign states
* - "intrastate": Intrastate and extrastate wars (civil and internal conflicts)
* - "causality": Interstate wars subject to narrative identification strategy
*
* Key shock measures:
* - shock_dummy_home: Binary indicator for war occurrence
* - shock_caspop_home: Normalizes casualties by pre-war local population
* - shock_dest_home: Geopolitical risk-based measure
* - buildup: Military expenditure buildup before conflict
* - drawdown: Economic destruction during conflict (GDP decline)
******************************************************************************/

* ==============================================================================
* SECTION 1: Define program to exclude wars according to narrative identification strategy
* ==============================================================================
capture program drop drop_narrative_wars
program define drop_narrative_wars
	drop if warname == "Boxer Rebellion"
	drop if warname == "Italian-Turkish"
	drop if warname == "Second Sino-Japanese"
	drop if warname == "Conquest of Ethiopia"
	drop if warname == "Falkland Islands"
	drop if warname == "Football War"
end

* ==============================================================================
* SECTION 2: For each sample (all, intrastate, interstate), compute shock measures
* ==============================================================================
foreach sample in all intrastate interstate {

	// Load relevant dataset
	if "`sample'" == "all" {
		use "${DIR_DATA_PROCESSED}/interstate_sites.dta", clear
		append using "${DIR_DATA_PROCESSED}/intrastate_sites.dta"
	}
	else {
		use "${DIR_DATA_PROCESSED}/`sample'_sites.dta", clear
	}
	
	preserve
	rename start year
	gen war = 1
	keep iso year war
	duplicates drop
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", keepusing(lgdp_dtrd lcs_ppp_dtrd milex milper pop gdp) keep(master matched using) nogen
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/gprc.dta", keep(master matched) nogen keepusing(gprc)
	egen cid = group(iso)
	xtset cid year
	
	* --------------------------------------------------------------------------
	* CALCULATE MILITARY BUILDUP
	* - Maximum military spending in 5-year forward window
	* - Captures peak militarization
	* --------------------------------------------------------------------------
	gen milex_gdp = milex / gdp
	gen buildup = max(milex_gdp, f.milex_gdp, f2.milex_gdp, f3.milex_gdp, f4.milex_gdp)
	
  * --------------------------------------------------------------------------
	* CALCULATE ECONOMIC DESTRUCTION
	* - Finds minimum GDP level in next 5 years, subtracts pre-war GDP
	* - Multiply by -1 to make it positive (larger values = more destruction)
	* --------------------------------------------------------------------------
	gen drawdown = (min(lgdp_dtrd, f.lgdp_dtrd, f2.lgdp_dtrd, f3.lgdp_dtrd, f4.lgdp_dtrd) - l.lgdp_dtrd) * -1

	* --------------------------------------------------------------------------
	* CALCULATE GEOPOLITICAL DESTRUCTION
	* - Maximum geopolitical risk in 5-year forward window
	* - Higher gprc indicates greater geopolitical instability/destruction
	* --------------------------------------------------------------------------
	gen destruction = max(gprc, f.gprc, f2.gprc, f3.gprc, f4.gprc)
	keep if war == 1
	keep iso year destruction buildup drawdown
	rename year start
	tempfile destruction
	save `destruction'
	restore
	
	* Merge destruction measures back to main sites data
	merge m:1 iso start using `destruction', nogen keep(master matched) keepusing(destruction buildup drawdown)
		
	* Merge pre-war GDP from macro panel (year before conflict start)
	gen year = start - 1
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", keepusing(gdp) keep(master matched) nogen
	rename gdp gdp_macro

	* Merge backup GDP from World Bank
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/macro_gdp_wb.dta", keep(master matched) nogen
	rename gdp gdp_wb

	* Construct GDP variable using macro data, fallback to WB
	gen gdp_site = gdp_macro
	replace gdp_site = gdp_wb if gdp_site == .
	drop gdp_macro gdp_wb

	* Merge pre-war world GDP
	merge m:1 year using "${DIR_DATA_PROCESSED}/gdp_world.dta", keepusing(gdp_world) keep(master matched) nogen

	* Merge pre-war population
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/pop.dta", keepusing(pop) keep(master matched) nogen
	rename pop pop_site

	* Merge pre-war world population
	merge m:1 year using "${DIR_DATA_PROCESSED}/pop_world.dta", keepusing(pop_world) keep(master matched) nogen

	* Clean up
	drop year

	* --------------------------------------------------------------------------
	* GENERATE SHOCK VARIABLES
	* --------------------------------------------------------------------------
	gen shock_dummy_home = 1
	gen shock_caspop_home = casualties / pop_site
	gen shock_dest_home = destruction

	* Housekeeping
	drop gdp_site gdp_world
	sort warname iso start
	save "${DIR_DATA_PROCESSED}/sites_`sample'.dta", replace

	* Create causality sample for interstate wars
	if "`sample'" == "interstate" {
		drop_narrative_wars
		save "${DIR_DATA_PROCESSED}/sites_causality.dta", replace
	}
}

* ==============================================================================
* SECTION 3: For each sample (all, intrastate, interstate), compute cross-border propagation through trade
* ==============================================================================
foreach sample in all intrastate interstate {

	* Load site-level shocks computed in previous section
	use "${DIR_DATA_PROCESSED}/sites_`sample'.dta", clear

	* Shift back to year before war start (for exposure-based trade)
	gen year = start - 1

	* Rename for compatibility with trade data structure
	rename iso exporter

	* Merge bilateral trade: exporter = country experiencing war (origin), importer = potentially affected trading partner
	joinby exporter year using "${DIR_DATA_PROCESSED}/trade_gravity.dta", unmatched(master)
	drop _merge

	* Housekeeping
	rename exporter iso_home
	rename importer iso_foreign
	drop year
	drop if iso_foreign == ""
	sort warname iso_home iso_foreign

	* Save cross-border propagation dataset to temporary file
	save "${DIR_DATA_PROCESSED}/sites_`sample'_distances.dta", replace

	* Create causality sample for interstate wars
	if "`sample'" == "interstate" {
		drop_narrative_wars
		save "${DIR_DATA_PROCESSED}/sites_causality_distances.dta", replace
	}

}

* ==============================================================================
* SECTION 4: Prepare unified belligerents file (interstate + intrastate)
* ==============================================================================
use "${DIR_DATA_PROCESSED}/interstate_belligerents.dta", clear
append using "${DIR_DATA_PROCESSED}/intrastate_belligerents.dta"
save "${DIR_DATA_PROCESSED}/all_belligerents.dta", replace

* ==============================================================================
* SECTION 5: Prepare causality sample
* ==============================================================================
use "${DIR_DATA_PROCESSED}/interstate_belligerents.dta", clear
drop_narrative_wars
save "${DIR_DATA_PROCESSED}/causality_belligerents.dta", replace
