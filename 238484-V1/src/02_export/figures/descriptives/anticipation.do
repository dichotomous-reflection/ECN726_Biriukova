/******************************************************************************
* ANTICIPATION EFFECTS ANALYSIS
*
* This program creates event study plots to examine anticipation effects around
* war onset. It shows how macroeconomic variables evolve in the years before
* and after wars begin, helping identify whether economic agents anticipate
* upcoming conflicts.
*
* METHODOLOGY:
* - Creates event windows around war start dates (t=0)
* - Calculates means and confidence intervals for each time period
* - Supports different demeaning options (country, year, or both fixed effects)
* - Generates plots showing variable evolution from t_min to t_max
*
* OUTPUT:
* Event study plots with confidence intervals for various macroeconomic variables
******************************************************************************/

qui include "${DIR_SRC_UTILS}/panel.do"

capture program drop plot_event_window
program define plot_event_window
	* ==============================================================================
	* PARAMETER DEFINITIONS
	* ==============================================================================
	* var:     Variable name to analyze in event study
	* t_min:   Minimum time relative to war onset (default: -4 years)
	* t_max:   Maximum time relative to war onset (default: +4 years)
	* demean:  Demeaning method ("country", "year", "both", or none)
	* title:   Plot title
	* name:    Graph name for saving
	* ytitle:  Y-axis label
	* ==============================================================================
	syntax, ///
		[var(string)] ///
		[t_min(real -4)] ///
		[t_max(real 4)] ///
		[demean(string)] ///
		[title(string)] ///
		[name(string)] ///
		[ytitle(string)]

	preserve

	* ==============================================================================
	* STEP 1: APPLY DEMEANING TRANSFORMATION
	* ==============================================================================
	* Remove fixed effects based on the specified demeaning method to isolate
	* variation relevant for the event study analysis
	* ==============================================================================

	if "`demean'" == "country" {
		* Remove country-specific means (country fixed effects)
		bysort iso: egen `var'_mean = mean(`var')
		gen `var'_dmd = `var' - `var'_mean
		local var `var'_dmd
		xtset cid year
	}
	else if "`demean'" == "year" {
		* Remove year-specific means (time fixed effects)
		bysort year: egen `var'_mean = mean(`var')
		gen `var'_dmd = `var' - `var'_mean
		local var `var'_dmd
		xtset cid year
	}
	else if "`demean'" == "both" {
		* Remove both country and year fixed effects using reghdfe
		reghdfe `var', absorb(iso year) resid
		predict `var'_dmd, resid
		local var `var'_dmd
	}

	* ==============================================================================
	* STEP 2: CREATE EVENT TIME VARIABLES
	* ==============================================================================
	* Generate variables for each time period relative to war onset (t=0)
	* Negative values use lags, positive values use leads
	* ==============================================================================

	local i = 1
	forvalues t = `t_min'/`t_max' {
		if `t' < 0 {
			* Pre-war periods: use lagged values
			local prefix l
			local rel = `t' * -1  // Convert negative to positive for lag notation
		}
		else {
			* War and post-war periods: use forward/current values
			local prefix f
			local rel = `t'
		}

		* Create variable for time t relative to war onset (convert to percentage)
		gen `var'_t`i' = `prefix'`rel'.`var' * 100

		local i = `i' + 1
	}

	* ==============================================================================
	* STEP 3: RESTRICT TO WAR SITE COUNTRIES
	* ==============================================================================
	* Keep only countries that experienced wars (positive war site exposure)
	* ==============================================================================
	keep if regr_cas_phi_site > 0

	* ==============================================================================
	* STEP 4: CALCULATE EVENT STUDY STATISTICS
	* ==============================================================================
	* For each time period, calculate mean, standard deviation, and sample size
	* ==============================================================================

	* Initialize result variables
	gen mean = . 
	gen sd = .
	gen count = .
	gen t = .

	* Calculate statistics for each time period
	local i = 1
	forvalues t = `t_min'/`t_max' {
		* Store the time period
		replace t = `t' if _n == `i'

		* Calculate mean
		egen tmp = mean(`var'_t`i')
		replace mean = tmp if _n == `i'
		drop tmp

		* Calculate standard deviation
		egen tmp = sd(`var'_t`i')
		replace sd = tmp if _n == `i'
		drop tmp

		* Calculate sample size
		egen tmp = count(`var'_t`i')
		replace count = tmp if _n == `i'
		drop tmp

		local i = `i' + 1
	}

	* ==============================================================================
	* STEP 5: PREPARE DATA FOR PLOTTING
	* ==============================================================================
	* Clean data and calculate confidence intervals for the event study plot
	* ==============================================================================

	* Keep only the summary statistics
	keep t mean sd count
	drop if t == .

	* Calculate standard errors and confidence intervals
	gen se = sd / sqrt(count)                    // Standard error of the mean
	gen ul = mean + 1.65 * se                    // Upper 90% confidence bound
	gen ll = mean - 1.65 * se                    // Lower 90% confidence bound

	* ==============================================================================
	* STEP 6: CREATE EVENT STUDY PLOT
	* ==============================================================================
	* Generate a plot showing the evolution of the variable around war onset
	* with confidence intervals and reference lines
	* ==============================================================================

	* Set x-axis range with small buffer
	local x_min = `t_min' - 0.2
	local x_max = `t_max' + 0.2

	* Create event study plot
	twoway ///
		(scatter mean t, mcolor(purple)) ///                                    // Point estimates
		(rcap ul ll t, color(purple)) ///                                       // Confidence intervals
		(line mean t, lcolor(purple) lpattern(dash)), ///                       // Connected line
		yline(0, lcolor(gray)) ///                                              // Horizontal reference line
		xline(0, lcolor(green) lpattern(dash)) ///                              // Vertical line at war onset
		ytitle("`ytitle'") ///                                                  // Y-axis title
		xtitle("Years around war onset") ///                                    // X-axis title
		xla(`t_min'(1)`t_max') ///                                              // X-axis labels
		legend(off) ///                                                         // No legend
		ysize(3) xsize(4) ///                                                   // Graph dimensions
		yscale(``var'_scale') yla(``var'_ylabel') ///                           // Y-axis scaling
		xsc(r(`x_min'(0.1)`x_max')) ///                                         // X-axis range
		plotregion(margin(zero)) ///                                            // Plot region margins
		scale(0.8) ///                                                          // Overall scale
		graphregion(margin(zero)) graphregion(margin(0 3 0 3)) ///              // Graph margins
		title("`title'") ///                                                    // Plot title
		name("`name'", replace)                                                 // Graph name

	restore
end

* ==============================================================================
* VARIABLE LABELS AND LAYOUT CONFIGURATIONS
* ==============================================================================
* Define human-readable labels for variables and layout specifications for
* different types of plots (macro, trade, cycle)
* ==============================================================================
local depvars
* Macro variables
local label_lgdp "Growth"
local label_lcpi "Inflation"
local label_lcons "Consumption change"
local label_lcs_ppp "Capital stock change"
local label_leqrtcum "Equity returns"
local label_ltfp "TFP change"
local label_lmilex "Military spending change"
local label_lmilper "Military personnel change"
local label_ltrate "Long-term interest rate change"
* Trade variables
local label_limports "Imports"
local label_lexports "Exports"

* Layout configuration for macro variables
local layout_macro_depvars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum lmilex lmilper
local layout_macro_ysize 11.7    // Plot height
local layout_macro_xsize 9       // Plot width
local layout_macro_scale 1       // Scale factor

* Layout configuration for trade variables
local layout_trade_depvars limports lexports
local layout_trade_ysize 3.5     // Plot height
local layout_trade_xsize 9       // Plot width
local layout_trade_scale 2.5     // Scale factor

* Layout configuration for business cycle variables (GDP and inflation)
local layout_cycle_depvars lgdp lcpi
local layout_cycle_ysize 3.5     // Plot height
local layout_cycle_xsize 9       // Plot width
local layout_cycle_scale 2.5     // Scale factor

* ==============================================================================
* MAIN LOOP: GENERATE ANTICIPATION PLOTS
* ==============================================================================
* For each layout type (macro, trade, cycle) and war type (interstate, intrastate),
* create event study plots showing anticipation effects around war onset
* ==============================================================================

foreach layout in macro trade cycle {
	foreach panel in interstate intrastate {
		* ==============================================================================
		* STEP 1: BUILD PANEL DATA FOR SPECIFIC WAR TYPE
		* ==============================================================================
		* Load and prepare the panel dataset for the specified war type
		qui build_panel, wars(`panel')

		* Create log variables for trade analysis
		*gen lmilex = log(milex)      // Military expenditure (commented out)
		*gen lmilper = log(milper)    // Military personnel (commented out)
		gen limports = log(imports)   // Log imports
		gen lexports = log(exports)   // Log exports

		* ==============================================================================
		* STEP 2: GENERATE EVENT STUDY PLOTS FOR EACH VARIABLE
		* ==============================================================================
		* Create anticipation plots for all variables in the current layout
		foreach depvar in `layout_`layout'_depvars' {
			* Set appropriate y-axis label based on variable type
			local ytitle "Percent"
			if "`depvar'" == "lcpi" {
				local ytitle "Percentage points"  // Inflation measured in percentage points
			}

			* Calculate variable changes (first differences)
			gen `depvar'_chg = `depvar' - l.`depvar'

			* Create event study plot with both country and year fixed effects
			plot_event_window, ///
				var(`depvar'_chg) ///
				name(`depvar') ///
				title(`label_`depvar'') ///
				ytitle(`ytitle') ///
				demean("both")
		}

		* ==============================================================================
		* STEP 3: COMBINE PLOTS AND EXPORT
		* ==============================================================================
		* Combine individual plots into a single figure and export as PDF
		grc1leg2 `layout_`layout'_depvars', ///
			cols(2) ///                                    // 2 columns layout
			ysize(`layout_`layout'_ysize') ///             // Overall height
			xsize(`layout_`layout'_xsize') ///             // Overall width
			scale(`layout_`layout'_scale') ///             // Scale factor
			loff                                           // Turn off legend

		* Export combined figure to PDF
		graph export "${DIR_DATA_EXPORTS}/figures/descriptives/anticipation/`panel'_`layout'.pdf", as(pdf) replace
	}
}
