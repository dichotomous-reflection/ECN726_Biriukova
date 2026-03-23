/******************************************************************************
* WAR REASONS FREQUENCY TABLE GENERATOR
*
* This program generates Table 2 in the paper, which presents a comprehensive
* summary of the frequency and descriptions of different reasons for interstate
* wars. It processes hand-coded war reasons data to create a publication-ready
* LaTeX table showing how often each theoretical category appears in the dataset.
*
* OUTPUT:
* - LaTeX table: reasons.tex (Table 2 in paper)
* - Contains reason titles, descriptions, and frequency counts
* - Sorted by frequency (most common reasons first)
******************************************************************************/

* Import hand-coded war reasons from Excel sheet containing systematic coding of underlying causes for each interstate war
import excel "${DIR_DATA_RAW}/handcoded/sites_2025-06-02.xlsx", clear sheet("Reason coding") firstrow cellrange(A2)

* Set up all reason categories and prepare data for frequency analysis
local vars BorderClashes EconomicCausesLongRun Nationalism ReligiousorIdeologicalDiffe EconomicCausesShortRun DomesticPoliticsnoneconomic PowerTransitionBalanceofPow RevengeorRetribution

drop if _n >= 78 // Wars beyond row 78 are empty

* Convert reason indicators from string to numeric (0/1 binary indicators)
foreach var in `vars' {
	destring `var', replace
}

* Sum up how many wars fall into each reason category
* Note: Wars can have multiple reasons, so totals may exceed number of wars
collapse (sum) `vars'

* Transform from wide format (one row, multiple columns) to long format (one row per reason category) for easier table generation
xpose, varname clear
rename v1 number

* Sort reasons by frequency (most common first)
gsort -number

* ==============================================================================
* Create publication-ready titles and detailed theoretical descriptions
* for each war causation category based on established literature
* ==============================================================================

* Nationalism
gen title = "Nationalism" if _varname == "Nationalism"
gen description = "Creation of own sovereign state, wars for independence, imperialism" if _varname == "Nationalism"

* Power Transition
replace title = "Power Transition \newline or Security Dilemma" if _varname == "PowerTransitionBalanceofPow"
replace description = "A rising power challenges a dominant one. Classic examples of the security dilemma in action are situations, where measures taken by one country to increase its security lead others to feel less secure and to take countermeasures, resulting in increased tensions that can lead to war." if _varname == "PowerTransitionBalanceofPow"

* Religion or Ideology
replace title = "Religion or Ideology" if _varname == "ReligiousorIdeologicalDiffe"
replace description = "Deep-rooted disagreements over religious beliefs or ideologies (e.g., communism)" if _varname == "ReligiousorIdeologicalDiffe"

* Border Clashes
replace title = "Border Clashes" if _varname == "BorderClashes"
replace description = "Unclear borders or intensifying border clashes" if _varname == "BorderClashes"

* Economic, Long-Run
replace title = "Economic, Long-Run" if _varname == "EconomicCausesLongRun"
replace description = "States might go to war to gain control over trade routes, markets, or valuable resources; economic rivalry and protectionism" if _varname == "EconomicCausesLongRun"

* Domestic Politics
replace title = "Domestic Politics" if _varname == "DomesticPoliticsnoneconomic"
replace description = "Leaders may use foreign war to distract from domestic political issues or to rally their population around a common cause" if _varname == "DomesticPoliticsnoneconomic"

* Revenge or Retribution
replace title = "Revenge/Retribution" if _varname == "RevengeorRetribution"
replace description = "Wars can be initiated in response to perceived wrongs or to regain lost honor, even if there's no tangible gain to be had" if _varname == "RevengeorRetribution"

replace title = "Economic, Short-Run" if _varname == "EconomicCausesShortRun"
replace description = "Wars are fought because the economy is in a severe recession" if _varname == "EconomicCausesShortRun"

* ==============================================================================
* Clean up variables and export publication-ready LaTeX table
* ==============================================================================
drop _varname
* Order columns for publication: title, description, frequency count
order title description number

* Export as LaTeX table (Table 2 in paper), dataonly option creates table content without LaTeX table environment
texsave * using "${DIR_DATA_EXPORTS}/tables/descriptives/reasons.tex", replace dataonly
