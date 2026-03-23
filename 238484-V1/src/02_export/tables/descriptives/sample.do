/******************************************************************************
* SAMPLE DESCRIPTIVE STATISTICS TABLE GENERATOR
*
* This program generates Table 1 in the paper, which presents comprehensive
* descriptive statistics for the war sites dataset across different war types.
* It creates separate tables for all wars, interstate wars, and intrastate wars,
* showing key statistics about casualties, war duration, and data availability.
*
* SAMPLE TYPES:
* - All wars: Complete dataset including both interstate and intrastate
* - Interstate wars: Wars between sovereign states
* - Intrastate wars: Civil wars and internal conflicts
*
* KEY STATISTICS:
* - Total number of war sites
* - Casualty rates (mean and median as % of local population)
* - War duration (mean and median in years spanned)
* - Data availability for different country roles
*
* OUTPUT:
* - LaTeX tables: sample_all.tex, sample_interstate.tex, sample_intrastate.tex
* - Used as Table 1 in the paper showing dataset characteristics
******************************************************************************/

* Process three different war samples to show robustness and coverage
local samples all interstate intrastate


foreach sample in `samples' {

	* Clear previous results and prepare for new sample analysis
	mat drop _all
	local rownames
	local i = 1

	* Load processed war sites data specific to current war type
	use "${DIR_DATA_PROCESSED}/sites_`sample'.dta", clear

	* Create war length variable for duration statistics
	*keep if casualties > 0
	gen length = end - start + 1

	* Compute descriptive statistics for casualty rates as % of population
	sum shock_caspop_home, d
	*local casualties_min = string(round(r(min)), "%9.0fc")
	*disp `casualties_min'
	local casualties_mean = round(r(mean) * 100, 0.001)
	local casualties_median = round(r(p50) * 100, 0.001)

	* Compute descriptive statistics for war length in years spanned
	sum length, d
	local length_mean = round(r(mean), 0.1)
	local length_median = r(p50)

	* Record total number of war sites in current sample
	local sites_total = _N

	* Construct panel dataset and count observations with macro data for different country roles in wars
	run "${DIR_SRC_UTILS}/panel.do"
	build_panel, wars(`sample')

	* Count observations with CPI data for war site countries
	sum lcpi if regr_cas_phi_site > 0
	local macro_home = r(N)

	* Count observations with CPI data for belligerent countries
	sum lcpi if regr_cas_phi_bell > 0
	local macro_bell = r(N)

	* Count observations with CPI data for third-party countries
	sum lcpi if regr_cas_phi_third > 0
	local macro_third = r(N)

	* Organize all calculated statistics into a single row for table
	local cols `sites_total', `casualties_mean', `casualties_median', `length_mean', `length_median', `macro_home', `macro_bell', `macro_third'

	* Build results matrix (one row per sample, but this loop processes one sample at a time)
	if `i' == 1 {
		matrix results = (`cols')
	}
	else {
		matrix results = results \ (`cols')
	}

	local i = `i' + 1

	* ===================================================================
	* GENERATE LATEX TABLE
	* ===================================================================
	matrix rownames results = ""
	tempfile tmp

	* Export matrix to LaTeX with specific formatting:
	* - Column formats: integers, 2 decimals, 2 decimals, 1 decimal, integers (x4)
	* - No table numbers, titles, or labels for fragment inclusion
	* - Fragment mode for inclusion in larger document
	* - No horizontal lines for cleaner appearance
	nois esttab matrix(results, fmt(%15.0fc %15.2fc %15.2fc %15.1fc %15.0fc %15.0fc %15.0fc %15.0fc)) using `tmp', ///
		nonumber nomtitles ///                        // No table numbering or titles
		mlabels(,none) collabels(,none) ///           // No model or column labels
		fragment ///                                  // Generate fragment (no begin/end tabular)
		nolines ///                                   // No horizontal lines
		tex replace                                   // LaTeX format, replace existing

	* Clean up LaTeX formatting by removing unwanted row identifier
	filefilter `tmp' "${DIR_DATA_EXPORTS}/tables/descriptives/sample_`sample'.tex", from("r1          &") to("") replace
}
