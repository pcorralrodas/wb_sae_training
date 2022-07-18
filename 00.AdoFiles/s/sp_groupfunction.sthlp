{smcl}
{* *! version 1.0.0  5December2018}{...}
{cmd:help sp_groupfunction}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col :{cmd:sp_groupfunction} {hline 1}} Command makes use of groupfunction, users must have the latest version of groupfunction installed.{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 23 2}
{opt sp_groupfunction}  {[aw pw fw]} {cmd:,}
{opt by(varlist)}
{opt mean(varlist numeric)}
{opt gini(varlist numeric)}
{opt theil(varlist numeric)}
{opt coverage(varlist numeric)}
{opt beneficiaries(varlist numeric)}
{opt benefits(varlist numeric)}
{opt dependency(varlist numeric)}
{opt dependency_d(varlist numeric)}
{opt poverty(varlist numeric)}
{opt povertyline(varlist numeric)}
{opt conditional}


{title:Description}

{pstd}
{cmd:groupfunction} Code makes use of groupfunction to speed up summary stats, and outputs in a long form dataset for easy manipulation.

{title:Options}

{phang}
{opt by(varlist)} Grouping for reporting estimates.

{phang}
{opt mean(varlist)} Calculates means of specified variables.

{phang}
{opt gini(varlist)} Calculates Gini coefficient of specified variables.

{phang}
{opt theil(varlist)} Calculates Theil coefficient of specified variables.

{phang}
{opt theil(varlist)} Calculates Theil coefficient of specified variables.

{phang}
{opt coverage(varlist)} Calculates the share of the group for which the variable is not zero.

{phang}
{opt beneficiaries(varlist)} Calculates the total population or observations, if weights are not specified, for which the value of variables specified is not 0 for groups specified in by().

{phang}
{opt benefits(varlist)} Calculates the total population expanded value of variables specified in by().

{phang}
{opt dependency(varlist)} Must be used together with dependency_d options. The output shows the mean ratio of the variables specified in dependency() over the variables specified in dependency_d() for groups specified in by(). If the conditional option is specified it will omit values where dependency() is 0.

{phang}
{opt dependency_d(varlist)} Is used as the reference incomes for the dependency calulations. Must be used with dependency().

{phang}
{opt conditional} Must be used with dependency() and dependency_d(). It will produce dependency where we omit values where dependency() is 0.

{phang}
{opt poverty(varlist)} Vectors for which we want to produce poverty rates for groups specified in by() by thresholds specified under povertyline(). povertyline() must be specified to use.

{phang}
{opt povertyline(varlist)} Variables indicating the thresholds for poverty rates. Must be used jointly with poverty().


{title:Example}

use "$data_pry\net_incs.dta", clear
xtile decs = gross_income [aw=popw], nq(10)

sp_groupfunction [aw=popw], poverty(`poverty_incs') povertyline(`poverty_lines') ///
mean(`concs') coverage(`concs') benefits(`tax' `transfers') ///
beneficiaries(`tax' `transfers') dependency(`concs') dependency_d(`poverty_lines' `incomes') conditional by(decs) 



{title:Authors}

{pstd}
Paul Corral{break}
The World Bank - Poverty and Equity Global Practice {break}
Washington, DC{break}
pcorralrodas@worldbank.org{p_end}







