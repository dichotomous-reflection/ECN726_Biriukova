/******************************************************************************
* EXTENSIVE SAMPLE DESCRIPTIVE STATISTICS TABLE GENERATOR
*
* This program generates comprehensive data availability tables showing the 
* number of observations available for different variables across multiple 
* samples and country roles. It creates separate tables for macroeconomic,
* trade, and societal variables, as well as a special winner/loser analysis.
*
* VARIABLE GROUPS:
* 1. Macroeconomic: GDP, CPI, capital stock, TFP, interest rates, equity, military
* 2. Trade: Imports and exports data availability
* 3. Society: Deaths, population, institutions, media freedom, judicial independence
*
* SAMPLE TYPES:
* - All wars: Complete dataset (1816-2007)
* - Post-WWII: Wars after 1945 for robustness
* - Causality: Subset for causal identification
*
* COUNTRY ROLES:
* - Total: All country-year observations
* - War sites: Countries where wars physically occurred
* - Belligerents: Countries actively fighting in wars
* - Third parties: Countries affected through economic channels
*
* OUTPUT:
* - LaTeX fragments for Appendix Table A1 showing data availability
* - Files: sample_extensive[sample]_[group].tex and sample_extensive_wl.tex
******************************************************************************/

* Set up three main variable groups with corresponding names and labels
local figures 3

* Macroeconomic indicators
local figure_1_vars lgdp lcpi lcs_ppp ltfp ltrate leqrtcum milex milper
local figure_1_name macro
local figure_1_rows QQQGDP "QQQCPI" "QQQCapital stock" "QQQTFP" "QQQLong-term interest rate" "QQQEquity return index" "QQQMilitary spending" "QQQMilitary personnel"

* Trade data
local figure_2_vars imports exports
local figure_2_name trade
local figure_2_rows QQQImports "QQQExports"

* Demographic and institutional indicators
local figure_3_vars deaths lpop medial judicial electoral institutions 
local figure_3_name society
local figure_3_rows QQQDeaths "QQQPopulation" "QQQMedia freedom" "QQQJudicial independence" "QQQElectoral fairness" "QQQInstitutions"

* Load utility functions for building balanced panel datasets
run "${DIR_SRC_UTILS}/panel.do"

* ==============================================================================
* Process each sample type and variable group combination to generate comprehensive data availability tables
* ==============================================================================

foreach sample in all postww causality {

	forvalues fignum = 1/`figures' {
		
		* Extract variable list for current group
		local variables `figure_`fignum'_vars'

		* Clear previous results and set up panel for current sample
		mat drop _all
		local rownames
		local i = 1

		* Build appropriate panel based on sample type with specific restrictions
		if "`sample'" == "all" {
			local sample ""
			build_panel, wars(all)
		}
		else if "`sample'" == "postww" {
			local sample "_postww"
			build_panel, wars(all) postww(1)
		}
		else if "`sample'" == "causality" {
			local sample "_causality"
			build_panel, wars(causality)
		}

		* Count observations for each variable across different country roles
		foreach variable in `variables' {
			
			* Total country-year observations with available data
			sum `variable' if `variable' != .
			local macro_total = r(N)

			* Countries where wars physically occurred with data available
			sum regr_cas_phi_site if regr_cas_phi_site > 0 & `variable' != .
			local macro_home = r(N)

			* Countries actively fighting in wars with data available
			sum regr_cas_phi_bell if regr_cas_phi_bell > 0 & `variable' != .
			local macro_bell = r(N)

			* Countries affected through economic channels with data available
			sum regr_cas_phi_third if regr_cas_phi_third > 0 & `variable' != .
			local macro_third = r(N)

			* Organize counts into matrix row format
			local cols `macro_total', `macro_home', `macro_bell', `macro_third'
			
			* Build results matrix row by row
			if `i' == 1 {
				matrix results = (`cols')
			}
			else {
				matrix results = results \ (`cols')
			}

			local ++i
		}

		* Add row names
		matrix rownames results = `figure_`fignum'_rows'

		* Generate LaTeX table fragment
		tempfile tmp
		nois esttab matrix(results, fmt(%15.0fc %15.0fc %15.0fc)) using `tmp', ///
			nonumber nomtitles ///                    // No table numbers or titles
			mlabels(,none) collabels(,none) ///       // No model or column labels
			fragment ///                              // Fragment for inclusion
			nolines ///                               // No horizontal lines
			tex replace                               // LaTeX format

		* Post-process using R for cleaner string manipulation
		rcall: ///
			library(readr); ///
			content <- read_file("`tmp'"); ///
			content <- gsub("QQQ", "\\\\quad ", content); ///
			content <- gsub("(&\\s+[0-9,]+)(&\\s+)([0-9,]+)(&\\s+)([0-9,]+)(&\\s+[0-9,]+)", ///
				"\\1&         \\\\multicolumn{2}{c}{\\3}&       \\\\multicolumn{2}{c}{\\5}\\6", content); ///
			write_file(content, "${DIR_DATA_EXPORTS}/tables/descriptives/sample_extensive`sample'_`figure_`fignum'_name'.tex")
	}
}


* ==============================================================================
* WINNER/LOSER ANALYSIS FOR INTERSTATE WARS
* ==============================================================================

* Build panel dataset focused on interstate wars with winner/loser coding
build_panel, wars(interstate)

mat drop _all
local i = 1

* Calculate data availability for GDP and CPI across winner/loser categories
foreach variable in lgdp lcpi {
	
	* Total country-year observations with non-missing data
	sum `variable' if `variable' != .
	local macro_total = r(N)
	
	* Countries that hosted wars and were on the winning side
	sum regr_cas_phi_site_winner if regr_cas_phi_site_winner > 0 & `variable' != .
	local macro_home_winner = r(N)

	* Countries that hosted wars and were on the losing side
	sum regr_cas_phi_site_loser if regr_cas_phi_site_loser > 0 & `variable' != .
	local macro_home_loser = r(N)

	* Countries that fought in wars and were on the winning side
	sum regr_cas_phi_bell_winner if regr_cas_phi_bell_winner > 0 & `variable' != .
	local macro_bell_winner = r(N)

	* Countries that fought in wars and were on the losing side
	sum regr_cas_phi_bell_loser if regr_cas_phi_bell_loser > 0 & `variable' != .
	local macro_bell_loser = r(N)

	* Countries affected through economic channels (no winner/loser distinction)
	sum regr_cas_phi_third if regr_cas_phi_third > 0 & `variable' != .
	local macro_third = r(N)
	
	* Organize all counts into matrix row format
	local cols `macro_total', `macro_home_winner', `macro_home_loser', `macro_bell_winner', `macro_bell_loser', `macro_third'
	
	* Build results matrix row by row
	if `i' == 1 {
		matrix results = (`cols')
	}
	else {
		matrix results = results \ (`cols')
	}
	
	local ++i
}

* Add variable labels and export formatted LaTeX table
matrix rownames results = "\quad GDP" "\quad CPI"   // Add row names for variables

* Export winner/loser data availability table
nois esttab matrix(results, fmt(%15.0fc %15.0fc %15.0fc)) using "${DIR_DATA_EXPORTS}/tables/descriptives/sample_extensive_wl.tex", ///
	nonumber nomtitles ///                            // No table numbers or titles
	mlabels(,none) collabels(,none) ///               // No model or column labels
	fragment ///                                      // Fragment for inclusion
	nolines ///                                       // No horizontal lines
	tex replace                                       // LaTeX format, replace existing
