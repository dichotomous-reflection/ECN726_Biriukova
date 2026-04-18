/****************************************************************************
* COMBINED STATA DRIVER 
*

****************************************************************************/

* ==============================================================================
* EDITABLE CONFIGURATION
* ==============================================================================
clear all
* Edit these locals to choose the panel type, specifications, layouts,
* horizons, and estimation option set used by the driver.
* panel name:     label used in output filenames and panel filtering
* panel params:   arguments passed to build_panel
* panel specs:    local-projection specifications to run
* panel layouts:  figure layouts to export
* panel horizons: maximum horizon(s) for each local projection
* panel estopts:  estimation option sets passed to run_and_plot_lp
local USER_PANEL_NAME     "all"
local USER_PANEL_PARAMS   "wars(all)"
*local USER_PANEL_SPECS    "casroles_nl casroles castrd casprox castrd_bell"
*local USER_PANEL_SPECS    "casroles castrd casprox castrd_bell wl_sites wl_bell init_sites init_bell"
*local USER_PANEL_SPECS    "init_sites init_bell"
local USER_PANEL_SPECS    "init_sites init_bell mixed_roles"
local USER_PANEL_LAYOUTS  "macro society trade"
*local USER_PANEL_LAYOUTS  "society"
local USER_PANEL_HORIZONS "8"
local USER_PANEL_ESTOPTS  "standard"

* ==============================================================================
* PANEL CONSTRUCTION HELPER
* ==============================================================================

*EDIT PATH HERE
* Define the base project directory
global main_path            "~/Documents/ASU_STUDIES/Econometrics_2026/238484-V1"
cd "${main_path}/src/02_export/figures/my_modifications"


* Define subdirectories relative to main_path
global DIR_DATA_PROCESSED   "${main_path}/data/02_processed"
global DIR_DATA_TMP         "${main_path}/data/00_tmp"
global DIR_OUT              "${main_path}/data/03_exports"
capture program drop build_panel

/******************************************************************************
* Constructs a balanced panel dataset for analyzing the economic effects of 
* war sites on different countries. The program creates exposure measures 
* that capture how wars in certain locations affect other countries through 
* various channels (population, trade, proximity).
*
* MAIN STEPS:
* 1. Load and filter war sites data based on specified criteria
* 2. Create balanced panel of all countries and years
* 3. Calculate exposure measures (gamma, epsilon) for different country types
* 4. Generate regression variables for econometric analysis
* 5. Apply sample restrictions and merge with macro data
*
* OUTPUT:
* A panel dataset with country-year observations containing war exposure variables for econometric estimation
******************************************************************************/

program define build_panel
	* ==============================================================================
	* PARAMETER DEFINITIONS: default values correspond to baseline configuration used in the paper
	* ==============================================================================
	* casmin:            Minimum casualty threshold for including war sites
	* eww:               Exclude both World Wars (1=yes, 0=no)
	* eww1:              Exclude World War I only (1=yes, 0=no)
	* eww2:              Exclude World War II only (1=yes, 0=no)
	* minlength:         Minimum war duration in years (-1=no restriction)
	* maxlength:         Maximum war duration in years (-1=no restriction)
	* altstart:          Use alternative war start dates (1=yes, 0=no)
	* excludeUS:         Exclude United States from analysis (1=yes, 0=no)
	* excludeterrchange: Exclude countries with territorial changes (1=yes, 0=no)
	* postww:            Restrict to post-WWII period (1=yes, 0=no)
	* wars:              Type of wars to include (e.g., "interstate", "intrastate")
	* balance:           Balance sample based on data availability (1=yes, 0=no)
	* winsor_cas:        Winsorize casualty variables at specified level (-1=no winsorization)
	* gprc_only:         Keep only countries with GPRC data (1=yes, 0=no)
	* region:            Restrict to specific geographic region
	* period:            Time period restriction for Kellogg-Briand Pact of 1928 ("prekb", "postkb")
	* ==============================================================================
	syntax, ///
		[casmin(real 0)] ///
		[eww(real 0)] ///
		[eww1(real 0)] ///
		[eww2(real 0)] ///
		[minlength(real -1)] ///
		[maxlength(real -1)] ///
		[altstart(real 0)] ///
		[excludeUS(real 0)] ///
		[excludeterrchange(real 0)] ///
		[postww(real 0)] ///
		[wars(string)] ///
		[balance(real 0)] ///
		[winsor_cas(real -1)] ///
		[gprc_only(real -1)] ///
		[region(string)] ///
		[period(string)]

	* ==============================================================================
	* STEP 1: Load and filter war sites data
	* ==============================================================================
	* Load war sites data (type specified by 'wars' parameter)
	use "${DIR_DATA_PROCESSED}/sites_`wars'.dta", clear

	* Apply casualty threshold filter
	keep if casualties >= `casmin'

	* Exclude World Wars
	if `eww' == 1 {
		drop if warname == "World War I"
		drop if warname == "World War II"
	}
	if `eww1' == 1 {
		drop if warname == "World War I"
	}
	if `eww2' == 1 {
		drop if warname == "World War II"
	}

	* Filter by war duration (minimum length)
	if `minlength' >= 0 {
		gen duration = end - start + 1
		keep if duration >= `minlength'
		drop duration
	}

	* Filter by war duration (maximum length)
	if `maxlength' >= 0 {
		gen duration = end - start + 1
		keep if duration <= `maxlength'
		drop duration
	}

	* Use alternative start dates
	if `altstart' == 1 {
		drop start
		rename start_alt start
	}

	* Create year variable; keep multiple wars in the same country-year and aggregate later
	gen year = start

	* Apply winsorization to casualty variables
	if `winsor_cas' > 0 {
		replace shock_caspop_home = `winsor_cas' if shock_caspop_home > `winsor_cas'
	}

	* Save filtered sites data for later use
	tempfile sites
	save `sites'

	* ==============================================================================
	* STEP 2: Create balanced panel
	* ==============================================================================
	* Determine the time span covered by the combined war-site and macro data
	use `sites', clear
	append using "${DIR_DATA_PROCESSED}/macro.dta"
	sum year
	local year_min = r(min)  // Earliest year in the combined source data
	local year_max = r(max)  // Latest year in the combined source data

	* Combine all countries from sites and macro datasets
	keep iso
	duplicates drop

	* Create balanced panel covering the full time period (1870 - 2024)
	gen year_min = `year_min'
	gen year_max = `year_max'
	gen n_years = year_max - year_min + 1

	* Expand dataset to create one observation per country-year
	expand n_years
	bysort iso: gen year = year_min + _n - 1

	* Clean up temporary variables and save panel structure
	drop n_years year_min year_max
	tempfile panel
	save `panel'

	* ==============================================================================
	* STEP 3: Merge sites data and create country-pair panel
	* ==============================================================================
	* Merge war sites data with panel
	rename year start
	merge 1:m iso start using `sites', nogen keepusing(warname shock_caspop_home destruction)
	rename shock_caspop_home sites_cas
	rename destruction sites_gprc

	* Keep only observations with valid war start dates
	drop if start == .
	rename start year

	* Calculate total casualties per country-year (across all wars)
	bysort iso year: egen sites_cas_tot = total(sites_cas)
	rename iso iso_site  // Country where war site is located

	* Create all possible country-pair combinations for each year
	joinby year using `panel'
	rename iso iso_exposed  // Country potentially exposed to war effects
	order iso*
	sort iso_site year iso_exposed

	* ==================================================
	* ==============================================================================
	* STEP 4: Identify country types and calculate gamma coefficients
	* - Classify countries as sites, belligerents, or third parties
	* - Calculate gamma coefficients that represent the share of total war impact
	* that each country experiences based on their relationship to the war:
	* - gamma_site: Share for countries where war occurred (direct impact)
	* - gamma_bell: Share for belligerent countries (participated in war)
	* - gamma_third: Share for third-party countries (not directly involved)
	* ==============================================================================
	* Merge belligerent information to identify country roles in wars
	rename iso_exposed iso
	merge m:1 iso warname using "${DIR_DATA_PROCESSED}/all_belligerents.dta", ///
		nogen keep(master matched) keepusing(bell outcome initiator)
	merge m:1 iso warname using `sites', ///
		nogen keep(master matched) keepusing(warname shock_dummy_home)
	rename iso iso_exposed
	rename shock_dummy_home site

	* Clean up country-type indicators
	replace site = 0 if missing(site)
	replace bell = 0 if missing(bell)

	* Set missing war impact measures to zero
	replace sites_cas = 0 if missing(sites_cas)
	replace sites_gprc = 0 if missing(sites_gprc)

	* Role indicators
	gen byte participant = (site == 1 | bell == 1)

	gen byte initiator_attack = .
	gen byte initiator_defend  = .

	capture confirm numeric variable initiator
	if !_rc {
		replace initiator_attack = participant & initiator == 1 if !missing(initiator)
		replace initiator_defend  = participant & initiator != 1 if !missing(initiator)
	}
	else {
		gen strL initiator_str = lower(trim(initiator))
		replace initiator_attack = participant & inlist(initiator_str, "1", "attack", "attacker", "initiator", "yes")
		replace initiator_defend  = participant & inlist(initiator_str, "0", "2", "defend", "defender", "no")
		drop initiator_str
	}

	* Fix missing values in the correct logical sequence:
	replace initiator_attack = 0 if missing(initiator_attack)
	
	* Ensure neutral war sites are classified as defenders to prevent their shock dropping out
	replace initiator_defend = 1 if missing(initiator_defend) & site == 1 & initiator_attack == 0
	
	* Now it is safe to set the rest of the missing defender values to zero
	replace initiator_defend = 0 if missing(initiator_defend)

	* Outcome indicators from the merged belligerent file
	gen byte outcome_winner = 0
	gen byte outcome_loser  = 0

	capture confirm numeric variable outcome
	if !_rc {
		replace outcome_winner = (outcome == 1) if !missing(outcome)
		replace outcome_loser  = inlist(outcome, 0, 2) if !missing(outcome)
	}
	else {
		gen strL outcome_str = lower(trim(outcome))
		replace outcome_winner = inlist(outcome_str, "1", "win", "winner", "w")
		replace outcome_loser  = inlist(outcome_str, "0", "2", "lose", "loser", "l")
		drop outcome_str
	}

	replace outcome_winner = 0 if missing(outcome_winner)
	replace outcome_loser  = 0 if missing(outcome_loser)

	* Calculate gamma coefficients that represent the share of total war impact
	gen double gamma_site = 0
	replace gamma_site = sites_cas / sites_cas_tot if iso_site == iso_exposed & sites_cas > 0 & sites_cas < .

	gen double gamma_bell = 0
	replace gamma_bell = sites_cas / sites_cas_tot if bell == 1 & sites_cas > 0 & sites_cas < .

	gen double gamma_third = 0
	replace gamma_third = sites_cas / sites_cas_tot if bell == 0 & site == 0 & sites_cas > 0 & sites_cas < .

	* Split gamma weights natively BEFORE collapsing to avoid double-counting
	foreach group in site bell third {
		gen double gamma_`group'_attack = gamma_`group'
		replace gamma_`group'_attack = 0 if initiator_attack <= 0

		gen double gamma_`group'_defend = gamma_`group'
		replace gamma_`group'_defend = 0 if initiator_defend <= 0
		
		* Do the same for outcomes
		gen double gamma_`group'_winner = gamma_`group'
		replace gamma_`group'_winner = 0 if outcome_winner <= 0

		gen double gamma_`group'_loser = gamma_`group'
		replace gamma_`group'_loser = 0 if outcome_loser <= 0
	}

	* Aggregate to country-pair-year level
	collapse (sum) gamma_* sites_cas outcome_winner outcome_loser initiator_attack initiator_defend ///
			 (mean) sites_gprc, by(iso_site iso_exposed year)
	* ==============================================================================
	* STEP 5: Calculate epsilon coefficients (exposure weights) by different channels
	*         (population size, trade relationships, and geographic proximity)
	* ==============================================================================
	* Merge population data
	gen year_cur = year
	replace year = year_cur - 1 // Use lagged year to avoid simultaneity bias
	rename iso_site iso
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/pop.dta", nogen keep(master matched)
	rename iso iso_site
	merge m:1 year using "${DIR_DATA_PROCESSED}/pop_world.dta", nogen keep(master matched)
	drop year
	rename year_cur year

	* Population-weighted exposure: larger countries have more global influence
	gen epsilon_pop_site         = 0                                // Sites don't have population-weighted exposure to themselves
	gen double epsilon_pop_bell  = (pop / pop_world) * gamma_bell   // Belligerent exposure weighted by population share
	gen double epsilon_pop_third = (pop / pop_world) * gamma_third  // Third-party exposure weighted by population share
	* Generate correctly partitioned population-weighted epsilon variables
	foreach role in attack defend winner loser {
		gen double epsilon_pop_site_`role' = 0
	}
	foreach group in bell third {
		gen double epsilon_pop_`group'_attack  = (pop / pop_world) * gamma_`group'_attack
		gen double epsilon_pop_`group'_defend  = (pop / pop_world) * gamma_`group'_defend
		gen double epsilon_pop_`group'_winner  = (pop / pop_world) * gamma_`group'_winner
		gen double epsilon_pop_`group'_loser   = (pop / pop_world) * gamma_`group'_loser
	}

	* Merge trade and macro data
	gen year_cur = year
	replace year = year_cur - 1 // Use lagged year to avoid simultaneity bias
	rename iso_site exporter
	rename iso_exposed importer
	merge m:1 importer exporter year using "${DIR_DATA_PROCESSED}/trade_gravity.dta", nogen keep(master matched) keepusing(trade_value proximity)
	rename exporter iso_site
	rename importer iso_exposed
	rename iso_exposed iso
	merge m:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", nogen keep(master matched) keepusing(gdp)
	rename iso iso_exposed
	drop year
	rename year_cur year

	* Set missing proximity to zero (no geographic connection)
	replace proximity = 0 if proximity == .

	* Trade-weighted exposure: countries with stronger trade links are more exposed
	gen epsilon_trade_site         = 0                                  // Sites don't have trade-weighted exposure to themselves
	gen double epsilon_trade_bell  = (trade_value / gdp) * gamma_bell   // Belligerent exposure weighted by trade intensity
	gen double epsilon_trade_third = (trade_value / gdp) * gamma_third  // Third-party exposure weighted by trade intensity

	* Proximity-weighted exposure: geographically closer countries are more exposed
	gen epsilon_prox_site         = 0                         // Sites don't have proximity-weighted exposure to themselves
	gen double epsilon_prox_bell  = proximity * gamma_bell    // Belligerent exposure weighted by geographic proximity
	gen double epsilon_prox_third = proximity * gamma_third   // Third-party exposure weighted by geographic proximity

	* ==============================================================================
	* STEP 6: Generate final regression variables that combine exposure measures with
	*         war intensity, including interactions for different war outcomes and initiator status
	* ==============================================================================

	* Generate main regression variables for each shock type (casualties, GPRC)
	foreach shock in cas gprc	{
		* Basic exposure variables for each country group
		foreach group in site bell third {
			gen double regr_`shock'_phi_`group' = gamma_`group' * sites_`shock'
		}

		* Weighted exposure variables (only for belligerents and third parties)
		foreach group in bell third {
			gen double regr_`shock'_psi_pop_`group'   = epsilon_pop_`group' * sites_`shock'    // Population-weighted
			gen double regr_`shock'_psi_trade_`group' = epsilon_trade_`group' * sites_`shock'  // Trade-weighted
			gen double regr_`shock'_psi_prox_`group'  = epsilon_prox_`group' * sites_`shock'   // Proximity-weighted
		}
		
		* Generate interaction variables for war outcomes and initiator status directly from split gammas
		foreach group in site bell {
			* Cleanly compute outcome interactions using split gammas
			gen double regr_`shock'_phi_`group'_winner = gamma_`group'_winner * sites_`shock'
			gen double regr_`shock'_phi_`group'_loser  = gamma_`group'_loser * sites_`shock'
			
			* Population-weighted outcome interactions using split epsilons
			gen double regr_`shock'_psi_pop_`group'_winner = epsilon_pop_`group'_winner * sites_`shock'
			gen double regr_`shock'_psi_pop_`group'_loser  = epsilon_pop_`group'_loser * sites_`shock'
			
			* Cleanly compute role interactions using split gammas
			gen double regr_`shock'_phi_`group'_attack = gamma_`group'_attack * sites_`shock'
			gen double regr_`shock'_phi_`group'_defend = gamma_`group'_defend * sites_`shock'
			
			* Population-weighted role interactions using split epsilons
			gen double regr_`shock'_psi_pop_`group'_attack = epsilon_pop_`group'_attack * sites_`shock'
			gen double regr_`shock'_psi_pop_`group'_defend = epsilon_pop_`group'_defend * sites_`shock'
		}
	}

	* Collapse to country-year level by summing all exposure measures
	collapse (sum) regr_*, by(iso_exposed year)
	rename iso_exposed iso
	sort iso year
		

	* ==============================================================================
	* STEP 7: Merge with macro data and apply final sample restrictions
	* ==============================================================================
	merge 1:1 iso year using "${DIR_DATA_PROCESSED}/macro.dta", keep(matched using) nogen

	* Exclude the United States if specified
	if `excludeUS' == 1 {
		drop if iso == "USA"
	}

	* Exclude countries with territorial changes in the following 8 years
	if `excludeterrchange' == 1 {
		tempfile panel
		save `panel'

		* Require no territorial change in next 8 years
		use "${DIR_DATA_PROCESSED}/territory.dta", clear
		gen id = _n
		expand 8
		bysort id: gen increment = _n - 1
		replace year = year - increment
		gen terrchange = 1
		keep iso year terrchange
		duplicates drop

		* Merge back and exclude countries with upcoming territorial changes
		merge 1:1 iso year using `panel', keep(matched using) nogen
		drop if terrchange == 1
		drop terrchange
		xtset cid year
	}

	* Restrict sample to post-World War II period
	if `postww' == 1 {
		keep if year >= 1946
	}

	* Balance sample based on availability of key macroeconomic variables
	if `balance' == 1 {
		merge 1:1 iso year using "${DIR_DATA_RAW}/macrohistory/JSTdatasetR6.dta", nogen keep(matched) keepusing(iso)
		// Commented lines below could enforce joint availability of GDP and inflation data
		//replace lgdp_dtrd = . if lcpi == .
		//replace lcpi = . if lgdp_dtrd == .
	}

	* Restrict to countries with GPRC data
	if `gprc_only' == 1 {
		merge 1:1 iso year using "${DIR_DATA_PROCESSED}/gprc.dta", nogen keep(matched) keepusing(iso)
	}

	* Restrict to specific geographic region if specified
	if "`region'" != "" {
		rcallcountrycode iso, gen(region) from(iso3c) to(continent)
		keep if region == "`region'"
	}

	* Ensure a numeric panel id exists for xtset
	capture confirm variable cid
	if _rc {
		egen cid = group(iso), label
	}

	* Apply time period restrictions for Kellogg-Briand Pact of 1928
	if "`period'" == "prekb" {
		keep if year < 1928
	}
	if "`period'" == "postkb" {
		keep if year >= 1928
	}

	* Set panel structure for time series analysis
	xtset cid year
end

* ==============================================================================
* LOCAL PROJECTIONS HELPER
* ==============================================================================

/******************************************************************************
* LOCAL PROJECTIONS
* - Estimates local projections for different war exposure specifications
* - Creates impulse response plots with confidence intervals
* - Supports various dependent variable transformations
* - Handles different country roles (sites, belligerents, third parties)
* - Includes nonlinear specifications and heterogeneous effects
******************************************************************************/

capture program drop run_and_plot_lp
program define run_and_plot_lp, rclass
	* ==============================================================================
	* PARAMETER DEFINITIONS
	* ==============================================================================
	* depvar:          Dependent variable name
	* lags:            Number of lags to include in regression (default: 4)
	* h_max:           Maximum irf horizon (default: 8)
	* spec:            Specification type (e.g., "casroles", "desttrd", "castrd")
	* name:            Graph name for saving
	* xtitle:          X-axis title for plot
	* legend:          Legend options ("off", "combined", or default)
	* title:           Plot title
	* timefe:          Include time fixed effects (1=yes, 0=no)
	* scale:           Graph scale factor (default: 1.6)
	* cas:             Casualty shock size (-1 = use default 0.02)
	* integration:     Trade integration level (-1 = use default 0.03)
	* custom_controls: Additional control variables
	* ==============================================================================
	syntax, ///
		[depvar(string)] ///
		[lags(real 4)] ///
		[h_max(real 8)] ///
		[spec(string)] ///
		[name(string)] ///
		[xtitle(string)] ///
		[legend(string)] ///
		[title(string)] ///
		[timefe(real 0)] ///
		[scale(real 1.6)] ///
		[cas(real -1)] ///
		[integration(real -1)] ///
		[custom_controls(string)] ///
		[csvout(string)]

	* ==============================================================================
	* DEPENDENT VARIABLE TRANSFORMATION CONFIGURATIONS
	* ==============================================================================
	* Define how each dependent variable should be transformed for local projections:
	* - difference_long:     (Y_{t+h} - Y_{t-1}) * 100 (cumulative percentage change)
	* - difference_long_ppt: Same as above but for percentage point variables
	* - change:              ((Y_{t+h} / Y_{t-1}) - 1) * 100 (growth rate)
	* - level:               Y_{t+h} * 100 (level variable)
	* - over_preshock_gdp:   ((Y_{t+h} - Y_{t-1}) / GDP_{t-1}) * 100 (scaled by pre-shock GDP)
	* - over_preshock_pop:   ((Y_{t+h} - Y_{t-1}) / POP_{t-1}) * 100 (scaled by pre-shock population)
	* ==============================================================================
	local depvar_lgdp_difftype difference_long             // log GDP
	local depvar_lcpi_difftype difference_long             // log CPI
	local depvar_cpi_difftype change                       // CPI (growth rate)
	local depvar_eq_tr_real_difftype level                 // Equity return index
	local depvar_capital_tr_real_difftype level            // Capital stock
	local depvar_unemp_difftype difference_long            // Unemployment rate
	local depvar_trade_difftype over_preshock_gdp          // Trade value
	local depvar_imports_difftype over_preshock_gdp        // Imports
	local depvar_cons_difftype over_preshock_gdp           // Consumption
	local depvar_lcons_difftype difference_long            // log Consumption
	local depvar_lcons_dtrd_difftype difference_long       // log Consumption (detrended)
	local depvar_exports_difftype over_preshock_gdp        // Exports
	local depvar_milex_difftype over_preshock_gdp          // Military expenditure
	local depvar_milex_gdp_difftype level                  // Military expenditure as % of GDP
	local depvar_inflation_difftype level                  // Inflation rate
	local depvar_linflation_difftype level                 // log Inflation rate
	local depvar_lcs_ppp_difftype difference_long          // log capital stock
	local depvar_lcs_ppp_dtrd_difftype difference_long     // log capital stock (detrended)
	local depvar_ltfp_difftype difference_long             // log TFP
	local depvar_lpop_difftype difference_long             // log Population
	local depvar_leqrtcum_difftype difference_long         // log equity return index
	local depvar_lcapital_tr_cum_difftype difference_long  // log capital stock
	local depvar_lfertility_difftype difference_long       // log fertility rate
	local depvar_ldeaths_mp_difftype difference_long       // log military deaths
	local depvar_ldeaths_nmp_difftype difference_long      // log non-military deaths
	local depvar_deaths_difftype over_preshock_pop         // log total deaths
	local depvar_deaths_mp_difftype over_preshock_pop      // military deaths
	local depvar_deaths_nmp_difftype over_preshock_pop     // non-military deaths
	local depvar_milper_difftype over_preshock_pop         // military personnel
	local depvar_institutions_difftype difference_long     // institutional quality
	local depvar_judicial_difftype difference_long         // judicial quality
	local depvar_medial_difftype difference_long           // media quality
	local depvar_electoral_difftype difference_long        // electoral quality
	local depvar_terrchange_pop_difftype over_preshock_pop // territorial change population
	local depvar_cbrate_difftype difference_long           // central bank rate
	local depvar_strate_difftype difference_long           // short-term interest rate
	local depvar_ltrate_difftype difference_long_ppt       // long-term interest rate
	local depvar_ltrate_dthp_difftype difference_long      // long-term interest rate (HP detrended)
	local depvar_ltrate_dtpl_difftype difference_long      // long-term interest rate (piecewise-linear detrended)
	local depvar_ca_difftype over_preshock_gdp             // current account
	local depvar_lgdp_dthp_difftype difference_long        // log GDP (HP detrended)
	local depvar_lcpi_dthp_difftype difference_long        // log CPI (HP detrended)
	local depvar_lcons_dthp_difftype difference_long       // log Consumption (HP detrended)
	local depvar_lcs_ppp_dthp_difftype difference_long     // log capital stock (HP detrended)
	local depvar_leqrtcum_dthp_difftype difference_long    // log equity return index (HP detrended)
	local depvar_ltfp_dthp_difftype difference_long        // log TFP (HP detrended)
	local depvar_lmilex_dthp_difftype difference_long      // log military expenditure (HP detrended)
	local depvar_lmilper_dthp_difftype difference_long     // log military personnel (HP detrended)
	local depvar_lHPI_difftype difference_long             // log housing price index
	local depvar_govtax_difftype over_preshock_gdp         // government taxes
	local depvar_lgdp_dtpl_difftype difference_long        // log GDP (piecewise-linear detrended)
	local depvar_lcpi_dtpl_difftype difference_long        // log CPI (piecewise-linear detrended)
	local depvar_lcons_dtpl_difftype difference_long       // log Consumption (piecewise-linear detrended)
	local depvar_lcs_ppp_dtpl_difftype difference_long     // log capital stock (piecewise-linear detrended)
	local depvar_leqrtcum_dtpl_difftype difference_long    // log equity return index (piecewise-linear detrended)
	local depvar_ltfp_dtpl_difftype difference_long        // log TFP (piecewise-linear detrended)
	local depvar_lmilex_dtpl_difftype difference_long      // log military expenditure (piecewise-linear detrended)
	local depvar_lmilper_dtpl_difftype difference_long     // log military personnel (piecewise-linear detrended)

	* Labels for y-axis based on transformation type
	local difftype_difference_long_l "Percent"
	local difftype_difference_long_ppt_l "Percentage points"
	local difftype_change_l "Percent"
	local difftype_level_l "Percent"
	local difftype_over_preshock_gdp_l "Percentage points"
	local difftype_over_preshock_pop_l "Percentage points"

	* ============================================================================
	* CREATE DEPENDENT VARIABLES FOR EACH FORECAST HORIZON
	* ==============================================================================
	forvalues h=0/`h_max' {
		if "`depvar_`depvar'_difftype'" == "difference_long" {
			* Cumulative percentage change: (Y_{t+h} - Y_{t-1}) * 100
			gen `depvar'_`h' = (f`h'.`depvar' - l.`depvar') * 100
		}
		else if "`depvar_`depvar'_difftype'" == "difference_long_ppt" {
			* Same as difference_long but for percentage point variables
			gen `depvar'_`h' = (f`h'.`depvar' - l.`depvar') * 100
		}
		else if "`depvar_`depvar'_difftype'" == "over_preshock_gdp" {
			* Change scaled by pre-shock GDP: ((Y_{t+h} - Y_{t-1}) / GDP_{t-1}) * 100
			gen `depvar'_`h' = ((f`h'.`depvar' - l.`depvar') / l.gdp) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "over_preshock_pop" {
			* Change scaled by pre-shock population: ((Y_{t+h} - Y_{t-1}) / POP_{t-1}) * 100
			gen `depvar'_`h' = ((f`h'.`depvar' - l.`depvar') / l.pop) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "change" {
			* Growth rate: ((Y_{t+h} / Y_{t-1}) - 1) * 100
			gen `depvar'_`h' = ((f`h'.`depvar' / l.`depvar') - 1) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "level" {
			* Level variable: Y_{t+h} * 100
			gen `depvar'_`h' = f`h'.`depvar' * 100
		}
		else {
			* Error handling for undefined transformation types
			nois disp "depvar_`depvar'_difftype"
			nois disp "`depvar_`depvar'_difftype'"
			error 199
		}
	}

	* ==============================================================================
	* SET SHOCK MAGNITUDES AND INTEGRATION LEVELS
	* ==============================================================================
  * Average destruction across war sites (GPRC measure)
	* This number is derived from average GPRC calculated in textnumbers.do
	local gprc = 1.975

	* Set default casualty shock size if not specified
	if `cas' < 0 {
		local cas 0.02
	}

	* Set default trade integration level if not specified
	if `integration' < 0 {
		local integration 0.03
	}

	* ============================================================================
	* SPECIFICATION-DEPENDENT VARIABLE SETUP
	* ==============================================================================
	if "`spec'" == "casprox" {
		* CASUALTY PROXIMITY SPECIFICATION: Uses geographic proximity weighted exposure
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_prox_bell l(0/`lags').regr_cas_psi_prox_third l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third
		local plot_specs 3

		* War site countries
		local plot_spec_1 `cas'*regr_cas_phi_site
		local plot_spec_1_label "War site"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"
		local plot_spec_1_name "site"

		* Belligerent countries with proximity exposure
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_prox_bell+`cas'*regr_cas_phi_bell
		local plot_spec_2_label "Belligerent"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
		local plot_spec_2_name "belligerent"

		* Third-party countries with proximity exposure
		local plot_spec_3 `cas'*`integration'*regr_cas_psi_prox_third+`cas'*regr_cas_phi_third
		local plot_spec_3_label "Third"
		local plot_spec_3_color "gs5"
		local plot_spec_3_pattern "dash_dot"
		local plot_spec_3_name "third"
	}
	else if "`spec'" == "castrd" {
		* CASUALTY TRADE SPECIFICATION: Uses trade-weighted exposure
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third
		local plot_specs 3

		* War site countries
		local plot_spec_1 `cas'*regr_cas_phi_site
		local plot_spec_1_label "War site"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"
		local plot_spec_1_name "site"

		* Belligerent countries with trade exposure
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_trade_bell+`cas'*regr_cas_phi_bell
		local plot_spec_2_label "Belligerent"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
		local plot_spec_2_name "belligerent"

		* Third-party countries with trade exposure
		local plot_spec_3 `cas'*`integration'*regr_cas_psi_trade_third+`cas'*regr_cas_phi_third
		local plot_spec_3_label "Third"
		local plot_spec_3_color "gs5"
		local plot_spec_3_pattern "dash_dot"
		local plot_spec_3_name "third"
	}
	else if "`spec'" == "castrd_bell" {
		* CASUALTY TRADE SPECIFICATION (BELLIGERENT ONLY): Belligerent and third-party exposure via trade
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* Belligerent countries with trade exposure
		local plot_spec_1 `cas'*`integration'*regr_cas_psi_trade_bell+`cas'*regr_cas_phi_bell
		local plot_spec_1_label "Belligerent"
		local plot_spec_1_color "orange"
		local plot_spec_1_pattern "dash"
		local plot_spec_1_name "belligerent"

		* Third-party countries with trade exposure
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_trade_third+`cas'*regr_cas_phi_third
		local plot_spec_2_label "Third"
		local plot_spec_2_color "gs5"
		local plot_spec_2_pattern "dash_dot"
		local plot_spec_2_name "third"
	}
	else if "`spec'" == "casroles" {
		* CASUALTY ROLES SPECIFICATION: Compare effects across different country roles
		* Uses population-weighted exposure and focuses on casualty effects
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_pop_bell l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third
		local plot_specs 3

		* War site countries (direct casualty effects)
		local plot_spec_1 `cas'*regr_cas_phi_site
		local plot_spec_1_label "War site"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"
		local plot_spec_1_name "site"

		* Belligerent countries (population-weighted exposure)
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_pop_bell+`cas'*regr_cas_phi_bell
		local plot_spec_2_label "Belligerent"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
		local plot_spec_2_name "belligerent"

		* Third-party countries (population-weighted exposure)
		local plot_spec_3 `cas'*`integration'*regr_cas_psi_pop_third+`cas'*regr_cas_phi_third
		local plot_spec_3_label "Third"
		local plot_spec_3_color "gs5"
		local plot_spec_3_pattern "dash_dot"
		local plot_spec_3_name "third"
	}
	else if "`spec'" == "casroles_nl" {
		* NONLINEAR CASUALTY ROLES SPECIFICATION: Same as casroles but with quadratic terms
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_pop_bell l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third
		* Create squared terms for nonlinear specification
		foreach xvar_nl in regr_cas_phi_site regr_cas_psi_pop_bell regr_cas_psi_pop_third regr_cas_phi_bell regr_cas_phi_third {
			cap drop `xvar_nl'_nl
			gen `xvar_nl'_nl = `xvar_nl' * `xvar_nl'
			local xvars `xvars' l(0/`lags').`xvar_nl'_nl
		}
		local plot_specs 3

		* War site countries (with quadratic terms)
		local plot_spec_1 `cas'*regr_cas_phi_site + `cas'*`cas'*regr_cas_phi_site_nl
		local plot_spec_1_label "War site"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"
		local plot_spec_1_name "site"

		* Belligerent countries (with quadratic terms)
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_pop_bell + `cas'*regr_cas_phi_bell + `cas'*`cas'*`integration'*`integration'*regr_cas_psi_pop_bell_nl+`cas'*`cas'*regr_cas_phi_bell_nl
		local plot_spec_2_label "Belligerent"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
		local plot_spec_2_name "belligerent"

		* Third-party countries (with quadratic terms)
		local plot_spec_3 `cas'*`integration'*regr_cas_psi_pop_third+`cas'*regr_cas_phi_third+`cas'*`integration'*`cas'*`integration'*regr_cas_psi_pop_third_nl+`cas'*`cas'*regr_cas_phi_third_nl
		local plot_spec_3_label "Third"
		local plot_spec_3_color "gs5"
		local plot_spec_3_pattern "dash_dot"
		local plot_spec_3_name "third"
	}
	else if "`spec'" == "wl_sites" {
		* WINNER-LOSER SITES SPECIFICATION: Compare winners vs losers for war site countries
		local xvars l(0/`lags').regr_cas_phi_site_winner l(0/`lags').regr_cas_phi_site_loser l(0/`lags').regr_cas_psi_pop_bell_winner l(0/`lags').regr_cas_psi_pop_bell_loser l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_winner l(0/`lags').regr_cas_phi_bell_loser l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* War sites that end up on winning side
		local plot_spec_1 `cas'*regr_cas_phi_site_winner
		local plot_spec_1_label "Winner"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"

		* War sites that end up on losing side
		local plot_spec_2 `cas'*regr_cas_phi_site_loser
		local plot_spec_2_label "Loser"
		local plot_spec_2_color "purple"
		local plot_spec_2_pattern "dash"
	}
	else if "`spec'" == "wl_bell" {
		* WINNER-LOSER BELLIGERENTS SPECIFICATION: Compare winners vs losers for belligerent countries
		local xvars l(0/`lags').regr_cas_phi_site_winner l(0/`lags').regr_cas_phi_site_loser l(0/`lags').regr_cas_psi_pop_bell_winner l(0/`lags').regr_cas_psi_pop_bell_loser l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_winner l(0/`lags').regr_cas_phi_bell_loser l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* Belligerent countries that won the war
		local plot_spec_1 `cas'*`integration'*regr_cas_psi_pop_bell_winner+`cas'*regr_cas_phi_bell_winner
		local plot_spec_1_label "Winner"
		local plot_spec_1_color "orange"
		local plot_spec_1_pattern "solid"

		* Belligerent countries that lost the war
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_pop_bell_loser+`cas'*regr_cas_phi_bell_loser
		local plot_spec_2_label "Loser"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
	}
	else if "`spec'" == "init_sites" {
		* INITIATOR SITES SPECIFICATION: Compare attackers vs defenders for war site countries
		local xvars l(0/`lags').regr_cas_phi_site_attack l(0/`lags').regr_cas_phi_site_defend l(0/`lags').regr_cas_psi_pop_bell_attack l(0/`lags').regr_cas_psi_pop_bell_defend l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_attack l(0/`lags').regr_cas_phi_bell_defend l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* War sites where the local side initiated the war
		local plot_spec_1 `cas'*regr_cas_phi_site_attack
		local plot_spec_1_label "Attacker"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"

		* War sites where the local side defended against attack
		local plot_spec_2 `cas'*regr_cas_phi_site_defend
		local plot_spec_2_label "Defender"
		local plot_spec_2_color "purple"
		local plot_spec_2_pattern "dash"
	}
	else if "`spec'" == "init_bell" {
		* INITIATOR BELLIGERENTS SPECIFICATION: Compare attackers vs defenders for belligerent countries
		local xvars l(0/`lags').regr_cas_phi_site_attack l(0/`lags').regr_cas_phi_site_defend l(0/`lags').regr_cas_psi_pop_bell_attack l(0/`lags').regr_cas_psi_pop_bell_defend l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_attack l(0/`lags').regr_cas_phi_bell_defend l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* Belligerent countries that initiated the war
		local plot_spec_1 `cas'*`integration'*regr_cas_psi_pop_bell_attack+`cas'*regr_cas_phi_bell_attack
		local plot_spec_1_label "Attacker"
		local plot_spec_1_color "orange"
		local plot_spec_1_pattern "solid"

		* Belligerent countries that defended against attack
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_pop_bell_defend+`cas'*regr_cas_phi_bell_defend
		local plot_spec_2_label "Defender"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"
	}
	else if "`spec'" == "mixed_roles" {
		* MIXED SPECIFICATION: Attacker Belligerent vs Defender Site
		local xvars l(0/`lags').regr_cas_phi_site_attack l(0/`lags').regr_cas_phi_site_defend l(0/`lags').regr_cas_psi_pop_bell_attack l(0/`lags').regr_cas_psi_pop_bell_defend l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_attack l(0/`lags').regr_cas_phi_bell_defend l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* Plot Line 1: Attacker Belligerent (Guns vs Butter shock)
		local plot_spec_1 `cas'*`integration'*regr_cas_psi_pop_bell_attack+`cas'*regr_cas_phi_bell_attack
		local plot_spec_1_label "Attacker Belligerent"
		local plot_spec_1_color "orange"
		local plot_spec_1_pattern "solid"

		* Plot Line 2: Defender Site (Home soil invasion shock)
		local plot_spec_2 `cas'*regr_cas_phi_site_defend
		local plot_spec_2_label "Defender Site"
		local plot_spec_2_color "purple"
		local plot_spec_2_pattern "dash"
	}

	* ==============================================================================
	* PREPARE VARIABLES AND MATRICES FOR ESTIMATION
	* ==============================================================================
	cap drop b_*    // Point estimates
	cap drop u_*    // Upper confidence bounds
	cap drop l_*    // Lower confidence bounds
	cap drop Years  // Time variable
	cap gen n = .   // Sample size variable

	* Create time variable for plotting (0, 1, 2, ..., h_max)
	local h_maxplusone = `h_max'+1
	gen Years = _n - 1 if _n <= `h_maxplusone'

	* Create placeholder variables for each plot specification
	forvalues plot_index = 1/`plot_specs' {
		gen b_`plot_index' = .  // Point estimates
		gen u_`plot_index' = .  // Upper confidence bounds
		gen l_`plot_index' = .  // Lower confidence bounds
	}

	* Create openness measure (imports as share of GDP)
	cap drop openness
	gen openness = imports/gdp

	* Add time fixed effects if specified
	if `timefe' == 1 {
		local controls i.year
	}
	local condition ""

	* Clear any previous estimation results
	eststo clear
	
	* Create matrix to store all estimation results
	local n_ests = (`h_max'+1) * `plot_specs'  // Total number of estimates
	matrix mat_estimates = J(`n_ests', 3, .)   // Matrix: [estimate, upper_bound, lower_bound]
	local rownames
	
	* ==============================================================================
	* MAIN ESTIMATION LOOP: LOCAL PROJECTIONS
	* ==============================================================================
	forvalues h=0/`h_max' {
		* Estimate local projection for horizon h using Driscoll-Kraay standard errors
		nois eststo e`plot_spec_`plot_index'_name'`h': xtscc `depvar'_`h' `xvars' l(1/`lags').`depvar'_0 `controls' `custom_controls' `condition', fe
		

		* Store sample size for this horizon
		replace n = e(N) if _n == `h'+1

		* Compute linear combinations for each plot specification
		forvalues plot_index = 1/`plot_specs' {
			lincom `plot_spec_`plot_index'', level(90)
			local est_cur = (`plot_index' - 1) * (`h_max' + 1) + `h' + 1 // Matrix position for storing results
			matrix mat_estimates[`est_cur', 1] = r(estimate)
			matrix mat_estimates[`est_cur', 2] = r(ub)
			matrix mat_estimates[`est_cur', 3] = r(lb)
			* Store results in variables for plotting
			replace b_`plot_index' = r(estimate) if _n == `h'+1
			replace u_`plot_index' = r(ub)  if _n == `h'+1
			replace l_`plot_index' = r(lb)  if _n == `h'+1
		}
	}

	* ==============================================================================
	* FINALIZE RESULTS AND CREATE PLOTS
	* ==============================================================================
	* Construct row and column names for matrix
	forvalues plot_index = 1/`plot_specs' {
		forvalues h=0/`h_max' {
			local rownames `rownames' e`plot_spec_`plot_index'_name'`h'
		}
	}
	matrix rownames mat_estimates = `rownames'
	matrix colnames mat_estimates = estimate upper lower

	* Optionally export the estimation table to CSV for this depvar/spec combination
	if "`csvout'" != "" {
		preserve
		clear
		svmat double mat_estimates, names(col)
		gen str80 rowname = ""
		local rownames_csv : rownames mat_estimates
		local i = 1
		foreach rn of local rownames_csv {
			replace rowname = "`rn'" in `i'
			local ++i
		}
		order rowname estimate upper lower
		export delimited using "`csvout'", replace
		restore
	}

	* Build twoway plot expression and legend labels
	local twoway_expression
	local labels
	forvalues plot_index = 1/`plot_specs' {
		* Add line plot for point estimates and confidence interval area
		local twoway_expression `twoway_expression' ///
			(line b_`plot_index' Years, lcolor("`plot_spec_`plot_index'_color'") lpattern("`plot_spec_`plot_index'_pattern'")) ///
			(rarea u_`plot_index' l_`plot_index' Years, ///
			fcolor("`plot_spec_`plot_index'_color'%20") lcolor("`plot_spec_`plot_index'_color'%20") lw(none) lpattern(solid))

		* Create legend labels (odd numbers correspond to line plots)
		local lindex = `plot_index' * 2 - 1
		local labels `labels' `lindex' "`plot_spec_`plot_index'_label'"
	}

	* Set default x-axis title if not specified
	if "`xtitle'" == "" {
		local xtitle "Year after start of war"
	}
	if "`xtitle'" == "none" {
		local xtitle ""
	}

	* Choose y-axis title from the dependent-variable mapping
	local dtyp "`depvar_`depvar'_difftype'"
	local ytitle_text "`difftype_`dtyp'_l'"
	if "`ytitle_text'" == "" {
		local ytitle_text "Percent"
	}

	* Configure legend based on user specification
	if "`legend'" == "off" {
		local legend legend(off)
	}
	else if "`legend'" == "" {
		* Standard single-plot legend
		local legend legend(order(`labels') position(0) bplacement(swest) region(lcolor(gray%50)))
	}
	else if "`legend'" == "combined" {
		* Combined graph legend (for multi-panel figures)
		local legend legend(order(`labels') position(6) ring(0) rows(1))
	}

	* Create the impulse response plot
	preserve
	keep b_* u_* l_* n Years
	keep if _n <= `h_max'+1
	twoway `twoway_expression', ///
		`legend' ///
		yline(0, lwidth(0.3pt) lpattern(solid)) ///
		scale(`scale') ///
		ytitle("`ytitle_text'") ///
		xtitle("`xtitle'") ///
		name("`name'", replace) ///
		title("`title'")
	restore

	* Clean up temporary variables created for this estimation
	forvalues h=0/`h_max' {
		drop `depvar'_`h'
	}
	cap drop b_*
	cap drop u_*
	cap drop l_*
	cap drop n
	cap drop Years
	gen n = .
end

* ==============================================================================
* FIGURE 4-6 DRIVER
* ==============================================================================

* Define different figure layouts with specific variable groups, dimensions,
* and scaling factors for creating publication-ready plots.
* cd "C:\Users\xenia\Documents\ASU_STUDIES\Econometrics_2026\238484-V1\src\02_export\figures\my_modifications"

local layout_macro_name "macro"
local layout_macro_depvars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum milex milper
local layout_macro_xsize 9
local layout_macro_ysize 11.7
local layout_macro_scale 1

local layout_society_name "society"
local layout_society_depvars deaths lpop medial judicial electoral institutions
local layout_society_xsize 9
local layout_society_ysize 10
local layout_society_scale 1

local layout_trade_name "trade"
local layout_trade_depvars exports imports
local layout_trade_xsize 9
local layout_trade_ysize 4
local layout_trade_scale 2

* Variable labels
local label_lgdp "Output"
local label_lcpi "CPI"
local label_lcs_ppp "Capital stock"
local label_ltfp "TFP"
local label_leqrtcum "Equity return index"
local label_ltrate "Long-term interest rate"
local label_milex "Military spending"
local label_milper "Military personnel"
local label_deaths "Deaths"
local label_lpop "Population"
local label_medial "Media freedom"
local label_judicial "Judicial independence"
local label_electoral "Electoral fairness"
local label_institutions "Quality of institutions"
local label_imports "Imports"
local label_exports "Exports"

* User-selected panel configuration
local panels 1
local panel_1_name     "`USER_PANEL_NAME'"
local panel_1_params   "`USER_PANEL_PARAMS'"
local panel_1_specs    "`USER_PANEL_SPECS'"
local panel_1_layouts  "`USER_PANEL_LAYOUTS'"
local panel_1_horizons "`USER_PANEL_HORIZONS'"
local panel_1_estopt   "`USER_PANEL_ESTOPTS'"

* Estimation option sets
local estopt_standard

capture confirm global DIR_DATA_EXPORTS
if _rc | "${DIR_DATA_EXPORTS}" == "" {
    global DIR_DATA_EXPORTS "`c(pwd)'"
}

*cap mkdir "${DIR_DATA_EXPORTS}/figures"
*cap mkdir "${DIR_DATA_EXPORTS}/figures/lp"
*cap mkdir "${DIR_DATA_EXPORTS}/figures/lp_log"
*cap mkdir "${DIR_DATA_EXPORTS}/figures/lp_csv"
cap mkdir "${DIR_DATA_EXPORTS}/results/Stata"

forvalues panel_id = 1/`panels' {

    qui build_panel, `panel_`panel_id'_params'

    local panelname "`panel_`panel_id'_name'"
    local paneltag  = strtoname("`panelname'")
    local panelcontrols "`panel_`panel_id'_estctrls'"

    foreach h_max of local panel_`panel_id'_horizons {
        foreach spec of local panel_`panel_id'_specs {
            foreach layout of local panel_`panel_id'_layouts {
                foreach estopt of local panel_`panel_id'_estopt {

                    local layouttag = strtoname("`layout'")
                    local spectag   = strtoname("`spec'")
                    local esttag    = strtoname("`estopt'")
                    local htag      = strtoname("`h_max'")

                    local pdf "${DIR_DATA_EXPORTS}/results/Stata/f4f6_`paneltag'_`layouttag'_`spectag'_`esttag'_h`htag'.pdf"

                    local depvars "`layout_`layout'_depvars'"
                    local count : word count `depvars'
                    local j = 1
                    local graphlist ""

                    foreach depvar of local depvars {

                        local xtitleopt "xtitle(none)"
                        if `j' >= (`count' - 1) local xtitleopt ""

                        local legendopt "legend(off)"
                        if `j' == 1 local legendopt "legend(combined)"

                        local gname "g_`panel_id'_`j'"
                        local dep_title "`label_`depvar''"

                        local csvout "${DIR_DATA_EXPORTS}/results/Stata/f4f6_`paneltag'_`layouttag'_`spectag'_`esttag'_h`htag'_`depvar'.csv"

                        qui run_and_plot_lp, ///
                            depvar(`depvar') ///
                            h_max(`h_max') ///
                            spec(`spec') ///
                            name(`gname') ///
                            `xtitleopt' ///
                            `legendopt' ///
                            title("`dep_title'") ///
                            scale(0.8) ///
                            `estopt_`estopt'' ///
                            custom_controls(`panelcontrols') ///
                            csvout("`csvout'")

                        local graphlist `"`graphlist' `gname'"'

                        local ++j

                        if inlist("`spec'", "casroles", "castrd", "castrd_bell") {
                            if "`panelname'" == "all" {
                                cap mkdir "${DIR_DATA_EXPORTS}/results/Stata"
                                mat2txt, matrix(mat_estimates) ///
                                    saving("${DIR_DATA_EXPORTS}/results/Stata/f4f6_`paneltag'_`layouttag'_`spectag'_`esttag'_h`htag'_`depvar'.txt") ///
                                    replace
                            }
                        }
                    }

                    grc1leg2 `graphlist', ///
                        cols(2) ///
                        margins(zero) ///
                        ysize(`layout_`layout'_ysize') ///
                        xsize(`layout_`layout'_xsize') ///
                        imargin(small) ///
                        symxsize(*1.5) ///
                        scale(`layout_`layout'_scale') ///
                        `panel_`panel_id'_legoptions'

                    capture noisily graph export "`pdf'", as(pdf) replace
                    if _rc {
                        di as error "graph export failed, rc=`_rc'"
                        di as error "path: `pdf'"
                    }
                }
            }
        }
    }
}
