/******************************************************************************
* CASUS BELLI LATEX DOCUMENTATION GENERATOR
*
* This program generates a comprehensive LaTeX document containing detailed
* information about the reasons for war (casus belli) for each interstate war
* in the dataset.
*
* MAIN FUNCTIONALITY:
* - Extracts war onset dates from CoW interstate war data
* - Processes hand-coded war reasons from Excel sheets
* - Handles complex text cleaning for LaTeX compatibility
* - Generates structured LaTeX document with sources and excerpts
*
* OUTPUT STRUCTURE:
* - LaTeX file: casusbelli.tex (Online Appendix O-E)
* - Contains war-by-war documentation with:
*   * War name and onset year
*   * Coded reasons (nationalism, power transition, etc.)
*   * Source citations and detailed excerpts
*   * Formatted tables with alternating row colors
*
******************************************************************************/

* ==============================================================================
* STEP 1: EXTRACT WAR ONSET DATES FROM COW DATA
* ==============================================================================
import delimited "${DIR_DATA_RAW}/cow/wars/Inter-StateWarData_v4.0.csv", clear
collapse (min) startyear1, by(warname)
rename startyear1 start
tempfile start
save `start'

* ==============================================================================
* STEP 2: LOAD WAR REASONS CODING DATA
* ==============================================================================
import excel "${DIR_DATA_RAW}/handcoded/sites_2025-06-02.xlsx", clear sheet("Reason coding") firstrow cellrange(A2)
rename war warname
drop if warname == ""
merge 1:1 warname using `start', keep(matched master) nogen  // Merge with start dates
replace start = 2022 if warname == "Invasion of Ukraine"     // Manual correction for recent conflict

* ==============================================================================
* STEP 3: DEFINE REASON CATEGORIES AND LABELS
* ==============================================================================

* Define all reason categories (variable names from Excel sheet)
local reasons Nationalism PowerTransitionBalanceofPow ReligiousorIdeologicalDiffe BorderClashes EconomicCausesLongRun DomesticPoliticsnoneconomic RevengeorRetribution EconomicCausesShortRun
destring `reasons', replace  // Convert to numeric (0/1 indicators)

* Define human-readable labels for each reason category
local r_Nationalism "Nationalism"
local r_PowerTransitionBalanceofPow "Power Transition or Security Dilemma"
local r_ReligiousorIdeologicalDiffe "Religion or Ideology"
local r_BorderClashes "Border Clashes"
local r_EconomicCausesLongRun "Economic, Long-Run"
local r_DomesticPoliticsnoneconomic "Domestic Politics"
local r_RevengeorRetribution "Revenge/Retribution"
local r_EconomicCausesShortRun "Economic, Short-Run"


* ==============================================================================
* STEP 4: COMPREHENSIVE TEXT CLEANING FOR LATEX COMPATIBILITY
* ==============================================================================

* Process all 7 source columns (Source_1 through Source_7 and their _Extensive versions)
forvalues sourcecol = 1/7 {

	* ===================================================================
	* Remove problematic Unicode control characters that break LaTeX
	* ===================================================================
	replace Source_`sourcecol' = ustrregexra(Source_`sourcecol', "\u0002", "", .)
	replace Source_`sourcecol'_Extensive = ustrregexra(Source_`sourcecol'_Extensive, "\u0002", "", .)
	replace Source_`sourcecol'_Extensive = ustrregexra(Source_`sourcecol'_Extensive, "\u0308", """", .)
	replace Source_`sourcecol'_Extensive = ustrregexra(Source_`sourcecol'_Extensive, "\u02BF", "'", .)

	* ===================================================================
	* Escape characters that have special meaning in LaTeX
	* ===================================================================
	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "&", "\&", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "&", "\&", .)

	* ===================================================================
	* Handle various quotation mark formats for consistent LaTeX output
	* ===================================================================
	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "''", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "''", "", .)

	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "'", "APOSTROPHE", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "'", "APOSTROPHE", .)

	replace Source_`sourcecol' = subinstr(Source_`sourcecol', `"""', "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, `"""', """", .)

	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "``", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "``", """", .)

	* ===================================================================
	* Replace symbols that cause LaTeX compilation issues
	* ===================================================================
	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "$", "USD", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "$", "USD", .)

	replace Source_`sourcecol' = subinstr(Source_`sourcecol', "#", "\#", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "#", "\#", .)

	* ===================================================================
	* Remove internal library availability notes (HU Berlin library)
	* ===================================================================
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "–verfügbar in HU Bib–", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "--verfügbar in HU bib--", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "--verfügbar in HU Bib--", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "-- in HU Bib verfügbar--", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "-- in HU Bib verfügbar --", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "-- in HU bib verfügbar --", "", .)
	replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "--verfügbar in HU Bib, widmet dem Konflikt ein Kapitel--", """", .)

	* Additional cleaning options (commented out)
	*replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "-", "", .)   // Remove hyphens
	*replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, "(", "", .)   // Remove parentheses
	*replace Source_`sourcecol'_Extensive = subinstr(Source_`sourcecol'_Extensive, ")", "", .)   // Remove parentheses
}

* ==============================================================================
* STEP 5: GENERATE LATEX FILE
* ==============================================================================
cap file close f
file open f using "${DIR_DATA_EXPORTS}/tables/descriptives/casusbelli.tex", write replace

sort start

forvalues row = 1/`=_N' {
	* ===================================================================
	* Create formatted header with war name and onset year
	* ===================================================================
	local warname = warname[`row']
	local start = start[`row']
	#delimit ;
	local header "
	\textbf{`warname'} \n\n

	\underline{Onset:} `start'
	" ;
	#delimit cr
	file write f "`header'" _n _n

	* ===================================================================
	* Generate bulleted list of coded reasons for this war
	* ===================================================================
	file write f "\underline{Reasons:}" _n
	file write f "\begin{itemize}" _n

	* Loop through all possible reasons and include those coded as present
	foreach reason in `reasons' {
		if `reason'[`row'] == 1 {
			file write f "\item `r_`reason''" _n
		}
	}

	file write f "\end{itemize}" _n _n

	* ===================================================================
	* Generate comprehensive table of sources and excerpts
	* ===================================================================

	#delimit ;
	local body_reasons_header "
	\underline{Sources:} \n
	\rowcolors{3}{white}{light-gray} \n
	{\scriptsize \n
	\begin{longtable}{p{0.2\textwidth}p{0.8\textwidth}} \n
	\hiderowcolors% \n
	\toprule \n
	Source & Excerpt \\ \n
	\midrule \n
	\showrowcolors% \n
	\endfirsthead% \n
	\hiderowcolors% \n
	\toprule \n
	Source & Excerpt \\ \n
	\midrule \n
	\showrowcolors% \n
	\endhead% \n
	\midrule \n
	\endfoot% \n
	\hiderowcolors% \n
	\bottomrule \n
	\showrowcolors% \n
	\endlastfoot% \n
	" ;
	#delimit cr
	file write f "`body_reasons_header'" _n

	* Loop through up to 7 source columns and write non-empty entries; handle long text by breaking into manageable chunks
	forvalues sourcecol = 1/7 {
		local source = "`=Source_`sourcecol'[`row']'"
		local excerpt = "`=Source_`sourcecol'_Extensive[`row']'"

		* Debug output
		disp "`source'"
		disp "YYYYYYYYYYYYYY"

		* Only process non-empty source-excerpt pairs
		if "`source'" != "" & "`excerpt'" != "" {
			* Break long source citations into chunks to avoid Stata string limits
			forvalues i = 1(244)`=length("`source'")' {
				local part = substr("`source'", `i', 244)
				file write f "`part'"
			}
			file write f " & "

			* Break long excerpts into chunks for proper handling
			disp `=length("`excerpt'")' // debug
			forvalues i = 1(244)`=length("`excerpt'")' {
				local part = substr("`excerpt'", `i', 244)
				file write f "`part'"
			}
			file write f "\n\\" _n
		}
	}

	* ===================================================================
	* Close LaTeX table environment and add page break
	* ===================================================================
	file write f "\end{longtable}"
	file write f "}" _n
	file write f "\clearpage" _n
}


* ==============================================================================
* STEP 6: FINALIZE LATEX FILE AND POST-PROCESSING
* ==============================================================================

file close f

* Convert escaped newline characters to actual newlines for proper LaTeX formatting
filefilter "${DIR_DATA_EXPORTS}/tables/descriptives/casusbelli.tex" "${DIR_DATA_EXPORTS}/tables/descriptives/casusbelli_tmp.tex", from("\BSn") to("\n") replace

* Restore apostrophes that were temporarily replaced during text cleaning
filefilter "${DIR_DATA_EXPORTS}/tables/descriptives/casusbelli_tmp.tex" "${DIR_DATA_EXPORTS}/tables/descriptives/casusbelli.tex", from("APOSTROPHE") to("'") replace

* Note: The temporary file (casusbelli_tmp.tex) is overwritten in the second step
* Final output: casusbelli.tex ready for LaTeX compilation
