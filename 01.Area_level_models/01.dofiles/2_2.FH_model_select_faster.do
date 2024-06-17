set more off
clear all

version 15
set matsize 8000
set seed 648743

*===============================================================================
//Specify team paths (this is for the WB SummerU_2024 branch)
*===============================================================================
global main       	"C:\Users\\`c(username)'\GitHub\wb_sae_training"
global data       	"$main\00.Data"


mata
	//Mata function for selection
	function mysel2(_bb, _se, _pval){
		thevars = tokens(st_local("_myhhvars"))
		zvals   = (_bb':/_se)[1..(rows(_se)-1)]
		zvals   = 2:*normal(-abs(zvals))
		if (colmax(zvals)>_pval){
			keepvar = thevars[selectindex(colmax(zvals):>zvals)]
			return(keepvar)	
		}	
		else{
			keepvar = "it's done"
			return(keepvar)
		}
	}

end


use "$data\input\FHcensus_district.dta", clear


local vars male head_age age depratio head_ghanaian ghanaian head_ethnicity1 head_ethnicity2 head_ethnicity3 head_ethnicity4 head_ethnicity5 head_ethnicity6 head_ethnicity7 head_ethnicity8 head_ethnicity9 head_birthplace1 head_birthplace2 head_birthplace3 head_birthplace4 head_birthplace5 head_birthplace6 head_birthplace7 head_birthplace8 head_birthplace9 head_birthplace10 head_birthplace11 head_religion1 head_religion2 head_religion3 head_religion4 christian  married noschooling head_schlvl1 head_schlvl2  head_schlvl4 head_schlvl5 employed head_empstatus1 head_empstatus2 head_empstatus3 head_empstatus4 head_empstatus5 head_empstatus6 head_empstatus8 head_empstatus9 employee internetuse fixedphone pc aghouse conventional  wall2 wall3  floor2 floor3 roof1 roof2 roof3  tenure1  tenure3 rooms bedrooms lighting2 lighting3 lighting4 water_drinking1  water_drinking3 water_drinking4  water_general2 water_general3 fuel1 fuel2 fuel3  toilet1  toilet3 toilet4 toilet5 solidwaste1 solidwaste2 solidwaste3 thereg1 thereg2 thereg3 thereg4 thereg5 thereg6 thereg7 thereg8 thereg9  workpop_primary

egen workpop_primary = rsum(workpop_schlvl_4 workpop_schlvl_5)

//Normalize
foreach x of local vars{
	cap sum `x'
	cap replace `x' = (`x' - r(mean))/r(sd)
}



gen D = region*100
replace D = D+district

drop district 
rename D district

merge 1:1 district using "$data\direct_glss7.dta"
tab region, gen(thereg)
unab hhvars: `vars'


*===============================================================================
//Create smoothed variance function
*===============================================================================
gen log_s2 = log(dir_fgt0_var)
gen logN = log(N)
gen logN2 = logN^2
gen logpop  = log(pop)
gen logpop2 = logpop^2
gen accra = region==3
//reg log_s2 logpop logpop2 i.accra#c.logN, r
//reg log_s2 logpop logpop2 i.accra##c.logN, r
gen share = log(N_hhsize/pop)
reg log_s2 share, r
local phi2 = e(rmse)^2
cap drop xb_fh
predict xb_fh, xb
predict residual,res
sum xb_fh if res!=.,d
gen exp_xb_fh = exp(xb_fh)
sum dir_fgt0_var
local sumvar = r(sum)
sum exp_xb_fh
local sump = r(sum)

//Below comes from: https://presidencia.gva.es/documents/166658342/168130165/Ejemplar+45-01.pdf/fb04aeb3-9ea6-441f-a15c-bc65e857d689?t=1557824876209#page=107
gen smoothed_var = exp_xb_fh*(`sumvar'/`sump') 

//Modified to only replace for the locations with 0 variance
replace dir_fgt0_var = smoothed_var if ((num_ea>1 & !missing(num_ea)) | (num_ea==1 & zero!=0 & zero!=1)) & missing(dir_fgt0_var)
replace dir_fgt0 = zero if !missing(dir_fgt0_var)

fhsae dir_fgt0 `hhvars', revar(dir_fgt0_var) method(fh)


//Removal of non-significant variables
	//Removal of non-significant variables
	local hhvars : list clean hhvars
	dis as error "Sim : `sim' first removal"
	//Removal of non-significant variables
	forval z= 0.8(-0.05)0.01{
		local regreso 
		while ("`regreso'"!="it's done"){
			fhsae dir_fgt0 `hhvars', revar(dir_fgt0_var) method(fh) 
			mata: bb=st_matrix("e(b)")
			mata: se=sqrt(diagonal(st_matrix("e(V)")))
			local _myhhvars : colnames(e(b))
			mata: st_local("regreso", invtokens(mysel2(bb, se, `z')))	
			if ("`regreso'"!="it's done") local hhvars `regreso'
		}		
	}
	
	//Global with non-significant variables removed
	global postsign `hhvars'
	
	//Final model without non-significant variables no funciona
	fhsae dir_fgt0 ${postsign}, revar(dir_fgt0_var) method(fh)
	
	//Check VIF
	reg dir_fgt0 $postsign, r
	gen touse = e(sample)
	gen weight = 1
	mata: ds = _f_stepvif("$postsign","weight",5,"touse") 
	
	//ver abajo
	global postvif `vifvar'
	
	local hhvars $postvif
	
	//One final removal of non-significant covariates
dis as error "Sim : `sim' final removal"
	//One final removal of non-significant covariates
	forval z= 0.8(-0.05)0.0001{
		local regreso 
		while ("`regreso'"!="it's done"){
			fhsae dir_fgt0 `hhvars', revar(dir_fgt0_var) method(reml) precision(1e-10)
			mata: bb=st_matrix("e(b)")
			mata: se=sqrt(diagonal(st_matrix("e(V)")))
			local _myhhvars : colnames(e(b))
			mata: st_local("regreso", invtokens(mysel2(bb, se, `z')))	
			if ("`regreso'"!="it's done") local hhvars `regreso'
		}	
	}	
	
	
	global last `hhvars'
	
	fhsae dir_fgt0 `hhvars', revar(dir_fgt0_var) method(reml) precision(1e-10)
	local remove head_religion3
	local hhvars: list hhvars - remove
	global last `hhvars'
	
	fhsae dir_fgt0 workpop_primary $last, revar(dir_fgt0_var) method(chandra)
	fhsae dir_fgt0 workpop_primary $last, revar(dir_fgt0_var) method(fh)
	fhsae dir_fgt0 workpop_primary $last, revar(dir_fgt0_var) method(reml)
//*********************************************************************************************//

	//Obtain SAE-FH-estimates	
	fhsae dir_fgt0 workpop_primary $last, revar(dir_fgt0_var) method(reml) fh(fh_fgt0) ///
	fhse(fh_fgt0_se) fhcv(fh_fgt0_cv) gamma(fh_fgt0_gamma) out noneg precision(1e-13)

	//Check normal errors
	predict xb
	gen u_d = fh_fgt0 - xb
		lab var u_d "FH area effects"
	
	histogram u_d, normal graphregion(color(white))
	//graph export "$figs\Fig1_left.png", as(png) replace
	qnorm u_d, graphregion(color(white))
	
	gen e_d = dir_fgt0 - fh_fgt0
		lab var e_d "FH errors"
	
	histogram e_d, normal graphregion(color(white))
	///graph export "$figs\SAE Ghana 2017\3. Graphics\Fig1_right.png", as(png) replace
	qnorm e_d, graphregion(color(white))

keep region district fh_fgt0 fh_fgt0_se
save "$data\FH_sae_poverty.dta", replace