clear all 
set more off

/*===============================================================================
Do-file prepared for SAE Guidelines
- Real world data application
- authors Paul Corral & Minh Nguyen
*==============================================================================*/

global main     "C:\Users\\`c(username)'\OneDrive\SAE Guidelines 2021\"
global section  "$main\3_Unit_level\"
global mdata    "C:\Users\WB378870\OneDrive\SAE Guidelines 2021\Data to share\Public data"
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
	
	gen popw = Whh*hhsize
	rename MUN HID_mun
	
tempfile svy0
save `svy0'

// Create data ready for SAE - optimized dataset
sae data import, datain(`svy0') varlist($hhmodel $alpha popw e_y state) ///
area(HID_mun) uniqid(hhid) dataout("$mdata\svy_mata") 


*===============================================================================
// Simulation -> Obtain point estimates
*===============================================================================	
use "$mdata\mysvy.dta", clear
	drop if e_y<1
	drop if $sel==1
	rename MUN HID_mun
sae sim h3 e_y $hhmodel [aw=Whh], area(HID_mun) zvar($alpha) mcrep(100) bsrep(0) ///
lnskew_w matin("$mdata\svy_mata") seed(`seed') pwcensus(popw) ///
indicators(fgt0 fgt1 fgt2) aggids(0 4) uniqid(hhid) plines(715) addvars(e_y state) ydump("$mdata\predicted")

sae data export, matasource("$mdata\predicted")

sp_groupfunction [aw=_WEIGHT], poverty(_YH* e_y) povertyline(pline) gini(_YH* e_y) by(state)

