*! hotspot November, 2017 
* Paul Corral (World Bank Group - Poverty and Equity Global Practice)
* Joao Pedro Azevedo (World Bank Group - Poverty and Equity Global Practice)
cap program drop hotspot
cap set matastrict off
program define hotspot, eclass
	version 11.2
	syntax varlist(min=1 numeric) [if] [in], Xcoord(varlist numeric max=1)   ///
											 Ycoord(varlist numeric max=1)   ///
											 RADius(numlist >0 max=1)  ///
											 [NEIghbors(numlist int >=0 max=1) ///
											 INDIFFerence(numlist >=0 max=1) ///
											 INVerse(numlist >0 max=1)  ///
											 EXPonential(numlist >0 max=1) ///
											 POPulation(varlist numeric max=1)]
											           
marksample touse1					 
local vlist: list uniq varlist


qui{
tempvar touse
gen `touse' = `touse1'
foreach x of varlist `vlist' `xcoord' `ycoord'{
	replace `touse'=0 if `x'==. & `touse1'==1
}

count if `touse'==0 & `touse1'==1
local ee=r(N)

if (`ee'>0) dis as error "Warning: `ee' observations will not be used in your analysis due to missing data"

//Get weights matrix
mata:st_view(y=., .,"`ycoord'","`touse'")
mata:st_view(x=., .,"`xcoord'","`touse'")
if (!missing("`population'")){
	qui: sum `population'
	tempvar xx
	gen double `xx' = `population'/r(sum)
	mata:st_view(popw=., .,"`xx'","`touse'")
}

//WEIGHT MATRIX TYPE
if ("`inverse'"!="" & "`exponential'"!=""){
	noi dis as error "Warning: Only one type of weights matrix allowed, inverse or exponential"
	exit
}

if ("`inverse'"=="" & "`exponential'"==""){
	local inverse 1
	noi dis in green "Analysis done with inverse distance (1) weight matrix"
}

if (!missing("`population'")){
	if ("`neighbors'"!=""){
		local indifference = 1 //Indifference is overriden by function!
		noi mata: _spw = calcdist6(y,x, `radius', 1, "", `neighbors', 1,`indifference',popw, 1)
	}
	else  noi mata: _spw = calcdist6(y,x, `radius', 1, "", 1,1,`indifference', popw)
}
else{
	if ("`neighbors'"!=""){
		local indifference = 1 //Indifference is overriden by function!
		noi mata: _spw = calcdist5(y,x, `radius', 1, "", `neighbors', 1,`indifference',1)
	}
	else  noi mata: _spw = calcdist5(y,x, `radius', 1, "", 1,1,`indifference')
}


foreach x of local vlist{
	gen double goZ_`x'   = .
	gen double goS_`x'  = .
	local thev goZ_`x' goS_`x'
	
	 
	mata: st_view(_x2=., .,"`x'","`touse'")
	mata: _z=_getord(_spw,_x2)
	mata: _p=_getordp(_z)
	mata: st_store(.,tokens("`thev'"),"`touse'", (_z,_p) )
	
	local allv `allv' `thev'
}
mata: mata drop _z _p _spw _x2
noi dis in yellow "The following variables were added to your data"
noi dis in green "`allv'"
drop `touse'
}
end

mata
//Zone of indifference matrix of distances
function calcdist5(latr, lonr, dist, pow,unit, knn,inter, indiff,| dcal)
{
cN = rows(lonr)
latr = ( pi() / 180 ):*latr
lonr = ( pi() / 180 ):*lonr
if (cN<knn) display("You have requested more neighbors than existing points, please check")
	/*Distance between i and j*/
	A = J(cN,cN,1) :* lonr
	C = J(cN,cN,1) :* latr
	difflonr = abs( A - A' )
	A=.
	numer1 = ( cos(C'):*sin(difflonr) ):^2
	numer2 = ( cos(C):*sin(C') :- sin(C):*cos(C'):*cos(difflonr) ):^2
	numer = sqrt( numer1 :+ numer2 )
	numer1=.
	numer2=.
	denom = sin(C):*sin(C') :+ cos(C):*cos(C'):*cos(difflonr)
	C=difflonr=.
	mDist = 6378.137 :* atan2( denom, numer )
	denom=numer=.
	
	/*Convert Unit of Distance*/
	if( unit == "mi" ){
		mDist = 0.621371 :* mDist
	}
	display("The max. distance between points is:")
	max(mDist)
	if (dcal==1){
	display("The mean distance between point is:")
		quadsum(mDist:/(cN*cN))
		for(i=1;i<=cols(mDist);i++){
			if (i==1) s=(sort(mDist[.,i],1))[(knn+1),1]
			else s=s,(sort(mDist[.,i],1))[(knn+1),1]
		}
		display("The min. distance for requested neighbors:")
		s=max(s)
		s
	}
	
	/*Return Distance Matrix*/
	if (dcal==1) indiff = s+1e-18
	else indiff = indiff + 1e-18

	if (st_local("inverse")!=""){
		pow=strtoreal(st_local("inverse"))		
		mDist = (((mDist:>=indiff):*mDist) + (mDist:<indiff)):^(-pow)
		mDist = mDist:*(mDist:>(dist^(-pow)))
	}
	if (st_local("exponential")!=""){
		pow=strtoreal(st_local("exponential"))
		mDist = mDist:*(mDist:>=indiff)
		mDist = exp(-pow*mDist):*(mDist:<dist)
	}
	return(mDist)
}

function calcdist6(latr, lonr, dist, pow,unit, knn,inter, indiff, popw, | dcal)
{
cN = rows(lonr)
latr = ( pi() / 180 ):*latr
lonr = ( pi() / 180 ):*lonr
if (cN<knn) display("You have requested more neighbors than existing points, please check")
	/*Distance between i and j*/
	A = J(cN,cN,1) :* lonr
	C = J(cN,cN,1) :* latr
	difflonr = abs( A - A' )
	A=.
	numer1 = ( cos(C'):*sin(difflonr) ):^2
	numer2 = ( cos(C):*sin(C') :- sin(C):*cos(C'):*cos(difflonr) ):^2
	numer = sqrt( numer1 :+ numer2 )
	numer1=.
	numer2=.
	denom = sin(C):*sin(C') :+ cos(C):*cos(C'):*cos(difflonr)
	C=difflonr=.
	mDist = 6378.137 :* atan2( denom, numer )
	denom=numer=.
	
	/*Convert Unit of Distance*/
	if( unit == "mi" ){
		mDist = 0.621371 :* mDist
	}
	display("The max. distance between points is:")
	max(mDist)
	if (dcal==1){
	display("The mean distance between point is:")
		quadsum(mDist:/(cN*cN))
		for(i=1;i<=cols(mDist);i++){
			if (i==1) s=(sort(mDist[.,i],1))[(knn+1),1]
			else s=s,(sort(mDist[.,i],1))[(knn+1),1]
		}
		display("The min. distance for requested neighbors:")
		s=max(s)
		s
	}
	
	
	/*Return Distance Matrix*/
	if (dcal==1) indiff = s+1e-18
	else indiff = indiff + 1e-18

	if (st_local("inverse")!=""){
		pow=strtoreal(st_local("inverse"))		
		mDist = (((mDist:>=indiff):*mDist) + (mDist:<indiff)):^(-pow)
		mDist = mDist:*(mDist:>(dist^(-pow)))
	}
	if (st_local("exponential")!=""){
		pow=strtoreal(st_local("exponential"))
		mDist = mDist:*(mDist:>=indiff)
		mDist = exp(-pow*mDist):*(mDist:<dist)
	}
	mDist[1..5, 1..5]
	mDist = mDist:*popw
	mDist[1..5, 1..5]
	return(mDist)
}


//Getis ord estimation
function _getord(weight, delta){
	x=mean(delta)
	num = weight*delta-(x:*rowsum(weight))
	den=(sqrt((variance(delta)*(rows(delta)*rowsum(weight:^2) - rowsum(weight):^2))/(rows(delta)-1) ))
	return(num:/den)
}
//Function take avg and se and gets a "bootstrapped" getis ord
function _getord_boot(weight, avg, se, sim){
	vals = rnormal(1,sim, avg, se)
	vals = vals:*(vals:<=1)+(vals:>1)
	vals = vals:*(vals:>=0) 
	gord=_getord(weight, vals[.,1])
	for(i=2; i<=sim; i++) gord=gord,_getord(weight, vals[.,i])
	return(mean(gord')')	
}
//Gets Z score and significance from getord output
function _getordp(z){
	
	pval1 = 0:*(z:<invnormal(.95)) +0:*(z:>invnormal(0.05))
	pval2 = .9:*(z:>=invnormal(0.95)) 
	pval3 =	.95:*(z:>=invnormal(0.975)) 
	pval4 = .99:*(z:>=invnormal(.995))
	pval = rowmax((pval1,pval2,pval3, pval4))
	pval1 = -.9:*(z:<=invnormal(0.05))
	pval2 = -.95:*(z:<=invnormal(0.025))
	pval3 = -.99:*(z:<=invnormal(0.005))
	pval4 = rowmin((pval1,pval2,pval3))
	pval = pval4+pval
		   
	return(pval)
	
}
									 
			
end											 
		
											 
