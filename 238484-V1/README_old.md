**Contributors**

| Jonathan Federle | André Meier | Gernot J. Müller | Willi Mutschler | Moritz Schularick |
| ---------------- | ----------- | ---------------- | --------------- | ----------------- |

# Replication Package: The Price of War


## Table of Contents

- [Overview](#overview)
- [Quick Instructions for Replication](#quick-instructions-for-replication)
- [Data Availability and Provenance Statements](#data-availability-and-provenance-statements)
  - [Sources, License, and Citation of Raw Data](#sources-license-and-citation-of-raw-data)
  - [Handcoded data](#handcoded-data)
  - [Misc files](#misc-files)
  - [Preprocessed files](#preprocessed-files)
  - [Statement about Rights](#statement-about-rights)
  - [License for Code](#license-for-code)
- [Computational requirements](#computational-requirements)
  - [Software Requirements](#software-requirements)
  - [Controlled Randomness](#controlled-randomness)
  - [Hardware Requirements and Runtime](#hardware-requirements-and-runtime)
- [Description of programs/code](#description-of-programscode)
- [List of tables and programs](#list-of-tables-and-programs)
- [References](#references)
- [PDF Generation](#pdf-generation)


## Overview

The code in this replication package reproduces all figures and tables using Stata and R.
Users should expect the code to run for about 1 hour and 10 minutes on a standard (2025) desktop machine.


## Quick Instructions for Replication

1. **Install required software**: Ensure you have R version 4.5.1 and Stata version 19.5 installed on your system.

2. **Set up R user library** (first-time R users only): If this is a clean R installation, you need to open R once and install any package to properly configure your user library.
For example, run the following command in R:
```r
install.packages("readstata13")
```
This step is necessary because the automated installation of packages in Stata via `setup.do` requires a properly configured R user library.

3. **Set up project directory**: Either place the replication files in `~/Documents/price-of-war` or adjust the path on line 20 of `main.do` to match your chosen location.

4. **Install required software dependencies**: In Stata, run `do setup.do` to install all dependencies for both Stata and R.

5. **Execute the main replication script**: In Stata, run `do main.do` to execute all analysis steps in sequence.
This script integrates R functionality through the [`rcall` package](https://github.com/haghish/rcall), allowing R code to be executed seamlessly from within Stata.


\clearpage
## Statement about Rights

- We certify that the authors of the manuscript have legitimate access to and permission to use the data used in this manuscript.
- We certify that the authors of the manuscript have documented permission to redistribute/publish the data contained within this replication package.


## License for Code

The source code is licensed under the **Modified BSD (3-Clause)** license, whereas all handcoded and preprocessed data and documentation files are licensed under the **Creative Commons Attribution 4.0 International** license.
See [LICENSE.txt](LICENSE.txt) for more details.


## Data Availability and Provenance Statements

Public-use datasets listed in “Sources, License, and Citation of Raw Data” are redistributed in this archive under their original licenses in `data/01_raw/*`, except for the *Correlates of War* (COW) datasets, which are not redistributed and must be obtained directly from the [COW website](https://correlatesofwar.org/data-sets/).

All scripts needed to clean, analyze, and reproduce results are in `src/*`; processed outputs are written to `data/02_processed` and final exports to `data/03_exports`.

Upon publication, a static copy of this replication package will be archived at [DOI to be added].

### Sources, License, and Citation of Raw Data

The following table lists all raw datasets used in the replication and their provenance (as provided by the original data providers).

Locations in the table refer consistently to subfolders of `data/01_raw/*`.

Below the table, we provide a clear description of access modalities and source locations for each dataset, as well as the license and citation information.

| Dataset                                        | Filename                                   | Location                               | Provision   | Original license                         | Data citation                      | Other citation |
| ---------------------------------------------- | ------------------------------------------ | -------------------------------------- | ----------- | ---------------------------------------- | -----------------------------------| -------------- |
| Geopolitical Risk Index (2024-11-18 vintage)   | data\_gpr\_export.xls                      | caldara/                               | Included    | CC-BY-4.0                                | Iacoviello and Caldara (2022)      | Caldara and Iacoviello (2022) |
| CEPII Gravity (V202211)                        | Gravity_V202211.csv                        | cepii/                                 | Included    | Etalab Open License 2.0                  | Conte, Cotterlaz, and Mayer (2022) | Conte, Cotterlaz, and Mayer (2022) |
| CEPII TradHist (v4)                            | TRADHIST_v4.dta                            | cepii/                                 | Included    | Etalab Open License 2.0                  | Fouquin and Hugot (2016)           | Fouquin and Hugot (2016) |
| COW Direct Contiguity (v3.2)                   | contdird.csv                               | cow/contiguity/DirectContiguity320/    | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2017)   | Stinnett et al. (2002) |
| COW Intra-State War (v5.1)                     | INTRA-STATE WARS v5.1.dta                  | cow/Intra-State-Wars-v5.1              | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2020)   | Sarkees and Wayman (2010) |
| COW Inter-State War (v4.0)                     | Inter-StateWarData_v4.0.csv                | cow/wars                               | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2011b)  | Sarkees and Wayman (2010) |
| COW Extra-State War (v4.0)                     | Extra-StateWarData_v4.0.csv                | cow/                                   | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2011a)  | Sarkees and Wayman (2010) |
| COW National Material Capabilities (v6.0)      | NMC-60-wsupplementary.dta                  | cow/NMC-60-wsupplementary              | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2021)   | Singer, Bremer, and Stuckey (1972) |
| COW Territorial Change (v6)                    | tc2018.csv                                 | cow/terr-changes-v6                    | COW website | https://correlatesofwar.org/data-sets/   | Correlates of War Project (2019)   | Tir et al. (1998) |
| Global Macro Database (2025_01)                | GMD.dta                                    | globalmacrodatabase                    | Included    | CC BY-NC-SA 4.0                          | Müller et al. (2025)               | Müller et al. (2025) |
| Human Mortality Database (01/09/2025)          | All files in folder                        | humanmortalitydatabase                 | Included    | CC-BY-4.0                                | Human Mortality Database (2025)    | |
| IMF Direction of Trade Statistics (2025-09-03) | DOT_03-09-2025 10-54-48-44\_timeSeries.csv | IMF                                    | Included    | IMF Open Data Policy                     | International Monetary Fund (2025) | International Monetary Fund (1993) |
| Long-Term Productivity (v2.6)                  | BCLDatabase\_online\_v2.6.xlsx             | ltp                                    | Included    | free for non-commercial use              | Bergeaud, Cette, and Lecat (2016)  | Bergeaud, Cette, and Lecat (2023) |
| Macro History Database (R6)                    | JSTdatasetR6.dta                           | macrohistory                           | Included    | CC BY-NC-SA 4.0                          | Jordà et al. (2022)                | Jordà, Schularick, and Taylor (2017); Jordà et al. (2019) |
| Maddison Project Database (2020)               | mpd2020.dta                                | maddison                               | Included    | CC BY 4.0                                | Bolt and Van Zanden (2020)         | Bolt and Van Zanden (2025) |
| Measuring Worth Dollar-Pound Exchange Rate     | fx.xlsx                                    | measuringworth                         | Included    | free for non-profit educational purposes | Officer (2024)                     | Officer (1996) |
| Our World In Data: Children born per woman     | children-born-per-woman.csv                | ourworldindata/children-born-per-woman | Included    | CC-BY-4.0                                | Our World in Data (2025a) | |
| Our World In Data: Population                  | population.csv                             | ourworldindata/population              | Included    | CC-BY-4.0                                | Our World in Data (2025b) | |
| Populist leaders and the economy               | ple\_dataset.dta                           | ple                                    | Included    | CC-BY-4.0                                | Funke, Schularick, and Trebesch (2022b) | Funke, Schularick, and Trebesch (2022a) |
| Manually matched population data               | population_matched.xlsx                    | roesel                                 | Included    | CC-BY-4.0                                | Fouquin and Hugot (2016); Gapminder (2023); Fink-Jensen (2015) | Mitchell (1992) |
| UCDP Battle-Related Deaths Dataset (24.1)      | BattleDeaths\_v24\_1\_conf.dta             | ucdp                                   | Included    | CC BY 4.0                                | UCDP (2024a)                       | Davies et al. (2025) |
| UCDP Dyadic Dataset (24.1)                     | Dyadic_v24\_1.dta                          | ucdp                                   | Included    | CC BY 4.0                                | UCDP (2024b)                       | Davies et al. (2025); Harbom, Melander, and Wallensteen (2008) |
| UCDP Georeferenced Event Dataset (GED, 24.1)   | GEDEvent\_v24\_1.dta                       | ucdp                                   | Included    | CC BY 4.0                                | UCDP (2024c)                       | Davies et al. (2025); Sundberg and Melander (2013) |
| UCDP/PRIO Armed Conflict Dataset (24.1)        | UcdpPrioConflict\_v24\_1.dta               | ucdp                                   | Included    | CC BY 4.0                                | UCDP (2024d)                       | Davies et al. (2025); Gleditsch et al. (2002) |
| Varieties of Democracy (V-Dem, v15)            | V-Dem-CY-Full+Others-v15.dta               | vdem/V-Dem-CY-FullOthers-v15_dta       | Included    | CC BY-SA 4.0                             | Coppedge et al. (2025)             | Pemstein et al. (2025) |
| World Bank World Development Indicators        | All files in folder                        | worldbank                              | Included    | CC BY 4.0                                | World Bank (2023); World Bank (2024a); World Bank (2024b); World Bank (2024c) | |


#### Geopolitical Risk Index

The geopolitical risk index (GPR) is a measure of adverse geopolitical events and associated risks based on a tally of newspaper articles covering geopolitical tensions.
Caldara and Iacoviello (2022) calculate the index by counting the number of articles related to adverse geopolitical events in each newspaper for each month (as a share of the total number of news articles).

The replication material of the published paper is available on the AEA repository (Iacoviello and Caldara, 2022).
Updated data are available at the [GPR website](https://www.matteoiacoviello.com/gpr.htm), with detailed documentation on the data collection and construction process, as well as changes to the vintages over time.

The data is in the public domain and can be used freely according to the CC-BY-4.0 license.
A copy of the data ([vintage 2024-11-18](https://github.com/iacoviel/iacoviel.github.io/blob/master/gpr_archive_files/data_gpr_daily_recent_20241118.xls), accessed November 23, 2024) is provided as part of this archive.


#### CEPII Gravity

The Gravity database collects country characteristics from the CEPII.
It is obtained by assembling data from institutional sources or from academic researchers.
The database gathers:
- Bilateral trade flows, from three distinct sources : IMF (DOTS), the UN (Comtrade) and the BACI database from CEPII.
- Geographical distance, including distances that reflect the within-country spatial distribution of activity.
- Trade facilitation measures : GATT/WTO membership, existence of trade agreements and nature of these agreements.
- Proxies for cultural proximity : language, religion, origins of the legal system, colonial ties, etc.
- Macroeconomic indicators : GDP, population, etc.

The data and codebook can be downloaded from the [CEPII Gravity website](https://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=8) (Conte, Cotterlaz, and Mayer, 2022).
The data is in the public domain and can be used freely according to the Etalab Open License 2.0.
A copy of the data ([version V202211](https://www.cepii.fr/DATA_DOWNLOAD/gravity/data/Gravity_csv_V202211.zip), accessed January 2, 2023) is provided as part of this archive.


#### CEPII TradHist

TRADHIST comprises five types of variables: bilateral annual nominal trade flows; country-level aggregate nominal imports and exports; nominal GDP; exchange rate; and bilateral features known to favor or hamper trade, including geographical distance, common borders, colonial and linguistic links, and bilateral tariffs.
TRADHIST includes about 1.9 million bilateral trade flows, 42,000 observations on total imports and exports, and 14,000 observations for GDP and exchange rates, for a 188-year period spanning 1827–2014.

The data and codebook can be downloaded from the [CEPII TradHist website](https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=32) (Fouquin and Hugot, 2016).
The data is in the public domain and can be used freely according to the Etalab Open License 2.0.
A copy of the data ([version v4](https://www.cepii.fr/DATA_DOWNLOAD/TRADHIST/TRADHIST_v4.dta), accessed January 13, 2025) is provided as part of this archive.


#### COW Direct Contiguity

The COW Direct Contiguity data identifies all direct contiguity relationships between states in the international system from 1816 through 2016.
The classification system for contiguous dyads is comprised of five categories, one for land contiguity and four for water contiguity.

The data and codebook can be downloaded from the [COW Direct Contiguity website](https://correlatesofwar.org/data-sets/direct-contiguity/) (Correlates of War, 2017).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [DirectContiguity320.zip](https://correlatesofwar.org/wp-content/uploads/DirectContiguity320.zip) from the website (last accessed September 30, 2025).


#### COW Intra-State War

The Correlates of War (COW) Project has utilized a classification of wars that is based upon the status of territorial entities, in particular focusing on those that are classified as members of the inter-state system (referred to as “states”).
This dataset encompasses wars that predominantly take place within the recognized territory of a state, or intra-state wars.

The data and codebook can be downloaded from the [COW War Data website](https://correlatesofwar.org/data-sets/cow-war/) (Correlates of War, 2020).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [Intra-State-Wars-v5.1.zip](https://correlatesofwar.org/wp-content/uploads/Intra-State-Wars-v5.1.zip) from the website (last accessed September 30, 2025).


\clearpage
#### COW Inter-State War

The Correlates of War (COW) Project has utilized a classification of wars that is based upon the status of territorial entities, in particular focusing on those that are classified as members of the inter-state system (referred to as “states”).
This dataset encompasses wars that take place between or among the recognized states, or inter-state wars.

The data and codebook can be downloaded from the [COW War Data website](https://correlatesofwar.org/data-sets/cow-war/) (Correlates of War, 2011b).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [Inter-StateWarData_v4.0.csv](https://correlatesofwar.org/wp-content/uploads/Inter-StateWarData_v4.0.csv) from the website (last accessed September 30, 2025).


#### COW Extra-State War

The Correlates of War (COW) Project has utilized a classification of wars that is based upon the status of territorial entities, in particular focusing on those that are classified as members of the inter-state system (referred to as “states”).
This dataset encompasses wars in the middle category - wars that take place between a state(s) and a nonstate entity outside the borders of the state, or extra-state wars.

The data and codebook can be downloaded from the [COW War Data website](https://correlatesofwar.org/data-sets/cow-war/) (Correlates of War, 2011a).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [Extra-StateWarData_v4.0.csv](https://correlatesofwar.org/wp-content/uploads/Extra-StateWarData_v4.0.csv) from the website (last accessed September 30, 2025).


#### COW National Material Capabilities

The National Material Capabilities data set contains annual values for total population, urban population, iron and steel production, energy consumption, military personnel, and military expenditure of all state members, currently from 1816-2016.
The widely-used Composite Index of National Capability (CINC) index is based on these six variables and included in the data set.

The data and codebook can be downloaded from the [COW National Material Capabilities website](https://correlatesofwar.org/data-sets/national-material-capabilities/) (Correlates of War, 2020).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [NMC_Documentation-6.0.zip](https://correlatesofwar.org/wp-content/uploads/NMC_Documentation-6.0.zip) from the website (last accessed September 30, 2025).


#### COW Territorial Change

This data set records all peaceful and violent changes of territory from 1816-2018.

The data and codebook can be downloaded from the [COW Territorial Change website](https://correlatesofwar.org/data-sets/territorial-change/) (Correlates of War, 2019).
The data is in the public domain, but due to its license restrictions cannot be provided as part of this archive.
The `main.do` file automatically downloads the file [terr-changes-v6.zip](https://correlatesofwar.org/wp-content/uploads/terr-changes-v6.zip) from the website (last accessed September 30, 2025).


#### Global Macro Database

This panel dataset consists of 46 macroeconomic variables across 243 countries from historical records beginning in the year 1086 until 2024, including projections through the year 2030.

The data and codebook can be downloaded from the [Global Macro Database website](https://www.globalmacrodata.com) (Müller et al., 2025).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY-NC-SA 4.0).
A copy of the data ([version 2025_01](https://www.globalmacrodata.com/GMD_2025_01.dta), accessed February 23, 2025) is provided as part of this archive.


#### Human Mortality Database

The Human Mortality Database (HMD) provides detailed high-quality harmonized mortality and population estimates.

The data and codebook can be downloaded from the [Human Mortality Database website](https://www.mortality.org) (HMD, 2025).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC-BY-4.0).
A copy of the data ([version 01/09/2025](https://www.mortality.org/File/Download/hcd/zip/all/all_data_20250109.zip), accessed March 11, 2025) is provided as part of this archive.


#### International Monetary Fund Direction of Trade Statistics (DOTS)

This database provides the value of merchandise exports and imports disaggregated according to a country's primary trading partners, areas and world aggregates.
The IMF supplements reported data by estimates whenever such data is not available or current.

The data can be downloaded from the [IMF Direction of Trade Statistics website](https://data.imf.org/dot) (International Monetary Fund, 2025), a guide is available as a book (International Monetary Fund, 1993).
The data is in the public domain and can be used freely according to the IMF's Open Data Policy.
A copy of the data (type: time series as csv file; annual frequency, time period 2010-2023, downloaded on March 9, 2025 at 10:54:48 CET) is provided as part of this archive with the following indicators:

- TMG_CIF_USD - Goods, Value of Imports, Cost, Insurance, Freight (CIF), US Dollars
- TXG_FOB_USD - Goods, Value of Exports, Free on board (FOB), US Dollars
- TBG_USD - Goods, Value of Trade Balance, US Dollars
- TMG_FOB_USD - Goods, Value of Imports, Free on board (FOB), US Dollars


#### Long-Term Productivity Database

The Long-Term Productivity database offers data on total factor productivity per hour worked, labor productivity per hour worked, capital intensity and GDP per capita.
These series cover at least the period 1890 to present annually for the following 17 countries Australia, Belgium, Canada, Denmark, Germany, Finland, France, Italy, Japan, the Netherlands, Norway, Portugal, Spain, Sweden, Switzerland, United Kingdom, United States.

The data can be downloaded from the [Long-Term Productivity Database website](https://www.longtermproductivity.com/download.html) (Bergeaud, Cette, and Lecat, 2023).
The variables are defined as follows:

- TFP: Solow residual from a constant return to scale Cobb-Douglas production function with capital stock and hours worked as input.
- LP: Labor productivity defined as the ratio of GDP over total hours worked.
- KI: Capital intensity defined as the ratio of total capital stock over total hours worked.
- GDPPC: GDP per capita.
All variables are calculated using GDP and capital stock series converted in US dollars of 2010 Purchasing Power Parities.
The data is in the public domain and can be used freely for non-commercial use.
A copy of the data ([version v2.6](https://www.longtermproductivity.com/download/BCLDatabase_online_v2.6.xlsx), accessed November 17, 2023) is provided as part of this archive.


#### Macrohistory Database

The database is a long-run macro-financial dataset that covers 18 advanced economies since 1870 on an annual basis covering core macroeconomic and financial variables.

The data and codebook can be downloaded from the [Macrohistory Database website](https://www.macrohistory.net/database/) (Jordà et al., 2022).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY-NC-SA 4.0).
A copy of the data ([version R6](https://www.macrohistory.net/app/download/9834512469/JSTdatasetR6.dta?t=1763503850), accessed February 23, 2025) is provided as part of this archive.


#### Maddison Project Database 2020

The Maddison Project Database provides information on comparative economic growth and income levels over the very long run.
The 2020 version of this database covers 169 countries and the period up to 2018.

The data and documentation can be downloaded from the [Maddison Project Database 2020 website](https://www.rug.nl/ggdc/historicaldevelopment/maddison/releases/maddison-project-database-2020) (Bolt and Van Zanden, 2020).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
A copy of the data ([version 2020](https://www.rug.nl/ggdc/historicaldevelopment/maddison/data/mpd2020.dta), accessed April 8, 2023) is provided as part of this archive.


\clearpage
#### Measuring Worth Dollar-Pound Exchange Rate

This dataset provides historical exchange rates between the US dollar and British pound from 1791 onwards, expressed as dollars per pound.
The data represents actual transaction rates (sight bills 1791-1912, cable transfers 1913+) averaged annually.

The data can be downloaded from the [Measuring Worth Dollar-Pound Exchange Rate website](https://www.measuringworth.com/exchangepound/) (Officer, 2024), with detailed methodology documented in Officer (1996).
The data is in the public domain and can be used freely for non-profit educational purposes.
A copy of the data ([1870-2022 USD/GBP](https://www.measuringworth.com/datasets/exchangepound/export.php?year_source=1870&year_result=2022), accessed January 6, 2024) is provided as part of this archive.


#### Our World in Data: Children born per woman

This dataset provides total fertility rates (births per woman) from Our World in Data (2025a), combining historical estimates from the Human Fertility Database for the period before 1950 with UN World Population Prospects data for the period 1950-2023.

The data can be downloaded from the [Our World in Data website](https://ourworldindata.org/grapher/children-born-per-woman) (based on Human Fertility Database (2024) and United Nations, 2024 with major processing by Our World in Data).
The data is in the public domain and can be used freely with proper attribution.
A copy of the data (accessed March 10, 2025) is provided as part of this archive.


#### Our World in Data: Population

This dataset provides population data from Our World in Data (2025b), combining historical estimates from the HYDE database (v3.3) for the period 10,000 BCE to 1799 with Gapminder (v7) data for the period 1800-1949 and with UN World Population Prospects data for the period 1950-2023 (2024 revision).

The data can be downloaded from the [Our World in Data website](https://ourworldindata.org/grapher/population) (based on HYDE (2024), Gapminder (2023), and United Nations (2024) with major processing by Our World in Data).
The data is in the public domain and can be used freely with proper attribution.
A copy of the data (accessed March 10, 2025) is provided as part of this archive.


#### Populist leaders and the economy

This dataset provides data on populist leaders and the economy from Funke, Schularick, and Trebesch (2023a).

The replication material of the published paper is available on the AEA repository (Funke, Schularick, and Trebesch, 2023b).
The data is in the public domain and can be used freely according to the CC-BY-4.0 license.
A copy of the data ([ple_dataset.dta](http://doi.org/10.3886/E184362V1), accessed January 17, 2023) is provided as part of this archive.


#### Manually matched population data

This dataset provides population estimates for specific country-years where belligerents lack coverage in standard historical population databases.
The dataset contains 105 country-year observations spanning 1875-1997, primarily covering war participants from the late 19th and early-to-mid 20th centuries.

Population estimates are drawn from three sources and matched using a hierarchical procedure:

1. **Primary sources**: CEPII TradHist database (Fouquin and Hugot, 2016) and Gapminder population data (Gapminder, 2023)
2. **Alternative source**: CLIO-INFRA Total Population database with decennial estimates (Fink-Jensen, 2015)

For country-years without exact matches in primary sources, alternative estimates are provided from CLIO-INFRA using the nearest decennial year (within ±50 years).
All three sources draw substantially on Mitchell (1992) and the Maddison Project (Bolt and Van Zanden, 2025).

The data is in the public domain and can be used freely according to the CC-BY-4.0 license.
A copy of the data (population_matched.xlsx) is provided as part of this archive.


#### UCDP Battle-Related Deaths Dataset

The UCDP Battle Deaths Dataset provides disaggregated data on battle-related deaths in armed conflicts.
The dataset includes information on the number of deaths per conflict and year, covering the period 1989-2023.

The data can be downloaded from the [UCDP Dataset Download Center: Historical Versions website](https://ucdp.uu.se/downloads/olddw.html) (Davies et al., 2025), the codebook is available at [ucdp-brd-241.pdf](https://ucdp.uu.se/downloads/brd/ucdp-brd-241.pdf).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
A copy of the data ([BattleDeaths_v24_1_conf.dta](https://ucdp.uu.se/downloads/brd/ucdp-brd-conf-241-dta.zip), accessed May 30, 2024) is provided as part of this archive.


#### UCDP Dyadic Dataset

The UCDP Dyadic Dataset provides dyad-level information on armed conflicts, specifying the parties involved in each conflict from 1946 to 2023.
This dataset disaggregates conflicts into dyads (pairs of opposing actors) and includes information on conflict type, intensity, and duration.

The data can be downloaded from the [UCDP Dataset Download Center: Historical Versions website](https://ucdp.uu.se/downloads/olddw.html) (Davies et al., 2025; Harbom, Melander, and Wallensteen, 2008), the codebook is available at [ucdp-dyadic-241.pdf](https://ucdp.uu.se/downloads/dyadic/ucdp-dyadic-241.pdf).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
A copy of the data ([Dyadic_v24_1.dta](https://ucdp.uu.se/downloads/dyadic/ucdp-dyadic-241-dta.zip), accessed May 30, 2024) is provided as part of this archive.


#### UCDP Georeferenced Event Dataset (GED)

The UCDP Georeferenced Event Dataset provides detailed information on individual events of organized violence, geocoded to specific locations and dates.
The dataset covers the period 1989-2023 and includes information on event type, location coordinates, date, actors involved, and estimated fatalities.

The data can be downloaded from the [UCDP Dataset Download Center: Historical Versions website](https://ucdp.uu.se/downloads/olddw.html) (Davies et al., 2025, Sundberg and Melander, 2013), the codebook is available at [ged241.pdf](https://ucdp.uu.se/downloads/ged/ged241.pdf).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
A copy of the data ([GEDEvent_v24_1.dta](https://ucdp.uu.se/downloads/ged/ged241-dta.zip), accessed May 30, 2024) is provided as part of this archive.


#### UCDP/PRIO Armed Conflict Dataset

The UCDP/PRIO Armed Conflict Dataset provides annual data on armed conflicts from 1946 to 2023.
The dataset identifies conflicts based on a threshold of at least 25 battle-related deaths per year and includes information on conflict onset, duration, intensity, and conflict type (interstate, intrastate, or internationalized intrastate).

The data can be downloaded from the [UCDP Dataset Download Center: Historical Versions website](https://ucdp.uu.se/downloads/olddw.html) (Gleditsch et al., 2002; Pettersson and Öberg, 2020), the codebook is available at [ucdp-prio-acd-241.pdf](https://ucdp.uu.se/downloads/ucdpprio/ucdp-prio-acd-241.pdf).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
A copy of the data ([UcdpPrioConflict_v24_1.dta](https://ucdp.uu.se/downloads/ucdpprio/ucdp-prio-acd-241-dta.zip), accessed May 30, 2024) is provided as part of this archive.


#### Varieties of Democracy (V-Dem)

The Varieties of Democracy (V-Dem) dataset is a comprehensive resource that captures the multifaceted nature of democracy through over 500 indicators and 245 indices.
The dataset covers 202 polities from 1789 to 2024 and evaluates five high-level principles of democracy: electoral, liberal, participatory, deliberative, and egalitarian.
Data is collected through expert assessments using rigorous measurement models to provide nuanced insights into democratic practices worldwide.

The data and codebook can be downloaded from the [V-Dem Institute website](https://v-dem.net/data/the-v-dem-dataset/) (Coppedge et al., 2025, Pemstein et al., 2025).
The data is in the public domain and can be used freely according to the Creative Commons Attribution-ShareAlike 4.0 International License (CC BY-SA 4.0).
A copy of the data ([version 15](https://v-dem.net/media/datasets/V-Dem-CY-FullOthers-v15_dta.zip), accessed May 31, 2025) is provided as part of this archive.


#### World Bank World Development Indicators

The World Bank's World Development Indicators (WDI) is a compilation of international statistics on global development.

The data can be downloaded from the [World Bank Data Catalog](https://datacatalog.worldbank.org/).
The data is in the public domain and can be used freely according to the Creative Commons Attribution 4.0 International License (CC BY 4.0).
Copies of the following data are provided as part of this archive:

- [NY.GDP.MKTP.KD](https://api.worldbank.org/v2/en/indicator/NY.GDP.MKTP.KD?downloadformat=csv): GDP (constant 2015 US$), 1960-2023 (World Bank, 2024a)
- [NY.GDP.PCAP.KD](https://api.worldbank.org/v2/en/indicator/NY.GDP.PCAP.KD?downloadformat=csv): GDP per capita (constant 2015 US$), 1960-2022 (World Bank, 2023)
- [FP.CPI.TOTL.ZG](https://api.worldbank.org/v2/en/indicator/FP.CPI.TOTL.ZG?downloadformat=csv): Inflation, consumer prices (annual %), 1960-2023 (World Bank, 2024b)
- [SP.POP.TOTL](https://api.worldbank.org/v2/en/indicator/SP.POP.TOTL?downloadformat=csv): Population, total, 1960-2023 (World Bank, 2024c)


\clearpage
### Handcoded data

Several data were originally collected by the authors and are distributed under the **Creative Commons Attribution 4.0 International** license in this replication package.
Those data are stored in `data/01_raw/handcoded/*` and explained in the table below.

| Filename                     | Description |
| ---------------------------- | ----------- |
| `sites_2025-06-02.xlsx`      | Main excel sheet comprising the interstate war site coding. The sheet "Reason coding" defines the Casus Belli Coding (see Online Appendix E). All other sheets collect the battle-level coding for each interstate war in sample. When no source is specified, the default source is Clodfelter (2017). |
| `sites_other_geocoding.xlsx` | Excel sheet comprising the casualties of intrastate/extrastate wars. |
| `gpt.xlsx`                   | Excel sheet comprising the comparison of GPT-4-identified sites with own coding. |
| `cow_codes_iso.csv`          | Table linking iso codes to COW country codes. |


### Misc files

In `ressources`, we store complementary files but not precisely qualifying as "data":

- `ressources/ne_50m_admin_0_countries`: Shape files for the creation of world maps (see Appendix Figure A.1).
- `ressources/pandoc`: Auxiliary files for PDF generation from README.md (see [PDF Generation](#pdf-generation)).


### Preprocessed files

The raw files above are automatically cleaned and prepared using a series of scripts located in `src/01_process`.
The table below provides a brief overview of each preprocessed file, where it is stored, and from which do file it is generated.
Throughout, preprocessed data files are stored in `data/02_processed` and do files generating those files are located in `src/01_process`.
To avoid redundancies, those paths are not included in the table below.

| Filename                         | Source              | File description |
| -------------------------------- | ------------------- | ---------------- |
| `all_belligerents.dta`           | `sites.do`          | List of all belligerents in interstate, intrastate, and extrastate wars |
| `causality_belligerents.dta`     | `sites.do`          | List of all belligerents in narratively identified interstate wars |
| `deflator.dta`                   | `deflator.do`       | CPI Deflator |
| `gdp_world.dta`                  | `macro.do`          | Time-series capturing global economic output |
| `gprc.dta`                       | `gprc.do`           | Geopolitical risk indices |
| `interstate_belligerents.dta`    | `interstate.do`     | List of all interstate war belligerents |
| `interstate_sites_gpt.dta`       | `sites.do`          | List of interstate sites identified via ChatGPT-4 |
| `interstate_sites.dta`           | `interstate.do`     | List of all interstate war sites |
| `intrastate_belligerents.dta`    | `intrastate.do`     | List of all intrastate and extrastate belligerents |
| `intrastate_sites.dta`           | `intrastate.do`     | List of all intrastate and extrastate war sites |
| `linking_cow_iso.dta`            | `isolinks.do`       | Mapper between ISO-3 codes and correlates of war country codes |
| `ltp.dta`                        | `ltp.do`            | Panel comprising capital stock and productivity across countries |
| `macro_gdp_wb.dta`               | `macro.do`          | GDP data from World Bank 2019+ |
| `macro.dta`                      | `macro.do`          | Panel consolidating all macro data |
| `milex.dta`                      | `milex.do`          | Panel on military expenditures |
| `mortality.dta`                  | `mortality.do`      | Panel on mortality statistics |
| `pop_world.dta`                  | `pop_world.do`      | Time-series capturing global population |
| `pop.dta`                        | `pop.do`            | Panel on population data |
| `sites_all_distances.dta`        | `sites.do`          | Dyadic relationships of countries to all interstate, intrastate, and extrastate war sites |
| `sites_all.dta`                  | `sites.do`          | List of all interstate, intrastate, and extrastate war sites including severity measures |
| `sites_causality_distances.dta`  | `sites.do`          | Dyadic relationships of countries to all narratively identified interstate war sites |
| `sites_causality.dta`            | `sites.do`          | List of all narratively identified interstate war sites |
| `sites_interstate_distances.dta` | `sites.do`          | Dyadic relationships of countries to all interstate war sites |
| `sites_interstate.dta`           | `sites.do`          | List of all interstate war sites including severity measures |
| `sites_intrastate_distances.dta` | `sites.do`          | Dyadic relationships of countries to all intrastate and extrastate war sites |
| `sites_intrastate.dta`           | `sites.do`          | List of all intrastate and extrastate war sites including severity measures |
| `territory_details.dta`          | `territory.do`      | Country-year panel of population changes due to territory changes |
| `territory.dta`                  | `territory.do`      | List of country-year combinations with territory changes |
| `trade_gravity.dta`              | `trade_gravity.do`  | Dyadic panel of gravity-imputed trade data |
| `trade_national.dta`             | `trade_national.do` | Panel of national trade data |


## Computational requirements


### Software Requirements

The replication package contains a `setup.do` to install all dependencies for both Stata and R.
The `main.do` sets up the necessary directory structure.
For completeness, we list the required software and dependencies below:


#### R Requirements

- **R version**: 4.5.1 or later
- **Required R packages** (installed automatically via rcall):
	- `readstata13` - Read Stata files in R
    - `countrycode` - Country name/code conversion
    - `haven` - Import/export SPSS, Stata, and SAS files
    - `tidyverse` - Collection of data science packages
    - `peacesciencer` - Peace science research tools
    - `stevemisc` - Miscellaneous functions for data analysis
    - `fixest` - Fast fixed-effects estimations
    - `modelsummary` - Create beautiful and customizable tables
    - `huxtable` - Easily create HTML and LaTeX tables
    - `tinytable` - Simple and lightweight table creation
    - `knitr` - Dynamic report generation
    - `WDI` - World Bank World Development Indicators


#### Stata Requirements

- **Stata version**: 19.5
- **Core Integration Tools**:
  - `github` - GitHub package manager for Stata
    - `rcall` - Execute R code from within Stata
    - `rcallcountrycode` - Stata wrapper for R's countrycode package

- **Regression and Econometric Tools**:
    - `estout` - Publication-quality regression tables and export to LaTeX, HTML, or text
    - `ftools` - Fast tools for large datasets (required by reghdfe)
    - `reghdfe` - High-dimensional fixed effects regression with multiple levels of clustering
    - `ppmlhdfe` - Poisson Pseudo-Maximum Likelihood with high-dimensional fixed effects
    - `xtscc` - Panel data regression with Driscoll-Kraay standard errors
    - `moremata` - Extended Mata library with additional mathematical and statistical functions
    - `mat2txt` - Convert matrices to text files

- **Data Manipulation Tools**:
    - `winsor2` - Winsorize variables at specified percentiles to handle outliers
    - `egenmore` - Additional egen functions for data manipulation and variable creation
    - `kountry` - Country name/code conversion

- **Visualization Tools**:
    - `grc1leg` - Combine graphs with a single common legend
    - `grc1leg2` - Enhanced version of grc1leg with additional options
    - `geoplot` - Geographical maps and spatial visualizations
    - `palettes` - Color palettes and schemes for graphs and visualizations
    - `colrspace` - Color space utilities (required by palettes)
    - `binscatter` - Binned scatter plots for visualizing relationships in large datasets
    - `texsave` - Export to LaTeX format

**Installation Process**: Run the program `setup.do` which will install all dependencies locally, and should be run once.


### Controlled Randomness

In `src/01_process/trade_gravity.do`, a pseudo random generator is used for the Poisson Pseudo-Maximum Likelihood estimation.
The seed is set to 0 to ensure reproducibility.


### Hardware Requirements and Runtime

- **Runtime**: Approximately 1 hour and 10 minutes
- **Storage**: Approximately 10 GB of disk space required
- The code was last run on the following machines:
  - Apple MacBook Pro M2 Max (Tahoe 26.0) with 64 GB of memory.
  - Apple Mac mini M4 Pro (Tahoe 26.0) with 64 GB of memory.
  - HP Elite Tower 800 G9 Desktop PC with 12th Gen Intel Core i7-12700 2.19 GHz (Windows 11 Home 24H2) with 64 GB of memory.
  - Lenovo ThinkSystem SR655 AMD EPYC 7402P 24C 2.8GHz (Ubuntu Linux 24.04 LTS) with 96 GB RAM.

## Description of programs/code

```bash
.
├── data/
│   ├── 01_raw/                   # only raw inputs (never edited)
│   ├── 02_processed/             # pipeline outputs from 01_raw
│   └── 03_exports/               # final tables/figures/logs/checks
├── LICENSES/                     # BSD-3-Clause and CC-BY-4.0 license texts
├── ressources/
│   ├── ne_50m_admin_0_countries/ # shapefiles for world map
│   └── pandoc/                   # PDF generation auxiliary files
├── src/
│   ├── 00_utils/                 # helper functions
│   ├── 01_process/               # preprocessing scripts
│   └── 02_export/                # export scripts
├── LICENSE.txt                   # license for code
├── main.do                       # main replication script
├── README.md                     # this file
├── setup.do                      # install dependencies for Stata and R (needs to be run only once)
└── .gitignore                    # gitignore file
```

- Programs in `src/00_utils` are helper functions facilitating repeated processes (downloads missing COW data, dynamic panel generations and local projections).
- Programs in `src/01_process` extract and reformat all datasets referenced above.
All files in this directory only read from `data/01_raw` and `data/02_processed` and write exclusively to `data/02_processed`.
- Programs in `src/02_export` generate all tables and figures in the main body of the article.
- The program `setup.do` installs all dependencies for Stata and R.
- The program `main.do` runs the entire analysis from start to end, possibly overwriting existing export files.
If some raw data are not shipped with the replication package, they are automatically downloaded (see above).

**Important**: The `main.do` script assumes the project is located at `~/Documents/price-of-war` as the Stata working directory.
If you have placed the replication package in a different location, you need to adjust the path on line 20 of `main.do`.


## List of tables and programs

The `main.do` script includes comprehensive comments that specify which code sections generate each figure and table appearing in the paper, appendix, and online appendix.

- Tables are generated by scripts located in `src/02_export/tables/`
- Figures are generated by scripts located in `src/02_export/figures/`
- In-text numerical values can be verified by examining the output from `src/02_export/textnumbers.do` and `tables/descriptives/battlenumbers.do` (for battle-related statistics)


\clearpage
## References

- Bergeaud, Antonin, Gilbert Cette, and Rémy Lecat. 2016. "Productivity Trends in Advanced Countries between 1890 and 2012." Review of Income and Wealth, 62 (3): 420–444. [doi:10.1111/roiw.12185](https://doi.org/10.1111/roiw.12185).

- Bergeaud, Antonin, Gilbert Cette, and Rémy Lecat. 2023. "The Long-Term Productivity Database." Data set, version v2.6. Data downloaded from [https://www.longtermproductivity.com/download.html](https://www.longtermproductivity.com/download.html) (accessed November 17, 2023).

- Bolt, Jutta, and Jan Luiten van Zanden. 2020. "Maddison tyle estimates of the evolution of the world economy. A new 2020 update." Maddison Project Working Paper WP-15. Data downloaded from [https://www.rug.nl/ggdc/historicaldevelopment/maddison/releases/maddison-project-database-2020](https://www.rug.nl/ggdc/historicaldevelopment/maddison/releases/maddison-project-database-2020) (accessed April 8, 2023).

- Bolt, Jutta, and Jan Luiten van Zanden. 2025. "Maddison-style estimates of the evolution of the world economy: A new 2023 update." Journal of Economic Surveys, 39 (2): 631–671. [doi:10.1111/joes.12618](https://doi.org/10.1111/joes.12618).

- Caldara, Dario, and Matteo Iacoviello. 2022. "Measuring Geopolitical Risk." American Economic Review, 112 (4): 1194–1225. [doi:10.1257/aer.20191823](https://doi.org/10.1257/aer.20191823).

- Clodfelter, Micheal. 2017. Warfare and Armed Conflicts: A Statistical Encyclopedia of Casualty and Other Figures, 1492–2015. 4th ed. Jefferson, NC: McFarland. ISBN 978-0786474707.

- Conte, Maddalena, Pierre Cotterlaz, and Thierry Mayer. 2022. "The CEPII Gravity Database." CEPII Working Paper 2022-05. Data downloaded as version V202211 from [https://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=8](https://www.cepii.fr/CEPII/en/bdd_modele/bdd_modele_item.asp?id=8) (accessed January 2, 2023).

- Coppedge, Michael, John Gerring, Carl Henrik Knutsen, Staffan I. Lindberg, Jan Teorell, David Altman, Fabio Angiolillo, Michael Bernhard, Agnes Cornell, M. Steven Fish, Linnea Fox, Lisa Gastaldi, Haakon Gjerløw, Adam Glynn, Ana Good God, Sandra Grahn, Allen Hicken, Katrin Kinzelbach, Joshua Krusell, Kyle L. Marquardt, Kelly McMann, Valeriya Mechkova, Juraj Medzihorsky, Natalia Natsika, Anja Neundorf, Pamela Paxton, Daniel Pemstein, Johannes von Römer, Brigitte Seim, Rachel Sigman, Svend-Erik Skaaning, Jeffrey Staton, Aksel Sundström, Marcus Tannenberg, Eitan Tzelgov, Yi-ting Wang, Felix Wiebrecht, Tore Wig, Steven Wilson, and Daniel Ziblatt. 2025. "V-Dem [Country-Year/Country-Date] Dataset v15." Varieties of Democracy (V-Dem) Project. Data downloaded as version 15 from [https://v-dem.net/data/the-v-dem-dataset/](https://v-dem.net/data/the-v-dem-dataset/) (accessed May 31, 2025). [doi:10.23696/vdemds25](https://doi.org/10.23696/vdemds25).

- Correlates of War Project. 2011a. "Extra-State War data set (v4.0)." Data available at [https://correlatesofwar.org/data-sets/cow-war/](https://correlatesofwar.org/data-sets/cow-war/) (accessed September 30, 2025).

- Correlates of War Project. 2011b. "Inter-State War data set (v4.0)." Data available at [https://correlatesofwar.org/data-sets/cow-war/](https://correlatesofwar.org/data-sets/cow-war/) (accessed September 30, 2025).

- Correlates of War Project. 2017. "Direct Contiguity Data, 1816-2016. Version 3.2." Data available at [https://correlatesofwar.org/data-sets/direct-contiguity/](https://correlatesofwar.org/data-sets/direct-contiguity/) (accessed September 30, 2025).

- Correlates of War Project. 2019. "Territorial Change, 1816-2018 (v6)." Data available at [https://correlatesofwar.org/data-sets/territorial-change/](https://correlatesofwar.org/data-sets/territorial-change/) (accessed September 30, 2025).

- Correlates of War Project. 2020. "Intra-State War data set (v5.1)." Data available at [https://correlatesofwar.org/data-sets/cow-war/](https://correlatesofwar.org/data-sets/cow-war/) (accessed September 30, 2025).

- Correlates of War Project. 2021. "National Material Capabilities (v6.0)." Data available at [https://correlatesofwar.org/data-sets/national-material-capabilities/](https://correlatesofwar.org/data-sets/national-material-capabilities/) (accessed September 30, 2025).

- Davies, Shawn, Therése Pettersson, Margareta Sollenberg, and Magnus Öberg. 2025. "Organized Violence 1989–2024, and the Challenges of Identifying Civilian Victims." Journal of Peace Research, 62 (4): 1223–1240. [doi:10.1177/00223433251345636](https://doi.org/10.1177/00223433251345636).

- Fink-Jensen, Jonathan. 2015. "Total Population." CLIO-INFRA, IISH Dataverse. Data available at [https://clio-infra.eu/Indicators/TotalPopulation.html](https://clio-infra.eu/Indicators/TotalPopulation.html) (accessed September 30, 2025).

- Fouquin, Michel, and Jules Hugot. 2016. "Two Centuries of Bilateral Trade and Gravity Data: 1827-2014." CEPII Working Paper 2016-14. Data downloaded as version v4 from [https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=32](https://www.cepii.fr/cepii/en/bdd_modele/bdd_modele_item.asp?id=32) (accessed January 13, 2025).

- Funke, Manuel, Moritz Schularick, and Christoph Trebesch. 2023a. "Populist Leaders and the Economy." American Economic Review, 113 (12): 3249–3288. [doi:10.1257/aer.20202045](https://doi.org/10.1257/aer.20202045).

- Funke, Manuel, Moritz Schularick, and Christoph Trebesch. 2023b. "Replication Data for: Populist Leaders and the Economy." American Economic Association, Inter-university Consortium for Political and Social Research (ICPSR). [doi:10.3886/E112357V1](https://doi.org/10.3886/E112357V1).

- Gapminder. 2023. "Population data (v7)." Data available at [https://gapm.io/d_popv7](https://gapm.io/d_popv7) (accessed March 31, 2023).

- Gleditsch, Nils Petter, Peter Wallensteen, Mikael Eriksson, Margareta Sollenberg, and Håvard Strand. 2002. "Armed Conflict 1946–2001: A New Dataset." Journal of Peace Research, 39 (5): 615–637. [doi:10.1177/0022343302039005007](https://doi.org/10.1177/0022343302039005007).

- Harbom, Lotta, Erik Melander, and Peter Wallensteen. 2008. "Dyadic Dimensions of Armed Conflict, 1946–2007." Journal of Peace Research, 45 (5): 697–710. [doi:10.1177/0022343308094331](https://doi.org/10.1177/0022343308094331).

- Human Fertility Database. 2024. "Human Fertility Database (HFD)." Max Planck Institute for Demographic Research (Germany) and Vienna Institute of Demography (Austria). Data downloaded from [https://www.humanfertility.org](https://www.humanfertility.org) (accessed November 19, 2024).

- Human Mortality Database. 2025. "Human Cause of Deaths data series (HCD)." Max Planck Institute for Demographic Research (Germany), University of California, Berkeley (USA), and French Institute for Demographic Studies (France). Version 01/09/2025 downloaded from [https://www.mortality.org/Data/HCD](https://www.mortality.org/Data/HCD).

- HYDE. 2024. "History Database of the Global Environment 3.3." Utrecht University. [doi:10.24416/UU01-AEZZIT](https://doi.org/10.24416/UU01-AEZZIT).

- Iacoviello, Matteo, and Dario Caldara. 2022. "Replication Data for: Measuring Geopolitical Risk." American Economic Association, Inter-university Consortium for Political and Social Research (ICPSR). [doi:10.3886/E154781V1](https://doi.org/10.3886/E154781V1). Vintage "November 18, 2024" downloaded from [https://www.matteoiacoviello.com/gpr.htm](https://www.matteoiacoviello.com/gpr.htm) (accessed November 23, 2024).

- International Monetary Fund. 1993. "A Guide to Direction of Trade Statistics." Washington, DC: International Monetary Fund. ISBN 9781451948431. [doi:10.5089/9781451948431.071](https://doi.org/10.5089/9781451948431.071).

- International Monetary Fund. 2025. "Direction of Trade Statistics." International Monetary Fund. Annual indicators (TMG_CIF_USD, TXG_FOB_USD, TBG_USD, TMG_FOB_USD) for 2010–2023 downloaded from [https://data.imf.org/dot](https://data.imf.org/dot) (accessed September 3, 2025).

- Jordà, Òscar, Katharina Knoll, Dmitry Kuvshinov, Moritz Schularick, and Alan M. Taylor. 2019. "The Rate of Return on Everything, 1870–2015." Quarterly Journal of Economics, 134 (3): 1225–1298. [doi:10.1093/qje/qjz012](https://doi.org/10.1093/qje/qjz012).

- Jordà, Òscar, Moritz Schularick, and Alan M. Taylor. 2017. "Macrofinancial History and the New Business Cycle Facts." In NBER Macroeconomics Annual 2016, Vol. 31, edited by Martin Eichenbaum and Jonathan A. Parker, 213–263. Chicago: University of Chicago Press. [doi:10.3386/w22743](https://doi.org/10.3386/w22743).

- Jordà, Òscar, Moritz Schularick, Alan M. Taylor, Xiaoting Chen, Sherifa Elsherbiny, Ricardo Duque Gabriel, and Chi Hyun Kim. 2022. "Documentation on the JST Database Update 2016–2020." Macrohistory Lab. Version R6 downloaded from [https://www.macrohistory.net/database/](https://www.macrohistory.net/database/) (accessed February 23, 2025).

- Müller, Karsten, Chenzi Xu, Mohamed Lehbib, and Ziliang Chen. 2025. "The Global Macro Database: A New International Macroeconomic Dataset." NBER Working Paper 33714. Cambridge, MA: National Bureau of Economic Research. [doi:10.3386/w33714](https://doi.org/10.3386/w33714). Version 2025_01 downloaded from [https://www.globalmacrodata.com/data.html](https://www.globalmacrodata.com/data.html) (accessed February 23, 2025).

- Mitchell, Brian R. 1992. International Historical Statistics: Europe, 1750–1988. 3rd ed. New York: Stockton Press. ISBN 978-1561590155.

- Officer, Lawrence H. 1996. Between the Dollar–Sterling Gold Points: Exchange Rates, Parity and Market Behavior. Cambridge: Cambridge University Press. ISBN 978-0-521-45462-9. [doi:10.1017/CBO9780511559723](https://doi.org/10.1017/CBO9780511559723).

- Officer, Lawrence H. 2024. "Dollar–Pound Exchange Rate From 1791." MeasuringWorth. Data downloaded from [http://www.measuringworth.com/exchangepound/](http://www.measuringworth.com/exchangepound/) (accessed January 6, 2024).

- Our World in Data. 2025a. "Fertility Rate: Births per Woman." Our World in Data. Data downloaded from [https://ourworldindata.org/grapher/children-born-per-woman?v=1&csvType=full&useColumnShortNames=false](https://ourworldindata.org/grapher/children-born-per-woman?v=1&csvType=full&useColumnShortNames=false) (accessed March 10, 2025). Sources: Before 1950: Human Fertility Database (2024); 1950–2023: United Nations World Population Prospects (2024).

- Our World in Data. 2025b. "Population." Our World in Data. Data downloaded from [https://ourworldindata.org/grapher/population?v=1&csvType=full&useColumnShortNames=false](https://ourworldindata.org/grapher/population?v=1&csvType=full&useColumnShortNames=false) (accessed March 10, 2025). Sources: 10,000 BCE–1799: HYDE (2024); 1800–1949: Gapminder (2023); 1950–2023: United Nations World Population Prospects (2024).

- Pemstein, Daniel, Kyle L. Marquardt, Eitan Tzelgov, Yi-ting Wang, Juraj Medzihorsky, Joshua Krusell, Farhad Miri, and Johannes von Römer. 2025. "The V-Dem Measurement Model: Latent Variable Analysis for Cross-National and Cross-Temporal Expert-Coded Data." V-Dem Working Paper 21, 10th ed. University of Gothenburg: Varieties of Democracy Institute.

- Sarkees, Meredith R., and Frank W. Wayman. 2010. Resort to War: 1816–2007. Washington, DC: CQ Press. ISBN 9780872894341.

- Singer, J. David, Stuart A. Bremer, and John Stuckey. 1972. "Capability Distribution, Uncertainty, and Major Power War, 1820–1965." In Peace, War, and Numbers, edited by Bruce Russett, 19–48. Beverly Hills, CA: Sage. ISBN 978-0803901643.

- Stinnett, Douglas M., Jaroslav Tir, Paul F. Diehl, Philip Schafer, and Charles Gochman. 2002. "The Correlates of War (COW) Project Direct Contiguity Data, Version 3.0." Conflict Management and Peace Science, 19 (2): 59–67. [doi:10.1177/073889420201900203](https://doi.org/10.1177/073889420201900203).

- Sundberg, Ralph, and Erik Melander. 2013. "Introducing the UCDP Georeferenced Event Dataset." Journal of Peace Research, 50 (4): 523–532. [doi:10.1177/0022343313484347](https://doi.org/10.1177/0022343313484347).

- Tir, Jaroslav, Philip Schafer, Paul F. Diehl, and Gary Goertz. 1998. "Territorial Changes, 1816–1996: Procedures and Data." Conflict Management and Peace Science, 16 (1): 89–97. [doi:10.1177/073889429801600105](https://doi.org/10.1177/073889429801600105).

- UCDP. 2024a. "Battle-Related Deaths Dataset, Version 24.1." Uppsala Conflict Data Program (UCDP). Data downloaded from [https://ucdp.uu.se/downloads/olddw.html](https://ucdp.uu.se/downloads/olddw.html) (accessed May 30, 2025).

- UCDP. 2024b. "UCDP Dyadic Dataset, Version 24.1." Uppsala Conflict Data Program (UCDP). Data downloaded from [https://ucdp.uu.se/downloads/olddw.html](https://ucdp.uu.se/downloads/olddw.html) (accessed May 30, 2025).

- UCDP. 2024c. "UCDP Georeferenced Event Dataset (GED), Version 24.1." Uppsala Conflict Data Program (UCDP). Data downloaded from [https://ucdp.uu.se/downloads/olddw.html](https://ucdp.uu.se/downloads/olddw.html) (accessed May 30, 2025).

- UCDP. 2024d. "UCDP/PRIO Armed Conflict Dataset, Version 24.1." Uppsala Conflict Data Program (UCDP). Data downloaded from [https://ucdp.uu.se/downloads/olddw.html](https://ucdp.uu.se/downloads/olddw.html) (accessed May 30, 2025).

- United Nations. 2024. "World Population Prospects 2024." United Nations, Department of Economic and Social Affairs, Population Division. Data available at [https://population.un.org/wpp/downloads](https://population.un.org/wpp/downloads) (accessed July 11, 2024).

- World Bank. 2023. "World Development Indicators: GDP per Capita (Constant 2015 US$) - NY.GDP.PCAP.KD." Washington, DC: World Bank. Data downloaded from [https://data.worldbank.org/indicator/NY.GDP.PCAP.KD](https://data.worldbank.org/indicator/NY.GDP.PCAP.KD) (accessed September 19, 2023).

- World Bank. 2024a. "World Development Indicators: GDP (Constant 2015 US$) - NY.GDP.MKTP.KD." Washington, DC: World Bank. Data downloaded from [https://data.worldbank.org/indicator/NY.GDP.MKTP.KD](https://data.worldbank.org/indicator/NY.GDP.MKTP.KD) (accessed July 10, 2024).

- World Bank. 2024b. "World Development Indicators: Inflation, Consumer Prices (Annual %) - FP.CPI.TOTL.ZG." Washington, DC: World Bank. Data downloaded from [https://data.worldbank.org/indicator/FP.CPI.TOTL.ZG](https://data.worldbank.org/indicator/FP.CPI.TOTL.ZG) (accessed July 9, 2024).

- World Bank. 2024c. "World Development Indicators: Population, Total - SP.POP.TOTL." Washington, DC: World Bank. Data downloaded from [https://data.worldbank.org/indicator/SP.POP.TOTL](https://data.worldbank.org/indicator/SP.POP.TOTL) (accessed July 10, 2024).


\clearpage
## PDF Generation

This README file can be converted to a professional PDF document using [Pandoc (version 2.0 or later)](https://pandoc.org/) with XeLaTeX (part of a TeX distribution such as TeX Live or MacTeX).

The conversion process uses two auxiliary files stored in `ressources/pandoc/`:

1. **`pdf_header.yaml`**: YAML metadata file containing document settings (page geometry, fonts, colors), LaTeX packages for formatting (tables, landscape orientation, headers), and custom commands (section breaks, single spacing for references).
2. **`landscape-tables.lua`**: Lua filter that automatically processes the document and adjusts settings to individual sections and tables.

To generate `README.pdf` from this markdown file, run the following command in the project root directory:

```bash
pandoc ressources/pandoc/pdf_header.yaml README.md -o README.pdf --pdf-engine=xelatex --lua-filter=ressources/pandoc/landscape-tables.lua
```
