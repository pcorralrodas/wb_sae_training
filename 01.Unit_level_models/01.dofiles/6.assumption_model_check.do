
clear all 
set more off

/*===============================================================================
Do-file prepared for SAE Guidelines
- Real world data application
- authors Paul Corral & Minh Nguyen
*==============================================================================*/

global main     "C:\Users\\`c(username)'\OneDrive\SAE Guidelines 2021\"
global mdata    "$main\Data to share\Public data\"
global survey   "$mdata\survey_public.dta"
global census   "C:\Users\WB378870\GitHub\Poverty-Mapping\Data\census_trim.dta"

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
	
	//Log shift transformation to approximate normality
	cap drop bcy
	lnskew0w double bcy = exp(lny) if $sel==0, weight(popw)
	
	pctile myP = bcy [aw=popw], nq(50)
	levelsof myP, local(myL)
	
	local a=2
	foreach x of local myL{
		gen p_`a' = `x'
		local a = `a'+2
	}
	
	rename MUN HID_mun
	
	preserve 
		gen MyS = int(HID/1e7)
		sp_groupfunction [aw=popw], poverty(bcy) povertyline(p_*) by(MyS)
		
		gen double popsh = real(subinstr(reference, "p_","",.))
		replace popsh = popsh/50
		
		rename value true
		
		rename MyS Unit
		tempfile state
		save `state'
	restore
	
tempfile mysvy
save `mysvy'

// Create data ready for SAE - optimized dataset
sae data import, datain(`mysvy') varlist($hhmodel $alpha popw) ///
area(HID_mun) uniqid(hhid) dataout("$mdata\census_mata")

*===============================================================================
// Simulation -> Obtain point estimates
*===============================================================================	
use "$mdata\mysvy.dta", clear
	drop if e_y<1
	drop if $sel==1
	rename MUN HID_mun
	cap drop bcy
	gen popw = Whh*hhsize
	lnskew0w double bcy = exp(lny) if $sel==0, weight(popw)
sae sim h3 bcy $hhmodel [aw=popw], area(HID_mun) zvar($alpha) mcrep(100) bsrep(0) ///
matin("$mdata\census_mata") seed(`seed') pwcensus(popw) ///
indicators(fgt0 fgt1 fgt2) aggids(0 4 7) uniqid(hhid) plines(`myL')

/*
drop if Unit < 1000
sp_groupfunction, mean(avg_fgt0*) by(Unit)
merge m:1 Unit using `mystate', clear

*/
keep if Unit==0
sp_groupfunction, mean(avg_fgt0*) by(Unit)
sort value
gen popsh = _n/50

twoway (scatter popsh value) (line popsh popsh)




