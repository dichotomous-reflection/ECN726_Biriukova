/******************************************************************************
* NONLINEAR CASUALTY EFFECTS ANALYSIS
*
* This program generates figures showing nonlinear relationships between war
* casualty rates and macroeconomic outcomes.
*
* MAIN FUNCTIONALITY:
* - Estimates nonlinear local projections with quadratic casualty terms
* - Tests three different specifications for casualty exposure
* - Generates impulse response functions across casualty intensity grid
* - Creates figures showing how effects vary with casualty rates
*
* SPECIFICATIONS:
* 1. casroles_site: War site countries with population-weighted exposure
* 2. castrd_exposed: Trade-exposed third countries with integration effects
* 3. castrd_nonexposed: Non-trade-exposed third countries
*
* OUTPUT STRUCTURE:
* - PDF files: nonlinear_cas_[specification].pdf
* - Shows casualty-response curves for multiple forecast horizons
******************************************************************************/

* ==============================================================================
* LOAD REQUIRED PROGRAMS
* ==============================================================================
qui include "${DIR_SRC_UTILS}/panel.do"  // Panel construction utilities

* ==============================================================================
* SPECIFICATION DEFINITIONS
* ==============================================================================
* Define variable sets for different casualty exposure specifications
* Each specification captures different channels of war exposure
* ==============================================================================

* Trade-exposed third countries: includes both direct casualty exposure and trade integration channels
local xvars_castrd_exposed regr_cas_phi_site regr_cas_psi_trade_bell regr_cas_phi_bell regr_cas_phi_third regr_cas_psi_trade_third regr_cas_psi_prox_third regr_cas_psi_prox_bell

* Non-trade-exposed third countries: direct effects only (same variables but without trade integration channel activation)
local xvars_castrd_nonexposed regr_cas_phi_site regr_cas_psi_trade_bell regr_cas_phi_bell regr_cas_phi_third regr_cas_psi_trade_third regr_cas_psi_prox_third regr_cas_psi_prox_bell

* War site countries with population-weighted exposure (focuses on direct casualty effects with population-based weights)
local xvars_casroles_site regr_cas_phi_site regr_cas_psi_pop_bell regr_cas_psi_pop_third regr_cas_phi_bell regr_cas_phi_third

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
* DATA PREPARATION
* ==============================================================================
build_panel, wars(all)
local horizons 0 1 3 5
local lags 4
local depvar lcpi
local depvars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum milex milper

* Casualty rate grid parameters (casualty rate as % of local population)
local cas_min = 0                                   // Minimum casualty rate (0%)
local cas_step = 0.1                                // Step size (0.1 percentage points)
local cas_max = 10                                  // Maximum casualty rate (10%)
local integration = 0.03                            // Trade integration parameter (3%)
cap drop cas
local cas_maxp1 = `cas_max'
local cas_total = (`cas_max' - `cas_min') / `cas_step' + 1  // Total number of grid points
gen cas = (_n-1) * `cas_step' + `cas_min' if _n <= `cas_total'  // Create casualty rate grid (0 to 10%)

* ==============================================================================
* MAIN ESTIMATION LOOP: NONLINEAR SPECIFICATIONS
* ==============================================================================
* Loop through different casualty exposure specifications to estimate
* nonlinear relationships between casualty rates and macroeconomic outcomes
* ==============================================================================

foreach spec in casroles_site castrd_exposed castrd_nonexposed {

	* Create quadratic terms for all variables in current specification
	local regressors
	foreach xvar in `xvars_`spec'' {
		cap drop `xvar'_nl
		gen `xvar'_nl = `xvar' * `xvar'
		
		* Add both linear and quadratic terms with lags to regressor list
		local regressors `regressors' l(0/`lags').`xvar'    // Linear terms with lags
		local regressors `regressors' l(0/`lags').`xvar'_nl // Quadratic terms with lags
	}

	foreach depvar in `depvars' {

		foreach h in `horizons' {
			cap drop b`h' u`h' l`h'                        // Drop existing result variables
			gen b`h' = .                                   // Point estimates
			gen u`h' = .                                   // Upper confidence bounds
			gen l`h' = .                                   // Lower confidence bounds
		}

		* ESTIMATE LOCAL PROJECTIONS FOR EACH HORIZON
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

			* Calculate nonlinear effects for casualty rate grid
			levelsof cas, local(caspos)
			forvalues caspos=1/`cas_total' {
				local cas = cas[`caspos'] / 100

				* Compute marginal effects for different specifications
				if "`spec'" == "casroles_site" {
					lincom `cas'*regr_cas_phi_site + `cas'*`cas'*regr_cas_phi_site_nl, level(90)

					replace b`h' = r(estimate) if _n == `caspos'
					replace u`h' = r(ub)  if _n == `caspos'
					replace l`h' = r(lb)  if _n == `caspos'
				}
				else if "`spec'" == "castrd_exposed" {
					lincom `cas'*regr_cas_phi_third+`cas'*`integration'*regr_cas_psi_trade_third+`cas'*`cas'*regr_cas_phi_third_nl+`cas'*`integration'*`cas'*`integration'*regr_cas_psi_trade_third_nl, level(90)

					replace b`h' = r(estimate) if _n == `caspos'
					replace u`h' = r(ub)  if _n == `caspos'
					replace l`h' = r(lb)  if _n == `caspos'
				}
				else if "`spec'" == "castrd_nonexposed" {
					lincom `cas'*regr_cas_phi_third+`cas'*`cas'*regr_cas_phi_third_nl, level(90)

					replace b`h' = r(estimate) if _n == `caspos'
					replace u`h' = r(ub)  if _n == `caspos'
					replace l`h' = r(lb)  if _n == `caspos'
				}
			}
		}

		* Use different colors to distinguish between specifications
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
		* CREATE NONLINEAR CASUALTY-RESPONSE PLOT
		* ===================================================================
		twoway ///
			(line b0 cas, color(`color')) ///                                   // Immediate effect (h=0): solid line
			///(rarea l1 u1 cas, lwidth(0) color(purple%30)) ///                // Confidence bands (commented out)
			(line b1 cas, color(`color') lpattern("dash")) ///                  // 1-year effect: dashed line
			///(rarea l3 u3 cas, lwidth(0) color(purple%30)) ///                // Confidence bands (commented out)
			(line b5 cas, color(`color') lpattern("dash_dot")) ///              // 5-year effect: dash-dot line
			///(rarea l5 u5 cas, lwidth(0) color(purple%30)) ///                // Confidence bands (commented out)
			, ///
			legend(order(1 "{it:h}=0" 2 "{it:h}=1" 3 "{it:h}=5") rows(1)) ///   // Legend for horizons
			name(`depvar', replace) ///                                         // Graph name
			title("`label_`depvar''") ///                                       // Plot title (human-readable variable name)
			ytitle("`difftype_`depvar_`depvar'_difftype'_l'") ///               // Y-axis title (appropriate units)
			xtitle("Casualties / Local population (in %)")                      // X-axis title
	}

	* =======================================================================
	* COMBINE ALL VARIABLE PLOTS AND EXPORT
	* =======================================================================
	grc1leg2 `depvars', ///
		cols(2) ///                                        // Two columns layout
		margins(zero) ///                                  // No margins between plots
		ysize(11.7) ///                                    // Figure height
		xsize(9) ///                                       // Figure width
		imargin(small) ///                                 // Small internal margins
		symxsize(*1.5) ///                                 // Symbol size adjustment
		scale(1)                                           // Scale factor

	* Export combined nonlinear casualty figure
	graph export "${DIR_DATA_EXPORTS}/figures/nonlinear_cas_`spec'.pdf", as(pdf) replace
}
