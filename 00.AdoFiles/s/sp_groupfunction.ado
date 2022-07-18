*! sp_groupfunction
* Paul Corral - World Bank Group 
cap prog drop sp_groupfunction
program define sp_groupfunction, eclass
	version 11.2
	#delimit ;
	syntax [aw pw fw],
	by(varlist)
	[
		coverage(varlist numeric)
		beneficiaries(varlist numeric)
		benefits(varlist numeric)
		targeting(varlist numeric)
		dependency(varlist numeric)
		dependency_d(varlist numeric)
		poverty(varlist numeric)
		povertyline(varlist numeric)
		mean(varlist numeric)
		gini(varlist numeric)
		theil(varlist numeric)
		slow
		conditional
	];
#delimit cr;
//Housekeeping
local meth coverage targeting dependency poverty mean beneficiaries benefits gini theil

foreach x of local meth{
	if ("``x''"!="") local todo `todo' `x'
}

if ("`todo'"==""){
	dis as error "You must specify at least one option:" 
	dis as error "`meth'"
	error 301
	exit
}

if (("`poverty'"!="" & "`povertyline'"=="")|("`povertyline'"!="" & "`poverty'"=="")){
	dis as error "poverty and povertyline options must be specified jointly"
	error 301
	exit
}

if (("`dependency'"!="" & "`dependency_d'"=="")|("`dependency_d'"!="" & "`dependency'"=="")){
	dis as error "dependency and dependency_d options must be specified jointly"
	error 301
	exit
}

if ("`conditional'"!="" & "`dependency'"==""){
	dis as error "Conditional option only valid when dependency is specified"
	error 301
	exit
}

qui{
	tempvar _useit _gr0up _thesort
	//gen `_thesort'   =_n
	gen `_useit'	 = 1
	
	//Weights
	if "`exp'"=="" {
		tempvar w
		qui:gen `w' = 1
		local wvar `w'
	}
	else{
		tempvar w 
		qui:gen double `w' `exp'
	}
	mata: st_view(_w=., .,"`w'")
	

//Take all variables and rename them for easy processing
local allmyvar `coverage' `dependency' `dependency_d' `poverty' `povertyline' `mean' `targeting' `beneficiaries' `benefits' `gini' `theil'
local allmyvar: list uniq allmyvar

local a = 1
foreach x of local allmyvar{
	rename `x' __a`a'
	local `x' __a`a'
	local __a`a' `x'
	local a=`a'+1
}	

foreach y in coverage dependency dependency_d poverty povertyline mean targeting beneficiaries benefits gini theil{
	if ("``y''"!=""){
		foreach x of local `y'{
			local _`y'1 `_`y'1' ``x''
		}
	}
}

//Generate the variables for the analysis, poverty is special
local pov poverty
local dep dependency
local todo1: list todo - pov
local todo1: list todo1 - dep

foreach method of local todo1{
	local `method': list uniq `method'
	local prefn = "_" + substr("`method'", 1,3)
	if ("`method'"=="beneficiaries") local prefn _ben1
	foreach x of local _`method'1{
		gen double `prefn'_`x' = .
		local `method'2 ``method'2' `prefn'_`x'
	}
}


forval a = 0/2{
	foreach line of local _povertyline1{
		foreach pov of local _poverty1{		
			gen _pov_`pov'_`line'_`a' = .
			local `line'_`a' ``line'_`a'' _pov_`pov'_`line'_`a'
		}
	}
}


foreach l of local _dependency_d1{
	local prefn = "_"+"dep"
	foreach dep of local _dependency1{
		gen double `prefn'_`dep'_`l' = .
		local 	_`l' `_`l'' `prefn'_`dep'_`l'
	}
}
*===============================================================================
//Prepare indicators
*===============================================================================
if ("`benefits'"!=""){
	mata: st_view(y=.,.,"`_benefits1'",.)
	mata:st_store(.,tokens(st_local("benefits2")),.,(y:/1))
}

if ("`beneficiaries'"!=""){
	mata: st_view(y=.,.,"`_beneficiaries1'",.)
	mata:st_store(.,tokens(st_local("beneficiaries2")),.,((y:>0):*(y:!=.)))
}

if ("`coverage'"!=""){
	mata: st_view(y=.,.,"`_coverage1'",.)
	mata:st_store(.,tokens(st_local("coverage2")),.,((y:>0):*(y:!=.)))
}

if ("`mean'"!=""){
	mata: st_view(y=.,.,"`_mean1'",.)
	mata:st_store(.,tokens(st_local("mean2")),.,(y:/1)) 
}
if ("`gini'"!=""){
	mata: st_view(y=.,.,"`_gini1'",.)
	mata:st_store(.,tokens(st_local("gini2")),.,(y:/1)) 
}
if ("`theil'"!=""){
	mata: st_view(y=.,.,"`_theil1'",.)
	mata:st_store(.,tokens(st_local("theil2")),.,(y:/1)) 
}

if ("`targeting'"!=""){
	mata: st_view(y=.,.,"`_targeting1'",.)
	mata:st_store(.,tokens(st_local("targeting2")),.,(y:/1))
}

if ("`dependency'"!=""){
	mata: st_view(y=.,.,"`_dependency1'",.)
	foreach l of local _dependency_d1{
		mata: st_view(p=.,.,"`l'",.) 
		if ("`conditional'"!=""){
			mata:st_store(.,tokens(st_local("_`l'")),.,((y:/p):*(((y:>0):*(y:!=.)))))
			foreach j of local _`l'{
				replace `j' = . if `j'==0
			}			
		}
		else mata:st_store(.,tokens(st_local("_`l'")),.,((y:/p):*(y:!=.)))
		local alldep `alldep' `_`l''
	}
}	

if ("`poverty'"!=""){
	mata: st_view(y=.,.,"`_poverty1'",.)	
	foreach line of local _povertyline1{
	mata: st_view(p=.,.,"`line'",.)
		forval a = 0/2{

		mata:st_store(.,tokens(st_local("`line'_`a'")),.,((y:<p):*(-(y:/p):+1):^`a'))
		local allpov `allpov' ``line'_`a''
		}
	}		
}

//Data is ready

gen double _population=`w'

qui: groupfunction [aw=`w'], mean(`mean2' `coverage2' `allpov' `alldep') ///
sum(`targeting2' `benefits2' `beneficiaries2') rawsum(_population) by(`by') norestore gini(`gini2') theil(`theil2') `slow'

if ("`mean2'"!="") local reshape1 `reshape1' _mea_
if ("`theil2'"!="") local reshape1 `reshape1' _the_
if ("`gini2'"!="") local reshape1 `reshape1' _gin_
if ("`coverage2'"!="") local reshape1 `reshape1' _cov_
if ("`allpov'"!="") local reshape1 `reshape1' _pov_
if ("`alldep'"!="") local reshape1 `reshape1' _dep_
if ("`targeting2'"!="") local reshape1 `reshape1' _tar_
if ("`benefits2'"!="") local reshape1 `reshape1' _ben_
if ("`beneficiaries2'"!="") local reshape1 `reshape1' _ben1_

local _mea_  mean
local _pov_  fgt
local _cov_  coverage
local _dep_  dependency
local _tar_  targeting
local _ben_  benefits
local _ben1_ beneficiaries
local _gin_  gini
local _the_  theil

cap which parallel
if _rc==0{
	dis as error "YAY - parallel!"
	parallel initialize `c(processors)'
	parallel, by(`by') force: reshape long `reshape1', i(`by') j(_indicator) string
}
else reshape long `reshape1', i(`by') j(_indicator) string

foreach x of local reshape1{
	rename `x' value`x'
}
reshape long value, i(`by' _indicator) j(measure) string
drop if value==.

foreach x of local reshape1{
	replace measure = "``x''" if measure=="`x'"
}

split _indicator, parse("__")
drop _indicator1 _indicator
cap confirm string variable _indicator3
local doref = _rc==0
if (`doref'==1){

	replace measure = measure+substr(_indicator3,-1,1) if measure=="fgt"
	
	gen _x = substr(_indicator3,-2,.)
	gen _h = subinstr(_indicator3, _x, "",.) if measure=="fgt"
	replace _h = _indicator3 if measure!="fgt"
	drop _x _indicator3
}

levelsof _indicator2, local(_myvar1)
foreach x of local _myvar1{
	replace _indicator2 = "`__`x''" if _indicator2=="`x'"
}

rename _indicator2 variable

if (`doref'==1){
	forval z=0/2{
		replace _h = subinstr(_h, "_`z'", "",.) if regexm(measure,"fgt")==1
	}
	
	levelsof _h, local(_myvar1)
	foreach x of local _myvar1{
		replace _h = "`_`x''" if _h=="`x'"
	}
	rename _h reference
}


}
end







