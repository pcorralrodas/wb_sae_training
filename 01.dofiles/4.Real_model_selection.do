global main 	"C:\Users\Paul Corral\OneDrive\SAE Guidelines 2021\"
global section  "$main\3_Unit_level\"
global dofile   "$section\2_dofiles\"

texdoc init "$dofile\Model_selection.tex", replace

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

//global with candidate variables.
global myvar rural  lnhhsize age_hh male_hh  piped_water no_piped_water ///
no_sewage sewage_pub sewage_priv electricity telephone cellphone internet ///
computer washmachine fridge television share_under15 share_elderly ///
share_adult max_tertiary max_secondary HID_* mun_* state_*


version 15
set seed 648743

*===============================================================================
// End of preamble
*===============================================================================
//load in survey data
use "$survey", clear
	//Remove small incomes affecting model
	drop if e_y<1
	//Log shift transformation to approximate normality
	lnskew0 double bcy = exp(lny)
	//removes skeweness from distribution
	sum lny, d 
	sum bcy, d
	
	//Data has already been cleaned and prepared. Data preparation and the creation
	// of eligible covariates is of extreme importance. 
	// In this instance, we skip these comparison steps because the sample is 
	// literally a subsample of the census.
	codebook HID //10 digits, every single one
	codebook HID_mun //7 digits every single one
	
	//We rename HID_mun
	rename HID_mun MUN
	//Drop automobile, it is missing
	drop *automobile* //all these are missing
	
	//Check to see if lassoregress is installed, if not install
	cap which lassoregress
	if (_rc) ssc install elasticregress
	
	//Model selection - with Lasso	
	gen lnhhsize = ln(hhsize)
	lassoregress bcy  $myvar [aw=Whh], lambda1se epsilon(1e-10) numfolds(10)
	local hhvars = e(varlist_nonzero)
	global postlasso  `hhvars'
	
	//Try Henderson III GLS
	sae model h3 bcy $postlasso [aw=Whh], area(MUN) 
	
	//Rename HID_mun
	rename MUN HID_mun
	
	//Loop designed to remove non-significant covariates sequentially
	forval z= 0.5(-0.05)0.05{
		qui:sae model h3 bcy `hhvars' [aw=Whh], area(HID_mun) 
		mata: bb=st_matrix("e(b_gls)")
		mata: se=sqrt(diagonal(st_matrix("e(V_gls)")))
		mata: zvals = bb':/se
		mata: st_matrix("min",min(abs(zvals)))
		local zv = (-min[1,1])
		if (2*normal(`zv')<`z') exit
	
		foreach x of varlist `hhvars'{
			local hhvars1
			qui: sae model h3 bcy `hhvars' [aw=Whh], area(HID_mun)
			qui: test `x' 
			if (r(p)>`z'){
				local hhvars1
				foreach yy of local hhvars{
					if ("`yy'"=="`x'") dis ""
					else local hhvars1 `hhvars1' `yy'
				}
			}
			else local hhvars1 `hhvars'
			local hhvars `hhvars1'		
		}
	}	
	
	global postsign `hhvars'
	
	//Henderson III GLS - model post removal of non-significant
	sae model h3 bcy $postsign [aw=Whh], area(HID_mun) 
	
	//Check for multicollinearity, and remove highly collinear (VIF>3)
	reg bcy $postsign [aw=Whh],r
	cap drop touse 	//remove vector if it is present to avoid error in next step
	gen touse = e(sample) 		//Indicates the observations used
	vif 						//Variance inflation factor
	local hhvars $postsign
	//Remove covariates with VIF greater than 3
	mata: ds = _f_stepvif("`hhvars'","Whh",3,"touse") 
	global postvif `vifvar'
	
	//VIF check
	reg bcy $postvif [aw=Whh], r
	vif
	
	//Henderson III GLS - model post removal of non-significant
	sae model h3 bcy $postvif [aw=Whh], area(HID_mun) 
	
*===============================================================================
// 2.5 Model checks
*===============================================================================

	reg bcy $postvif	
	predict cdist, cooksd
	predict rstud, rstudent
	
	reg bcy $postvif [aw=Whh]
	local KK = e(df_m)
	predict lev, leverage
	predict eps, resid
	predict bc_yhat, xb
	
	//Let's take a look at our residuals
	//Notice there is a downward sloping line,which seems to be the smallest eps for that xb
	scatter eps bc_yhat
	//so we can see what the figure looks like
	sleep 15000
	// so there's a bunch of small incomes that may be affecting our model!
	scatter eps bc_yhat if exp(lny)>1 	

/* https://stats.idre.ucla.edu/stata/dae/robust-regression/
Residual:  The difference between the predicted value (based on the regression ///
equation) and the actual, observed value.

Outlier:  In linear regression, an outlier is an observation with large ///
residual.  In other words, it is an observation whose dependent-variable ///
value is unusual given its value on the predictor variables.  An outlier may ///
indicate a sample peculiarity or may indicate a data entry error or ///
other problem.
	
Leverage:  An observation with an extreme value on a predictor variable is a ///
point with high leverage.  Leverage is a measure of how far an independent ///
variable deviates from its mean.  High leverage points can have a great ///
amount of effect on the estimate of regression coefficients.
	
Influence:  An observation is said to be influential if removing the ///
substantially changes the estimate of the regression coefficients.  ///
Influence can be thought of as the product of leverage and outlierness. 
	
Cook’s distance (or Cook’s D): A measure that combines the information of ///
leverage and residual of the observation
*/
	
/* Rules of thumb:
Cooks -> >4/N, also according to "Regression Diagnostics: An Expository ///
Treatment of Outliers and Influential Cases, values over 1...
	
Abs(rstu) -> >2 We should pay attention to studentized residuals that exceed ///
+2 or -2, and get even more concerned about residuals that exceed +2.5 or ///
-2.5 and even yet more concerned about residuals that exceed +3 or -3.  ///

leverage ->	>(2k+2)/n	
*/
	hist cdist, name(diag_cooksd, replace)
	hist lev, name(diag_leverage, replace)
	hist rstud, name(diag_rstudent, replace)
	twoway scatter cdist lev, name(diag_cooksd_lev, replace)
	
	lvr2plot, name(lvr2)
	rvfplot, name(rvf)
	
	sum cdist, d
	local max = r(max)
	local p99 = r(p99)		
	
	reg lny $postvif [aw=Whh]
	local myN=e(N)
	local myK=e(rank)
	
	//We have influential data points...
	reg lny $postvif if cdist<4/`myN' [aw=Whh]
	reg lny $postvif if cdist<`max'   [aw=Whh]
	reg lny $postvif if cdist<`p99'   [aw=Whh]
	gen nogo = abs(rstud)>2 & cdist>4/`myN' & lev>(2*`myK'+2)/`myN'
	

*===============================================================================
// Selecting the Alpha model
*===============================================================================	
	//Rename HID_mun
	cap rename HID_mun MUN
	//Henderson III GLS - add alfa model
	sae model h3 bcy $postvif if nogo==0 [aw=Whh], area(MUN) ///
	alfatest(residual) zvar(hhsize)
	
	des residual_alfa //The dependent variable for the alfa model
	
	// Macro holding all eligible vars
	unab allvars : $myvar
	//Macro with current variables
	local nogo $postvif
	
	//We want to only use variables not used
	foreach x of local allvars{
		local in = 0
		foreach y of local nogo{
			if ("`x'"=="`y'")	local in=1
		}
		if (`in'==0) local A `A' `x'
	}	
	
	global A `A' //macro holding eligible variables for alpha model
	
	lassoregress residual_alfa `A' if nogo==0 [aw=Whh]
	
	local alfa = e(varlist_nonzero)
	global alfa `alfa'
	
	reg residual_alfa $alfa if nogo==0 [aw=Whh],r
	gen tousealfa = e(sample)
	
	//Remove vif vars
	mata: ds = _f_stepvif("$alfa","Whh",5,"tousealfa")
	
	global alfa `vifvar'
	
	//Alfa vars before removal of non-significant vars
	global beforealfa `alfa'
	
	local hhvars $alfa
	
	forval z= 0.9(-0.1)0.1{
		foreach x of varlist `hhvars'{
			local hhvars1
			qui: reg residual_alfa `hhvars' [aw=Whh], r
			qui: test `x' 
			if (r(p)>`z'){
				local hhvars1
				foreach yy of local hhvars{
					if ("`yy'"=="`x'") dis ""
					else local hhvars1 `hhvars1' `yy'
				}
			}
			else local hhvars1 `hhvars'
			local hhvars `hhvars1'
		
		}
	}
	global alfavars `hhvars'
	
	//Henderson III Model with alpha model
	sae model h3 bcy $postvif if nogo==0 [aw=Whh], area(MUN) zvar($alfavars)
	
*===============================================================================
// GLS model, one final removal of non-significant variables
*===============================================================================
	//Loop designed to remove non-significant covariates sequentially
	local hhvars $postvif
	forval z= 0.5(-0.05)0.05{
		qui:sae model h3 bcy `hhvars' if nogo==0 [aw=Whh], area(MUN) ///
		zvar($alfavars)
		mata: bb=st_matrix("e(b_gls)")
		mata: se=sqrt(diagonal(st_matrix("e(V_gls)")))
		mata: zvals = bb':/se
		mata: st_matrix("min",min(abs(zvals)))
		local zv = (-min[1,1])
		if (2*normal(`zv')<`z') exit
	
		foreach x of varlist `hhvars'{
			local hhvars1
			qui:sae model h3 bcy `hhvars' if nogo==0 [aw=Whh], area(MUN) ///
			zvar($alfavars)
			qui: test `x' 
			if (r(p)>`z'){
				local hhvars1
				foreach yy of local hhvars{
					if ("`yy'"=="`x'") dis ""
					else local hhvars1 `hhvars1' `yy'
				}
			}
			else local hhvars1 `hhvars'
			local hhvars `hhvars1'		
		}
	}	
	
	global postalfa `hhvars'
	
*===============================================================================
// SAVE the data with the pertinent covariates and other info	
*===============================================================================
sae model h3 bcy $postalfa if nogo==0 [aw=Whh], area(MUN) zvar($alfavars)

char _dta[rhs]   $postalfa
char _dta[alpha] $alfavars
char _dta[sel]   nogo

save "$mdata\mysvy.dta", replace
texdoc stlog close
	