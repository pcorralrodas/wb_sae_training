clear all 
set more off

/*==============================================================================
 Do-file 02 - testing assumptions...EB and ELL
 Developed for SAE training WB
 author Paul Corral
 
 * In the codes below I refer to Census EB estimates as EB
 * Everything in the code below referred to as EB are Census EB
 * CensusEB and EB differ in how estimates are calculated. Under EB, estimates
 * are a weighted average of CensusEB estimates and the sample's estimates. The
 * weight attached to the sample corresponds to the sample size by area. 
*=============================================================================*/
version 14
set seed 648743
set maxvar 10500

*===============================================================================
// Let's create our population with a DGP that follows the model's assumptions
*===============================================================================

local obsnum    = 20000  //Number of observations in our "census"
local areasize  = 250    //Number of observations by area
local outsample = 20	 //Sample size from each area (%)

local sigmaeta = 0.15     //Sigma eta
local sigmaeps = 0.5     //Sigma eps


// Create area random effects
set obs `=`obsnum'/`areasize''

	gen area = _n	// label areas 1 to C
	gen eta  = rnormal(0,`sigmaeta')  //Generate random location effects

//The code in this section is to illustrate how the assumptions on the 
//errors work out
	//See random value
	forval z=1(1)1000{
		gen eta_`z' = rnormal(0,`sigmaeta')
	}
	
	//Notice how under each simulated value for eta - the model assumptions are
	//approximated: mean = 0, sigma = 0.15. We see this here for the first 5 
	//simulated etas
	tabstat eta_1-eta_5, stat(mean sd) 
	
	//If we get the average across all 1000 simulated vectors, then for each area
	// the mean and sigma are approximated (so mean=0 and sd=0.15)
	egen themean = rmean(eta*) //get the mean
	egen rsd     = rsd(eta*) //get the sigma
	//notice how in each area across the 1000 simulated vectors the assumptions 
	//are met. This is what the ELL method does. However, for a given realized
	//population the random location effect for an area is certainly not 
	//equal to 0
	list themean rsd eta_1 in 1/10
	
	drop eta_1 - eta_1000 //drop the simulated etas to see the effect on 1 population

expand `areasize' //leaves us with 250 observations per area

	sort area //To ensure everything is ordered - this matters for replicability
	
	//Household identifier
	gen hhid = _n

	//Household specific residual	
	gen e = rnormal(0,`sigmaeps')
	
	//Covariates, some are corrlated to the area's label
	gen x1= runiform()<=(0.3+.5*area/80)
	gen x2= runiform()<=(0.2) 
	gen x3= runiform()<=(0.1 + .2*area/80)
	gen x4= runiform()<=(0.5+0.3*area/80)
	gen x5= round(max(1,rpoisson(3)*(1-.1*area/80)),1)
	gen x6= runiform()<=0.4
	
	//Welfare vector
	gen Y_B = 3+ .09*x1-.04*x2 - 0.09*x3 + 0.4*x4 - 0.25*x5 + 0.1*x6 + eta + e

	//un-logged welfare
	gen e_y = exp(Y_B)	
	sum e_y, d
	
	//Get poverty rates at 25th percentile
	global pline = r(p25)
	global lnpline = ln(${pline})
	gen poor = e_y<$pline
	global p50line = r(p50)
	
	//Merge in the true poverty rate, and welfare means by area
	groupfunction, mean(poor Y_B e_y) merge by(area)

tempfile census
save `census'
*===============================================================================	
//Take a 20% SRS by area, and fit the model
*===============================================================================
sort hhid
sample 20, by(area)

//Fit the model
mixed Y_B x1 x2 x3 x4 x5 x6 ||area: , reml

	local uvar =  (exp([lns1_1_1]_cons))^2 //Macro containing estimated random effect variance
	local evar =  (exp([lnsig_e]_cons))^2  //Macro containing estimated household residual variance
	
	//Notice how these values should match the ones we specified above for 
	// sigmaeta and sigmaeps respectively
	dis sqrt(`uvar')
	dis sqrt(`evar')


// Obtain linear fit
predict xb, xb

//Obtain linear fit with location effects
predict xb_eta, fitted

//Obtain only the location effects (eta_c)
predict eta_c, reffect

//Obtain residuals...(e_ch = (Y-(xb+eta)))
predict e_ch, res

sum xb xb_eta //Notice how both predict the same population mean for Y_B. 
// However notice the considerable difference between the SDs.

preserve

//Let's see how it looks at the area level
groupfunction, mean(xb xb_eta Y_B) by(area)
//Notice how much closer the XB_eta is to the area's Y_B

list in 1/20
//EB is optimal in the sense that it minimizes the MSE under the assumed model

restore

*-------------------------------------------------------------------------------
//Why do we need to add the household specific residuals? 
// Remember, poverty is a non-linear parameter.
// Without errors and just the linear fit you fail to replicate the 
// welfare distribution, and your estimates will be considerably off. 
*-------------------------------------------------------------------------------
//Create percentiles for easier figures
pctile xb_ptile = xb, nq(100)
lab var xb_ptile "Linear fit"
pctile xb_eta_ptile = xb_eta, nq(100)
lab var xb_eta_ptile "Linear fit plus location effect"
gen sh_pop = _n/100 if xb_ptile!=.
pctile Y_B_ptile = Y_B, nq(100)
lab var Y_B_ptile "Welfare (nat. log)"


//When the threshold falls on the 25th percentile, you miss the mark 
twoway (line xb_ptile sh_pop) (line xb_eta_ptile sh_pop ) (line Y_B_ptile sh_pop ), yline(${lnpline}) xtitle(Cumulative share of population) ytitle(Welfare value (nat. log))
//When the threshold falls on the 50th percentile, you don't miss
twoway (line xb_ptile sh_pop) (line xb_eta_ptile sh_pop ) (line Y_B_ptile sh_pop ), yline(`=ln(${p50line})') xtitle(Cumulative share of population) ytitle(Welfare value (nat. log))

*-------------------------------------------------------------------------------
//Let's calculate etas and variance of etas using the formulas
//Formulas are different when using sampling weights; not included here for
//simplicity.
*-------------------------------------------------------------------------------

egen numobs_area = sum(!missing(Y_B)), by(area) //number of observations in area
egen double y_minusxb = mean(Y_B-xb), by(area)         // Y_B - xb
gen double gamma  = `uvar'/(`uvar'+`evar'/numobs_area) //Gamma or adjustment factor
gen double my_eta = gamma*y_minusxb                    //eta

//variance of random location effects
gen double var_eta = `uvar'*(1-gamma) //note how the variance under EB in 
//sampled areas is always smaller than without EB since (1-gamma)<=1. For 
//non-sampled areas gamma=0.

groupfunction, mean( var_eta my_eta) by(area) //collapse data to area level

tempfile etas
save `etas'

*===============================================================================
//...final check, move to the census
// Let's see how EB and ELL differ for headcount poverty and welfare
*===============================================================================
use `census', clear

predict double xb, xb //Obtain the linear fit in the census
	//Include random effects and their variance
	merge m:1 area using `etas', keepusing(var_eta my_eta)
		drop if _m==2
		drop _m
		
sort hhid //to ensure replicability

//Let's use the analytical formula to get EB and ELL poverty estimates
// Analytical formula can be used in lieu of MC
//Let's do ELL, remember it doesn't condition on the survey sample, so
//we don't add the predicted random effects, but do consider the error structure
gen p_poor_ell = normal((${lnpline}-xb)/sqrt(`uvar'+`evar'))

//Let's do EB, this does include the predicted random effects...
// Notice how the variance used is different and would differ by area
gen p_poor_eb  = normal((${lnpline}-xb-my_eta)/sqrt(var_eta+`evar'))

*-------------------------------------------------------------------------------
// Usually under the SAE code we do it as a Monte Carlo  (MC) simulation since it is 
// easier to obtain indicators beyond headcount poverty
*-------------------------------------------------------------------------------
forval z=1/100{
	gen ell_w_`z' = exp(rnormal(xb,sqrt(`uvar'+`evar')))
		gen mc_poor_ell_`z' = ell_w_`z'<${pline}
	gen eb_w_`z'  = exp(rnormal(xb+my_eta,sqrt(var_eta+`evar')))
		gen mc_poor_eb_`z' = eb_w_`z'<${pline}
}

//get the MC prob of being poor by HH
egen mc_poor_eb  = rmean(mc_poor_eb_*)
egen mc_poor_ell = rmean(mc_poor_ell_*)
//Get the MC mean welfare
egen w_eb = rmean(eb_w_*)
egen w_ell = rmean(ell_w_*)

*-------------------------------------------------------------------------------
// When assuming log normality, for mean welfare we can use Duan's smearing 
// transformation to back out welfare
*-------------------------------------------------------------------------------
//Get the fitted value
gen fitted = xb+my_eta
//Produce transformed welfare from linear fit...with Duan's smearing transformation
gen t_welfare_lfit = exp(xb)*exp(.5*(`uvar'+`evar'))
gen t_welfare_fitted = exp(fitted)*exp(.5*(var_eta+`evar'))

*--> Compare mean values
sum e_y t_welfare_fitted w_eb //Fitted values including location effect align with MC EB
sum e_y t_welfare_lfit   w_ell //Linear fit, without location effect align to MC ELL
//Notice how the mean is aligned across all 5 measures.


*--> How well does our model work for poverty at the national level?
sum poor p_poor_eb   mc_poor_eb
sum poor p_poor_ell  mc_poor_ell
// At the national level ELL and EB poverty are quite similar 
// and aligned to the true poverty rate. 

*-------------------------------------------------------------------------------
//Let's see how aligned are estimates by area, which is what we actually care about...
*-------------------------------------------------------------------------------
groupfunction, mean(poor p_poor_eb mc_poor_eb p_poor_ell mc_poor_ell Y_B e_y w_eb w_ell xb fitted t_welfare_lfit t_welfare_fitted) by(area)

//Check untransformed welfare...
//1. Note how ELL estimates of transformed welfare are rather flat. Recall how 
// t_welfare_lfit was calculated. This is what is meant when it is stated that
// ELL is a synthetic estimator. 
list e_y t_welfare_lfit w_ell in 1/10 
//2. Note how CensusEB is much better aligned to the true welfare value
list e_y t_welfare_fitted w_eb in 1/10


//Label variables for figure below
lab var poor       "True poverty rate"
lab var p_poor_ell "ELL poverty estimates"
lab var p_poor_eb  "CensusEB poverty estimates"

//Check poverty
list poor p_poor_eb mc_poor_eb p_poor_ell mc_poor_ell in 1/10 // see how the EB 
///estimates are better aligned to the truth

//rank areas by true poverty rates
sort poor
gen ranking = _n

// Note how ELL hovers around the mean national rate...
// Since it doesn't incorporate the random location effect, the value won't track
// the true poverty rate well
twoway (scatter poor ranking, ms(t)) (scatter p_poor_ell ranking, ms(dh) ) ///
(scatter p_poor_eb ranking, ms(x)) 

//Just something quick to see the relationship between the ranking and estimates
twoway (scatter poor ranking, ms(t))  (lfit p_poor_ell ranking) ///
(lfit p_poor_eb ranking, lpattern(dash))
// This is why considerable emphasis is placed in the ELL method to add 
// area level covariates AND to minimize the share of error attributed to 
// the locations. These area level covariates should always be included, 
// regardless of the method used, since they improve out of sample estimates.
















	
	
