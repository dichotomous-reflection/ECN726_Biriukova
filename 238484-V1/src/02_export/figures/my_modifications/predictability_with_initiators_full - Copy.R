############
# PACKAGES #
############
rm(list = ls())
DIR_DATA_PROCESSED <- "C:/Users/xenia/Documents/ASU_STUDIES/Econometrics_2026/238484-V1/data/02_processed"
DIR_DATA_TMP       <- "C:/Users/xenia/Documents/ASU_STUDIES/Econometrics_2026/238484-V1/data/00_tmp"
DIR_OUT            <- "C:/Users/xenia/Documents/ASU_STUDIES/Econometrics_2026/238484-V1/data/03_exports"

setwd("C:/Users/xenia/Documents/ASU_STUDIES/Econometrics_2026/238484-V1/")
library(tidyverse)
library(peacesciencer)


########################
# INTERSTATE WAR SITES #
########################
sites_interstate <- haven::read_dta("data/02_processed/sites_interstate.dta") %>%
  select(
    iso,    # iso3 code
    start,  # start year of country being a warsite (not necessarily the year of the war onset)
    end,    # end year of country being a warsite (not necessarily the year of the war end)
    warname # name of the inter-state war
  ) %>%
  rename(iso3 = iso) %>%
  # remove warsites that have short-run economic narratives
  filter(!warname %in% c("Boxer Rebellion", "Italian-Turkish", "Second Sino-Japanese", "Conquest of Ethiopia", "Falkland Islands", "Football War")) %>%
  # add indicators
  rowwise() %>%                                           # process each row individually
  mutate(year = list(seq(start, end))) %>%                # create a list of years for each war period
  unnest(year) %>%                                        # expand the data so each year gets its own row
  mutate(warsite = 1) %>%                                 # add indicator that country is a warsite from start to end
  mutate(warsite_onset = ifelse(year == start, 1, 0)) %>% # add indicator for first year of warsite onset
  select(-start, -end) %>%                                # remove start and end year columns as they are no longer needed
  # handle cases where a country has participated in multiple wars in same year
  group_by(iso3, year) %>%
  summarise(
    warsite = max(warsite),
    warsite_onset = max(warsite_onset),
    warname = paste(unique(warname), collapse = ", ")
  ) %>%
  ungroup()
#View(sites_interstate)


###############################
# INTERSTATE WAR INITIATORS   #
###############################
interstate_belligerents <- haven::read_dta("data/02_processed/interstate_belligerents.dta") %>%
  select(
    iso,      # iso3 code
    warname,  # name of the interstate war
    initiator # 1 if country initiated the conflict, missing otherwise
  ) %>%
  rename(iso3 = iso) %>%
  # keep only observations with initiation information
  filter(!is.na(initiator)) %>%
  mutate(starter = as.integer(initiator == 1)) %>%
  select(iso3, warname, starter)

# identify the first year of each interstate war so that initiators can be
# attached to the country-year panel used in the regressions
interstate_war_onsets <- sites_interstate %>%
  distinct(warname, year) %>%
  group_by(warname) %>%
  summarise(year = min(year), .groups = "drop")

sites_interstate_starter <- interstate_belligerents %>%
  left_join(interstate_war_onsets, by = "warname") %>%
  filter(!is.na(year)) %>%
  group_by(iso3, year) %>%
  summarise(
    starter = max(starter),
    starter_onset = max(starter),
    .groups = "drop"
  )

###################
# OTHER WAR SITES #
###################
sites_other <- haven::read_dta("data/02_processed/sites_intrastate.dta") %>%
  select(
    iso,   # iso3 code
    start,  # start year of country being a warsite (not necessarily the year of the war onset)
    end,    # end year of country being a warsite (not necessarily the year of the war end)
    warname # name of the war
  ) %>%
  rename(iso3 = iso) %>%
  # set missing end years to 2023
  mutate(end = ifelse(is.na(end), 2023, end)) %>%
  # add indicators
  rowwise() %>%                                           # process each row individually
  mutate(year = list(seq(start, end))) %>%                # create a list of years for each war period
  unnest(year) %>%                                        # expand the data so each year gets its own row
  mutate(warsite = 1) %>%                                 # add indicator that country is a warsite from start to end
  mutate(warsite_onset = ifelse(year == start, 1, 0)) %>% # add indicator for first year of warsite onset
  select(-start, -end) %>%                                # remove start and end year columns as they are no longer needed
  # handle cases where a country has participated in multiple wars in same year
  group_by(iso3, year) %>%
  summarise(
    warsite = max(warsite),
    warsite_onset = max(warsite_onset),
    warname = paste(unique(warname), collapse = ", ")
  ) %>%
  ungroup()
#View(sites_other)

#################
# MACRO DATASET #
#################
macro <- haven::read_dta("data/02_processed/macro.dta") %>%
  rename(iso3 = iso) %>%
  filter(year >= 1870 & year <= 2023) %>%
  # create additional variables
  mutate(
    openness = (exports + imports) / gdp,
    milex_gdp = milex / gdp,
    milper_pop = milper / pop
  ) %>%
  select(
    year,       # year
    iso3,       # iso3 country code
    gdp,        # GDP
    gdp_growth, # GDP growth rate
    inflation,  # inflation rate
    openness,   # openness
    milex_gdp,  # military expenditures as a share of GDP
    milper_pop  # military personnel as a share of population
  )
names(macro)
#####
sum(!is.nan(macro$gdp) &
      is.nan(macro$openness))
sum(!is.na(macro$gdp) &
      is.na(macro$openness))
macro %>%
  count(year, iso3) %>%
  filter(n > 1)

library(haven)

gmd <- read_dta("data/01_raw/globalmacrodatabase/GMD.dta")

names(gmd)

####

print("Note: unbalanced panel of 60 countries represents 95% of global GDP in 1960 with coverage remaining at 90% throughout 2000-2022:")
macro %>%
  select(year, iso3, gdp) %>%
  group_by(year) %>%
  summarise(macro_gdp_sum = sum(gdp, na.rm = TRUE)) %>%
  filter(year >= 1960) %>%
  ungroup() %>%
  arrange(year) %>%
  # merge world_gdp and compute ratio of macro_gdp_sum to world_gdp
  left_join(
    WDI::WDI(indicator = "NY.GDP.MKTP.KD", start = 1960, end = 2023,extra = FALSE) %>%
      select(country, iso3c, year, NY.GDP.MKTP.KD) %>%
      filter(country == "World") %>%
      rename(world_gdp = NY.GDP.MKTP.KD) %>%
      arrange(year),
    by = "year"
  ) %>%
  mutate(macro_gdp_ratio = round(macro_gdp_sum / world_gdp, 3)) %>%
  filter(year %in% c(1960, 2000:2023)) %>%
  print(n = 30)

macro %>%
  summarise(
    missing = sum(is.na(openness)),
    total = n(),
    share_missing = mean(is.na(openness))
  )
macro %>%
  summarise(
    missing = sum(is.na(gdp)),
    total = n(),
    share_missing = mean(is.na(gdp))
  )

#macro
################
# VDEM DATASET #
################
# prepare V-Dem dataset for democracy index
vdem_data <- haven::read_dta("data/01_raw/vdem/V-Dem-CY-FullOthers-v15_dta/V-Dem-CY-Full+Others-v15.dta") %>%
  select(
    year,          # year
    country_id,    # vdem country code
    COWcode,       # COW country code
    v2x_libdem     # liberal democracy index (ideal of liberal democracy): interval from low (0) to high (1)
  ) %>%
  rename(vdem = country_id, cown = COWcode) %>%
  filter(year >= 1870)
#View(vdem_data)

######################
# CONTIGUITY DATASET #
######################
# provides data on land borders
contiguity <- create_stateyears(system = "cow", mry = FALSE) %>%
  add_contiguity() %>%
  mutate(borders = land) %>%
  rename(cown = ccode) %>%
  select(
    year,   # year
    cown,   # COW country code
    borders # number of land borders
  ) %>%
  filter(year >= 1870) %>%
  # add observations for 2017 to 2023 for each cown
  group_by(cown) %>%
  group_modify(~ {
    borders_2016 <- .x %>% filter(year == 2016) %>% pull(borders) # get the borders value for 2016 if it exists
    if (length(borders_2016) > 0) { # if year 2016 exists for this country, add rows for 2017-2023
      new_years <- tibble(
        year = 2017:2023,
        borders = borders_2016
      )
      bind_rows(.x, new_years)
    } else {
      .x
    }
  }) %>%
  ungroup()
#View(contiguity)

########################
# MAJOR POWERS DATASET #
########################
# provides data on major powers
major_powers <- create_stateyears(system = "cow", mry = FALSE) %>%
  add_cow_majors() %>%
  rename(cown = ccode) %>%
  select(
    year,  # year
    cown,  # COW country code
    cowmaj # 1 = major power, 0 = not major power
  ) %>%
  filter(year >= 1870) %>%
  # add observations for 2017 to 2023 for each cown
  group_by(cown) %>%
  group_modify(~ {
    cowmaj_2016 <- .x %>% filter(year == 2016) %>% pull(cowmaj) # get the cowmaj value for 2016 if it exists
    if (length(cowmaj_2016) > 0) { # if year 2016 exists for this country, add rows for 2017-2023
      new_years <- tibble(
        year = 2017:2023,
        cowmaj = cowmaj_2016
      )
      bind_rows(.x, new_years)
    } else {
      .x
    }
  }) %>%
  ungroup()
#View(major_powers %>% filter(cowmaj == 1))

######################
# COUNTRY-YEAR PANEL #
######################
# countrycode package provides common linking between iso3-year, cown-year, and vdem-year
linking_iso3_cown_vdem <- countrycode::codelist_panel %>%
  rename(country_name = country.name.en, iso3 = iso3c) %>%
  # cown codes end in 2020
  filter(year %in% c(1870:2020)) %>%
  select(
    year,            # year
    country_name,    # country name
    iso3,            # iso3 code
    cown,            # COW country code
    vdem             # vdem country code
  )
#View(linking_iso3_cown_vdem)

# create a full panel of all iso3-year combinations for which we have macro-level data
country_year_panel <- expand_grid(
  year = 1870:max(linking_iso3_cown_vdem$year), # cown codes end in 2020, we fill in missing values for 2021-2023 later
  iso3 = unique(macro$iso3)
) %>%
  arrange(iso3, year) %>%
  # merge linking_iso3_cown_vdem
  left_join(linking_iso3_cown_vdem, by = c("iso3", "year")) %>%
  select(year, iso3, cown, vdem)
#View(country_year_panel)
print("Missing values in country_year_panel before manual adjustments:")
country_year_panel %>% filter(if_any(everything(), is.na)) %>% print() # many missing values

# MANUALLY add missing COW and V-Dem codes based on ISO3 codes
# Important notes:
# - ISO3 serves as our primary country identifier: it's used for warsite coding because macro-level covariates are available based on current borders
# - COW and V-Dem codes are required to merge data about the historical governing entity
#   that controlled the territory of modern-day ISO3 warsites to capture characteristics like:
#   borders, power status, democracy index and possibly other relevant historical attributes coded in COW or V-Dem
country_year_panel <- country_year_panel %>%
  # AUS missing cown for 1870 to 1919: use United Kingdom (cown = 200) as Australia was a British colony
  mutate(cown = ifelse(iso3 == "AUS" & year >= 1870 & year <= 1919 & is.na(cown), 200, cown)) %>%
  # AUT missing cown for 1870 to 1919: use Austria-Hungary (cown = 300) as Austria was part of Austria-Hungary
  mutate(cown = ifelse(iso3 == "AUT" & year >= 1870 & year <= 1918 & is.na(cown), 300, cown)) %>%
  # AUT missing cown for 1939 to 1945: use Germany (cown = 255) as Austria was annexed by Germany
  mutate(cown = ifelse(iso3 == "AUT" & year >= 1939 & year <= 1945 & is.na(cown), 255, cown)) %>%
  # AUT missing cown for 1946 to 1954: use Austria (cown = 305) as Austria was a separate country (but occupied by Allies)
  mutate(cown = ifelse(iso3 == "AUT" & year >= 1946 & year <= 1954 & is.na(cown), 305, cown)) %>%
  # AUT missing vdem for 1939 to 1944: use Germany (vdem = 77) as Austria was annexed by Germany
  mutate(vdem = ifelse(iso3 == "AUT" & year >= 1939 & year <= 1944 & is.na(vdem), 77, vdem)) %>%
  # BEL missing cown for 1941 to 1944: use Germany (cown = 255) as Belgium was occupied by Germany
  mutate(cown = ifelse(iso3 == "BEL" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # BGR missing cown for 1870 to 1907: use Turkey (cown = 640) as Bulgaria was part of Ottoman Empire
  mutate(cown = ifelse(iso3 == "BGR" & year >= 1870 & year <= 1907 & is.na(cown), 640, cown)) %>%
  # BGR missing vdem for 1870 to 1877: use Turkey (vdem = 99) as Bulgaria was part of Ottoman Empire
  mutate(vdem = ifelse(iso3 == "BGR" & year >= 1870 & year <= 1877 & is.na(vdem), 99, vdem)) %>%
  # CAN missing cown for 1870 to 1919: use United Kingdom (cown = 200) as Canada was a self-governing dominion of the British empire
  mutate(cown = ifelse(iso3 == "CAN" & year >= 1870 & year <= 1919 & is.na(cown), 200, cown)) %>%
  # CYP missing cown for 1870 to 1877: use Turkey (cown = 640) as Cyprus was part of Ottoman Empire
  mutate(cown = ifelse(iso3 == "CYP" & year >= 1870 & year <= 1877 & is.na(cown), 640, cown)) %>%
  # CYP missing vdem for 1870 to 1877: use Turkey (vdem = 99) as Cyprus was part of Ottoman Empire
  mutate(vdem = ifelse(iso3 == "CYP" & year >= 1870 & year <= 1877 & is.na(vdem), 99, vdem)) %>%
  # CYP missing cown for 1878 to 1959: use United Kingdom (cown = 200) as Cyprus was a British protectorate
  mutate(cown = ifelse(iso3 == "CYP" & year >= 1878 & year <= 1959 & is.na(cown), 200, cown)) %>%
  # CYP missing vdem for 1878 to 1899: use United Kingdom (vdem = 101) as Cyprus was a British protectorate
  mutate(vdem = ifelse(iso3 == "CYP" & year >= 1878 & year <= 1899 & is.na(vdem), 101, vdem)) %>%
  # CZE missing cown for 1870 to 1917: use Austria-Hungary (cown = 300) as Czechoslovakia was part of Austria-Hungary
  mutate(cown = ifelse(iso3 == "CZE" & year >= 1870 & year <= 1917 & is.na(cown), 300, cown)) %>%
  # CZE missing vdem for 1870 to 1917: use Austria (vdem = 144) as Czechoslovakia was part of Austria-Hungary
  mutate(vdem = ifelse(iso3 == "CZE" & year >= 1870 & year <= 1917 & is.na(vdem), 144, vdem)) %>%
  # CZE missing cown for 1918 to 1939: use Czechoslovakia (cown = 315) as Czechoslovakia is independent country
  mutate(cown = ifelse(iso3 == "CZE" & year >= 1918 & year <= 1939 & is.na(cown), 315, cown)) %>%
  # CZE missing cown for 1940 to 1944: use Germany (cown = 255) as Czechoslovakia was occupied by Germany
  mutate(cown = ifelse(iso3 == "CZE" & year >= 1940 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # CZE missing cown for 1945 to 1992: use Czechoslovakia (cown = 315) as Czechoslovakia is independent country
  mutate(cown = ifelse(iso3 == "CZE" & year >= 1945 & year <= 1992 & is.na(cown), 315, cown)) %>%
  # CZE missing vdem for 1918 to 1992: use Czechia (vdem = 157) as Czechoslovakia is independent country
  mutate(vdem = ifelse(iso3 == "CZE" & year >= 1918 & year <= 1992 & is.na(vdem), 157, vdem)) %>%
  # DEU missing cown for 1946 to 1954: use Germany (cown = 255) even though occupied by Allies
  mutate(cown = ifelse(iso3 == "DEU" & year >= 1946 & year <= 1954 & is.na(cown), 255, cown)) %>%
  # DEU missing vdem for 1945 to 1948: use Germany (vdem = 77) even though occupied by Allies
  mutate(vdem = ifelse(iso3 == "DEU" & year >= 1945 & year <= 1948 & is.na(vdem), 77, vdem)) %>%
  # DNK missing cown for 1941 to 1944: use Germany (cown = 255) as Denmark was occupied by Germany
  mutate(cown = ifelse(iso3 == "DNK" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # EGY missing cown for 1883 to 1913: use Turkey (cown = 640) as Egypt was part of Ottoman Empire
  mutate(cown = ifelse(iso3 == "EGY" & year >= 1883 & year <= 1913 & is.na(cown), 640, cown)) %>%
  # EGY missing cown for 1914 to 1936: use United Kingdom (cown = 200) as Egypt was British protectorate
  mutate(cown = ifelse(iso3 == "EGY" & year >= 1914 & year <= 1936 & is.na(cown), 200, cown)) %>%
  # EST missing cown for 1870 to 1917: use Russia (cown = 365) as Estonia was part of Russian Empire
  mutate(cown = ifelse(iso3 == "EST" & year >= 1870 & year <= 1917 & is.na(cown), 365, cown)) %>%
  # EST missing cown for 1941 to 1990: use Russia (cown = 365) as Estonia was part of Soviet Union
  mutate(cown = ifelse(iso3 == "EST" & year >= 1941 & year <= 1990 & is.na(cown), 365, cown)) %>%
  # EST missing vdem for 1870 to 1917: use Russia (vdem = 11) as Estonia was part of Russian Empire
  mutate(vdem = ifelse(iso3 == "EST" & year >= 1870 & year <= 1917 & is.na(vdem), 11, vdem)) %>%
  # EST missing vdem for 1918 to 1939: use Estonia (vdem = 161) as vdem data is available
  mutate(vdem = ifelse(iso3 == "EST" & year >= 1918 & year <= 1939 & is.na(vdem), 161, vdem)) %>%
  # EST missing vdem for 1940 to 1989: use Russia (vdem = 11) as Estonia was part of Soviet Union
  mutate(vdem = ifelse(iso3 == "EST" & year >= 1940 & year <= 1989 & is.na(vdem), 11, vdem)) %>%
  # FIN missing cown for 1870 to 1916: use Russia (cown = 365) as Finland was part of Russian Empire
  mutate(cown = ifelse(iso3 == "FIN" & year >= 1870 & year <= 1916 & is.na(cown), 365, cown)) %>%
  # FRA missing cown for 1943 to 1943: use Germany (cown = 255) as France was occupied by Germany
  mutate(cown = ifelse(iso3 == "FRA" & year == 1943 & is.na(cown), 255, cown)) %>%
  # GRC missing cown for 1942 to 1943: use Italy (cown = 325) as most of Greece was occupied by Italy
  mutate(cown = ifelse(iso3 == "GRC" & year >= 1942 & year <= 1943 & is.na(cown), 325, cown)) %>%
  # HRV missing cown for 1870 to 1917: use Austria-Hungary (cown = 300) as Croatia was part of Austria-Hungary
  mutate(cown = ifelse(iso3 == "HRV" & year >= 1870 & year <= 1917 & is.na(cown), 300, cown)) %>%
  # HRV missing vdem for 1870 to 1917: use Austria-Hungary (vdem = 144) as Croatia was part of Austria-Hungary
  mutate(vdem = ifelse(iso3 == "HRV" & year >= 1870 & year <= 1917 & is.na(vdem), 144, vdem)) %>%
  # HRV missing cown for 1918 to 1940: use Yugoslavia (cown = 345) as Croatia was part of Yugoslavia
  mutate(cown = ifelse(iso3 == "HRV" & year >= 1918 & year <= 1940 & is.na(cown), 345, cown)) %>%
  # HRV missing vdem for 1918 to 1940: use Yugoslavia/Serbia (vdem = 198) as Croatia was part of Yugoslavia
  mutate(vdem = ifelse(iso3 == "HRV" & year >= 1918 & year <= 1940 & is.na(vdem), 198, vdem)) %>%
  # HRV missing cown for 1941 to 1944: use Croatia (cown = 344) as Croatia was independent (Axis puppet state)
  mutate(cown = ifelse(iso3 == "HRV" & year >= 1941 & year <= 1944 & is.na(cown), 344, cown)) %>%
  # HRV missing cown for 1945 to 1991: use Yugoslavia (cown = 345) as Croatia was part of Yugoslavia
  mutate(cown = ifelse(iso3 == "HRV" & year >= 1945 & year <= 1991 & is.na(cown), 345, cown)) %>%
  # HRV missing vdem for 1945 to 1990: use Yugoslavia/Serbia (vdem = 198) as Croatia was part of Yugoslavia
  mutate(vdem = ifelse(iso3 == "HRV" & year >= 1945 & year <= 1990 & is.na(vdem), 198, vdem)) %>%
  # HUN missing cown for 1870 to 1917: use Austria-Hungary (cown = 300) as Hungary was part of Austria-Hungary
  mutate(cown = ifelse(iso3 == "HUN" & year >= 1870 & year <= 1917 & is.na(cown), 300, cown)) %>%
  # IDN missing cown for 1870 to 1941: use Netherlands (cown = 210) as Indonesia was a Dutch colony
  mutate(cown = ifelse(iso3 == "IDN" & year >= 1870 & year <= 1941 & is.na(cown), 210, cown)) %>%
  # IDN missing cown for 1942 to 1944: use Japan (cown = 740) as Indonesia was occupied by Empire of Japan
  mutate(cown = ifelse(iso3 == "IDN" & year >= 1942 & year <= 1944 & is.na(cown), 740, cown)) %>%
  # IDN missing cown for 1945 to 1948: use Netherlands (cown = 210) as Indonesia was not yet recognized internationally and Netherlands re-asserted colonial territory
  mutate(cown = ifelse(iso3 == "IDN" & year >= 1945 & year <= 1948 & is.na(cown), 210, cown)) %>%
  # IND missing cown for 1870 to 1946: use United Kingdom (cown = 200) as Indonesia was a British colony
  mutate(cown = ifelse(iso3 == "IND" & year >= 1870 & year <= 1946 & is.na(cown), 200, cown)) %>%
  # IRL missing cown for 1870 to 1921: use United Kingdom (cown = 200) as Ireland was part of the United Kingdom
  mutate(cown = ifelse(iso3 == "IRL" & year >= 1870 & year <= 1921 & is.na(cown), 200, cown)) %>%
  # IRL missing vdem for 1870 to 1918: use United Kingdom (vdem = 101) as Ireland was part of the United Kingdom
  mutate(vdem = ifelse(iso3 == "IRL" & year >= 1870 & year <= 1918 & is.na(vdem), 101, vdem)) %>%
  # ISL missing cown for 1870 to 1943: use Denmark (cown = 390) as Iceland was part of Kingdom of Denmark (or Kingdom of Iceland outsources foreign affairs to Denmark)
  mutate(cown = ifelse(iso3 == "ISL" & year >= 1870 & year <= 1943 & is.na(cown), 390, cown)) %>%
  # ISL missing vdem for 1870 to 1899: use Denmark (vdem = 158) as Iceland was part of Kingdom of Denmark (or Kingdom of Iceland outsources foreign affairs to Denmark)
  mutate(vdem = ifelse(iso3 == "ISL" & year >= 1870 & year <= 1899 & is.na(vdem), 158, vdem)) %>%
  # ISR missing cown for 1870 to 1916: use Turkey (cown = 640) as territory was part of Ottoman Empire
  mutate(cown = ifelse(iso3 == "ISR" & year >= 1870 & year <= 1916 & is.na(cown), 640, cown)) %>%
  # ISR missing vdem for 1870 to 1916: use Turkey (vdem = 99) as territory was part of Ottoman Empire
  mutate(vdem = ifelse(iso3 == "ISR" & year >= 1870 & year <= 1916 & is.na(vdem), 99, vdem)) %>%
  # ISR missing cown for 1917 to 1947: use United Kingdom (cown = 200) as territory was under British Military Occupation and League of Nations Mandate
  mutate(cown = ifelse(iso3 == "ISR" & year >= 1917 & year <= 1947 & is.na(cown), 200, cown)) %>%
  # ISR missing vdem for 1917 to 1947: use United Kingdom (vdem = 101) as territory was under British Military Occupation and League of Nations Mandate
  mutate(vdem = ifelse(iso3 == "ISR" & year >= 1917 & year <= 1947 & is.na(vdem), 101, vdem)) %>%
  # JPN missing cown for 1946 to 1951: use United States (cown = 2) as Japan was under US Military Occupation
  mutate(cown = ifelse(iso3 == "JPN" & year >= 1946 & year <= 1951 & is.na(cown), 2, cown)) %>%
  # KOR missing cown for 1870 to 1886: use Korea (cown = 730) as territory was independent monarchy (Joseon dynasty)
  mutate(cown = ifelse(iso3 == "KOR" & year >= 1870 & year <= 1886 & is.na(cown), 730, cown)) %>%
  # KOR missing cown for 1906 to 1945: use Japan (cown = 730) as Korea was part of Empire of Japan
  mutate(cown = ifelse(iso3 == "KOR" & year >= 1906 & year <= 1945 & is.na(cown), 730, cown)) %>%
  # KOR missing cown for 1946 to 1948: use United States (cown = 2) as Korea was under US Military Occupation
  mutate(cown = ifelse(iso3 == "KOR" & year >= 1946 & year <= 1948 & is.na(cown), 2, cown)) %>%
  # LTU missing cown for 1870 to 1915: use Russia (cown = 365) as Lithuania was part of Russian Empire
  mutate(cown = ifelse(iso3 == "LTU" & year >= 1870 & year <= 1915 & is.na(cown), 365, cown)) %>%
  # LTU missing vdem for 1870 to 1915: use Russia (vdem = 11) as Lithuania was part of Russian Empire
  mutate(vdem = ifelse(iso3 == "LTU" & year >= 1870 & year <= 1915 & is.na(vdem), 11, vdem)) %>%
  # LTU missing cown for 1916 to 1917: use Germany (cown = 255) as Lithuania was occupied by Germany
  mutate(cown = ifelse(iso3 == "LTU" & year >= 1916 & year <= 1917 & is.na(cown), 255, cown)) %>%
  # LTU missing vdem for 1916 to 1917: use Germany (vdem = 77) as Lithuania was occupied by Germany
  mutate(vdem = ifelse(iso3 == "LTU" & year >= 1916 & year <= 1917 & is.na(vdem), 77, vdem)) %>%
  # LTU missing vdem for 1940 to 1940: use Lithuania (vdem = 173) as Lithuania was independent for the first part of year
  mutate(vdem = ifelse(iso3 == "LTU" & year == 1940 & is.na(vdem), 173, vdem)) %>%
  # LTU missing cown for 1941 to 1944: use Germany (cown = 255) as Lithuania was occupied by Germany
  mutate(cown = ifelse(iso3 == "LTU" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # LTU missing vdem for 1941 to 1944: use Germany (vdem = 77) as Lithuania was occupied by Germany
  mutate(vdem = ifelse(iso3 == "LTU" & year >= 1941 & year <= 1944 & is.na(vdem), 77, vdem)) %>%
  # LTU missing cown for 1945 to 1989: use Russia (cown = 365) as Lithuania was part of Soviet Union
  mutate(cown = ifelse(iso3 == "LTU" & year >= 1945 & year <= 1989 & is.na(cown), 365, cown)) %>%
  # LTU missing vdem for 1945 to 1989: use Russia (vdem = 11) as Lithuania was part of Soviet Union
  mutate(vdem = ifelse(iso3 == "LTU" & year >= 1945 & year <= 1989 & is.na(vdem), 11, vdem)) %>%
  # LTU missing cown for 1990 to 1990: use Lithuania (cown = 368) as Lithuania regained independence
  mutate(cown = ifelse(iso3 == "LTU" & year == 1990 & is.na(cown), 368, cown)) %>%
  # LUX missing cown for 1870 to 1914: use Luxembourg (cown = 212) as Luxembourg was independent
  mutate(cown = ifelse(iso3 == "LUX" & year >= 1870 & year <= 1914 & is.na(cown), 212, cown)) %>%
  # LUX missing cown for 1914 to 1918: use Germany (cown = 255) as Luxembourg was occupied by Germany
  mutate(cown = ifelse(iso3 == "LUX" & year >= 1914 & year <= 1918 & is.na(cown), 255, cown)) %>%
  # LUX missing cown for 1919 to 1919: use Luxembourg (cown = 212) as Luxembourg was independent
  mutate(cown = ifelse(iso3 == "LUX" & year == 1919 & is.na(cown), 212, cown)) %>%
  # LUX missing cown for 1941 to 1943: use Germany (cown = 255) as Luxembourg was occupied by Germany
  mutate(cown = ifelse(iso3 == "LUX" & year >= 1941 & year <= 1943 & is.na(cown), 255, cown)) %>%
  # LVA missing cown for 1870 to 1915: use Russia (cown = 365) as Latvia was part of the Russian empire
  mutate(cown = ifelse(iso3 == "LVA" & year >= 1870 & year <= 1915 & is.na(cown), 365, cown)) %>%
  # LVA missing vdem for 1870 to 1915: use Russia (vdem = 11) as Latvia was part of the Russian empire
  mutate(vdem = ifelse(iso3 == "LVA" & year >= 1870 & year <= 1915 & is.na(vdem), 11, vdem)) %>%
  # LVA missing cown for 1916 to 1917: use Germany (cown = 255) as Latvia was occupied by Germany
  mutate(cown = ifelse(iso3 == "LVA" & year >= 1916 & year <= 1917 & is.na(cown), 255, cown)) %>%
  # LVA missing vdem for 1916 to 1917: use Germany (vdem = 77) as Latvia was occupied by Germany
  mutate(vdem = ifelse(iso3 == "LVA" & year >= 1916 & year <= 1917 & is.na(vdem), 77, vdem)) %>%
  # LVA missing vdem for 1918 to 1919: use Latvia (vdem = 84) as Latvia regained independence
  mutate(vdem = ifelse(iso3 == "LVA" & year >= 1918 & year <= 1919 & is.na(vdem), 84, vdem)) %>%
  # LVA missing vdem for 1940 to 1940: use Russia (vdem = 11) as Latvia became part of Soviet Union
  mutate(vdem = ifelse(iso3 == "LVA" & year == 1940 & is.na(vdem), 11, vdem)) %>%
  # LVA missing cown for 1941 to 1944: use Germany (cown = 255) as Latvia was occupied by Germany
  mutate(cown = ifelse(iso3 == "LVA" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # LVA missing vdem for 1941 to 1944: use Germany (vdem = 77) as Latvia was occupied by Germany
  mutate(vdem = ifelse(iso3 == "LVA" & year >= 1941 & year <= 1944 & is.na(vdem), 77, vdem)) %>%
  # LVA missing cown for 1945 to 1990: use Russia (cown = 365) as Latvia was part of Soviet Union
  mutate(cown = ifelse(iso3 == "LVA" & year >= 1945 & year <= 1990 & is.na(cown), 365, cown)) %>%
  # LVA missing vdem for 1945 to 1989: use Russia (vdem = 11) as Latvia was part of Soviet Union
  mutate(vdem = ifelse(iso3 == "LVA" & year >= 1945 & year <= 1989 & is.na(vdem), 11, vdem)) %>%
  # MLT missing cown for 1870 to 1963: use United Kingdom (cown = 200) as Malta was part of British Empire
  mutate(cown = ifelse(iso3 == "MLT" & year >= 1870 & year <= 1963 & is.na(cown), 200, cown)) %>%
  # MLT missing vdem for 1870 to 1899: use United Kingdom (vdem = 101) as Malta was part of British Empire
  mutate(vdem = ifelse(iso3 == "MLT" & year >= 1870 & year <= 1899 & is.na(vdem), 101, vdem)) %>%
  # MLT missing vdem for 1900 to 1963: use Malta (vdem = 178) as data code is available
  mutate(vdem = ifelse(iso3 == "MLT" & year >= 1900 & year <= 1963 & is.na(vdem), 178, vdem)) %>%
  # MYS missing cown for 1870 to 1956: use United Kingdom (cown = 200) as Malaysia was part of British Empire
  mutate(cown = ifelse(iso3 == "MYS" & year >= 1870 & year <= 1956 & is.na(cown), 200, cown)) %>%
  # MYS missing vdem for 1870 to 1899: use United Kingdom (vdem = 101) as Malaysia was part of British Empire
  mutate(vdem = ifelse(iso3 == "MYS" & year >= 1870 & year <= 1899 & is.na(vdem), 101, vdem)) %>%
  # NLD missing cown for 1941 to 1944: use Germany (cown = 255) as Netherlands was occupied by Germany
  mutate(cown = ifelse(iso3 == "NLD" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # NOR missing cown for 1870 to 1904: use Sweden (cown = 380) as Norway was in a personal union with Sweden
  mutate(cown = ifelse(iso3 == "NOR" & year >= 1870 & year <= 1904 & is.na(cown), 380, cown)) %>%
  # NOR missing cown for 1941 to 1944: use Germany (cown = 255) as Norway was occupied by Germany
  mutate(cown = ifelse(iso3 == "NOR" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # NZL missing cown for 1870 to 1919: use United Kingdom (cown = 200) as New Zealand was part of British Empire
  mutate(cown = ifelse(iso3 == "NZL" & year >= 1870 & year <= 1919 & is.na(cown), 200, cown)) %>%
  # PHL missing cown for 1870 to 1898: use Spain (cown = 230) as Philippines was part of Spanish East Indies
  mutate(cown = ifelse(iso3 == "PHL" & year >= 1870 & year <= 1898 & is.na(cown), 230, cown)) %>%
  # PHL missing vdem for 1870 to 1898: use Spain (vdem = 96) as Philippines was part of Spanish East Indies
  mutate(vdem = ifelse(iso3 == "PHL" & year >= 1870 & year <= 1898 & is.na(vdem), 96, vdem)) %>%
  # PHL missing cown for 1899 to 1941: use United States (cown = 2) as Philippines was under US sovereignty
  mutate(cown = ifelse(iso3 == "PHL" & year >= 1899 & year <= 1941 & is.na(cown), 2, cown)) %>%
  # PHL missing vdem for 1899 to 1899: use United States (vdem = 20) as Philippines was under US sovereignty
  mutate(vdem = ifelse(iso3 == "PHL" & year == 1899 & is.na(vdem), 20, vdem)) %>%
  # PHL missing cown for 1942 to 1945: use Japan (cown = 740) as Philippines was occupied by Empire of Japan
  mutate(cown = ifelse(iso3 == "PHL" & year >= 1942 & year <= 1945 & is.na(cown), 740, cown)) %>%
  # POL missing cown for 1870 to 1917: use Russia (cown = 365) as Russian Empire controlled largest portion of historical Poland (including Warsaw)
  mutate(cown = ifelse(iso3 == "POL" & year >= 1870 & year <= 1917 & is.na(cown), 365, cown)) %>%
  # POL missing vdem for 1870 to 1917: use Russia (vdem = 11) as Russian Empire controlled largest portion of historical Poland (including Warsaw)
  mutate(vdem = ifelse(iso3 == "POL" & year >= 1870 & year <= 1917 & is.na(vdem), 11, vdem)) %>%
  # POL missing cown for 1940 to 1944: use Germany (cown = 255) as Poland was occupied by Germany
  mutate(cown = ifelse(iso3 == "POL" & year >= 1940 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # POL missing vdem for 1939 to 1943: use Germany (vdem = 77) as Poland was occupied by Germany
  mutate(vdem = ifelse(iso3 == "POL" & year >= 1939 & year <= 1943 & is.na(vdem), 77, vdem)) %>%
  # PRY missing cown for 1871 to 1875: use Paraguay (cown = 150) even though Paraguay lost territory to Argentina and Bolivia
  mutate(cown = ifelse(iso3 == "PRY" & year >= 1871 & year <= 1875 & is.na(cown), 150, cown)) %>%
  # ROU missing cown for 1870 to 1877: use Romania (cown = 360) because Ottoman empire only nominally controlled the territory
  mutate(cown = ifelse(iso3 == "ROU" & year >= 1870 & year <= 1877 & is.na(cown), 360, cown)) %>%
  # SVK missing cown for 1870 to 1917: use Austria-Hungary (cown = 300) as Slovakia was part of Austro-Hungarian Empire
  mutate(cown = ifelse(iso3 == "SVK" & year >= 1870 & year <= 1917 & is.na(cown), 300, cown)) %>%
  # SVK missing vdem for 1870 to 1917: use Austria (vdem = 144) as Slovakia was part of Austro-Hungarian Empire
  mutate(vdem = ifelse(iso3 == "SVK" & year >= 1870 & year <= 1917 & is.na(vdem), 144, vdem)) %>%
  # SVK missing cown for 1918 to 1939: use Czechoslovakia (cown = 315) as Slovakia was part of Czechoslovakia
  mutate(cown = ifelse(iso3 == "SVK" & year >= 1918 & year <= 1939 & is.na(cown), 315, cown)) %>%
  # SVK missing cown for 1940 to 1944: use Germany (cown = 255) as Slovakia was occupied by Germany
  mutate(cown = ifelse(iso3 == "SVK" & year >= 1940 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # SVK missing cown for 1945 to 1992: use Czechoslovakia (cown = 315) as Slovakia was part of Czechoslovakia
  mutate(cown = ifelse(iso3 == "SVK" & year >= 1945 & year <= 1992 & is.na(cown), 315, cown)) %>%
  # SVK missing vdem for 1918 to 1938: use Czechia (vdem = 157) as Slovakia was part of Czechoslovakia
  mutate(vdem = ifelse(iso3 == "SVK" & year >= 1918 & year <= 1938 & is.na(vdem), 157, vdem)) %>%
  # SVK missing vdem for 1945 to 1992: use Czechia (vdem = 157) as Slovakia was part of Czechoslovakia
  mutate(vdem = ifelse(iso3 == "SVK" & year >= 1945 & year <= 1992 & is.na(vdem), 157, vdem)) %>%
  # SVN missing cown for 1870 to 1917: use Austria-Hungary (cown = 300) as Slovenia was part of Austro-Hungarian Empire
  mutate(cown = ifelse(iso3 == "SVN" & year >= 1870 & year <= 1917 & is.na(cown), 300, cown)) %>%
  # SVN missing vdem for 1870 to 1917: use Austria (vdem = 144) as Slovenia was part of Austro-Hungarian Empire
  mutate(vdem = ifelse(iso3 == "SVN" & year >= 1870 & year <= 1917 & is.na(vdem), 144, vdem)) %>%
  # SVN missing cown for 1918 to 1940: use Yugoslavia (cown = 345) as Slovenia was part of Kingdom of Yugoslavia
  mutate(cown = ifelse(iso3 == "SVN" & year >= 1918 & year <= 1940 & is.na(cown), 345, cown)) %>%
  # SVN missing vdem for 1918 to 1940: use Yugoslavia (vdem = 198) as Slovenia was part of Kingdom of Yugoslavia
  mutate(vdem = ifelse(iso3 == "SVN" & year >= 1918 & year <= 1940 & is.na(vdem), 198, vdem)) %>%
  # SVN missing cown for 1941 to 1944: use Germany (cown = 255) as Slovenia was occupied by Germany
  mutate(cown = ifelse(iso3 == "SVN" & year >= 1941 & year <= 1944 & is.na(cown), 255, cown)) %>%
  # SVN missing vdem for 1941 to 1944: use Germany (vdem = 77) as Slovenia was occupied by Germany
  mutate(vdem = ifelse(iso3 == "SVN" & year >= 1941 & year <= 1944 & is.na(vdem), 77, vdem)) %>%
  # SVN missing cown for 1945 to 1991: use Yugoslavia (cown = 345) as Slovenia was part of Yugoslavia
  mutate(cown = ifelse(iso3 == "SVN" & year >= 1945 & year <= 1991 & is.na(cown), 345, cown)) %>%
  # SVN missing vdem for 1945 to 1988: use Yugoslavia (vdem = 198) as Slovenia was part of Yugoslavia
  mutate(vdem = ifelse(iso3 == "SVN" & year >= 1945 & year <= 1988 & is.na(vdem), 198, vdem)) %>%
  # THA missing cown for 1870 to 1886: use Thailand (cown = 800) as Siam was independent kingdom
  mutate(cown = ifelse(iso3 == "THA" & year >= 1870 & year <= 1886 & is.na(cown), 800, cown)) %>%
  # TWN missing cown for 1870 to 1895: use China (cown = 710) as Taiwan was part of Qing Dynasty
  mutate(cown = ifelse(iso3 == "TWN" & year >= 1870 & year <= 1895 & is.na(cown), 710, cown)) %>%
  # TWN missing cown for 1896 to 1944: use Japan (cown = 740) as Taiwan was colonized by Japan
  mutate(cown = ifelse(iso3 == "TWN" & year >= 1896 & year <= 1945 & is.na(cown), 740, cown)) %>%
  # TWN missing cown for 1945 to 1948: use China (cown = 710) as Taiwan was under Chinese control
  mutate(cown = ifelse(iso3 == "TWN" & year >= 1945 & year <= 1948 & is.na(cown), 710, cown)) %>%
  # TWN missing vdem for 1870 to 1895: use China (vdem = 110) as Taiwan was part of Qing Dynasty
  mutate(vdem = ifelse(iso3 == "TWN" & year >= 1870 & year <= 1895 & is.na(vdem), 110, vdem)) %>%
  # TWN missing vdem for 1896 to 1899: use Japan (vdem = 9) as Taiwan was under Japanese control
  mutate(vdem = ifelse(iso3 == "TWN" & year >= 1896 & year <= 1899 & is.na(vdem), 9, vdem)) %>%
  # URY missing cown for 1870 to 1881: use Uruguay (cown = 165) as Uruguay was independent but under military control
  mutate(cown = ifelse(iso3 == "URY" & year >= 1870 & year <= 1881 & is.na(cown), 165, cown)) %>%
  # ZAF missing cown for 1870 to 1909: use United Kingdom (cown = 200) as South Africa was mostly under British control
  mutate(cown = ifelse(iso3 == "ZAF" & year >= 1870 & year <= 1909 & is.na(cown), 200, cown)) %>%
  # ZAF missing cown for 1910 to 1919: use South Africa (cown = 560) as Union of South Africa was self-governing
  mutate(cown = ifelse(iso3 == "ZAF" & year >= 1910 & year <= 1919 & is.na(cown), 560, cown)) %>%
  # ZAF missing vdem for 1870 to 1899: use United Kingdom (vdem = 101) as South Africa was mostly under British control
  mutate(vdem = ifelse(iso3 == "ZAF" & year >= 1870 & year <= 1899 & is.na(vdem), 101, vdem)) %>%
  # finally, fill missing values for 2021 to 2023
  group_by(iso3) %>%
  complete(year = 1870:2023) %>%
  arrange(iso3, year) %>%
  fill(cown, vdem, .direction = "down") %>%
  ungroup()
#View(country_year_panel)
print("Missing values in country_year_panel after manual adjustments:")
country_year_panel %>% filter(if_any(everything(), is.na)) %>% print() # complete panel with no missing values

################################
# FULL PANELS WITH MERGED DATA #
################################
country_year_panel <- country_year_panel %>%
  # merge macro data via iso3-year
  left_join(macro, by = c("iso3", "year")) %>%
  # merge contiguity data via cown-year
  left_join(contiguity, by = c("cown", "year")) %>%
  # merge major_powers data via cown-year
  left_join(major_powers, by = c("cown", "year")) %>%
  replace_na(list(cowmaj = 0)) %>%
  # merge VDEM data via vdem-year
  left_join(vdem_data %>% select(-cown), by = c("vdem", "year"))

# panel for interstate war sites
country_year_panel_inter <- country_year_panel %>%
  # merge sites_interstate via iso3-year
  left_join(sites_interstate, by = c("iso3", "year")) %>%
  replace_na(list(warsite = 0, warsite_onset = 0, warname = "Peace")) %>%
  # compute peace years
  group_by(iso3) %>%
  arrange(iso3, year) %>%
  mutate(peace_years = accumulate(!warsite, function(acc, x) {
    if (x == 0) 0 else acc + 1
  }, .init = 0)[-1]) %>%
  mutate(peace_years = lag(peace_years, 1, default = 0)) %>%
  mutate(peace_years_sq = peace_years^2) %>%
  mutate(peace_years_cub = peace_years^3) %>%
  ungroup()
#View(country_year_panel_inter)


# merge interstate initiator information via iso3-year
country_year_panel_inter <- country_year_panel_inter %>%
  left_join(sites_interstate_starter, by = c("iso3", "year")) %>%
  replace_na(list(starter = 0, starter_onset = 0))

# panel for other war sites
country_year_panel_other <- country_year_panel %>%
  # merge sites_other via iso3-year
  left_join(sites_other, by = c("iso3", "year")) %>%
  replace_na(list(warsite = 0, warsite_onset = 0, warname = "Peace")) %>%
  # compute peace years
  group_by(iso3) %>%
  arrange(iso3, year) %>%
  mutate(peace_years = accumulate(!warsite, function(acc, x) {
    if (x == 0) 0 else acc + 1
  }, .init = 0)[-1]) %>%
  mutate(peace_years = lag(peace_years, 1, default = 0)) %>%
  mutate(peace_years_sq = peace_years^2) %>%
  mutate(peace_years_cub = peace_years^3) %>%
  ungroup()
#View(country_year_panel_other)
macro %>%
  summarise(
    missing = sum(is.na(openness)),
    total = n(),
    share_missing = mean(is.na(openness))
  )
###################
# REGRESSION DATA #
###################
regr_data_inter <- country_year_panel_inter %>%
  group_by(iso3) %>%
  arrange(year) %>%
  # create four lags of variables
  mutate(across(
    c(warsite_onset, gdp_growth, inflation, openness, milex_gdp, milper_pop, v2x_libdem, borders, cowmaj),
    list(lag1 = ~lag(., 1), lag2 = ~lag(., 2), lag3 = ~lag(., 3), lag4 = ~lag(., 4)),
    .names = "{.col}_{.fn}"
  )) %>%
  ungroup() %>%
  # remove ongoing warsites
  filter(!(warsite == 1 & warsite_onset == 0)) %>%
  # r2sd() for a more readable regression output to put regression inputs on roughly the same scale
  mutate_at(vars(
    gdp_growth, gdp_growth_lag1, gdp_growth_lag2, gdp_growth_lag3, gdp_growth_lag4,
    inflation, inflation_lag1, inflation_lag2, inflation_lag3, inflation_lag4,
    openness, openness_lag1, openness_lag2, openness_lag3, openness_lag4,
    milex_gdp, milex_gdp_lag1, milex_gdp_lag2, milex_gdp_lag3, milex_gdp_lag4,
    milper_pop, milper_pop_lag1, milper_pop_lag2, milper_pop_lag3, milper_pop_lag4,
    peace_years, peace_years_sq, peace_years_cub
  ), stevemisc::r2sd)

regr_data_other <- country_year_panel_other %>%
  group_by(iso3) %>%
  arrange(year) %>%
  # create four lags of variables
  mutate(across(
    c(warsite_onset, gdp_growth, inflation, openness, milex_gdp, milper_pop, v2x_libdem, borders, cowmaj),
    list(lag1 = ~lag(., 1), lag2 = ~lag(., 2), lag3 = ~lag(., 3), lag4 = ~lag(., 4)),
    .names = "{.col}_{.fn}"
  )) %>%
  ungroup() %>%
  # remove ongoing warsites
  filter(!(warsite == 1 & warsite_onset == 0)) %>%
  # r2sd() for a more readable regression output to put regression inputs on roughly the same scale
  mutate_at(vars(
    gdp_growth, gdp_growth_lag1, gdp_growth_lag2, gdp_growth_lag3, gdp_growth_lag4,
    inflation, inflation_lag1, inflation_lag2, inflation_lag3, inflation_lag4,
    openness, openness_lag1, openness_lag2, openness_lag3, openness_lag4,
    milex_gdp, milex_gdp_lag1, milex_gdp_lag2, milex_gdp_lag3, milex_gdp_lag4,
    milper_pop, milper_pop_lag1, milper_pop_lag2, milper_pop_lag3, milper_pop_lag4,
    peace_years, peace_years_sq, peace_years_cub
  ), stevemisc::r2sd)

#####################################
# LOGIT REGRESSIONS (1): GDP GROWTH #
#####################################

# no fixed effects
inter_gdp1_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)

other_gdp1_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp1_no)
summary(other_gdp1_no)

# country fixed effects
inter_gdp1_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp1_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp1_feiso)
summary(other_gdp1_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_gdp1_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4
)
other_gdp1_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4
)
summary(inter_gdp1_feisoyear)
summary(other_gdp1_feisoyear)

################################################
# LOGIT REGRESSIONS (2): GDP GROWTH + OPENNESS #
################################################

# no fixed effects
inter_gdp2_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp2_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp2_no)
summary(other_gdp2_no)

# country fixed effects
inter_gdp2_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp2_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp2_feiso)
summary(other_gdp2_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_gdp2_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
other_gdp2_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
summary(inter_gdp2_feisoyear)
summary(other_gdp2_feisoyear)

################################################
# LOGIT REGRESSIONS (3): GDP GROWTH + MILITARY #
################################################

# no fixed effects
inter_gdp3_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp3_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp3_no)
summary(other_gdp3_no)

# country fixed effects
inter_gdp3_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp3_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp3_feiso)
summary(other_gdp3_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_gdp3_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
other_gdp3_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
summary(inter_gdp3_feisoyear)
summary(other_gdp3_feisoyear)

####################################################
# LOGIT REGRESSIONS (4): GDP GROWTH + GEOPOLITICAL #
####################################################

# no fixed effects
inter_gdp4_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp4_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp4_no)
summary(other_gdp4_no)

# country fixed effects
inter_gdp4_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp4_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp4_feiso)
summary(other_gdp4_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_gdp4_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_gdp4_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_gdp4_feisoyear)
summary(other_gdp4_feisoyear)

##########################################################################
# LOGIT REGRESSIONS (5): GDP GROWTH + OPENNESS + MILITARY + GEOPOLITICAL #
##########################################################################

# no fixed effects
inter_gdp5_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp5_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp5_no)
summary(other_gdp5_no)

# country fixed effects
inter_gdp5_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_gdp5_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    #milper_pop_lag1 + milper_pop_lag2 + milper_pop_lag3 + milper_pop_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_gdp5_feiso)
summary(other_gdp5_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_gdp5_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_gdp5_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_gdp5_feisoyear)
summary(other_gdp5_feisoyear)

####################################
# LOGIT REGRESSIONS (1): INFLATION #
####################################

# no fixed effects
inter_infl1_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl1_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl1_no)
summary(other_infl1_no)

# country fixed effects
inter_infl1_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl1_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl1_feiso)
summary(other_infl1_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_infl1_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4
)
other_infl1_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4
)
summary(inter_infl1_feisoyear)
summary(other_infl1_feisoyear)

###############################################
# LOGIT REGRESSIONS (2): INFLATION + OPENNESS #
###############################################

# no fixed effects
inter_infl2_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl2_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl2_no)
summary(other_infl2_no)

# country fixed effects
inter_infl2_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl2_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl2_feiso)
summary(other_infl2_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_infl2_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
other_infl2_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
summary(inter_infl2_feisoyear)
summary(other_infl2_feisoyear)

###############################################
# LOGIT REGRESSIONS (3): INFLATION + MILITARY #
###############################################

# no fixed effects
inter_infl3_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl3_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl3_no)
summary(other_infl3_no)

# country fixed effects
inter_infl3_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl3_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl3_feiso)
summary(other_infl3_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_infl3_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
other_infl3_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
summary(inter_infl3_feisoyear)
summary(other_infl3_feisoyear)

###################################################
# LOGIT REGRESSIONS (4): INFLATION + GEOPOLITICAL #
###################################################

# no fixed effects
inter_infl4_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl4_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl4_no)
summary(other_infl4_no)

# country fixed effects
inter_infl4_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl4_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl4_feiso)
summary(other_infl4_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_infl4_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_infl4_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_infl4_feisoyear)
summary(other_infl4_feisoyear)

#########################################################################
# LOGIT REGRESSIONS (5): INFLATION + OPENNESS + MILITARY + GEOPOLITICAL #
#########################################################################

# no fixed effects
inter_infl5_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl5_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl5_no)
summary(other_infl5_no)

# country fixed effects
inter_infl5_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
other_infl5_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_infl5_feiso)
summary(other_infl5_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_infl5_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_infl5_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_infl5_feisoyear)
summary(other_infl5_feisoyear)

###############################
# LOGIT REGRESSIONS (1): BOTH #
###############################

# no fixed effects
inter_both1_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both1_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both1_no)
summary(other_both1_no)

# country fixed effects
inter_both1_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both1_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both1_feiso)
summary(other_both1_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_both1_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4
)
other_both1_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4
)
summary(inter_both1_feisoyear)
summary(other_both1_feisoyear)

##########################################
# LOGIT REGRESSIONS (2): BOTH + OPENNESS #
##########################################

# no fixed effects
inter_both2_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both2_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both2_no)
summary(other_both2_no)

# country fixed effects
inter_both2_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both2_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both2_feiso)
summary(other_both2_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_both2_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
other_both2_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4
)
summary(inter_both2_feisoyear)
summary(other_both2_feisoyear)

##########################################
# LOGIT REGRESSIONS (3): BOTH + MILITARY #
##########################################

# no fixed effects
inter_both3_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both3_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both3_no)
summary(other_both3_no)

# country fixed effects
inter_both3_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both3_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both3_feiso)
summary(other_both3_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_both3_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
other_both3_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4
)
summary(inter_both3_feisoyear)
summary(other_both3_feisoyear)

##############################################
# LOGIT REGRESSIONS (4): BOTH + GEOPOLITICAL #
##############################################

# no fixed effects
inter_both4_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both4_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both4_no)
summary(other_both4_no)

# country fixed effects
inter_both4_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both4_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both4_feiso)
summary(other_both4_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_both4_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_both4_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_both4_feisoyear)
summary(other_both4_feisoyear)

####################################################################
# LOGIT REGRESSIONS (5): BOTH + OPENNESS + MILITARY + GEOPOLITICAL #
####################################################################

# no fixed effects
inter_both5_no <- fixest::feglm(data = regr_data_inter, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both5_no <- fixest::feglm(data = regr_data_other, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both5_no)
summary(other_both5_no)

# country fixed effects
inter_both5_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
other_both5_feiso <- fixest::feglm(data = regr_data_other, fixef = c("iso3"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
  peace_years + peace_years_sq + peace_years_cub
)
summary(inter_both5_feiso)
summary(other_both5_feiso)

# country-year fixed effects (remove Beck-Katz-Tucker peace years because they are collinear with country fixed effects)
inter_both5_feisoyear <- fixest::feglm(data = regr_data_inter, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
other_both5_feisoyear <- fixest::feglm(data = regr_data_other, fixef = c("iso3", "year"),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = warsite_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
  openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
  milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
  borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1
)
summary(inter_both5_feisoyear)
summary(other_both5_feisoyear)



#########################################################
# LOGIT REGRESSIONS (6): INTERSTATE WAR INITIATORS      #
#########################################################

#------------------------------------------------------------
# MODIFICATIONS FOR FINAL HERE
# # FINAL REGRESSIONS ONLY

# Data processing


regr_data_inter_avg <- regr_data_inter %>%
  mutate(
    gdp_growth_avg = rowMeans(select(., gdp_growth_lag1, gdp_growth_lag2, gdp_growth_lag3, gdp_growth_lag4), na.rm = TRUE),
    inflation_avg  = rowMeans(select(., inflation_lag1, inflation_lag2, inflation_lag3, inflation_lag4), na.rm = TRUE),
    openness_avg   = rowMeans(select(., openness_lag1, openness_lag2, openness_lag3, openness_lag4), na.rm = TRUE),
    milex_gdp_avg  = rowMeans(select(., milex_gdp_lag1, milex_gdp_lag2, milex_gdp_lag3, milex_gdp_lag4), na.rm = TRUE)
  )


regr_data_inter_target <- regr_data_inter %>%
  mutate(
    # 1 if the country becomes a war site in year t and is not the initiator
    target_onset = as.integer(warsite_onset == 1 & starter_onset == 0)
  ) %>%
  # keep only country-years where the country did not initiate in that year
  filter(starter_onset == 0) %>%
  # keep the same treatment of ongoing war-site years as in the baseline code
  filter(!(warsite == 1 & warsite_onset == 0))

regr_data_inter_conditional <- regr_data_inter %>%
  mutate(
    # ensure binary (just in case)
    starter_onset = as.integer(starter_onset == 1),
    warsite_onset = as.integer(warsite_onset == 1),
    
    # dependent variable: target (defender)
    target_onset = as.integer(warsite_onset == 1 & starter_onset == 0)
  ) %>%
  # keep only observations where a war onset occurs
  filter(starter_onset == 1 | warsite_onset == 1)

regr_data_inter_conditional_avg <- regr_data_inter_conditional %>%
  mutate(
    gdp_growth_avg = rowMeans(select(., gdp_growth_lag1, gdp_growth_lag2, gdp_growth_lag3, gdp_growth_lag4), na.rm = TRUE),
    inflation_avg  = rowMeans(select(., inflation_lag1, inflation_lag2, inflation_lag3, inflation_lag4), na.rm = TRUE),
    openness_avg   = rowMeans(select(., openness_lag1, openness_lag2, openness_lag3, openness_lag4), na.rm = TRUE),
    milex_gdp_avg  = rowMeans(select(., milex_gdp_lag1, milex_gdp_lag2, milex_gdp_lag3, milex_gdp_lag4), na.rm = TRUE)
  )

# initiator
inter_starter_avg <- fixest::feglm(
  data = regr_data_inter_avg,
  fixef = c("iso3"),  
  panel.id = ~ iso3 + year,
  family = binomial(link = "logit"),
  vcov = ~iso3,
  fml = starter_onset ~
    gdp_growth_avg +
    inflation_avg +
    openness_avg +
    milex_gdp_avg +
    borders_lag1 +
    cowmaj_lag1 +
    v2x_libdem_lag1 +
    peace_years
)

summary(inter_starter_avg)

inter_starter_simple <- fixest::feglm(
  data = regr_data_inter,
  fixef = c("iso3"),   # control global shocks
  panel.id = ~ iso3 + year,
  family = binomial(link = "logit"),
  vcov = ~iso3,
  fml = starter_onset ~
    gdp_growth_lag1 +
    inflation_lag1 +
    openness_lag1 +
    milex_gdp_lag1 +
    borders_lag1 +
    cowmaj_lag1 +
    v2x_libdem_lag1 +
    peace_years
)

summary(inter_starter_simple)

# country fixed effects +initiator
inter_starter_full_feiso <- fixest::feglm(data = regr_data_inter, fixef = c("iso3"),
                                          panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
                                          fml = starter_onset ~ gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
                                            openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
                                            inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 + 
                                            milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
                                            borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
                                            peace_years + peace_years_sq + peace_years_cub
)
summary(inter_starter_full_feiso)



# Unconditional: country fixed effects + target
inter_target_full_countryfe <- fixest::feglm(
  data = regr_data_inter_target,
  fixef = c("iso3"),
  panel.id = ~ iso3 + year,
  family = binomial(link = "logit"),
  vcov = ~ iso3,
  fml = target_onset ~
    gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
    openness_lag1 + openness_lag2 + openness_lag3 + openness_lag4 +
    inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 + 
    milex_gdp_lag1 + milex_gdp_lag2 + milex_gdp_lag3 + milex_gdp_lag4 +
    borders_lag1 + cowmaj_lag1 + v2x_libdem_lag1 +
    peace_years + peace_years_sq + peace_years_cub
)
summary(inter_target_full_countryfe)

# conditional on war onset + target
# no fe because too few countries.

inter_target_conditional_avg <- fixest::feglm(
  data = regr_data_inter_conditional_avg,
  #fixef = c("iso3"),
  panel.id = ~ iso3 + year,
  family = binomial(link = "logit"),
  vcov = ~ iso3,
  fml = target_onset ~
    gdp_growth_avg +
    inflation_avg +
    openness_avg +
    milex_gdp_avg +
    borders_lag1 +
    cowmaj_lag1 +
    v2x_libdem_lag1 +
    peace_years
)
summary(inter_target_conditional_avg)

inter_target_conditional_countryfe <- fixest::feglm(
  data = regr_data_inter_conditional,
  #fixef = c("iso3"),
  panel.id = ~ iso3 + year,
  family = binomial(link = "logit"),
  vcov = ~ iso3,
  fml = target_onset ~
    gdp_growth_lag1 +
    inflation_lag1 +
    openness_lag1 +
    milex_gdp_lag1 +
    borders_lag1 +
    cowmaj_lag1 +
    v2x_libdem_lag1 +
    peace_years
)

summary(inter_target_conditional_countryfe)



library(dplyr)
library(nnet)



# Bad idea here
# ------------------------------------------------------------
# Multinomial logit: peace vs initiator vs target
# 0 = peace
# 1 = initiator
# 2 = target
# ------------------------------------------------------------

regr_data_multi <- regr_data_inter %>%
  mutate(
    war_role = case_when(
      starter_onset == 1 ~ "initiator",
      warsite_onset == 1 & starter_onset == 0 ~ "target",
      TRUE ~ "peace"
    ),
    war_role = factor(war_role, levels = c("peace", "initiator", "target"))
  ) %>%
  filter(
    !is.na(gdp_growth_lag1),
    !is.na(inflation_lag1),
    !is.na(openness_lag1),
    !is.na(milex_gdp_lag1),
    !is.na(borders_lag1),
    !is.na(cowmaj_lag1),
    !is.na(v2x_libdem_lag1),
    !is.na(peace_years)
  )

form_multi <- war_role ~
  gdp_growth_lag1 +
  inflation_lag1 +
  openness_lag1 +
  milex_gdp_lag1 +
  borders_lag1 +
  cowmaj_lag1 +
  v2x_libdem_lag1 +
  peace_years +
  factor(year)

multi_yearfe <- multinom(
  form_multi,
  data = regr_data_multi,
  Hess = TRUE,
  trace = FALSE
)

summary(multi_yearfe)

library(broom)
library(dplyr)
library(tidyr)

# Function to create stars
add_stars <- function(p) {
  case_when(
    p < 0.001 ~ "***",
    p < 0.01  ~ "**",
    p < 0.05  ~ "*",
    p < 0.1   ~ ".",
    TRUE      ~ ""
  )
}

multi_table <- broom::tidy(multi_yearfe) %>%
  # remove year FE
  filter(!grepl("^factor\\(year\\)", term)) %>%
  mutate(
    outcome = y.level,
    stars = add_stars(p.value),
    estimate = round(estimate, 3),
    std.error = round(std.error, 3),
    
    # format: coef*** (se)
    coef_se = paste0(estimate, stars, " (", std.error, ")")
  ) %>%
  select(outcome, term, coef_se) %>%
  pivot_wider(names_from = outcome, values_from = coef_se) %>%
  arrange(term)

print(multi_table)

# ------------------------------------------------------------
# Multinomial logit: country FE (no year FE)
# peace vs initiator vs target
# ------------------------------------------------------------

regr_data_multi_isofe <- regr_data_inter %>%
  mutate(
    war_role = case_when(
      starter_onset == 1 ~ "initiator",
      warsite_onset == 1 & starter_onset == 0 ~ "target",
      TRUE ~ "peace"
    ),
    war_role = factor(war_role, levels = c("peace", "initiator", "target"))
  ) %>%
  filter(
    !is.na(gdp_growth_lag1),
    !is.na(inflation_lag1),
    !is.na(openness_lag1),
    !is.na(milex_gdp_lag1),
    !is.na(borders_lag1),
    !is.na(cowmaj_lag1),
    !is.na(v2x_libdem_lag1),
    !is.na(peace_years)
  )

form_multi_isofe <- war_role ~
  gdp_growth_lag1 +
  inflation_lag1 +
  openness_lag1 +
  milex_gdp_lag1 +
  borders_lag1 +
  cowmaj_lag1 +
  v2x_libdem_lag1 +
  peace_years +
  factor(iso3)

multi_isofe <- multinom(
  form_multi_isofe,
  data = regr_data_multi_isofe,
  Hess = TRUE,
  trace = FALSE
)

summary(multi_isofe)

multi_table_isofe <- broom::tidy(multi_isofe) %>%
  filter(!grepl("^factor\\(iso3\\)", term)) %>%
  mutate(
    outcome = y.level,
    stars = add_stars(p.value),
    estimate = round(estimate, 3),
    std.error = round(std.error, 3),
    coef_se = paste0(estimate, stars, " (", std.error, ")")
  ) %>%
  select(outcome, term, coef_se) %>%
  pivot_wider(names_from = outcome, values_from = coef_se) %>%
  arrange(term)

print(multi_table_isofe)

# ------------------------------------------------------------
# Multinomial logit: country FE + averaged lags
# peace vs initiator vs target
# ------------------------------------------------------------

regr_data_multi_isofe_avg <- regr_data_inter %>%
  mutate(
    war_role = case_when(
      starter_onset == 1 ~ "initiator",
      warsite_onset == 1 & starter_onset == 0 ~ "target",
      TRUE ~ "peace"
    ),
    war_role = factor(war_role, levels = c("peace", "initiator", "target")),
    gdp_growth_avg = rowMeans(cbind(gdp_growth_lag1, gdp_growth_lag2, gdp_growth_lag3, gdp_growth_lag4), na.rm = FALSE),
    inflation_avg  = rowMeans(cbind(inflation_lag1, inflation_lag2, inflation_lag3, inflation_lag4), na.rm = FALSE),
    openness_avg   = rowMeans(cbind(openness_lag1, openness_lag2, openness_lag3, openness_lag4), na.rm = FALSE),
    milex_gdp_avg  = rowMeans(cbind(milex_gdp_lag1, milex_gdp_lag2, milex_gdp_lag3, milex_gdp_lag4), na.rm = FALSE)
  ) %>%
  filter(
    !is.na(gdp_growth_avg),
    !is.na(inflation_avg),
    !is.na(openness_avg),
    !is.na(milex_gdp_avg),
    !is.na(borders_lag1),
    !is.na(cowmaj_lag1),
    !is.na(v2x_libdem_lag1),
    !is.na(peace_years)
  )

form_multi_isofe_avg <- war_role ~
  gdp_growth_avg +
  inflation_avg +
  openness_avg +
  milex_gdp_avg +
  borders_lag1 +
  cowmaj_lag1 +
  v2x_libdem_lag1 +
  peace_years +
  factor(iso3)

multi_isofe_avg <- multinom(
  form_multi_isofe_avg,
  data = regr_data_multi_isofe_avg,
  Hess = TRUE,
  trace = FALSE
)

#summary(multi_isofe_avg)

multi_table_isofe_avg <- broom::tidy(multi_isofe_avg) %>%
  filter(!grepl("^factor\\(iso3\\)", term)) %>%
  mutate(
    outcome = y.level,
    stars = add_stars(p.value),
    estimate = round(estimate, 3),
    std.error = round(std.error, 3),
    coef_se = paste0(estimate, stars, " (", std.error, ")")
  ) %>%
  select(outcome, term, coef_se) %>%
  pivot_wider(names_from = outcome, values_from = coef_se) %>%
  arrange(term)

print(multi_table_isofe_avg)



# ------------------------------------------------------------
# Multinomial logit: country FE + all lags
# peace vs initiator vs target
# ------------------------------------------------------------

regr_data_multi_isofe_all <- regr_data_inter %>%
  mutate(
    war_role = case_when(
      starter_onset == 1 ~ "initiator",
      warsite_onset == 1 & starter_onset == 0 ~ "target",
      TRUE ~ "peace"
    ),
    war_role = factor(war_role, levels = c("peace", "initiator", "target"))
  ) %>%
  filter(
    !is.na(gdp_growth_lag1), !is.na(gdp_growth_lag2), !is.na(gdp_growth_lag3), !is.na(gdp_growth_lag4),
    !is.na(inflation_lag1),   !is.na(inflation_lag2),   !is.na(inflation_lag3),   !is.na(inflation_lag4),
    !is.na(openness_lag1),    !is.na(openness_lag2),    !is.na(openness_lag3),    !is.na(openness_lag4),
    !is.na(milex_gdp_lag1),   !is.na(milex_gdp_lag2),   !is.na(milex_gdp_lag3),   !is.na(milex_gdp_lag4),
    !is.na(borders_lag1),
    !is.na(cowmaj_lag1),
    !is.na(v2x_libdem_lag1),
    !is.na(peace_years)
  )

form_multi_isofe_all <- war_role ~
  gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
  inflation_lag1   + inflation_lag2   + inflation_lag3   + inflation_lag4 +
  openness_lag1    + openness_lag2    + openness_lag3    + openness_lag4 +
  milex_gdp_lag1   + milex_gdp_lag2   + milex_gdp_lag3   + milex_gdp_lag4 +
  borders_lag1 +
  cowmaj_lag1 +
  v2x_libdem_lag1 +
  peace_years +
  factor(iso3)

multi_isofe_all <- multinom(
  form_multi_isofe_all,
  data = regr_data_multi_isofe_all,
  Hess = TRUE,
  trace = FALSE
)

#summary(multi_isofe_all)
multi_table_isofe_all <- broom::tidy(multi_isofe_all) %>%
  filter(!grepl("^factor\\(iso3\\)", term)) %>%
  mutate(
    outcome = y.level,
    stars = add_stars(p.value),
    estimate = round(estimate, 3),
    std.error = round(std.error, 3),
    coef_se = paste0(estimate, stars, " (", std.error, ")")
  ) %>%
  select(outcome, term, coef_se) %>%
  pivot_wider(names_from = outcome, values_from = coef_se) %>%
  arrange(term)

print(multi_table_isofe_all, n=25)



