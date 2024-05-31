* Set directory
global path  "/Users/hendersonhl/Documents/Articles/Poverty-Mapping/Data/"

* Import "true" poverty rates
import delimited "$path/true_mun.csv", clear
keep mimun poor
rename poor true
tempfile true
save `true'

* Import poverty rates from one sample
import delimited "$path/svydata_mun.csv", clear
keep if sim_sample==1
keep mimun poor
rename poor direct
tempfile direct
save `direct'

* Merge poverty rates and covariates
use "$path/xmatrix_mun_ntl.dta", clear
drop hhid estado municipio
rename MiMun mimun 
merge 1:1 mimun using `true'
drop _merge
merge 1:1 mimun using `direct'
drop _merge
rename mimun municipality
order municipality direct true
drop census_automobile

* Miscellaneous cleaning and save
drop gis*
rename census_* *
export delimited using "/Users/hendersonhl/Desktop/Summer University/Application/data", replace
clear all
