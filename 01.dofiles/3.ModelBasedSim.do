clear all 
set more off

/*==============================================================================
 Do-file 03 - ModelBasedSim
 Developed for SAE training WB
 author Paul Corral
 
 * This code implements a model based simulation to illustrate how methods
 * are validated.
 * Note how, under every simulation, the population's random components are re-
 * drawn. 
 * This will be the first instance using the sae codes to run the MC
*=============================================================================*/
version 14
set seed 588919

*===============================================================================
//1. Let's create a population. Just like we did before in dofiles 1 and 2
*===============================================================================
local numpop    = 10 //Number of populations to generate 
//Normally, we do this with 10K populations

local obsnum    = 20000  //Number of observations in our "census"
local areasize  = 250    //Number of observations by area
local outsample = 20	 //Sample size from each area (%)

local sigmaeta = 0.15     //Sigma eta
local sigmaeps = 0.5      //Sigma eps


// Create area random effects
set obs `=`obsnum'/`areasize''

	gen area = _n	// label areas 1 to C
	forval np = 1/`numpop'{
		qui:gen eta_`np' = rnormal(0,`sigmaeta')
	}

expand `areasize' //leaves us with 250 observations per area

	sort area //To ensure everything is ordered - this matters for replicability
	
	//Household identifier
	gen hhid = _n
	
	//Covariates, note that some are corrlated to the area's label
	gen x1= runiform()<=(0.3+.5*area/80)
	gen x2= runiform()<=(0.2)
	gen x3= runiform()<=(0.1 + .2*area/80)
	gen x4= runiform()<=(0.5+0.3*area/80)
	gen x5= round(max(1,rpoisson(3)*(1-.1*area/80)),1)
	gen x6= runiform()<=0.4
	
	bysort area: gen first = _n==1	
	
	//Welfare vector, minus the error term
	forval np = 1/`numpop'{
		qui: gen e_`np'    = rnormal(0, `sigmaeps')   
	}
	
	// The linear fit
	gen XB = 3+ .09*x1-.04*x2 - 0.09*x3 + 0.4*x4 - 0.25*x5 + 0.1*x6 
	
	//Create a vector for checks
	gen Y = XB + eta_1 + e_1
	
	//Welfare vector is log-normal
	gen e_y = exp(Y)
	// Pull poverty lines at different thresholds
	sum e_y, d
	global pline10 = ceil(r(p10))
	global pline25 = ceil(r(p25))
	global pline50 = ceil(r(p50))
	global pline75 = ceil(r(p75))
		
	mixed Y x1 x2 x3 x4 x5 x6 || area:, reml
	local uvar =  (exp([lns1_1_1]_cons))^2 //Macro containing estimated random effect variance
	local evar =  (exp([lnsig_e]_cons))^2  //Macro containing estimated household residual variance
	
	//Notice how these values should be aligned to the ones we specified above for 
	// sigmaeta and sigmaeps respectively
	dis sqrt(`uvar')
	dis sqrt(`evar')
	
	//drop the created Y and e_y vector
	drop Y
	
	//Generate HH size - needed for the codes
	gen hhsize = 1

tempfile dpopulation
save `dpopulation' //note that we haven't added errors here...those are random 
// consequently will be added for each population...

/*-------------------------------------------------------------------------------
// Pull the survey sample. Note that the sample is kept fixed throughout
// the process. 

// Here we see the main differences between EB and CensusEB:

EB: Notice that the assumption here is that the household survey is a direct 
sub-sample of the Census. This is the assumption used under EB for the 
estimation of MSEs under the parametric bootstrap.

Census EB: We assume that the survey is not a direct sub-sample of the census. 
Consequently, household specific errors are drawn separately. However, the 
location effects are kept fixed.
*------------------------------------------------------------------------------*/
//Pull sample
sort hhid	
sample 20, by(area)

	//redraw household idiosyncratic errors for each population, we'll use these
	//for CensusEB estimates...
	forval np = 1/`numpop'{
		qui: gen ehh_`np'    = rnormal(0, `sigmaeps')   
	}

tempfile dsample
save `dsample'

*===============================================================================
// The Stata sae codes require the census to be imported in to a mata file. This
// is done to speed up the simulation process.
*===============================================================================
tempfile mfile
sae data import, datain("`dpopulation'") varlist( x1 x2 x3 x4 x5 x6 hhsize) ///
area(area) uniqid(hhid) dataout("`mfile'")

*===============================================================================
// Now we start the process of creating poverty estimates under different methods
*===============================================================================

*-------------------------------------------------------------------------------
//True population estimates
*-------------------------------------------------------------------------------
use `dpopulation', clear
	// Generate the 100 true welfare vectors...
	forval np=1/`numpop'{
		gen Y_`np' = XB + eta_`np' + e_`np'
		gen e_y_`np' = exp(Y_`np')
	}
	
	foreach z in 10 25 50 75{
		gen pline_`z' = ${pline`z'}
	}
	
sp_groupfunction [aw=hhsize], mean(e_y_*) poverty(e_y_*) povertyline(pline_*) by(area)

//The below is done to shape the data for comparison with "sae" outputs
gen name = measure + "_" +reference
split variable, parse(_)
replace variable3 = variable2 if missing(variable3)
rename variable3 simnum
drop  measure _population variable reference variable1 variable2
reshape wide value, i(area simnum) j(name) string
rename value* true_*

tempfile true
save `true'

*-------------------------------------------------------------------------------
//Direct estimates (EB assumption)
*-------------------------------------------------------------------------------
use `dsample', clear
	// Generate the 100 true welfare vectors...//note that the welfare vector of 
	// household i in the census and the sample will have the exact same welfare
	// notice that we use the same e_* vectors as in the census population
	forval np=1/`numpop'{
		gen Y_`np' = XB + eta_`np' + e_`np'
		gen e_y_`np' = exp(Y_`np')		
	}
	
	foreach z in 10 25 50 75{
		gen pline_`z' = ${pline`z'}
	}
	
sp_groupfunction [aw=hhsize], mean(e_y_*) poverty(Y_*) povertyline(pline_*) by(area)

//The below is done to shape the data for comparison with "sae" outputs
gen name = measure + "_" +reference
split variable, parse(_)
replace variable3 = variable2 if missing(variable3)
rename variable3 simnum
drop  measure _population variable reference variable1 variable2
replace name = subinstr(name,"pline_", "pline",.)
reshape wide value, i(area simnum) j(name) string
rename value* *

tempfile directEB
save `directEB'

*-------------------------------------------------------------------------------
//Direct estimates (Census EB assumption)
*-------------------------------------------------------------------------------
use `dsample', clear
	// Generate the 100 welfare vectors...//note that the welfare vector of 
	// household i in the census and the sample will not match since the errors
	// are drawn separately. Consequently we do not "match" household across 
	// survey and census. 
	forval np=1/`numpop'{
		gen Y_`np' = XB + eta_`np' + ehh_`np'
		gen e_y_`np' = exp(Y_`np')		
	}
	
	foreach z in 10 25 50 75{
		gen pline_`z' = ${pline`z'}
	}
	
sp_groupfunction [aw=hhsize], mean(e_y_*) poverty(Y_*) povertyline(pline_*) by(area)

//The below is done to shape the data for comparison with "sae" outputs
gen name = measure + "_" +reference
split variable, parse(_)
replace variable3 = variable2 if missing(variable3)
rename variable3 simnum
drop  measure _population variable reference variable1 variable2
replace name = subinstr(name,"pline_", "pline",.)
reshape wide value, i(area simnum) j(name) string
rename value* *

tempfile directCEB
save `directCEB'

*-------------------------------------------------------------------------------
//EB estimates
*-------------------------------------------------------------------------------
forval np=1/`numpop'{
	use `dsample', clear
	// Note that here we assume the survey sample is a subsample of the population
	gen Y_`np' = XB + eta_`np' + e_`np'
	//Now we fit the model. Remember that in practice we have Y and Xs, and 
	//need to estimate their relationship.
	// help sae_reml
	sae sim reml  Y_`np' x1 x2 x3 x4 x5 x6, appendsvy lny mcrep(50) bsrep(0) ///
	matin(`mfile') pwcensus(hhsize) plines($pline10 $pline25 $pline50 $pline75) ///
	aggids(0) ind(fgt0 fgt1 fgt2) uniqid(hhid) area(area) 
	
	//Now we structure the data according to our needs.
	foreach x in 10 25 50 75{
		local xp = subinstr("${pline`x'}",".","_",.)
		foreach y in fgt0 fgt1 fgt2{
			rename avg_`y'_`xp' `y'_pline`x'
		}
	}
	rename Mean mean_
	gen simnum = "`np'"
	rename Unit area
	cap append using `EB'
	tempfile EB
	save `EB'
}

*-------------------------------------------------------------------------------
//CensusEB estimates with H3 decomposition of the error terms
*-------------------------------------------------------------------------------
forval np=1/`numpop'{
	use `dsample', clear
	gen Y_`np' = XB + eta_`np' + ehh_`np'
	//Now we fit the model. Remember that in practice we have Y and Xs, and 
	//need to estimate their relationship.
	// Under H3 we could incorporate survey weights into the model fit and can
	// also consider hetersokedasticity in the household specific errors
	// help sae_mc_bs
	sae sim h3  Y_`np' x1 x2 x3 x4 x5 x6, lny mcrep(50) bsrep(0) ///
	matin(`mfile') pwcensus(hhsize) plines($pline10 $pline25 $pline50 $pline75) ///
	aggids(0) ind(fgt0 fgt1 fgt2) uniqid(hhid) area(area) 
	
	//Now we structure the data according to our needs.
	foreach x in 10 25 50 75{
		local xp = subinstr("${pline`x'}",".","_",.)
		foreach y in fgt0 fgt1 fgt2{
			rename avg_`y'_`xp' `y'_pline`x'
		}
	}
	rename Mean mean_
	gen simnum = "`np'"
	rename Unit area
	cap append using `h3CEB'
	tempfile h3CEB
	save `h3CEB'
}

*-------------------------------------------------------------------------------
//CensusEB estimates with reml fitting
*-------------------------------------------------------------------------------
forval np=1/`numpop'{
	use `dsample', clear
	gen Y_`np' = XB + eta_`np' + ehh_`np'
	//Now we fit the model. Remember that in practice we have Y and Xs, and 
	//need to estimate their relationship.
	//Notice that the sample is not appended here so we remove that option
	// help sae_reml
	sae sim reml  Y_`np' x1 x2 x3 x4 x5 x6, lny mcrep(50) bsrep(0) ///
	matin(`mfile') pwcensus(hhsize) plines($pline10 $pline25 $pline50 $pline75) ///
	aggids(0) ind(fgt0 fgt1 fgt2) uniqid(hhid) area(area)
	
	//Now we structure the data according to our needs.
	foreach x in 10 25 50 75{
		local xp = subinstr("${pline`x'}",".","_",.)
		foreach y in fgt0 fgt1 fgt2{
			rename avg_`y'_`xp' `y'_pline`x'
		}
	}
	rename Mean mean_
	gen simnum = "`np'"
	rename Unit area
	cap append using `CEB'
	tempfile CEB
	save `CEB'
}

*-------------------------------------------------------------------------------
//ELL estimates 
*-------------------------------------------------------------------------------
forval np=1/`numpop'{
	use `dsample', clear
	gen Y_`np' = XB + eta_`np' + ehh_`np'
	//Now we fit the model. Remember that in practice we have Y and Xs, and 
	//need to estimate their relationship.
	// Under ELL we increase the repetitions due to the MI algorithm that 
	// was originally used in PovMap
	// help sae_ell
	sae sim ell  Y_`np' x1 x2 x3 x4 x5 x6, lny rep(200) ///
	matin(`mfile') pwcensus(hhsize) plines($pline10 $pline25 $pline50 $pline75) ///
	aggids(0) ind(fgt0 fgt1 fgt2) uniqid(hhid) area(area) eta(normal) epsilon(normal)
	
	rename avg*, lower
	//Now we structure the data according to our needs.
	foreach x in 10 25 50 75{
		local xp = subinstr("${pline`x'}",".","",.)
		foreach y in fgt0 fgt1 fgt2{
			rename avg_`y'_`xp' `y'_pline`x'
		}
	}
	rename Mean mean_
	gen simnum = "`np'"
	rename Unit area
	cap append using `ELL'
	tempfile ELL
	save `ELL'
}


*===============================================================================
// Now we get measures of the empirical bias and MSE under the model of each
// method
*===============================================================================
//Start with the true estimates
use `true', clear

	foreach method in directCEB directEB EB CEB h3CEB ELL{
		merge 1:1 area simnum using ``method''
		drop if _m==2
		drop _m
		//Get bias and MSE for mean
		gen bias_`method'_mean = mean_ - true_mean
		gen mse_`method'_mean = (mean_ - true_mean)^2		
		drop mean_ //drop mean for next method
		foreach ind in fgt0 fgt1 fgt2{
			foreach x in 10 25 50 75{
				gen bias_`method'_`ind'_pline`x' = `ind'_pline`x' - true_`ind'_pline_`x' 
				gen mse_`method'_`ind'_pline`x'  = (`ind'_pline`x' - true_`ind'_pline_`x')^2
				drop `ind'_pline`x'
			}			
		}		
	}

//Now collapse by area to get the bias and MSE
groupfunction, mean(bias_* mse_*) by(area)

//Let's label the vectors...
foreach method in directCEB directEB EB CEB h3CEB ELL{
	lab var bias_`method'_mean "Bias `method'"
	lab var mse_`method'_mean  "MSE `method'" 
	foreach ind in fgt0 fgt1 fgt2{
		foreach x in 10 25 50 75{
			lab var  bias_`method'_`ind'_pline`x' "Bias `method' Z=p`x'"
			lab var  mse_`method'_`ind'_pline`x'  "MSE `method' Z=p`x'"
		}
	}			
}

*===============================================================================
// Let's plot some figures...
*===============================================================================
// Do the FGT0 MSE & Biases of the EB and CensusEB models differ? 
twoway (scatter bias_h3CEB_fgt0_pline25 area) (scatter bias_EB_fgt0_pline25 area, ms(dh)) (scatter bias_CEB_fgt0_pline25 area, ms(dh))
twoway (scatter mse_h3CEB_fgt0_pline25 area) (scatter mse_EB_fgt0_pline25 area, ms(dh)) (scatter mse_CEB_fgt0_pline25 area, ms(dh))

// How does ELL FGT0 estimates stack up against h3 census eb?
twoway (scatter bias_h3CEB_fgt0_pline25 area) (scatter bias_ELL_fgt0_pline25 area, ms(dh)) 
twoway (scatter mse_h3CEB_fgt0_pline25 area)  (scatter mse_ELL_fgt0_pline25 area, ms(dh)) 

// What about mean welfare?
twoway (scatter bias_h3CEB_mean area) (scatter bias_EB_mean area, ms(dh)) (scatter bias_ELL_mean area, ms(dh))
twoway (scatter mse_h3CEB_mean area) (scatter mse_EB_mean area, ms(dh)) (scatter mse_ELL_mean area, ms(dh))


