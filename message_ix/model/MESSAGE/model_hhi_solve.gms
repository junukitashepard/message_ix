***
* Solve statement workflow
* ========================
*
* This part of the code includes the perfect-foresight, myopic and rolling-horizon model solve statements
* including the required accounting of investment costs beyond the model horizon.
***
* Perfect-foresight model
* ~~~~~~~~~~~~~~~~~~~~~~~
* For the perfect foresight version of |MESSAGEix|, include all years in the model horizon and solve the entire model.
* This is the standard option; the GAMS global variable ``%foresight%=0`` by default.
*
* .. math::
*    \min_x \text{OBJ} = \sum_{y \in Y} \text{OBJ}_y(x_y)
***

* reset year in case it was set by MACRO to include the base year before
    year(year_all) = no ;
* include all model periods in the optimization horizon (excluding historical periods prior to 'first_period')
    year(year_all)$( model_horizon(year_all) ) = yes ;

***
*** This part is new for the HHI fuzzy MCMA
********************************************
* Solve base case to get cost bounds
put_utility 'log' /'+++ Baselining: the perfect-foresight version of MESSAGEix +++ ' ;
$SETGLOBAL HHI_CORE "0"
SOLVE MESSAGE_LP using LP minimizing OBJ;

Scalars
    cost_base_total
    cost_max_total
    hhi_min_total
    hhi_max_total
    MAXIMIN_LO
;

cost_base_total = OBJ.L;

* Worst case as 50% greater system costs
cost_max_total = OBJ.L * 1.5; 

* Set HHI bounds
hhi_min_total = 0;
hhi_max_total = 1;

* Set MAXIMIN bounds
MAXIMIN_LO = 0;

* Run updated model for HHI MCMA
*$SETGLOBAL HHI_CORE "1"
*SOLVE MESSAGE_LP using QCP maximizing MAXIMIN;