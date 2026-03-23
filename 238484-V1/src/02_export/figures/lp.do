/******************************************************************************
* LOCAL PROJECTIONS FIGURE GENERATION
*
* This program generates comprehensive sets of local projection (impulse response)
* figures showing the dynamic effects of war shocks on various macroeconomic,
* societal, and trade variables. It systematically runs multiple specifications,
* sample restrictions, and variable layouts to create a complete set of results.
*
* MAIN FUNCTIONALITY:
* - Generates impulse response functions for 28 different panel configurations
* - Tests multiple econometric specifications
* - Creates figures for different variable groups (macro, society, trade)
* - Applies various robustness checks and sample restrictions
* - Exports both PDF figures and CSV data for further use (e.g. model matching)
*
* OUTPUT STRUCTURE:
* - PDF files: panel[name]_layout[type]_spec[specification]_estopt[options]_h[horizon].pdf
* - CSV files: Estimation results for baseline specifications
******************************************************************************/

* ==============================================================================
* LOAD REQUIRED PROGRAMS
* ==============================================================================
qui include "${DIR_SRC_UTILS}/panel.do"  // Panel construction utilities
qui include "${DIR_SRC_UTILS}/lp.do"     // Local projection estimation and plotting


* ==============================================================================
* LAYOUT CONFIGURATIONS
* ==============================================================================
* Define different figure layouts with specific variable groups, dimensions,
* and scaling factors for creating publication-ready plots
* ==============================================================================

* Rate variables layout
/*local layout_rates_name "rates"
local layout_rates_depvars cbrate ltrate strate ca lHPI govtax
local layout_rates_xsize 9          // Figure width
local layout_rates_ysize 10         // Figure height
local layout_rates_scale 1          // Scale factor*/

* Macroeconomic variables layout
local layout_macro_name "macro"
local layout_macro_depvars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum milex milper
local layout_macro_xsize 9          // Figure width
local layout_macro_ysize 11.7       // Figure height
local layout_macro_scale 1          // Scale factor

* Society variables layout
local layout_society_name "society"
local layout_society_depvars deaths lpop medial judicial electoral institutions
local layout_society_xsize 9        // Figure width
local layout_society_ysize 10       // Figure height
local layout_society_scale 1        // Scale factor

* Trade variables layout
local layout_trade_name "trade"
local layout_trade_depvars exports imports
local layout_trade_xsize 9          // Figure width
local layout_trade_ysize 4          // Figure height
local layout_trade_scale 2          // Scale factor (larger for fewer variables)

* Business cycle variables layout (GDP and inflation focus)
local layout_cycle_name "cycle"
local layout_cycle_depvars lgdp lcpi
local layout_cycle_xsize 9          // Figure width
local layout_cycle_ysize 4          // Figure height
local layout_cycle_scale 2          // Scale factor

* Small business cycle layout (compact version for regional analysis)
local layout_cycle_small_name "cycle_small"
local layout_cycle_small_depvars lgdp lcpi
local layout_cycle_small_xsize 9    // Figure width
local layout_cycle_small_ysize 3.2  // Figure height (smaller height)
local layout_cycle_small_scale 2    // Scale factor

* Macroeconomic variables with Hodrick-Prescott detrending
local layout_macro_hp_name "macro_hp"
local layout_macro_hp_depvars lgdp_dthp lcpi_dthp lcs_ppp_dthp ltfp_dthp ltrate_dthp leqrtcum_dthp lmilex_dthp lmilper_dthp
local layout_macro_hp_xsize 9       // Figure width
local layout_macro_hp_ysize 11.7    // Figure height
local layout_macro_hp_scale 1       // Scale factor

* Macroeconomic variables with piecewise-linear detrending
local layout_macro_pl_name "macro_pl"
local layout_macro_pl_depvars lgdp_dtpl lcpi_dtpl lcs_ppp_dtpl ltfp_dtpl ltrate_dtpl leqrtcum_dtpl lmilex_dtpl lmilper_dtpl
local layout_macro_pl_xsize 9       // Figure width
local layout_macro_pl_ysize 11.7    // Figure height
local layout_macro_pl_scale 1       // Scale factor


* ==============================================================================
* VARIABLE LABELS FOR PLOT TITLES
* ==============================================================================

* Rate variables
local label_strate "Short-term interest rate"
local label_ltrate "Long-term interest rate"
local label_ltrate_dthp "Long-term interest rate"    // HP detrended
local label_ltrate_dtpl "Long-term interest rate"    // Piecewise-linear detrended

* Macroeconomic variables (levels)
local label_lgdp "Output"                            // Log GDP
local label_lcpi "CPI"                               // Log consumer price index
local label_lcs_ppp "Capital stock"                  // Log capital stock (PPP)
local label_leqrtcum "Equity return index"           // Log cumulative equity returns
local label_ltfp "TFP"                               // Log total factor productivity
local label_milex "Military spending"                // Military expenditure
local label_milper "Military personnel"              // Military personnel

* Macroeconomic variables (Hodrick-Prescott detrended)
local label_lgdp_dthp "Output"                       // HP detrended log GDP
local label_lcpi_dthp "CPI"                          // HP detrended log CPI
local label_lcons_dthp "Consumption"                 // HP detrended log consumption
local label_lcs_ppp_dthp "Capital stock"             // HP detrended log capital stock
local label_leqrtcum_dthp "Equity return index"      // HP detrended log equity returns
local label_ltfp_dthp "TFP"                          // HP detrended log TFP
local label_lmilex_dthp "Military spending"          // HP detrended log military expenditure
local label_lmilper_dthp "Military personnel"        // HP detrended log military personnel

* Macroeconomic variables (piecewise-linear detrended)
local label_lgdp_dtpl "Output"                       // Piecewise-linear detrended log GDP
local label_lcpi_dtpl "CPI"                          // Piecewise-linear detrended log CPI
local label_lcons_dtpl "Consumption"                 // Piecewise-linear detrended log consumption
local label_lcs_ppp_dtpl "Capital stock"             // Piecewise-linear detrended log capital stock
local label_leqrtcum_dtpl "Equity return index"      // Piecewise-linear detrended log equity returns
local label_ltfp_dtpl "TFP"                          // Piecewise-linear detrended log TFP
local label_lmilex_dtpl "Military spending"          // Piecewise-linear detrended log military expenditure
local label_lmilper_dtpl "Military personnel"        // Piecewise-linear detrended log military personnel

* Societal and institutional variables
local label_deaths "Deaths"                          // Death rates
local label_lpop "Population"                        // Log population
local label_medial "Media freedom"                   // Media freedom index
local label_judicial "Judicial independence"         // Judicial independence index
local label_electoral "Electoral fairness"           // Electoral fairness index
local label_institutions "Quality of institutions"   // Overall institutional quality

* Trade variables
local label_imports "Imports"                        // Import values
local label_exports "Exports"                        // Export values

* ==============================================================================
* PANEL CONFIGURATIONS
* ==============================================================================
* Define 28 different panel configurations for comprehensive robustness testing.
* Each panel specifies: sample restrictions, econometric specifications, 
* variable layouts, forecast horizons, and estimation options.
* ==============================================================================

local panels 28  // Total number of panel configurations

* Panel 1: Baseline specification with all wars and comprehensive specifications
* (Figure 4, Figure 5, Figure 6, Figure 8, Figure O-C.3.1, Figure O-C.3.2, Figure O-C.5.4, Figure O-C.5.5, Figure O-C.5.6, Figure O-C.5.7, Figure O-C.13.1, Figure O-C.13.2)
local panel_1_name "all"
local panel_1_params wars(all)                                                 // All war types
local panel_1_specs casroles_nl castrd_nl casroles castrd casprox castrd_bell  // Baseline specifications, including nonlinear specifications
local panel_1_layouts macro society trade                                      // All variable layouts
local panel_1_horizons 8                                                       // 8-year horizon
local panel_1_estopt standard                                                  // Standard estimation options

* Panel 2: Interstate wars only
local panel_2_name "interstate"
local panel_2_params wars(interstate)                                          // Interstate wars only
local panel_2_specs casroles castrd                                            // Baseline specifications
local panel_2_layouts macro society trade                                      // All variable layouts
local panel_2_horizons 8                                                       // 8-year horizon
local panel_2_estopt standard                                                  // Standard estimation options

* Panel 3: Intrastate wars only (Figure O-B.6.1, Figure O-B.6.2, Figure O-B.6.3, Figure O-B.6.4)
local panel_3_name "intrastate"
local panel_3_params wars(intrastate)                                          // Intrastate wars only
local panel_3_specs casroles castrd                                            // Baseline specifications
local panel_3_layouts macro society trade                                      // All variable layouts
local panel_3_horizons 8                                                       // 8-year horizon
local panel_3_estopt standard                                                  // Standard estimation options

* Panel 4: Exclude World Wars (Figure O-B.2.9, Figure O-B.2.10, Figure O-B.2.11, Figure O-B.2.12)
local panel_4_name "exww"
local panel_4_params wars(all) eww(1)                                          // Exclude both World Wars
local panel_4_specs castrd casroles                                            // Baseline specifications
local panel_4_layouts macro society trade                                      // All variable layouts
local panel_4_horizons 8                                                       // 8-year horizon
local panel_4_estopt standard                                                  // Standard estimation options

* Panel 5: Causality-restricted sample (Figure O-C.15.1, Figure O-C.15.2, Figure O-C.15.3, Figure O-C.15.4)
local panel_5_name "causality"
local panel_5_params wars(causality)                                           // Only causality-identified interstate wars
local panel_5_specs casroles castrd                                            // Baseline specifications
local panel_5_layouts macro society trade                                      // All variable layouts
local panel_5_horizons 8                                                       // 8-year horizon
local panel_5_estopt standard                                                  // Standard estimation options

* Panel 6: Alternative war start dates (Figure O-C.4.1, Figure O-C.4.2, Figure O-C.4.3, Figure O-C.4.4)
local panel_6_name "altstart"
local panel_6_params wars(all) altstart(1)                                     // Use alternative start dates
local panel_6_specs casroles castrd casroles_nl castrd_nl                      // Baseline specifications, including nonlinear specifications
local panel_6_layouts macro society trade                                      // All variable layouts
local panel_6_horizons 8                                                       // 8-year horizon
local panel_6_estopt standard                                                  // Standard estimation options

* Panel 7: Exclude United States
local panel_7_name "exus"
local panel_7_params wars(all) excludeUS(1)                                    // Exclude US observations
local panel_7_specs casroles castrd                                            // Baseline specifications
local panel_7_layouts macro society trade                                      // All variable layouts
local panel_7_horizons 8                                                       // 8-year horizon
local panel_7_estopt standard                                                  // Standard estimation options

* Panel 8: Long wars only - minimum 4 years (Figure O-C.12.1, Figure O-C.12.2, Figure O-C.12.3, Figure O-C.12.4)
local panel_8_name "long"
local panel_8_params wars(all) minlength(4)                                    // Wars lasting at least 4 years
local panel_8_specs casroles castrd                                            // Baseline specifications
local panel_8_layouts macro society trade                                      // All variable layouts
local panel_8_horizons 8                                                       // 8-year horizon
local panel_8_estopt standard                                                  // Standard estimation options

* Panel 9: Short wars only - maximum 3 years (Figure O-C.11.1, Figure O-C.11.2, Figure O-C.11.3, Figure O-C.11.4)
local panel_9_name "short"
local panel_9_params wars(all) maxlength(3)                                    // Wars lasting at most 3 years
local panel_9_specs casroles castrd                                            // Baseline specifications
local panel_9_layouts macro society trade                                      // All variable layouts
local panel_9_horizons 8                                                       // 8-year horizon
local panel_9_estopt standard                                                  // Standard estimation options

* Panel 10: Exclude territorial changes (Figure O-B.1.1, Figure O-B.1.2, Figure O-B.1.3, Figure O-B.1.4)
local panel_10_name "territory"
local panel_10_params wars(all) excludeterrchange(1)                           // Exclude countries with territorial changes
local panel_10_specs casroles castrd                                           // Baseline specifications
local panel_10_layouts macro society trade                                     // All variable layouts
local panel_10_horizons 8                                                      // 8-year horizon
local panel_10_estopt standard                                                 // Standard estimation options

* Panel 11: Post-World War II period only
local panel_11_name "postww"
local panel_11_params wars(all) postww(1)                                      // Post-1945 period only
local panel_11_specs casroles castrd                                           // Baseline specifications
local panel_11_layouts macro society trade                                     // All variable layouts
local panel_11_horizons 8                                                      // 8-year horizon
local panel_11_estopt postww                                                   // Special post-WW estimation options

* Panel 12: Balanced sample - 18 countries from Macrohistory (Figure O-B.4.1, Figure O-B.4.2, Figure O-B.4.3, Figure O-B.4.4)
local panel_12_name "balanced"
local panel_12_params wars(all) balance(1)                                     // Require balanced data availability
local panel_12_specs casroles castrd                                           // Baseline specifications
local panel_12_layouts macro society trade                                     // All variable layouts
local panel_12_horizons 8                                                      // 8-year horizon
local panel_12_estopt standard                                                 // Standard estimation options

* Panel 13: Winsorized casualty variables (Figure O-C.8.1, Figure O-C.8.2, Figure O-C.8.3, Figure O-C.8.4)
local panel_13_name "winsorized"
local panel_13_params wars(all) winsor_cas(0.1)                                // Winsorize casualties at 10%
local panel_13_specs casroles castrd                                           // Baseline specifications
local panel_13_layouts macro society trade                                     // All variable layouts
local panel_13_horizons 8                                                      // 8-year horizon
local panel_13_estopt standard                                                 // Standard estimation options

* Panel 14: Extended horizon - 16 years (Figure O-C.2.1, Figure O-C.2.2, Figure O-C.2.3, Figure O-C.2.4)
local panel_14_name "all"
local panel_14_params wars(all)                                                // All wars
local panel_14_specs casroles castrd                                           // Baseline specifications
local panel_14_layouts macro society trade                                     // All variable layouts
local panel_14_horizons 16                                                     // Extended 16-year horizon
local panel_14_estopt standard                                                 // Standard estimation options

* Panel 15: Time fixed effects
local panel_15_name "all"
local panel_15_params wars(all)                                                // All wars
local panel_15_specs casroles castrd                                           // Baseline specifications
local panel_15_layouts macro society trade                                     // All variable layouts
local panel_15_horizons 8                                                      // 8-year horizon
local panel_15_estopt timefe                                                   // Include time fixed effects

* Panel 16: Detrending robustness - HP and piecewise-linear (Figure O-C.9.1, Figure O-C.9.2, Figure O-C.10.1, Figure O-C.10.2)
local panel_16_name "all"
local panel_16_params wars(all)                                                // All wars
local panel_16_specs casroles castrd                                           // Baseline specifications
local panel_16_layouts society trade macro_hp macro_pl                         // All variable layouts, including detrended macro variables
local panel_16_horizons 8                                                      // 8-year horizon
local panel_16_estopt standard                                                 // Standard estimation options

* Panel 17: Exclude World War I only (Figure O-B.2.1, Figure O-B.2.2, Figure O-B.2.3, Figure O-B.2.4)
local panel_17_name "exww1"
local panel_17_params wars(all) eww1(1)                                        // Exclude WWI only
local panel_17_specs castrd casroles                                           // Baseline specifications
local panel_17_layouts macro society trade                                     // All variable layouts
local panel_17_horizons 8                                                      // 8-year horizon
local panel_17_estopt standard                                                 // Standard estimation options

* Panel 18: Exclude World War II only (Figure O-B.2.5, Figure O-B.2.6, Figure O-B.2.7, Figure O-B.2.8)
local panel_18_name "exww2"
local panel_18_params wars(all) eww2(1)                                        // Exclude WWII only
local panel_18_specs castrd casroles                                           // Baseline specifications
local panel_18_layouts macro society trade                                     // All variable layouts
local panel_18_horizons 8                                                      // 8-year horizon
local panel_18_estopt standard                                                 // Standard estimation options

* Panel 19: High-casualty wars only - minimum 1000 casualties (Figure O-B.5.1, Figure O-B.5.2, Figure O-B.5.3, Figure O-B.5.4)
local panel_19_name "min1000cas"
local panel_19_params wars(all) casmin(1000)                                   // Wars with at least 1000 casualties
local panel_19_specs castrd casroles                                           // Baseline specifications
local panel_19_layouts macro society trade                                     // All variable layouts
local panel_19_horizons 8                                                      // 8-year horizon
local panel_19_estopt standard                                                 // Standard estimation options

* Panel 20: GPRC-only sample with destruction specifications (Figure O-C.1.1, Figure O-C.1.2, Figure O-C.1.3, Figure O-C.1.4)
local panel_20_name "all"
local panel_20_params wars(all) gprc_only(1)                                   // Only countries with GPRC data
local panel_20_specs destroles desttrd                                         // Destruction-focused (GPRC) specifications
local panel_20_layouts macro society trade                                     // All variable layouts
local panel_20_horizons 8                                                      // 8-year horizon
local panel_20_estopt standard                                                 // Standard estimation options

* Panel 21: European countries only (Figure O-B.7.1 middle panel)
local panel_21_name "region_europe"
local panel_21_params wars(all) region("Europe")                               // European countries only
local panel_21_specs casroles castrd                                           // Baseline specifications
local panel_21_layouts cycle_small                                             // Compact layout for regional analysis
local panel_21_horizons 8                                                      // 8-year horizon
local panel_21_estopt standard                                                 // Standard estimation options
local panel_21_legoptions loff                                                 // No legend for combined plots

* Panel 22: Americas countries only (Figure O-B.7.1 top panel)
local panel_22_name "region_americas"
local panel_22_params wars(all) region("Americas")                             // Americas countries only
local panel_22_specs casroles castrd                                           // Baseline specifications
local panel_22_layouts cycle_small                                             // Compact layout for regional analysis
local panel_22_horizons 8                                                      // 8-year horizon
local panel_22_estopt standard                                                 // Standard estimation options
local panel_22_legoptions loff                                                 // No legend for combined plots

* Panel 23: Asian countries only (Figure O-B.7.1 bottom panel)
local panel_23_name "region_asia"
local panel_23_params wars(all) region("Asia")                                 // Asian countries only
local panel_23_specs casroles castrd                                           // Baseline specifications
local panel_23_layouts cycle                                                   // Standard cycle layout
local panel_23_horizons 8                                                      // 8-year horizon
local panel_23_estopt standard                                                 // Standard estimation options

* Panel 24: Control for nationalism (Figure O-C.6.1, Figure O-C.6.2, Figure O-C.6.3, Figure O-C.6.4)
local panel_24_name "nationalism"
local panel_24_params wars(all)                                                // All wars
local panel_24_specs casroles castrd                                           // Baseline specifications
local panel_24_layouts macro society trade                                     // All variable layouts
local panel_24_horizons 8                                                      // 8-year horizon
local panel_24_estopt standard                                                 // Standard estimation options
local panel_24_estctrls l(0/4).nationalism                                     // Control for lagged nationalism

* Panel 25: Control for military strength (Figure O-C.14.1, Figure O-C.14.2, Figure O-C.14.3, Figure O-C.14.4)
local panel_25_name "milstrength"
local panel_25_params wars(all)                                                // All wars
local panel_25_specs casroles castrd                                           // Baseline specifications
local panel_25_layouts macro society trade                                     // All variable layouts
local panel_25_horizons 8                                                      // 8-year horizon
local panel_25_estopt standard                                                 // Standard estimation options
local panel_25_estctrls l(0/4).cinc                                            // Control for lagged CINC scores

* Panel 26: Control for trade openness (Figure O-C.7.1, Figure O-C.7.2, Figure O-C.7.3, Figure O-C.7.4)
local panel_26_name "openness"
local panel_26_params wars(all)                                                // All wars
local panel_26_specs casroles castrd                                           // Baseline specifications
local panel_26_layouts macro society trade                                     // All variable layouts
local panel_26_horizons 8                                                      // 8-year horizon
local panel_26_estopt standard                                                 // Standard estimation options
local panel_26_estctrls l(0/4).openness                                        // Control for lagged trade openness

* Panel 27: Prior to the Kellog-Briand Pact of 1928 (Figure O-B.3.1, Figure O-B.3.2, Figure O-B.3.3, Figure O-B.3.4)
local panel_27_name "prekb"
local panel_27_params wars(all) period(prekb)                                  // Prior to Kellog-Briand Pact of 1928
local panel_27_specs casroles castrd                                           // Baseline specifications
local panel_27_layouts macro society trade                                     // All variable layouts
local panel_27_horizons 8                                                      // 8-year horizon
local panel_27_estopt standard                                                 // Standard estimation options

* Panel 28: After the Kellog-Briand Pact of 1928 (Figure O-B.3.5, Figure O-B.3.6, Figure O-B.3.7, Figure O-B.3.8)
local panel_28_name "postkb"
local panel_28_params wars(all) period(postkb)                                  // After Kellog-Briand Pact of 1928
local panel_28_specs casroles castrd                                            // Baseline specifications
local panel_28_layouts macro society trade                                      // All variable layouts
local panel_28_horizons 8                                                       // 8-year horizon
local panel_28_estopt standard                                                  // Standard estimation options

* ==============================================================================
* ESTIMATION OPTIONS
* ==============================================================================
* Define different estimation option sets for various robustness checks
* ==============================================================================
local estopt_standard                            // Standard estimation (baseline)
local estopt_timefe timefe(1)                    // Include time fixed effects
local estopt_postww cas(0.01) integration(0.02)  // Post-WW specific options with integration parameters


* ==============================================================================
* MAIN EXECUTION LOOP
* ==============================================================================
* Generate all impulse response figures by systematically looping through
* all panel configurations, horizons, specifications, layouts, and estimation options
* ==============================================================================

forvalues panel_id=1/`panels' {

	* Build panel dataset for current configuration
	qui build_panel, `panel_`panel_id'_params'

	* Loop through all forecast horizons for this panel
	foreach h_max in `panel_`panel_id'_horizons' {

		* Loop through all econometric specifications
		foreach spec in `panel_`panel_id'_specs' {

			* Loop through all variable layouts (macro, society, trade, etc.)
			foreach layout in `panel_`panel_id'_layouts' {

				* Loop through all estimation option sets
				foreach estopt in `panel_`panel_id'_estopt' {

					* Define output file path with descriptive naming convention
					local path "${DIR_DATA_EXPORTS}/figures/lp/panel[`panel_`panel_id'_name']_layout[`layout']_spec[`spec']_estopt[`estopt']_h[`h_max'].pdf"

					* Skip if file already exists (avoid re-computation)
					* if fileexists("`path'") == 1 {
					* 	continue
					* }

					* Generate individual plots for each variable in the layout
					local j = 1
					foreach depvar in `layout_`layout'_depvars' {

						* Configure x-axis title (only show for bottom row of plots)
						local count = `:word count `layout_`layout'_depvars''
						local xtitle none
						if `j' >= (`count'-1) {
							local xtitle
						}

						* Configure legend (only show in first plot to avoid duplication)
						if `j' == 1 {
							local legend "combined"
						}
						else {
							local legend "off"
						}

						* Estimate local projections and create individual plot
						qui run_and_plot_lp, ///
							depvar(`depvar') ///                          // Dependent variable
							h_max(`h_max') ///                            // Maximum forecast horizon
							spec(`spec') ///                              // Econometric specification
							name(`depvar') ///                            // Graph name
							xtitle(`xtitle') ///                          // X-axis title setting
							legend(`legend') ///                          // Legend setting
							title(`label_`depvar'') ///                   // Plot title (human-readable)
							scale(0.8) ///                                // Plot scale factor
							`estopt_`estopt'' ///                         // Estimation options
							custom_controls(`panel_`panel_id'_estctrls')  // Additional control variables

						local ++j

						* Export estimation results for baseline specifications (e.g. for model matching)
						if ("`spec'" == "casroles" | "`spec'" == "castrd" | "`spec'" == "castrd_bell") & "`panel_`panel_id'_name'" == "all" {
							mat2txt, matrix(mat_estimates) saving("${DIR_DATA_EXPORTS}/figures/lp_log/panel[`panel_`panel_id'_name']_layout[`layout']_spec[`spec']_estopt[`estopt']_h[`h_max']_`depvar'.txt") replace
						}
					}

					* Combine all individual plots into a single layout
					grc1leg2 `layout_`layout'_depvars', ///
						cols(2) ///                                       // Two columns
						margins(zero) ///                                 // No margins between plots
						ysize(`layout_`layout'_ysize') ///                // Layout height
						xsize(`layout_`layout'_xsize') ///                // Layout width
						imargin(small) ///                                // Small internal margins
						symxsize(*1.5) ///                                // Symbol size adjustment
						scale(`layout_`layout'_scale') ///                // Overall scale factor
						`panel_`panel_id'_legoptions'                     // Panel-specific legend options

					* Export combined figure as PDF
					graph export "`path'", replace
				}
			}
		}
	}
}
