/******************************************************************************
* CASUALTIES vs DESTRUCTION SCATTER PLOT
*
* This program creates a binned scatter plot showing the relationship between
* war casualties (as percentage of local population) and economic destruction
* (measured as maximum 5-year GDP drawdown). This visualization helps examine
* whether wars with higher casualty rates also tend to cause more economic damage.
*
* MAIN OUTPUT:
* - PDF scatter plot showing casualties vs GDP drawdown relationship
*
* DATA SOURCE:
* - Processed war sites data containing casualty and economic impact measures
******************************************************************************/

* Load and transform data to appropriate scales for visualization
use "${DIR_DATA_PROCESSED}/sites_all.dta", clear
replace shock_caspop_home = shock_caspop_home * 100

* Convert log-transformed GDP drawdown back to percentage terms for easier interpretation in the visualization
replace drawdown = (1-exp(drawdown*-1)) * 100

* Create binned scatter plot with 25 quantile bins
binscatter shock_caspop_home drawdown, ///
    ytitle("Casualties / local population (in %)") ///       // Y-axis label
    xtitle("5-years maximum drawdown of GDP (in %)") ///     // X-axis label
    lcolor(purple) ///                                       // Line color
    mcolor(orange) ///                                       // Marker color
    xsize(20) ///                                            // Graph width
    ysize(9) ///                                             // Graph height
    scale(1.4) ///                                           // Overall scale factor
    nquantiles(25)                                           // Number of bins (25 quantiles)

* Export scatter plot as PDF
graph export "${DIR_DATA_EXPORTS}/figures/casdestr.pdf", as(pdf) replace
graph close
