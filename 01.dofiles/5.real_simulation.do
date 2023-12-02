global main 	"C:\Users\Paul Corral\OneDrive\SAE Guidelines 2021\"
global section  "$main\3_Unit_level\"
global dofile   "$section\2_dofiles\"

texdoc init "$dofile\Simulation.tex", replace

texdoc stlog, cmdlog
clear all 
set more off

/*===============================================================================
Do-file prepared for SAE Guidelines
- Real world data application
- authors Paul Corral & Minh Nguyen
*==============================================================================*/

global main     "C:\Users\\`c(username)'\OneDrive\SAE Guidelines 2021\"
global section  "$main\3_Unit_level\"
global mdata    "$section\1_data\"
global survey "$mdata\survey_public.dta"
global census "$mdata\census_public.dta"

version 15
local seed 648743

*===============================================================================
// End of preamble
*===============================================================================
use "$mdata\mysvy.dta", clear
	char list
	
	global hhmodel : char _dta[rhs]
	global alpha   : char _dta[alpha]
	global sel     : char _dta[sel]

//Add lnhhsize
use "$census"
gen lnhhsize = ln(hhsize)

tempfile census1
save `census1'

// Create data ready for SAE - optimized dataset
sae data import, datain(`census1') varlist($hhmodel $alpha hhsize) ///
area(HID_mun) uniqid(hhid) dataout("$mdata\census_mata")

*===============================================================================
// Simulation -> Obtain point estimates
*===============================================================================	
use "$mdata\mysvy.dta", clear
	drop if e_y<1
	drop if $sel==1
	rename MUN HID_mun
sae sim h3 e_y $hhmodel, area(HID_mun) zvar($alpha) mcrep(100) bsrep(0) ///
lnskew matin("$mdata\census_mata") seed(`seed') pwcensus(hhsize) ///
indicators(fgt0 fgt1 fgt2) aggids(0 4) uniqid(hhid) plines(715)


*===============================================================================
// Simulation -> Obtain MSE estimates
*===============================================================================	

use "$mdata\mysvy.dta", clear
	drop if e_y<1
	drop if $sel==1
	rename MUN HID_mun
sae sim h3 e_y $hhmodel, area(HID_mun) zvar($alpha) mcrep(100) bsrep(200) ///
lnskew matin("$mdata\census_mata") seed(`seed') pwcensus(hhsize) ///
indicators(fgt0 fgt1 fgt2) aggids(0 4) uniqid(hhid) plines(715)


save "$mdata\mySAE.dta", replace 

texdoc stlog close
