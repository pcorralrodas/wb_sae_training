clear all 
set more off

/*===============================================================================
 Do-file 01 - testing assumptions...Developed for SAE training WB
 author Paul Corral
*=============================================================================*/
version 14
set seed 648743

*===============================================================================
// Let's create our population with a DGP that follows the model's assumptions
*===============================================================================

local obsnum    = 20000  //Number of observations in our "census"
local areasize  = 250    //Number of observations by area
local outsample = 20	 //Sample size from each area (%)

local sigmaeta = 0.15     //Sigma eta
local sigmaeps = 0.5      //Sigma eps


// Create area random effects
set obs `=`obsnum'/`areasize''

	gen area = _n	// label areas 1 to C
	gen eta  = rnormal(0,`sigmaeta')  //Generate random location effects

expand `areasize' //leaves us with 250 observations per area

	sort area //To ensure everything is ordered - this matters for replicability
	
	//Household identifier
	gen hhid = _n

	//Household specific residual	
	gen e = rnormal(0,`sigmaeps')
	
	//Covariates, note that some are corrlated to the area's label
	gen x1=	runiform()<=(0.3+.5*area/80)
	gen x2=	runiform()<=(0.2)
	gen x3= runiform()<=(0.1 + .2*area/80)
	gen x4= runiform()<=(0.5+0.3*area/80)
	gen x5= round(max(1,rpoisson(3)*(1-.1*area/80)),1)
	gen x6= runiform()<=0.4
	
	//Welfare vector
	gen Y_B = 3+ .09* x1-.04* x2 - 0.09*x3 + 0.4*x4 - 0.25*x5 + 0.1*x6 + eta + e
	
	//un-logged welfare
	gen e_y = exp(Y_B)	
	sum e_y [aw=x5], d
	
	local pline_25 = r(p25)
	local pline_50 = r(p50)
	local pline_75 = r(p75)
	
	//Hh size
	gen hhsize = x5
	
tempfile census
save `census'
*===============================================================================	
//Take a 20% SRS by area
*===============================================================================
sort hhid
sample 20, by(area)

tempfile survey
save `survey'

*===============================================================================
// Import census
*===============================================================================
tempfile matacensus
sae data import, datain(`census') varlist(x1 x2 x3 x4 x5 x6 hhsize) uniqid(hhid) ///
area(area) dataout(`matacensus')

*===============================================================================
// Do simulations
*===============================================================================
use `survey', clear

sae sim h3 e_y x1-x6 [aw=x5], area(area) uniqid(hhid) mcrep(100) bsrep(10) ///
matin(`matacensus') indicators(fgt0 fgt1 fgt2 gini) aggids(0) ///
pwcensus(hhsize) plines(`pline_25' `pline_50' `pline_75') ///
seed(26092024) lnskew_w


