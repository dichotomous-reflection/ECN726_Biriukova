/******************************************************************
* Fetch missing public CoW datasets into data/01_raw
* Requires that project globals are defined:
*   DIR_DATA_RAW, DIR_DATA_PROCESSED, DIR_DATA_EXPORTS, DIR_DATA_TMP,
*   DIR_RESSOURCES, DIR_SRC_UTILS, DIR_SRC_PROCESS, DIR_SRC_EXPORTS
******************************************************************/

//version 17
clear all
set more off

/* ---------- Ensure required directory structure exists ---------- */
cap mkdir "$DIR_DATA_RAW/cow"
cap mkdir "$DIR_DATA_RAW/cow/contiguity"
cap mkdir "$DIR_DATA_RAW/cow/contiguity/DirectContiguity320"
cap mkdir "$DIR_DATA_RAW/cow/wars"
cap mkdir "$DIR_DATA_RAW/cow/Intra-State-Wars-v5.1"
cap mkdir "$DIR_DATA_RAW/cow/NMC-60-wsupplementary"
cap mkdir "$DIR_DATA_RAW/cow/terr-changes-v6"
cap mkdir "$DIR_DATA_TMP"

/* ---------- Helper: safe downloader + unzipper (no braces) ---------- */
/* - Downloads to TMP (Stata tempdir or $DIR_DATA_TMP)
   - Unzips in destination by temporarily cd'ing there
   - Fixes "double nesting" (folder-within-same-folder)
   - Expands inner ZIPs (needed for NMC bundle)
*/
cap program drop _dl_if_missing
program define _dl_if_missing
    //version 17
    syntax , url(string) target(string) [ unzipto(string) zip(string) ]

    local tgt  `"`target'"'
    local src  `"`url'"'

    // Skip if target already present
    capture confirm file `"`tgt'"'
    if (_rc==0) {
        di as res "✓ Already present: `tgt'"
        exit
    }

    // TMP download path
    if ("`zip'"!="") {
        local tmpfile "`c(tmpdir)'\`zip''"
        if ("$DIR_DATA_TMP"!="") { 
			cap mkdir "$DIR_DATA_TMP"
            local tmpfile "$DIR_DATA_TMP/`zip'"
        }
    }
    else {
        local fname = substr("`src'", max(strrpos("`src'","/")+1,1), .)
        local tmpfile "`c(tmpdir)'\`fname''"
        if ("$DIR_DATA_TMP"!="") { 
			cap mkdir "$DIR_DATA_TMP"
            local tmpfile "$DIR_DATA_TMP/`fname'"
        }
    }

    di as txt "→ Fetching: `src'"
    di as txt "  to: `tmpfile'"

    // Download (Stata copy; then curl fallback)
    cap noisily copy "`src'" "`tmpfile'", replace
    if (_rc) {
        di as txt "… Stata copy failed (rc=`_rc'). Trying curl fallback."
        cap noisily shell curl -L -o "`tmpfile'" "`src'"
    }
    capture confirm file `"`tmpfile'"'
    if (_rc) {
        di as error "× Download failed or file not created: `src'"
        exit 601
    }

    // For direct files, ensure parent dir exists
    if ("`unzipto'"=="") {
        local parent = substr("`target'", 1, strrpos("`target'","/")-1)
        cap mkdir "`parent'"
    }

    // Unzip or place
    if ("`unzipto'"!="") {
        cap mkdir "`unzipto'"
        local oldpwd "`c(pwd)'"
        quietly cd "`unzipto'"
        di as txt "→ Unzipping in: `c(pwd)'"
        cap noisily unzipfile "`tmpfile'", replace
        local rc = _rc
        quietly cd "`oldpwd'"
        if (`rc') {
			erase `tmpfile'
            di as error "× Unzip failed: `tmpfile'"
            exit `rc'
        }

        // Fix possible "double nesting"
        capture confirm file `"`tgt'"'
        if (_rc) {
            local tgt_folder = substr("`target'", 1, strrpos("`target'","/")-1)
            local base = substr("`tgt_folder'", strrpos("`tgt_folder'","/")+1, .)
            local nested "`tgt_folder'/`base'"
            local leaf = substr("`target'", strrpos("`target'","/")+1, .)
            capture confirm file `"`nested'/`leaf'"'
            if (_rc==0) {
                di as txt "→ Fixing double-nesting: moving `leaf' up from `nested'"
                cap noisily copy `"`nested'/`leaf'"' `"`tgt'"', replace
            }
        }

        // Expand any inner ZIPs (e.g., NMC)
        capture confirm file `"`tgt'"'
        if (_rc) {
            local oldpwd "`c(pwd)'"
            quietly cd "`unzipto'"
            local zips : dir "." files "*.zip"
            foreach z of local zips {
                di as txt "→ Unzipping inner archive: `z'"
                cap noisily unzipfile "`z'", replace
            }
            quietly cd "`oldpwd'"
        }
    }
    else {
        di as txt "→ Saving to: `tgt'"
        cap noisily copy "`tmpfile'" "`tgt'", replace
        if (_rc) {
            di as error "× Could not place file at: `tgt'"
            exit _rc
        }
    }

	erase `tmpfile'
    di as res "✓ Done (or already present)"
end

/* ---------- One-time normalization for existing downloads ---------- */

/* 1) Contiguity: flatten extra nesting if present */
local cont_base "$DIR_DATA_RAW/cow/contiguity/DirectContiguity320"
capture confirm file "`cont_base'/contdird.csv"
if (_rc) {
    local nested "`cont_base'/DirectContiguity320"
    capture confirm file "`nested'/contdird.csv"
    if (_rc==0) {
        foreach f in contdir.csv contdir.dta contdird.csv contdird.dta contdirs.csv contdirs.dta "Direct Contiguity Codebook.pdf" {
            capture confirm file "`nested'/`f'"
            if (_rc==0) {
                cap copy "`nested'/`f'" "`cont_base'/`f'", replace
            }
        }
    }
}

/* 2) NMC: expand inner ZIPs so supplementary .dta is available */
local nmc "$DIR_DATA_RAW/cow/NMC-60-wsupplementary"
capture confirm file "`nmc'/NMC-60-wsupplementary.dta"
if (_rc) {
    local oldpwd "`c(pwd)'"
    quietly cd "`nmc'"
    local zips : dir "." files "*.zip"
    foreach z of local zips {
        di as txt "→ Unzipping inner archive: `z'"
        cap noisily unzipfile "`z'", replace
    }
    quietly cd "`oldpwd'"
}

/* ---------- The six fetch calls (idempotent: skip if present) ---------- */

// (1) CoW Contiguity (zip -> contdird.csv expected)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/DirectContiguity320.zip") ///
    target("$DIR_DATA_RAW/cow/contiguity/DirectContiguity320/contdird.csv")       ///
    unzipto("$DIR_DATA_RAW/cow/contiguity/DirectContiguity320") zip("DirectContiguity320.zip")

// (2) CoW Extra-state war (csv)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/Extra-StateWarData_v4.0.csv") ///
    target("$DIR_DATA_RAW/cow/Extra-StateWarData_v4.0.csv")

// (3) CoW Intra-state wars v5.1 (zip -> .dta expected)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/Intra-State-Wars-v5.1.zip") ///
    target("$DIR_DATA_RAW/cow/Intra-State-Wars-v5.1/INTRA-STATE WARS v5.1.dta")     ///
    unzipto("$DIR_DATA_RAW/cow/Intra-State-Wars-v5.1") zip("Intra-State-Wars-v5.1.zip")

// (4) CoW Inter-state wars (csv)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/Inter-StateWarData_v4.0.csv") ///
    target("$DIR_DATA_RAW/cow/wars/Inter-StateWarData_v4.0.csv")

// (5) CoW NMC 6.0 supplementary (zip with inner zips -> .dta expected)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/NMC_Documentation-6.0.zip") ///
    target("$DIR_DATA_RAW/cow/NMC-60-wsupplementary/NMC-60-wsupplementary.dta")     ///
    unzipto("$DIR_DATA_RAW/cow/NMC-60-wsupplementary") zip("NMC_Documentation-6.0.zip")

// (6) CoW Territory changes v6 (zip -> tc2018.csv expected)
_dl_if_missing,                                                        ///
    url("https://correlatesofwar.org/wp-content/uploads/terr-changes-v6.zip") ///
    target("$DIR_DATA_RAW/cow/terr-changes-v6/tc2018.csv")            ///
    unzipto("$DIR_DATA_RAW/cow/terr-changes-v6") zip("terr-changes-v6.zip")

/* ---------- Final sanity printouts ---------- */
confirm file "$DIR_DATA_RAW/cow/contiguity/DirectContiguity320/contdird.csv"
confirm file "$DIR_DATA_RAW/cow/Extra-StateWarData_v4.0.csv"
confirm file "$DIR_DATA_RAW/cow/Intra-State-Wars-v5.1/INTRA-STATE WARS v5.1.dta"
confirm file "$DIR_DATA_RAW/cow/wars/Inter-StateWarData_v4.0.csv"
confirm file "$DIR_DATA_RAW/cow/NMC-60-wsupplementary/NMC-60-wsupplementary.dta"
confirm file "$DIR_DATA_RAW/cow/terr-changes-v6/tc2018.csv"
