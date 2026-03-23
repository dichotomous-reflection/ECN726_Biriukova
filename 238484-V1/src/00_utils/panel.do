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

	* Create year variable and remove duplicates
	gen year = start
	duplicates drop iso year, force

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
	* Determine the time span covered by the war sites data
	use `sites', clear
	sum start
	local year_min = r(min)  // Earliest war start year
	sum end
	local year_max = r(max)  // Latest war end year

	* Combine all countries from sites and macro datasets
	append using "${DIR_DATA_PROCESSED}/macro.dta"
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

	* ==============================================================================
	* STEP 4: Identify country types and calculate gamma coefficients
	* - Classify countries as sites, belligerents, or third parties
	* - Calculate gamma coefficients that represent the share of total war impact
	*   that each country experiences based on their relationship to the war:
	*   - gamma_site: Share for countries where war occurred (direct impact)
	*   - gamma_bell: Share for belligerent countries (participated in war)
	*   - gamma_third: Share for third-party countries (not directly involved)
	* ==============================================================================
	* Merge belligerent information to identify country roles in wars
	rename iso_exposed iso
	merge m:1 iso warname using "${DIR_DATA_PROCESSED}/all_belligerents.dta", nogen keep(master matched) keepusing(bell outcome initiator)
	merge m:1 iso warname using `sites', nogen keepusing(warname shock_dummy_home) keep(master matched)
	rename iso iso_exposed
	rename shock_dummy_home site
	
	* Clean up country type indicators
	replace site = 0 if site == .                    // Site indicator (war occurred in this country)
	replace bell = 0 if bell == . | site == 1        // Belligerent indicator (country fought in war)

	* Set missing war impact measures to zero
	replace sites_cas = 0 if sites_cas == .
	replace sites_gprc = 0 if sites_gprc == .

	* Calculate gamma coefficients that represent the share of total war impact
	gen double gamma_site  = sites_cas / sites_cas_tot if iso_site == iso_exposed & sites_cas > 0 & sites_cas != .
	gen double gamma_bell  = sites_cas / sites_cas_tot if bell == 1
	gen double gamma_third = sites_cas / sites_cas_tot if bell == 0 & site == 0

	* Aggregate to country-pair-year level
	collapse (sum) gamma_* sites_cas (mean) sites_gprc outcome initiator, by(iso_site iso_exposed year)

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
	*         war intensity, including interactions for different war outcomes and roles
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

		* Generate interaction variables for war outcomes and initiator status; only for sites and belligerents as they directly participate
		foreach group in site bell {
			* War outcome interactions (winner vs loser)
			gen double regr_`shock'_phi_`group'_winner = gamma_`group' * sites_`shock' if outcome == 1
			gen double regr_`shock'_phi_`group'_loser = gamma_`group' * sites_`shock' if outcome == 2

			* Population-weighted outcome interactions
			gen double regr_`shock'_psi_pop_`group'_winner = epsilon_pop_`group' * sites_`shock' if outcome == 1
			gen double regr_`shock'_psi_pop_`group'_loser = epsilon_pop_`group' * sites_`shock' if outcome == 2

			* War role interactions (attacker vs defender)
			gen double regr_`shock'_phi_`group'_attack = gamma_`group' * sites_`shock' if initiator == 1
			gen double regr_`shock'_phi_`group'_defend = gamma_`group' * sites_`shock' if initiator == 2

			* Population-weighted role interactions
			gen double regr_`shock'_psi_pop_`group'_attack = epsilon_pop_`group' * sites_`shock' if initiator == 1
			gen double regr_`shock'_psi_pop_`group'_defend = epsilon_pop_`group' * sites_`shock' if initiator == 2
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
