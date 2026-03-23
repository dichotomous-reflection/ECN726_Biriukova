/******************************************************************************
* LOCAL PROJECTIONS HETEROGENEITY ANALYSIS
*
* This program generates specialized local projection figures focusing on
* heterogeneous effects of wars, particularly examining winner/loser dynamics
*
* MAIN FUNCTIONALITY:
* - Analyzes heterogeneous war effects using winner/loser specifications
* - Compares impacts on war sites vs belligerent countries
* - Tests robustness across different sample restrictions
* - Focuses on core macroeconomic variables (GDP and inflation)
* - Generates figures for multiple forecast horizons
*
* OUTPUT STRUCTURE:
* - PDF files: heterogeneity/panel[name]_spec[specification]_h[horizon].pdf
* - Specifications: wl_sites (winner/loser sites), wl_bell (winner/loser belligerents)
******************************************************************************/

* Load utility programs for panel construction and local projection estimation
qui include "${DIR_SRC_UTILS}/panel.do"  // Panel construction utilities
qui include "${DIR_SRC_UTILS}/lp.do"     // Local projection estimation and plotting

* ==============================================================================
* VARIABLE CONFIGURATION
* ==============================================================================
* Define core macroeconomic variables for heterogeneity analysis
* Focus on GDP and inflation as key outcome variables
* ==============================================================================
local depvars lgdp lcpi  // Core macro variables: log GDP and log CPI

* ==============================================================================
* PANEL CONFIGURATIONS
* ==============================================================================
local panels 1  // Number of active panels

* Panel 1: Interstate wars only (primary specification)
local panel_1_name "interstate"
local panel_1_params wars(interstate)

* Panel 2: Exclude World Wars (alternative specification - currently inactive)
local panel_2_name "exww"
local panel_2_params wars(all) eww(1)

* Panel 3: Causality-restricted sample (alternative specification - currently inactive)
local panel_3_name "causality"
local panel_3_params wars(causality)

* ==============================================================================
* VARIABLE LABELS FOR PLOT TITLES
* ==============================================================================
local label_lgdp "Output"  // Log GDP
local label_lcpi "CPI"     // Log consumer price index

* ==============================================================================
* MAIN EXECUTION LOOP: HETEROGENEITY ANALYSIS
* ==============================================================================

* Loop through different forecast horizons (8 and 16 years)
foreach h_max in 8 16 {

	* Loop through active panel configurations
	forvalues panel_id=1/`panels' {

		* Build panel dataset for current configuration
		qui build_panel, `panel_`panel_id'_params'

		* Loop through winner/loser specifications
		foreach spec in wl_sites wl_bell {

			* Generate individual plots for each dependent variable
			foreach depvar in `depvars' {
				* Estimate local projections with winner/loser heterogeneity
				* wl_sites: Winner/loser effects for war site countries
				* wl_bell: Winner/loser effects for belligerent countries
				qui run_and_plot_lp, ///
					depvar("`depvar'") ///    // Dependent variable (lgdp or lcpi)
					h_max(`h_max') ///        // Maximum forecast horizon
					spec("`spec'") ///        // Winner/loser specification
					legend("combined") ///    // Show legend for interpretation
					name(`depvar') ///        // Graph name
					scale(0.8) ///            // Plot scale factor
					title(`label_`depvar'')   // Human-readable plot title
			}

			* Combine individual plots into a single layout
			grc1leg2 `depvars', ///
				cols(2) ///                 // Two columns (GDP and CPI)
				margins(zero) ///           // No margins between plots
				ysize(4) ///                // Layout height
				xsize(9) ///                // Layout width
				imargin(small) ///          // Small internal margins
				symxsize(*1.5) ///          // Symbol size adjustment
				scale(2)                    // Overall scale factor

			* Export combined heterogeneity figure as PDF
			graph export "${DIR_DATA_EXPORTS}/figures/lp/heterogeneity/panel[`panel_`panel_id'_name']_spec[`spec']_h[`h_max'].pdf", replace
		}

		* Close all graphs to free memory
		graph close _all
	}
}
