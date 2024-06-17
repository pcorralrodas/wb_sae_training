{smcl}
{* *! version 1.0.0  5December2017}{...}
{cmd:help hotspot}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col :{cmd:hotspot} {hline 1} Identifies statistically significant hot spots and cold spots using Getis-Ord Gi* statistic. Tool identifies statistically significant clusters of high and low values.}{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 23 2}
{opt hotspot} {varlist} {ifin} {cmd:,}
{opt X:coord(varname)}
{opt Y:coord(varname)}
{opt RAD:ius(numlist)}
[{opt NEI:ghbors(numlist)}
{opt INDIFF:erence(numlist)}]

{title:Description}

{pstd}
{cmd:hotspot} Supports estimation of Getis-Ord Gi* statistic making use of a zone of indifference type of spatial relationship

{title:Options}

{phang}
{opt X:coord(varname)} Latitude

{phang}
{opt Y:coord(varname)} Longitude

{phang}
{opt RAD:ius(numlist)} Neighbors outside this distance will not influence the calculation.

{phang}
{opt NEI:ghbors(numlist)} Specifies that every feature has at least a certain number of neighbors, each of these count equally in the calculation. After this distance, the level of influence of the neighbors quickly drops off.

{phang}
{opt INDIFF:erence(numlist)} Specifies distance for the zone of indifference. Only one option should be used, indifference or neighbors.

{phang}
{opt INV:erse(numlist)} Indicates that the spatial weight matrix be the inverse to the power specified, only positive numbers allowed.

{phang}
{opt EXP:onential(numlist)} Indicates that the spatial weight matrix to be used is exponential where the negative of the number specified is multiplied with the distance. Only positive numbers allowed.


{title:Example}
hotspot  imd imddemography imdeconomicdevelopment imdfiscalcapacity imdhealthandeducation imdlabormarket imdphysicalinfrastructure imdsocialprotection imdsocialservices imdEconomic imdPhysical imdSocial, x(X) y(Y) radius(600) neighbors(1)

{title:Authors}

{pstd}
Paul Corral{break}
The World Bank - Poverty and Equity Global Practice {break}
Washington, DC{break}
pcorralrodas@worldbank.org{p_end}

Joao Pedro Azevedo{break}
The World Bank - Poverty and Equity Global Practice {break}
Washington, DC{break}
jazevedo@worldbank.org{p_end}
