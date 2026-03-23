/******************************************************************************
* Table O-A.4: Military strength and the economy
*
* This program analyzes the relationship between economic strength (GDP) and
* military capabilities (CINC - Composite Index of National Capability) using
* panel regression methods.
*
* MAIN FUNCTIONALITY:
* - Constructs balanced panel dataset for all wars sample
* - Creates economic growth and military capability growth variables
* - Estimates fixed effects regressions with country and year controls
* - Tests relationship between GDP levels/growth and military capabilities
* - Generates LaTeX regression table
*
* VARIABLES:
* - lcinc: Log of Composite Index of National Capability (military strength)
* - lgdp: Log of Gross Domestic Product (economic strength)
* - dlgrowth: GDP growth rate (first difference of log GDP)
*
* OUTPUT:
* - LaTeX table: strengthgrowth.tex
* - Two-column regression table showing level and growth relationships
******************************************************************************/

* Load panel construction utilities and build dataset
do "${DIR_SRC_UTILS}/panel.do"
build_panel, wars(all)

* Generate key variables for analyzing economic-military relationship
gen dlgrowth = lgdp - l.lgdp
gen dlcinc = log(cinc) - log(l.cinc)
gen lcinc = log(cinc)

* Clear previous estimation results
eststo clear

* Regression 1: Military capabilities on GDP level
* Tests: Do richer countries have stronger militaries?
eststo: reghdfe lcinc lgdp, absorb(iso year) cluster(year) nocons
estadd local hascfe "\checkmark"
estadd local hasyfe "\checkmark"

* Regression 2: Military capabilities on GDP growth
* Tests: Does economic growth lead to military expansion?
eststo: reghdfe lcinc dlgrowth, absorb(iso year) cluster(year) nocons
estadd local hascfe "\checkmark"
estadd local hasyfe "\checkmark"

* Set descriptive variable labels for table presentation
label var lgdp "Log GDP"
label var dlgrowth "GDP Growth"

* Export comprehensive regression table with:
* - Column 1: Military capabilities on GDP level
* - Column 2: Military capabilities on GDP growth
* - Fixed effects indicators, R-squared, and sample size
esttab using "${DIR_DATA_EXPORTS}/tables/strengthgrowth.tex", ///
    tex ///                                               // LaTeX format
    scalars("hascfe" "hasyfe") ///                        // Include FE indicators
    cells(b(fmt(a3)) se(fmt(a3) par) p(fmt(%12.3fc) par(\{ \}))) ///  // Coef, SE, p-values
    ar2 ///                                               // Include adjusted R-squared
    nostar ///                                            // No significance stars
    label ///                                             // Use variable labels
    substitute(\_ _) ///                                  // LaTeX underscore handling
    stats(hascfe hasyfe r2_a_within N, ///                // Table statistics
        fmt(1 1 2 "%9.0fc") ///                           // Format specifications
        label("Country fixed effects" "Year fixed effects" "Adj. within \$R^2\$" "\$N\$")) ///
    nonotes nomtitles nonumbers ///                       // Clean table appearance
    eqlabels(none) collabels(none) ///                    // No equation/column labels
    replace ///                                           // Replace existing file
    varlabels(_cons Constant , ///                        // Variable label customization
        elist(lgdp "\noalign{\vskip 1.3mm}" ///           // Add spacing after variables
              dlgrowth "\noalign{\vskip 1.3mm}" ///
              dist_ukr_rest "\noalign{\vskip 1.3mm}")) ///
    fragment                                              // Generate fragment for inclusion

* Clear stored estimation results to free memory
eststo clear
