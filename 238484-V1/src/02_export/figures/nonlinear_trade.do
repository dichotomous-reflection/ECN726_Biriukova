/******************************************************************************
* NONLINEAR TRADE INTEGRATION EFFECTS ANALYSIS
*
* This program generates figures showing nonlinear relationships between trade
* integration levels and war effects on macroeconomic outcomes.
*
* MAIN FUNCTIONALITY:
* - Estimates nonlinear local projections with quadratic trade integration terms
* - Analyzes how trade integration modifies casualty effects
* - Generates integration-response curves across different integration levels
* - Creates figures showing how war effects vary with trade openness
*
* OUTPUT STRUCTURE:
* - PDF file: nonlinear_trd.pdf
* - Shows integration-response curves for all macroeconomic variables
******************************************************************************/

* ==============================================================================
* LOAD REQUIRED PROGRAMS
* ==============================================================================
qui include "${DIR_SRC_UTILS}/panel.do"  // Panel construction utilities

* ==============================================================================
* REGRESSION VARIABLES SPECIFICATION
* ==============================================================================
* Define variables for trade-exposed casualty specification (includes direct casualty effects and trade integration channels)
local xvars regr_cas_phi_site regr_cas_psi_trade_bell regr_cas_phi_bell regr_cas_phi_third regr_cas_psi_trade_third regr_cas_psi_prox_third regr_cas_psi_prox_bell

* ==============================================================================
* VARIABLE LABELS FOR PLOT TITLES
* ==============================================================================
local label_lgdp "Output"
local label_lcpi "CPI"
local label_lcs_ppp "Capital stock"
local label_leqrtcum "Equity return index"
local label_ltfp "TFP"
local label_milex "Military spending"
local label_milper "Military personnel"
local label_ltrate "Long-term interest rate"

* ==============================================================================
* Y-AXIS LABELS FOR DIFFERENT TRANSFORMATION TYPES
* ==============================================================================
local difftype_difference_long_l "Percent"
local difftype_change_l "Percent"
local difftype_over_preshock_gdp_l "Percentage points"
local difftype_over_preshock_pop_l "Percentage points"
local difftype_difference_long_ppt_l "Percentage points"

* ==============================================================================
* VARIABLE TRANSFORMATION SPECIFICATIONS
* ==============================================================================
local depvar_lgdp_difftype difference_long
local depvar_lcpi_difftype difference_long
local depvar_lcs_ppp_difftype difference_long
local depvar_ltfp_difftype difference_long
local depvar_ltrate_difftype difference_long_ppt
local depvar_leqrtcum_difftype difference_long
local depvar_milex_difftype over_preshock_gdp
local depvar_milper_difftype over_preshock_pop

* ==============================================================================
* DATA PREPARATION (COMMENTED OUT - ASSUMES PANEL IS ALREADY BUILT)
* ==============================================================================
*build_panel, wars(all)
local horizons 0 1 3 5
local lags 4
local depvar lcpi
local depvars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum milex milper

* Trade integration grid parameters (imports/GDP as percentage points)
local integration_min = 0                           // Minimum integration level (0 ppts)
local integration_step = 0.1                        // Step size (0.1 percentage points)
local integration_max = 10                          // Maximum integration level (10 ppts)
local integration = 0.03                            // Deprecated: fixed integration level
local cas = 0.02                                    // Fixed casualty rate (2% of population)
cap drop integration
local integration_maxp1 = `integration_max'
local integration_total = (`integration_max' - `integration_min') / `integration_step' + 1  // Total number of grid points
gen integration = (_n-1) * `integration_step' + `integration_min' if _n <= `integration_total'  // Create integration grid (0 to 10 ppts)

* Create quadratic terms for all variables to capture nonlinear effects
local regressors
foreach xvar in `xvars' {
	cap drop `xvar'_nl
	gen `xvar'_nl = `xvar' * `xvar'

	* Add both linear and quadratic terms with lags to regressor list
	local regressors `regressors' l(0/`lags').`xvar'    // Linear terms with lags
	local regressors `regressors' l(0/`lags').`xvar'_nl // Quadratic terms with lags
}

* ==============================================================================
* MAIN ESTIMATION LOOP: NONLINEAR TRADE INTEGRATION ANALYSIS
* ==============================================================================

foreach depvar in `depvars' {
	foreach h in `horizons' {
		cap drop b`h' u`h' l`h'
		gen b`h' = .
		gen u`h' = .
		gen l`h' = .
	}

	* Estimate local projections for each horizon
	foreach h in `horizons' {
		cap drop `depvar'_`h'

		* Create dependent variable with appropriate transformation
		if "`depvar_`depvar'_difftype'" == "difference_long" {
			gen `depvar'_`h' = (f`h'.`depvar' - l.`depvar') * 100
		}
		else if "`depvar_`depvar'_difftype'" == "difference_long_ppt" {
			gen `depvar'_`h' = (f`h'.`depvar' - l.`depvar') * 100
		}
		else if "`depvar_`depvar'_difftype'" == "over_preshock_gdp" {
			gen `depvar'_`h' = ((f`h'.`depvar' - l.`depvar') / l.gdp) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "over_preshock_pop" {
			gen `depvar'_`h' = ((f`h'.`depvar' - l.`depvar') / l.pop) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "change" {
			gen `depvar'_`h' = ((f`h'.`depvar' / l.`depvar') - 1) * 100
		}
		else if "`depvar_`depvar'_difftype'" == "level" {
			gen `depvar'_`h' = f`h'.`depvar' * 100
		}
		else {
			* Error handling for undefined transformation types
			nois disp "depvar_`depvar'_difftype"
			nois disp "`depvar_`depvar'_difftype'"
			error 199
		}

		* Estimate local projection with Driscoll-Kraay standard errors
		xtscc `depvar'_`h' `regressors' l(1/`lags').`depvar'_0, fe

		* Calculate nonlinear effects for trade integration grid
		levelsof integration, local(integrationpos)
		forvalues integrationpos=1/`integration_total' {
			local integration = integration[`integrationpos'] / 100
			* Compute marginal effect for trade-exposed third countries
			lincom `cas'*regr_cas_phi_third+`cas'*`integration'*regr_cas_psi_trade_third+`cas'*`cas'*regr_cas_phi_third_nl+`cas'*`integration'*`cas'*`integration'*regr_cas_psi_trade_third_nl, level(90)

			replace b`h' = r(estimate) if _n == `integrationpos'
			replace u`h' = r(ub)  if _n == `integrationpos'
			replace l`h' = r(lb)  if _n == `integrationpos'
		}
	}

	* Set color scheme (not used in this analysis)
	if "`spec'" == "casroles_site" {
		local color "purple"
	}
	else if "`spec'" == "castrd_exposed" {
		local color "red"
	}
	else if "`spec'" == "castrd_nonexposed" {
		local color "blue"
	}

	* ===================================================================
	* CREATE NONLINEAR TRADE INTEGRATION-RESPONSE PLOT
	* ===================================================================
	* Plot shows how casualty effects vary across trade integration spectrum
	* Different line patterns represent different forecast horizons
	* Fixed at 2% casualty rate, varying integration from 0-10 ppts
	* ===================================================================
	twoway ///
		(line b0 integration, color(red)) ///                                  // Immediate effect (h=0): solid red line
		///(rarea l1 u1 cas, lwidth(0) color(purple%30)) ///                   // Confidence bands (commented out)
		(line b1 integration, color(red) lpattern("dash")) ///                 // 1-year effect: dashed red line
		///(rarea l3 u3 cas, lwidth(0) color(purple%30)) ///                   // Confidence bands (commented out)
		(line b5 integration, color(red) lpattern("dash_dot")) ///             // 5-year effect: dash-dot red line
		///(rarea l5 u5 cas, lwidth(0) color(purple%30)) ///                   // Confidence bands (commented out)
		, ///
		legend(order(1 "{it:h}=0" 2 "{it:h}=1" 3 "{it:h}=5") rows(1)) ///      // Legend for horizons
		name(`depvar', replace) ///                                            // Graph name
		title("`label_`depvar''") ///                                          // Plot title (human-readable variable name)
		ytitle("`difftype_`depvar_`depvar'_difftype'_l'") ///                  // Y-axis title (appropriate units)
		xtitle("Imports / GDP (in ppts)")                                      // X-axis title (trade integration level)
}

* ==============================================================================
* COMBINE ALL VARIABLE PLOTS AND EXPORT
* ==============================================================================
grc1leg2 `depvars', ///
	cols(2) ///                                        // Two columns layout
	margins(zero) ///                                  // No margins between plots
	ysize(11.7) ///                                    // Figure height
	xsize(9) ///                                       // Figure width
	imargin(small) ///                                 // Small internal margins
	symxsize(*1.5) ///                                 // Symbol size adjustment
	scale(1)                                           // Scale factor

* Export combined nonlinear trade integration figure
graph export "${DIR_DATA_EXPORTS}/figures/nonlinear_trd.pdf", as(pdf) replace
