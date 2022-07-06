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
set seed 648743

*===============================================================================
//1. Let's create a population. Just like we did before in dofiles 1 and 2
*===============================================================================
local numpop    = 100 //Normally, we do this with 10K populations

local obsnum    = 20000  //Number of observations in our "census"
local areasize  = 250    //Number of observations by area
local outsample = 20	 //Sample size from each area (%)

local sigmaeta = 0.15     //Sigma eta
local sigmaeps = 0.5      //Sigma eps


// Create area random effects
set obs `=`obsnum'/`areasize''

	gen area = _n	// label areas 1 to C
	forval np = 1/`numpop'{
		qui:gen Y_`np' = rnormal(0,`sigmaeta')
	}

expand `areasize' //leaves us with 250 observations per area

	sort area //To ensure everything is ordered - this matters for replicability
	
	//Household identifier
	gen hhid = _n
	
	//Covariates, note that some are corrlated to the area's label
	gen x1=runiform()<=(0.3+.5*area/80)
	gen x2=runiform()<=(0.2)
	gen x3= runiform()<=(0.1 + .2*area/80)
	gen x4= runiform()<=(0.5+0.3*area/80)
	gen x5= round(max(1,rpoisson(3)*(1-.1*area/80)),1)
	gen x6= runiform()<=0.4
	
	bysort area: gen first = _n==1	
	
	//Welfare vector, minus the error term
	forval np = 1/`numpop'{
		qui:replace Y_`np' = 3+ .09*x1-.04*x2 - 0.09*x3 + 0.4*x4 - 0.25*x5 + 0.1*x6 + Y_`np' + rnormal(0, `sigmaeps')
	}
	
	mixed Y_23  x1 x2 x3 x4 x5 x6 || area:, reml
	local uvar =  (exp([lns1_1_1]_cons))^2 //Macro containing estimated random effect variance
	local evar =  (exp([lnsig_e]_cons))^2  //Macro containing estimated household residual variance
	
	//Notice how these values should match the ones we specified above for 
	// sigmaeta and sigmaeps respectively
	dis sqrt(`uvar')
	dis sqrt(`evar')

tempfile dpopulation
save `dpopulation' //note that we haven't added errors here...those are random 
// consequently will be added for each population...

*-------------------------------------------------------------------------------
// Pull the survey sample. Note that the sample is kept fixed throughout
// the process. 
// Notice that the assumption here is that the household survey is a direct 
// sub-sample of the Census. This is the assumption used under EB for the 
// estimation of MSEs. For Census EB, we assume that the survey and
*-------------------------------------------------------------------------------
	
sample 20, by(area)
tempfile dsample
save `dsample'

*===============================================================================








