############
# PACKAGES #
############
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

##########
# TABLES #
##########
inter_models_list_gdp <- list(
  "(1)" = inter_gdp1_no, "(2)" = inter_gdp1_feiso,
  "(3)" = inter_gdp2_no, "(4)" = inter_gdp2_feiso,
  "(5)" = inter_gdp3_no, "(6)" = inter_gdp3_feiso,
  "(7)" = inter_gdp4_no, "(8)" = inter_gdp4_feiso,
  "(9)" = inter_gdp5_no, "(10)" = inter_gdp5_feiso
)
other_models_list_gdp <- list(
  "(1)" = other_gdp1_no, "(2)" = other_gdp1_feiso,
  "(3)" = other_gdp2_no, "(4)" = other_gdp2_feiso,
  "(5)" = other_gdp3_no, "(6)" = other_gdp3_feiso,
  "(7)" = other_gdp4_no, "(8)" = other_gdp4_feiso,
  "(9)" = other_gdp5_no, "(10)" = other_gdp5_feiso
)
inter_models_list_infl <- list(
  "(11)" = inter_infl1_no, "(12)" = inter_infl1_feiso,
  "(13)" = inter_infl2_no, "(14)" = inter_infl2_feiso,
  "(15)" = inter_infl3_no, "(16)" = inter_infl3_feiso,
  "(17)" = inter_infl4_no, "(18)" = inter_infl4_feiso,
  "(19)" = inter_infl5_no, "(20)" = inter_infl5_feiso
)
other_models_list_infl <- list(
  "(11)" = other_infl1_no, "(12)" = other_infl1_feiso,
  "(13)" = other_infl2_no, "(14)" = other_infl2_feiso,
  "(15)" = other_infl3_no, "(16)" = other_infl3_feiso,
  "(17)" = other_infl4_no, "(18)" = other_infl4_feiso,
  "(19)" = other_infl5_no, "(20)" = other_infl5_feiso
)
inter_models_list_both <- list(
  "(21)" = inter_both1_no, "(22)" = inter_both1_feiso,
  "(23)" = inter_both2_no, "(24)" = inter_both2_feiso,
  "(25)" = inter_both3_no, "(26)" = inter_both3_feiso,
  "(27)" = inter_both4_no, "(28)" = inter_both4_feiso,
  "(29)" = inter_both5_no, "(30)" = inter_both5_feiso
)
other_models_list_both <- list(
  "(21)" = other_both1_no, "(22)" = other_both1_feiso,
  "(23)" = other_both2_no, "(24)" = other_both2_feiso,
  "(25)" = other_both3_no, "(26)" = other_both3_feiso,
  "(27)" = other_both4_no, "(28)" = other_both4_feiso,
  "(29)" = other_both5_no, "(30)" = other_both5_feiso
)

inter_models_list_paper <- list(
  "(21)" = inter_both1_no, "(22)" = inter_both1_feiso,
  "(29)" = inter_both5_no, "(30)" = inter_both5_feiso
)
other_models_list_paper <- list(
  "(21)" = other_both1_no, "(22)" = other_both1_feiso,
  "(29)" = other_both5_no, "(30)" = other_both5_feiso
)

# extract GOF stats for each model
count_warsites <- function(model, data) {data[model$obs_selection$obsRemoved, ] %>% filter(warsite_onset == 1) %>% nrow()}

inter_gof_stats_gdp <- lapply(inter_models_list_gdp, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_inter)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})
other_gof_stats_gdp <- lapply(other_models_list_gdp, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_other)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})

inter_gof_stats_infl <- lapply(inter_models_list_infl, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_inter)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})
other_gof_stats_infl <- lapply(other_models_list_infl, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_other)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})

inter_gof_stats_both <- lapply(inter_models_list_both, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_inter)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})
other_gof_stats_both <- lapply(other_models_list_both, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_other)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})

inter_gof_stats_paper <- lapply(inter_models_list_paper, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_inter)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})
other_gof_stats_paper <- lapply(other_models_list_paper, function(m) {
  c(
    "Fixed Effects" = if (length(m$fixef_vars) == 0) "" else paste(m$fixef_vars, collapse = ", "),
    "Observations" = as.character(nobs(m)),
    "War Sites" = as.character(count_warsites(m, regr_data_other)),
    "Pseudo R2" = sprintf("%.2f", summary(m)$pseudo_r2),
    "Log-Likelihood" = sprintf("%.2f", as.numeric(logLik(m))),
    "AIC" = sprintf("%.2f", AIC(m)),
    "BIC" = sprintf("%.2f", BIC(m))
  )
})

options("modelsummary_format_numeric_latex" = "plain")

my_coef_map <- c(
    "gdp_growth_lag1" = "GDP Growth (t-1)", "gdp_growth_lag2" = "GDP Growth (t-2)", "gdp_growth_lag3" = "GDP Growth (t-3)", "gdp_growth_lag4" = "GDP Growth (t-4)",
    "inflation_lag1" = "Inflation (t-1)", "inflation_lag2" = "Inflation (t-2)", "inflation_lag3" = "Inflation (t-3)", "inflation_lag4" = "Inflation (t-4)",
    "openness_lag1" = "Openness (t-1)", "openness_lag2" = "Openness (t-2)", "openness_lag3" = "Openness (t-3)", "openness_lag4" = "Openness (t-4)",
    "milex_gdp_lag1" = "Military Exp. (t-1)", "milex_gdp_lag2" = "Military Exp. (t-2)", "milex_gdp_lag3" = "Military Exp. (t-3)", "milex_gdp_lag4" = "Military Exp. (t-4)",
    "milper_pop_lag1" = "Military Pers. (t-1)", "milper_pop_lag2" = "Military Pers. (t-2)", "milper_pop_lag3" = "Military Pers. (t-3)", "milper_pop_lag4" = "Military Pers. (t-4)",
    "borders" = "Borders", "borders_lag1" = "Borders (t-1)",
    "v2x_libdem" = "Democracy", "v2x_libdem_lag1" = "Democracy (t-1)",
    "cowmaj" = "Major Power", "cowmaj_lag1" = "Major Power (t-1)",
    "sum_igo_anytype" = "IGO", "sum_igo_anytype_lag1" = "IGO (t-1)",
    "defense" = "Alliance", "defense_lag1" = "Alliance (t-1)",
    "peace_years" = "Peace Years", "I(peace_years^2)" = "Peace Years Squared", "I(peace_years^3)" = "Peace Years Cubed",
    "peace_years_sq" = "(Peace Years)^2", "peace_years_cub" = "(Peace Years)^3",
    "splines::bs(peace_years, 4)1" = "Peace Years Spline 1", "splines::bs(peace_years, 4)2" = "Peace Years Spline 2", "splines::bs(peace_years, 4)3" = "Peace Years Spline 3", "splines::bs(peace_years, 4)4" = "Peace Years Spline 4"
  )

##############
# GDP TABLES #
##############

tbl_gdp_inter <- modelsummary::modelsummary(
  inter_models_list_gdp,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP growth) - Inter-State Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_gdp)
  )
)
tbl_gdp_inter_tex <- modelsummary::modelsummary(
  inter_models_list_gdp,
  output = "latex_tabular",
  align = "lcccccccccc",
  title = "Predictability of becoming a warsite (GDP growth) - Inter-State Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_gdp)
  )
)
tbl_gdp_other <- modelsummary::modelsummary(
  other_models_list_gdp,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP growth) - Other Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_gdp)
  )
)
tbl_gdp_other_tex <- modelsummary::modelsummary(
  other_models_list_gdp,
  output = "latex_tabular",
  align = "lcccccccccc",
  title = "Predictability of becoming a warsite (GDP growth) - Other Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_gdp)
  )
)

####################
# INFLATION TABLES #
####################
tbl_infl_inter <- modelsummary::modelsummary(
  inter_models_list_infl,
  output = "huxtable",
  title = "Predictability of becoming a warsite (Inflation) - Inter-State Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_infl)
  )
)
tbl_infl_inter_tex <- modelsummary::modelsummary(
  inter_models_list_infl,
  align = "lcccccccccc",
  output = "latex_tabular",
  title = "Predictability of becoming a warsite (Inflation) - Inter-State Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_infl)
  )
)

tbl_infl_other <- modelsummary::modelsummary(
  other_models_list_infl,
  output = "huxtable",
  title = "Predictability of becoming a warsite (Inflation) - Other Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_infl)
  )
)
tbl_infl_other_tex <- modelsummary::modelsummary(
  other_models_list_infl,
  output = "latex_tabular",
  align = "lcccccccccc",
  title = "Predictability of becoming a warsite (Inflation) - Other Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_infl)
  )
)

###############
# BOTH TABLES #
###############
tbl_both_inter <- modelsummary::modelsummary(
  inter_models_list_both,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Inter-State Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_both)
  )
)
tbl_both_inter_tex <- modelsummary::modelsummary(
  inter_models_list_both,
  output = "latex_tabular",
  align = "lcccccccccc",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Inter-State Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_both)
  )
)
tbl_both_other <- modelsummary::modelsummary(
  other_models_list_both,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Other Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_both)
  )
)
tbl_both_other_tex <- modelsummary::modelsummary(
  other_models_list_both,
  output = "latex_tabular",
  align = "lcccccccccc",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Other Warsites",
  #stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_both)
  )
)

#################
# PAPER TABLE 3 #
#################
inter_models <- modelsummary::modelsummary(
  inter_models_list_paper,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Inter-State Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(inter_gof_stats_paper)
  )
)
other_models <- modelsummary::modelsummary(
  other_models_list_paper,
  output = "huxtable",
  title = "Predictability of becoming a warsite (GDP Growth + Inflation) - Other Warsites",
  stars = c("." = .10, "*" = .05, "**" = .01, "***" = 0.001),
  fmt = "%.2f",
  coef_map = my_coef_map,
  gof_map = NA,
  add_rows = tibble(
    term = c("Fixed Effects", "Observations", "War Sites", "Pseudo R^2", "Log-Likelihood", "AIC", "BIC"),
    !!!as.list(other_gof_stats_paper)
  )
)
print("===== PAPER TABLE 3 - INTERSTATE =====")
print(inter_models)
print("===== PAPER TABLE 3 - OTHER =====")
print(other_models)

#########################
# PAPER APPENDIX TABLES #
#########################
paper_tinytable <- function(tinytable_obj) {
  # Get the name of the input object
  obj_name <- deparse(substitute(tinytable_obj))
  filename <- paste0("data/03_exports/tables/predictability/", obj_name, ".tex")
  # save tinytable to temporary file
  temp_file <- paste0(tempfile(), ".tex")
  tinytable::save_tt(tinytable_obj, temp_file, overwrite = TRUE)
  # read and process the file
  tex_lines <- readLines(temp_file)
  # replace {lllllllllll} by {lcccccccccc}
  tex_lines <- gsub("\\{lllllllllll\\}", "\\{lcccccccccc\\}", tex_lines)
  # remove \hline commands
  tex_lines <- gsub("\\\\hline", "", tex_lines)
  # replace second line by \toprule and second to last line by \bottomrule
  tex_lines[2] <- "\\toprule"
  tex_lines[length(tex_lines)-1] <- "\\bottomrule"
  # Add \midrule after third line
  tex_lines <- c(tex_lines[1:3], "\\midrule", tex_lines[4:length(tex_lines)])
  # replace Fixed Effects line
  tex_lines <- c(
    tex_lines[1:40],
    "\\midrule",
    "Fixed Effects & no & iso & no & iso & no & iso & no & iso & no & iso \\\\",
    tex_lines[42:length(tex_lines)]
  )
  # replace mathematical expressions
  tex_lines <- gsub("\\(Peace Years\\)\\\\textasciicircum\\{\\}2", "$\\\\text{Peace Years}^2$", tex_lines)
  tex_lines <- gsub("\\(Peace Years\\)\\\\textasciicircum\\{\\}3", "$\\\\text{Peace Years}^3$", tex_lines)
  tex_lines <- gsub("R\\\\textasciicircum\\{\\}2", "$R^2$", tex_lines)
  # write to final file
  writeLines(tex_lines, filename)
  # clean up temporary file
  file.remove(temp_file)
  cat("Table saved to:", filename, "\n")
}

print("====== APPENDIX TABLE O-F-1 =====")
print(tbl_gdp_inter)
paper_tinytable(tbl_gdp_inter_tex)

print("====== APPENDIX TABLE O-F-2 =====")
print(tbl_gdp_other)
paper_tinytable(tbl_gdp_other_tex)

print("====== APPENDIX TABLE O-F-3 =====")
print(tbl_infl_inter)
paper_tinytable(tbl_infl_inter_tex)

print("====== APPENDIX TABLE O-F-4 =====")
print(tbl_infl_other)
paper_tinytable(tbl_infl_other_tex)

print("====== APPENDIX TABLE O-F-5 =====")
print(tbl_both_inter)
paper_tinytable(tbl_both_inter_tex)

print("====== APPENDIX TABLE O-F-6 =====")
print(tbl_both_other)
paper_tinytable(tbl_both_other_tex)

####################################
# PREDICTABILITY TABLE 3 (SUMMARY) #
####################################

# Function to check if any lag of a variable is significant at p < 0.05
check_significance <- function(model, var_prefix) {
  coef_summary <- summary(model)$coeftable
  var_names <- grep(paste0("^", var_prefix), rownames(coef_summary), value = TRUE)
  if (length(var_names) == 0) {
    return(list(included = FALSE, significant = FALSE))
  }
  p_values <- coef_summary[var_names, "Pr(>|z|)", drop = FALSE]
  min_p <- min(p_values, na.rm = TRUE)
  return(list(included = TRUE, significant = min_p < 0.05))
}

# Function to check significance of a single variable
check_single_var <- function(model, var_name) {
  coef_summary <- summary(model)$coeftable
  if (!(var_name %in% rownames(coef_summary))) {
    return(list(included = FALSE, significant = FALSE))
  }
  p_value <- coef_summary[var_name, "Pr(>|z|)"]
  return(list(included = TRUE, significant = p_value < 0.05))
}

# Function to check if any peace years term is significant
check_peace_years <- function(model) {
  coef_summary <- summary(model)$coeftable
  peace_vars <- grep("peace_years", rownames(coef_summary), value = TRUE)
  if (length(peace_vars) == 0) {
    return(list(included = FALSE, significant = FALSE))
  }
  p_values <- coef_summary[peace_vars, "Pr(>|z|)", drop = FALSE]
  min_p <- min(p_values, na.rm = TRUE)
  return(list(included = TRUE, significant = min_p < 0.05))
}

# Function to create the symbol (✓ or ✕ or ~)
create_symbol <- function(check_result) {
  if (!check_result$included) {
    return("~")
  } else if (check_result$significant) {
    return("\\ding{108}")  # checkmark
  } else {
    return("\\ding{109}")  # crossmark
  }
}

# Extract information for interstate models
inter_predictability_data <- lapply(names(inter_models_list_paper), function(model_num) {
  model <- inter_models_list_paper[[model_num]]
  
  list(
    gdp_growth = check_significance(model, "gdp_growth_lag"),
    inflation = check_significance(model, "inflation_lag"),
    openness = check_significance(model, "openness_lag"),
    military = check_significance(model, "milex_gdp_lag"),
    borders = check_single_var(model, "borders_lag1"),
    democracy = check_single_var(model, "v2x_libdem_lag1"),
    major_power = check_single_var(model, "cowmaj_lag1"),
    peace_years = check_peace_years(model),
    fe = if (length(model$fixef_vars) > 0 && "iso3" %in% model$fixef_vars) "\\checkmark" else "",
    obs = nobs(model),
    war_sites = count_warsites(model, regr_data_inter),
    pseudo_r2 = sprintf("%.2f", summary(model)$pseudo_r2),
    loglik = sprintf("%.1f", as.numeric(logLik(model)))
  )
})
names(inter_predictability_data) <- names(inter_models_list_paper)

# Extract information for other models
other_predictability_data <- lapply(names(other_models_list_paper), function(model_num) {
  model <- other_models_list_paper[[model_num]]
  
  list(
    gdp_growth = check_significance(model, "gdp_growth_lag"),
    inflation = check_significance(model, "inflation_lag"),
    openness = check_significance(model, "openness_lag"),
    military = check_significance(model, "milex_gdp_lag"),
    borders = check_single_var(model, "borders_lag1"),
    democracy = check_single_var(model, "v2x_libdem_lag1"),
    major_power = check_single_var(model, "cowmaj_lag1"),
    peace_years = check_peace_years(model),
    fe = if (length(model$fixef_vars) > 0 && "iso3" %in% model$fixef_vars) "\\checkmark" else "",
    obs = nobs(model),
    war_sites = count_warsites(model, regr_data_other),
    pseudo_r2 = sprintf("%.2f", summary(model)$pseudo_r2),
    loglik = sprintf("%.1f", as.numeric(logLik(model)))
  )
})
names(other_predictability_data) <- names(other_models_list_paper)

# Build the LaTeX table
tex_lines <- c(
  "\\begin{tabular}{lcccccccc}",
  "\\toprule",
  "&\\multicolumn{8}{c}{Probability of being war site}\\\\",
  "\\cmidrule{2-9}",
  "&\\multicolumn{4}{c}{Interstate wars} & \\multicolumn{4}{c}{Other wars}\\\\",
  "\\cmidrule(lr){2-5} \\cmidrule(lr){6-9}",
  "                        & (21)       & (22)        & (29)       & (30)      & (21)       & (22)        & (29)       & (30) \\\\",
  "\\midrule"
)

# Variable rows
var_rows <- list(
  c("GDP growth (any lag)",    "gdp_growth"),
  c("Inflation (any lag)",     "inflation"),
  c("Openness (any lag)",      "openness"),
  c("Military exp. (any lag)", "military"),
  c("Borders (t-1)",           "borders"),
  c("Democracy (t-1)",         "democracy"),
  c("Major power (t-1)",       "major_power"),
  c("Peace years  (any term)", "peace_years")
)

for (var_info in var_rows) {
  var_label <- var_info[1]
  var_name <- var_info[2]
  
  line <- sprintf("%-23s", var_label)
  # Add interstate models
  for (model_num in names(inter_models_list_paper)) {
    symbol <- create_symbol(inter_predictability_data[[model_num]][[var_name]])
    line <- paste0(line, " & ", sprintf("%-10s", symbol))
  }
  # Add other models
  for (model_num in names(other_models_list_paper)) {
    symbol <- create_symbol(other_predictability_data[[model_num]][[var_name]])
    line <- paste0(line, " & ", sprintf("%-10s", symbol))
  }
  line <- paste0(line, "\\\\")
  tex_lines <- c(tex_lines, line)
}

# Model diagnostics
tex_lines <- c(tex_lines, "\\midrule")

# Country fixed effects
line <- sprintf("%-23s", "Country fixed effects")
for (model_num in names(inter_models_list_paper)) {
  fe <- inter_predictability_data[[model_num]]$fe
  line <- paste0(line, " & ", sprintf("%-10s", fe))
}
for (model_num in names(other_models_list_paper)) {
  fe <- other_predictability_data[[model_num]]$fe
  line <- paste0(line, " & ", sprintf("%-10s", fe))
}
line <- paste0(line, "\\\\")
tex_lines <- c(tex_lines, line)

# Observations
line <- sprintf("%-23s", "Observations")
for (model_num in names(inter_models_list_paper)) {
  obs <- inter_predictability_data[[model_num]]$obs
  line <- paste0(line, " & ", sprintf("%-10s", obs))
}
for (model_num in names(other_models_list_paper)) {
  obs <- other_predictability_data[[model_num]]$obs
  line <- paste0(line, " & ", sprintf("%-10s", obs))
}
line <- paste0(line, "\\\\")
tex_lines <- c(tex_lines, line)

# War sites
line <- sprintf("%-23s", "War sites")
for (model_num in names(inter_models_list_paper)) {
  sites <- inter_predictability_data[[model_num]]$war_sites
  line <- paste0(line, " & ", sprintf("%-10s", sites))
}
for (model_num in names(other_models_list_paper)) {
  sites <- other_predictability_data[[model_num]]$war_sites
  line <- paste0(line, " & ", sprintf("%-10s", sites))
}
line <- paste0(line, "\\\\")
tex_lines <- c(tex_lines, line)

# Pseudo R²
line <- sprintf("%-23s", "Pseudo-$R^2$")
for (model_num in names(inter_models_list_paper)) {
  r2 <- inter_predictability_data[[model_num]]$pseudo_r2
  line <- paste0(line, " & ", sprintf("%-10s", r2))
}
for (model_num in names(other_models_list_paper)) {
  r2 <- other_predictability_data[[model_num]]$pseudo_r2
  line <- paste0(line, " & ", sprintf("%-10s", r2))
}
line <- paste0(line, "\\\\")
tex_lines <- c(tex_lines, line)

# Log-Likelihood
line <- sprintf("%-23s", "Log-Likelihood")
for (model_num in names(inter_models_list_paper)) {
  loglik <- inter_predictability_data[[model_num]]$loglik
  line <- paste0(line, " & ", sprintf("%-10s", loglik))
}
for (model_num in names(other_models_list_paper)) {
  loglik <- other_predictability_data[[model_num]]$loglik
  line <- paste0(line, " & ", sprintf("%-10s", loglik))
}
line <- paste0(line, "\\\\")
tex_lines <- c(tex_lines, line)

# Close table
tex_lines <- c(tex_lines, "\\bottomrule", "\\end{tabular}")

# Write to file (without trailing newline)
cat(paste(tex_lines, collapse = "\n"), file = "data/03_exports/tables/predictability/tbl_predictability.tex")
cat("\n===== PREDICTABILITY SUMMARY TABLE 3 =====\n")
cat("Table saved to: data/03_exports/tables/predictability/tbl_predictability.tex\n")
cat("Models included: (21), (22), (29), (30) for both Interstate and Other wars\n")
cat("Symbols: \\ding{108} = included and significant (p<0.05)\n")
cat("         \\ding{109} = included but not significant\n")
cat("         ~ = not included in model\n")

#####################
# GRANGER CAUSALITY #
#####################
# Create panel with complete cases
vars_needed_both <- c(
  paste0("warsite_onset_lag", 1:4), # warsite onsets
  paste0("gdp_growth_lag", 1:4),    # GDP‐growth lags
  paste0("inflation_lag", 1:4),     # inflation lags
  "peace_years"                     # peace‐years terms
)
vars_needed_gdp <- c(
  paste0("warsite_onset_lag", 1:4), # warsite onsets
  paste0("gdp_growth_lag", 1:4),    # GDP‐growth lags
  "peace_years"                     # peace‐years terms
)
vars_needed_infl <- c(
  paste0("warsite_onset_lag", 1:4), # warsite onsets
  paste0("inflation_lag", 1:4),     # inflation lags
  "peace_years"                     # peace‐years terms
)

inter_data_granger_both <- regr_data_inter %>% filter(if_all(all_of(vars_needed_both), ~ !is.na(.)))
other_data_granger_both <- regr_data_other %>% filter(if_all(all_of(vars_needed_both), ~ !is.na(.)))
inter_data_granger_gdp <- regr_data_inter %>% filter(if_all(all_of(vars_needed_gdp), ~ !is.na(.)))
other_data_granger_gdp <- regr_data_other %>% filter(if_all(all_of(vars_needed_gdp), ~ !is.na(.)))
inter_data_granger_infl <- regr_data_inter %>% filter(if_all(all_of(vars_needed_infl), ~ !is.na(.)))
other_data_granger_infl <- regr_data_other %>% filter(if_all(all_of(vars_needed_infl), ~ !is.na(.)))

# unrestricted models: add lags of GDP growth and/or inflation
inter_unrestricted_both <- fixest::feglm(data = inter_data_granger_both, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
      inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_unrestricted_both <- fixest::feglm(data = other_data_granger_both, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
      inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)

inter_unrestricted_gdp <- fixest::feglm(data = inter_data_granger_gdp, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_unrestricted_gdp <- fixest::feglm(data = other_data_granger_gdp, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      gdp_growth_lag1 + gdp_growth_lag2 + gdp_growth_lag3 + gdp_growth_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)

inter_unrestricted_infl <- fixest::feglm(data = inter_data_granger_infl, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_unrestricted_infl <- fixest::feglm(data = other_data_granger_infl, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      inflation_lag1 + inflation_lag2 + inflation_lag3 + inflation_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
print("===== GRANGER CAUSALITY UNRESTRICTED REGRESSIONS =====")
summary(inter_unrestricted_both)
summary(other_unrestricted_both)
summary(inter_unrestricted_gdp)
summary(other_unrestricted_gdp)
summary(inter_unrestricted_infl)
summary(other_unrestricted_infl)

# restricted model: only past warsite history and peace‐year controls
inter_restricted_both <- fixest::feglm(data = inter_data_granger_both, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_restricted_both <- fixest::feglm(data = other_data_granger_both, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)

inter_restricted_gdp <- fixest::feglm(data = inter_data_granger_gdp, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_restricted_gdp <- fixest::feglm(data = other_data_granger_gdp, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)

inter_restricted_infl <- fixest::feglm(data = inter_data_granger_infl, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
other_restricted_infl <- fixest::feglm(data = other_data_granger_infl, fixef = c(),
  panel.id = ~ iso3 + year, family = binomial(link = "logit"), vcov = ~iso3,
  fml = as.formula(
    warsite_onset ~ warsite_onset_lag1 + warsite_onset_lag2 + warsite_onset_lag3 + warsite_onset_lag4 +
      peace_years + peace_years_sq + peace_years_cub
  )
)
print("===== GRANGER CAUSALITY RESTRICTED REGRESSIONS =====")
summary(inter_restricted_both)
summary(other_restricted_both)
summary(inter_restricted_gdp)
summary(other_restricted_gdp)
summary(inter_restricted_infl)
summary(other_restricted_infl)

# Likelihood‐ratio test for Granger causality of GDP growth and/or inflation on warsite onset
inter_lr_statistic_both <- -2 * (logLik(inter_restricted_both) - logLik(inter_unrestricted_both))
other_lr_statistic_both <- -2 * (logLik(other_restricted_both) - logLik(other_unrestricted_both))
inter_lr_statistic_gdp <- -2 * (logLik(inter_restricted_gdp) - logLik(inter_unrestricted_gdp))
other_lr_statistic_gdp <- -2 * (logLik(other_restricted_gdp) - logLik(other_unrestricted_gdp))
inter_lr_statistic_infl <- -2 * (logLik(inter_restricted_infl) - logLik(inter_unrestricted_infl))
other_lr_statistic_infl <- -2 * (logLik(other_restricted_infl) - logLik(other_unrestricted_infl))

inter_df_both <- length(coef(inter_unrestricted_both)) - length(coef(inter_restricted_both))
other_df_both <- length(coef(other_unrestricted_both)) - length(coef(other_restricted_both))
inter_df_gdp <- length(coef(inter_unrestricted_gdp)) - length(coef(inter_restricted_gdp))
other_df_gdp <- length(coef(other_unrestricted_gdp)) - length(coef(other_restricted_gdp))
inter_df_infl <- length(coef(inter_unrestricted_infl)) - length(coef(inter_restricted_infl))
other_df_infl <- length(coef(other_unrestricted_infl)) - length(coef(other_restricted_infl))

inter_p_value_both <- pchisq(inter_lr_statistic_both, df = inter_df_both, lower.tail = FALSE)
other_p_value_both <- pchisq(other_lr_statistic_both, df = other_df_both, lower.tail = FALSE)
inter_p_value_gdp <- pchisq(inter_lr_statistic_gdp, df = inter_df_gdp, lower.tail = FALSE)
other_p_value_gdp <- pchisq(other_lr_statistic_gdp, df = other_df_gdp, lower.tail = FALSE)
inter_p_value_infl <- pchisq(inter_lr_statistic_infl, df = inter_df_infl, lower.tail = FALSE)
other_p_value_infl <- pchisq(other_lr_statistic_infl, df = other_df_infl, lower.tail = FALSE)

inter_results_lr <- data.frame(
  `Model Comparison` = c("Restricted vs. GDP growth lags",
                         "Restricted vs. Inflation lags",
                         "Restricted vs. GDP & Inflation lags"),
  `LR statistic` = c(as.numeric(inter_lr_statistic_gdp),
                     as.numeric(inter_lr_statistic_infl),
                     as.numeric(inter_lr_statistic_both)),
  `df` = c(inter_df_gdp, inter_df_infl, inter_df_both),
  `p-value` = c(inter_p_value_gdp, inter_p_value_infl, inter_p_value_both),
  `Granger-causal?` = ifelse(
    c(inter_p_value_gdp, inter_p_value_infl, inter_p_value_both) < 0.05, "Yes", "No"
  )
)
other_results_lr <- data.frame(
  `Model Comparison` = c("Restricted vs. GDP growth lags",
                         "Restricted vs. Inflation lags",
                         "Restricted vs. GDP & Inflation lags"),
  `LR statistic` = c(as.numeric(other_lr_statistic_gdp),
                     as.numeric(other_lr_statistic_infl),
                     as.numeric(other_lr_statistic_both)),
  `df` = c(other_df_gdp, other_df_infl, other_df_both),
  `p-value` = c(other_p_value_gdp, other_p_value_infl, other_p_value_both),
  `Granger-causal?` = ifelse(
    c(other_p_value_gdp, other_p_value_infl, other_p_value_both) < 0.05, "Yes", "No"
  )
)

print("===== GRANGER CAUSALITY TEST RESULTS =====")
print(knitr::kable(
  inter_results_lr,
  digits = 3,
  align = "lcccl",
  caption = "Likelihood-ratio Tests for Granger Causality (Panel Logit Model) Interstate"
))
print(knitr::kable(
  other_results_lr,
  digits = 3,
  align = "lcccl",
  caption = "Likelihood-ratio Tests for Granger Causality (Panel Logit Model) Other"
))
