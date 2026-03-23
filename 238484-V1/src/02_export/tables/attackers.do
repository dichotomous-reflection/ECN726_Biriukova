/******************************************************************************
* Table O-A.5: War initiators and becoming war site
*
* This program analyzes the relationship between war initiation and the
* likelihood of experiencing battles on one's territory. It tests whether
* countries that start wars are more or less likely to have war sites
* (battles with casualties) on their own soil during interstate conflicts.
*
* MAIN FUNCTIONALITY:
* - Merges interstate war sites data with belligerent information
* - Creates binary indicators for war initiation and battle presence
* - Estimates logistic regressions with different fixed effects structures
* - Tests relationship between being a war initiator and hosting battles
* - Generates LaTeX regression table
*
* VARIABLES:
* - site: Binary indicator for having war sites (casualties > 0)
* - starter: Binary indicator for being the war initiator
*
* OUTPUT:
* - LaTeX table: attackers.tex
* - Three-column regression table with different fixed effects specifications
******************************************************************************/

* Load interstate war sites data (contains casualty information by country-war)
use "${DIR_DATA_PROCESSED}/interstate_sites.dta", clear

* Merge with belligerent data to get war initiation information
merge 1:1 iso warname using "${DIR_DATA_PROCESSED}/interstate_belligerents.dta", keep(master matched using)

* ==============================================================================
* Generate binary indicators for war initiation and battle site presence
* ==============================================================================

* Remove observations without initiation information (cannot classify as starter/non-starter)
drop if initiator == .
* Create binary indicator for war initiator
gen byte starter = initiator == 1
* Create binary indicator for having war sites with casualties
gen byte site = (casualties > 0) & (casualties != .)

* ==============================================================================
* Estimate logistic regression models with different fixed effects structures
* ==============================================================================
* Run preliminary probit model to check basic relationship
probit site starter, vce(robust)

* Clear previous estimation results
eststo clear

* Model 1: Basic logistic regression without fixed effects
eststo: logit site starter, vce(robust)

* Model 2: Conditional logit with war fixed effects
eststo: clogit site starter, group(warname) vce(robust)
estadd local haswarfe "\checkmark"

* Model 3: Conditional logit with country fixed effects
eststo: clogit site starter, group(iso) vce(robust)
estadd local hascfe "\checkmark"

* Set descriptive variable label for table presentation
label var starter "Initiator"

* ==============================================================================
* Export comprehensive regression table
* ==============================================================================
* - Column 1: Basic logit (unconditional relationship)
* - Column 2: Conditional logit with war fixed effects (within-war comparison)
* - Column 3: Conditional logit with country fixed effects (within-country comparison)
* - Fixed effects indicators, pseudo R-squared, and sample size
esttab using "${DIR_DATA_EXPORTS}/tables/attackers.tex", ///
    tex ///                                                // LaTeX format
    scalars("hascfe" "hasyfe") ///                         // Include FE indicators
    cells(b(fmt(a3)) se(fmt(a3) par) p(fmt(%12.3fc) par(\{ \}))) ///  // Coef, SE, p-values
    ar2 ///                                                // Include pseudo R-squared
    nostar ///                                             // No significance stars
    label ///                                              // Use variable labels
    substitute(\_ _) ///                                   // LaTeX underscore handling
    stats(haswarfe hascfe r2_p N, ///                      // Table statistics
        fmt(1 1 2 "%9.0fc") ///                            // Format specifications
        label("Conditional fixed effects (War)" "Conditional fixed effects (Country)" "Pseudo \$R^2\$" "\$N\$")) ///
    nonotes nomtitles nonumbers ///                        // Clean table appearance
    eqlabels(none) collabels(none) ///                     // No equation/column labels
    replace ///                                            // Replace existing file
    varlabels(_cons Constant , ///                         // Variable label customization
        elist(lgdp "\noalign{\vskip 1.3mm}" ///            // Add spacing after variables
              dlgrowth "\noalign{\vskip 1.3mm}" ///
              dist_ukr_rest "\noalign{\vskip 1.3mm}")) ///
    fragment                                               // Generate fragment for inclusion
