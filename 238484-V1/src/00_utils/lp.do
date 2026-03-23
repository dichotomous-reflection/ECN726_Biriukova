/******************************************************************************
* LOCAL PROJECTIONS
* - Estimates local projections for different war exposure specifications
* - Creates impulse response plots with confidence intervals
* - Supports various dependent variable transformations
* - Handles different country roles (sites, belligerents, third parties)
* - Includes nonlinear specifications and heterogeneous effects
******************************************************************************/

qui include "${DIR_SRC_UTILS}/panel.do"

capture program drop run_and_plot_lp
program define run_and_plot_lp
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
		[custom_controls(string)]

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
	*local difftype_level_l "Percent"
	local difftype_over_preshock_gdp_l "Percentage points"
	local difftype_over_preshock_pop_l "Percentage points"

	* ==============================================================================
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

	* Convert integration level to percentage for labeling
	local integration_pct = `integration' * 100
	
	* Sample restriction condition (can be modified by specification)
	local condition ""

	* ==============================================================================
	* SPECIFICATION DEFINITIONS
	* ==============================================================================
	* Define regression variables and plot specifications for different analysis types.
	* Each specification focuses on different aspects of war exposure effects.
	* ==============================================================================
	if "`spec'" == "castrd" {
		* CASUALTY-TRADE SPECIFICATION: Includes all war exposure channels (direct, trade-weighted, and proximity-weighted)
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_psi_prox_third l(0/`lags').regr_cas_psi_prox_bell
		local plot_specs 2

		* Third-party country with no trade exposure
		local plot_spec_1 `cas'*regr_cas_phi_third
		local plot_spec_1_label "Third (exposure = 0%)"
		local plot_spec_1_color "blue"
		local plot_spec_1_pattern "dash"
		local plot_spec_1_name "third_trd0pct"

		* Third-party country with trade exposure
		local plot_spec_2 `cas'*regr_cas_phi_third+`cas'*`integration'*regr_cas_psi_trade_third
		local plot_spec_2_label "Third (exposure = `integration_pct'%)"
		local plot_spec_2_color "red"
		local plot_spec_2_pattern "solid"
		local plot_spec_2_name "third_trd`integration_pct'pct"
	}
	else if "`spec'" == "castrd_nl" {
		* NONLINEAR CASUALTY-TRADE SPECIFICATION: Same as castrd but with quadratic terms
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_psi_prox_third l(0/`lags').regr_cas_psi_prox_bell
		* Create squared terms for nonlinear specification
		foreach xvar_nl in regr_cas_phi_site regr_cas_psi_trade_bell regr_cas_phi_bell regr_cas_phi_third regr_cas_psi_trade_third regr_cas_psi_prox_third regr_cas_psi_prox_bell {
			cap drop `xvar_nl'_nl
			gen `xvar_nl'_nl = `xvar_nl' * `xvar_nl'
			local xvars `xvars' l(0/`lags').`xvar_nl'_nl
		}
		local plot_specs 2

		* Third-party country with no trade exposure (including quadratic terms)
		local plot_spec_1 `cas'*regr_cas_phi_third+`cas'*`cas'*regr_cas_phi_third_nl
		local plot_spec_1_label "Third (exposure = 0%)"
		local plot_spec_1_color "blue"
		local plot_spec_1_pattern "dash"
		local plot_spec_1_name "third_trd0pct"

		* Third-party country with trade exposure (including quadratic terms)
		local plot_spec_2 `cas'*regr_cas_phi_third+`cas'*`integration'*regr_cas_psi_trade_third+`cas'*`cas'*regr_cas_phi_third_nl+`cas'*`integration'*`cas'*`integration'*regr_cas_psi_trade_third_nl
		local plot_spec_2_label "Third (exposure = `integration_pct'%)"
		local plot_spec_2_color "red"
		local plot_spec_2_pattern "solid"
		local plot_spec_2_name "third_trd`integration_pct'pct"
	}
	else if "`spec'" == "castrd_bell" {
		* CASUALTY-TRADE BELLIGERENT SPECIFICATION: Same variables as castrd but plots focus on belligerent exposure
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_psi_prox_third l(0/`lags').regr_cas_psi_prox_bell
		local plot_specs 2

		* Belligerent with no trade exposure
		local plot_spec_1 `cas'*regr_cas_phi_bell
		local plot_spec_1_label "Third (exposure = 0%)"
		local plot_spec_1_color "blue"
		local plot_spec_1_pattern "dash"
		local plot_spec_1_name "bell_trd0pct"

		* Belligerent with trade exposure
		local plot_spec_2 `cas'*regr_cas_phi_bell+`cas'*`integration'*regr_cas_psi_trade_bell
		local plot_spec_2_label "Third (exposure = `integration_pct'%)"
		local plot_spec_2_color "red"
		local plot_spec_2_pattern "solid"
		local plot_spec_2_name "bell_trd`integration_pct'pct"
	}
	else if "`spec'" == "desttrd" {
		* DESTRUCTION-TRADE SPECIFICATION: Focus on GPRC specification, restricts sample to post-1900 period when GPRC data is more reliable
		local condition if year >= 1900
		local xvars l(0/`lags').regr_gprc_phi_site l(0/`lags').regr_gprc_psi_trade_bell l(0/`lags').regr_gprc_phi_bell l(0/`lags').regr_gprc_phi_third l(0/`lags').regr_gprc_psi_trade_third l(0/`lags').regr_gprc_psi_prox_third l(0/`lags').regr_gprc_psi_prox_bell
		local plot_specs 2

		* Third-party with no trade exposure to destruction
		local plot_spec_1 `gprc'*regr_gprc_phi_third
		local plot_spec_1_label "Third (exposure = 0%)"
		local plot_spec_1_color "blue"
		local plot_spec_1_pattern "dash"

		* Third-party with trade exposure to destruction
		local plot_spec_2 `gprc'*regr_gprc_phi_third+`gprc'*`integration'*regr_gprc_psi_trade_third
		local plot_spec_2_label "Third (exposure = `integration_pct'%)"
		local plot_spec_2_color "red"
		local plot_spec_2_pattern "solid"
	}
	else if "`spec'" == "destroles" {
		* DESTRUCTION ROLES SPECIFICATION: Compare effects across different country roles
		* Uses population-weighted exposure and focuses on destruction (GPRC) effects
		local condition if year >= 1900
		local xvars l(0/`lags').regr_gprc_phi_site l(0/`lags').regr_gprc_psi_pop_bell l(0/`lags').regr_gprc_psi_pop_third l(0/`lags').regr_gprc_phi_bell l(0/`lags').regr_gprc_phi_third
		local plot_specs 3

		* War site countries (direct destruction effects)
		local plot_spec_1 `gprc'*regr_gprc_phi_site
		local plot_spec_1_label "War site"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "solid"

		* Belligerent countries (population-weighted exposure)
		local plot_spec_2 `gprc'*`integration'*regr_gprc_psi_pop_bell+`gprc'*regr_gprc_phi_bell
		local plot_spec_2_label "Belligerent"
		local plot_spec_2_color "orange"
		local plot_spec_2_pattern "dash"

		* Third-party countries (population-weighted exposure)
		local plot_spec_3 `gprc'*`integration'*regr_gprc_psi_pop_third+`gprc'*regr_gprc_phi_third
		local plot_spec_3_label "Third"
		local plot_spec_3_color "gs5"
		local plot_spec_3_pattern "dash_dot"
	}
	else if "`spec'" == "casprox" {
		* CASUALTY-PROXIMITY SPECIFICATION: Focus on geographic proximity effects
		* Compares neighboring vs non-neighboring third-party countries
		local xvars l(0/`lags').regr_cas_phi_site l(0/`lags').regr_cas_psi_trade_bell l(0/`lags').regr_cas_phi_bell l(0/`lags').regr_cas_phi_third l(0/`lags').regr_cas_psi_trade_third l(0/`lags').regr_cas_psi_prox_third l(0/`lags').regr_cas_psi_prox_bell
		local plot_specs 2

		* Third-party countries with no geographic proximity
		local plot_spec_1 `cas'*regr_cas_phi_third
		local plot_spec_1_label "Third (non-neighbors)"
		local plot_spec_1_color "blue"
		local plot_spec_1_pattern "dash"

		* Third-party countries that are geographic neighbors
		local plot_spec_2 `cas'*regr_cas_phi_third+`cas'*regr_cas_psi_prox_third
		local plot_spec_2_label "Third (neighbors)"
		local plot_spec_2_color "red"
		local plot_spec_2_pattern "solid"
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
		local xvars l(0/`lags').regr_cas_phi_site_attacker l(0/`lags').regr_cas_phi_site_defender l(0/`lags').regr_cas_psi_pop_bell_attacker l(0/`lags').regr_cas_psi_pop_bell_defender l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_attacker l(0/`lags').regr_cas_phi_bell_defender l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* War sites where the local side initiated the war
		local plot_spec_1 `cas'*regr_cas_phi_site_attacker
		local plot_spec_1_label "Attacker"
		local plot_spec_1_color "purple"
		local plot_spec_1_pattern "dash"

		* War sites where the local side defended against attack
		local plot_spec_2 `cas'*regr_cas_phi_site_defender
		local plot_spec_2_label "Defender"
		local plot_spec_2_color "purple"
		local plot_spec_2_pattern "solid"
	}
	else if "`spec'" == "init_bell" {
		* INITIATOR BELLIGERENTS SPECIFICATION: Compare attackers vs defenders for belligerent countries
		local xvars l(0/`lags').regr_cas_phi_site_attacker l(0/`lags').regr_cas_phi_site_defender l(0/`lags').regr_cas_psi_pop_bell_attacker l(0/`lags').regr_cas_psi_pop_bell_defender l(0/`lags').regr_cas_psi_pop_third l(0/`lags').regr_cas_phi_bell_attacker l(0/`lags').regr_cas_phi_bell_defender l(0/`lags').regr_cas_phi_third
		local plot_specs 2

		* Belligerent countries that initiated the war
		local plot_spec_1 `cas'*`integration'*regr_cas_psi_pop_bell_attacker+`cas'*regr_cas_phi_bell_attacker
		local plot_spec_1_label "Attacker"
		local plot_spec_1_color "orange"
		local plot_spec_1_pattern "solid"

		* Belligerent countries that defended against attack
		local plot_spec_2 `cas'*`integration'*regr_cas_psi_pop_bell_defender+`cas'*regr_cas_phi_bell_defender
		local plot_spec_2_label "Defender"
		local plot_spec_2_color "orange"
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
	gen Years = _n - 1 if _n <= `h_maxplusone' & _n >= `h_min'+1

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
		* Alternative estimation methods (commented out): reghdfe with country fixed effects and clustered standard errors
		*reghdfe `depvar'_`h' `xvars' l(1/`lags').`depvar'_0 `controls' if (year < 1914 | year > 1918) & (year < 1939 | year > 1945), absorb(iso) cluster(iso)
		*reghdfe `depvar'_`h' `xvars' l(1/`lags').`depvar'_0 `controls' if (year < 1914 | year > 1945), absorb(iso) cluster(iso)

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
		ytitle("`difftype_`depvar_`depvar'_difftype'_l'") ///
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
