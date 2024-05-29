//do file to prepare SURVEY data for poverty mapping
*same as collapse
*ssc install groupfunction
**************************************
*This dofile prepares data from GLSS7 for
* small area estimation
*****************************************
clear all
set more off

version 14

*===============================================================================
//Specify team paths
*===============================================================================

global main       	"C:\Users\\`c(username)'\GitHub\wb_sae_training"
global data       	"$main\04.Data"
global figs      	"$main\05.Figures"


use "$data\input\survey_2017.dta",clear

	egen strata = group(region urban)
	svyset clust [pw=WTA_S_HHSIZE], strata(strata)
	gen fgt0 = (welfare < pl_abs) if !missing(welfare)
	
preserve
groupfunction [aw=WTA_S_HHSIZE], mean(fgt0) rawsum(WTA_S_HHSIZE) by(district clust)

groupfunction [aw=WTA_S_HHSIZE], mean(fgt0) count(clust) by(district)
restore

preserve
//The below are for comparison to final FH estimates
svy: proportion fgt0, over(region)
	mata: fgt0 = st_matrix("e(b)")
	mata: fgt0 = fgt0[(cols(fgt0)/2+1)..cols(fgt0)]'
	mata: fgt0_var = st_matrix("e(V)")
	mata: fgt0_var = diagonal(fgt0_var)[(cols(fgt0_var)/2+1)..cols(fgt0_var)]

	groupfunction [aw=WTA_S_HHSIZE], mean(fgt0) rawsum(WTA_S_HHSIZE) by(region)
	sort region
	getmata dir_fgt0 = fgt0 dir_fgt0_var = fgt0_var

	replace dir_fgt0_var = . if dir_fgt0_var==0
	replace dir_fgt0 = . if missing(dir_fgt0_var)

	save "$data\direct_glss7_region.dta", replace


restore

svy:proportion fgt0, over(district)

mata: fgt0 = st_matrix("e(b)")
mata: fgt0 = fgt0[(cols(fgt0)/2+1)..cols(fgt0)]'
mata: fgt0_var = st_matrix("e(V)")
mata: fgt0_var = diagonal(fgt0_var)[(cols(fgt0_var)/2+1)..cols(fgt0_var)]

gen N=1 //Need the number of observation by district...for smoother variance function
gen N_hhsize = hhsize

//Number of EA by district
bysort district clust: gen num_ea = 1 if _n==1

groupfunction [aw=WTA_S_HHSIZE], mean(fgt0) rawsum(N WTA_S_HHSIZE N_hhsize num_ea) by(region district)

sort district
getmata dir_fgt0 = fgt0 dir_fgt0_var = fgt0_var

gen zero = dir_fgt0 //original variable with direct estimates

replace dir_fgt0_var = . if dir_fgt0_var==0
replace dir_fgt0 = . if missing(dir_fgt0_var)

save "$data\direct_glss7.dta", replace