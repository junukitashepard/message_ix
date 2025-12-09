***
* MESSAGE supplement to add HHI penalty formulation
* ====================================================
*
* This code implements a weighted sum approach for multi-objective optimization
* balancing system cost minimization and HHI (diversity) minimization.
* User parameter lambda_ws ∈ [0,1] controls the trade-off:
*   - lambda_ws = 1: pure cost minimization
*   - lambda_ws = 0: pure diversity maximization (HHI minimization)
*   - Sweep lambda_ws to trace Pareto frontier
***
* Equation definitions
* --------------------
Equations
    EQ_COST_TOTAL                   Aggregate total costs
    EQ_COM_TOTAL                    Total commodity flow at each location-level
    EQ_TEC_TOTAL                    Total technology flow for each location-level-commodity
    EQ_HHI_COUNT                    Total number of location-level-commodities to average system-wide HHI
    EQ_MAX_TECH_SHARE               Linearized constraint linking technology shares to concentration penalty
    EQ_HHI_APPROX_TOTAL             Sum of concentration penalties across all periods
    EQ_COM_TOTAL_SUM                Sum of all COM_TOTAL variables
    EQ_HHI_APPROX_BOUND             Bound approximate HHI by COM_TOTAL_SUM and hhi_max_total
    EQ_WS_OBJ                       Weighted sum objective for cost-HHI trade-off
;

* Set up HHI weighted sum workflow
* ---------------------------------
* Equation EQ_COST_TOTAL
* """"""""""""""""""""""
* This equation aggregates total system costs.
***
EQ_COST_TOTAL..
    COST_TOTAL =E= SUM((node,year), df_period(year) * COST_NODAL(node,year));

***
* Equation EQ_COM_TOTAL
* """""""""""""""""""""""""""
* Total commodity flow per (location,commodity,level,year,time)
* Based on location where output is produced
***
EQ_COM_TOTAL(location,commodity,level,year,time)$(
    include_commodity_hhi(location,commodity,level)
)..
    COM_TOTAL(location,commodity,level,year,time) =E=
        SUM((node,tec,vintage,mode,time2)$(
            map_tec_lifetime(location,tec,vintage,year)
            AND map_tec_act(location,tec,year,mode,time)
            AND output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
        ),
            output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
            * duration_time_rel(time2,time)
            * ACT(location,tec,vintage,year,mode,time2)
        );

***
* Equation EQ_TEC_TOTAL
* """"""""""""""""""""""""""""""
* Total commodity flow per technology per (location,commodity,level,year,time,tec)
* Based on location where output is produced
***
EQ_TEC_TOTAL(location,commodity,level,year,time,tec)$(
    include_commodity_hhi(location,commodity,level)
)..
    TEC_TOTAL(location,commodity,level,year,time,tec) =E=
        SUM((node,vintage,mode,time2)$(
            map_tec_lifetime(location,tec,vintage,year)
            AND map_tec_act(location,tec,year,mode,time)
            AND output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
        ),
            output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
            * duration_time_rel(time2,time)
            * ACT(location,tec,vintage,year,mode,time2)
        );

***
* Equation EQ_MAX_TECH_SHARE
* """""""""""""""""""""""""""
* Linearized approximation of concentration penalty using Gini/entropy-like measure
***
EQ_MAX_TECH_SHARE(location,commodity,level,year,time,tec)$(
    include_commodity_hhi(location,commodity,level)
    AND SUM((node,vintage,mode,time2)$(
        map_tec_lifetime(location,tec,vintage,year)
        AND map_tec_act(location,tec,year,mode,time)
        AND output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
    ), 1)
)..
    HHI_APPROX(location,commodity,level,year,time,tec) =G= 
        TEC_TOTAL(location,commodity,level,year,time,tec);

***
* Equation EQ_HHI_COUNT
* """""""""""""""""""""""
* Count number of periods for which HHI is calculated (for reporting)
***
EQ_HHI_COUNT..
    HHI_COUNT =E=
        SUM((location,commodity,level,year,time)$(
            include_commodity_hhi(location,commodity,level)), 1);

***
* Equation EQ_HHI_APPROX_TOTAL
* """"""""""""""""""""""""""""""
* Sum concentration penalties across all technologies and periods
***
EQ_HHI_APPROX_TOTAL..
    HHI_APPROX_TOTAL =E=
        SUM((location,commodity,level,year,time,tec)$(
            include_commodity_hhi(location,commodity,level)),
            concentration_penalty * HHI_APPROX(location,commodity,level,year,time,tec));

***
* Equation EQ_COM_TOTAL_SUM
* """""""""""""""""""""""""""
* Sum COM_TOTAL across all periods (for normalization in objective)
***
EQ_COM_TOTAL_SUM..
    COM_TOTAL_SUM =E=
        SUM((location,commodity,level,year,time)$(
            include_commodity_hhi(location,commodity,level)),
            COM_TOTAL(location,commodity,level,year,time));

***
* Equation EQ_HHI_APPROX_BOUND
* """"""""""""""""""""""""""""""
* Optional upper bound on concentration (only active if hhi_max_total < 0.999)
* This provides a hard limit on concentration when needed
***
EQ_HHI_APPROX_BOUND$(hhi_max_total < 0.999)..
    HHI_APPROX_TOTAL =L= COM_TOTAL_SUM * hhi_max_total * concentration_penalty;

***
* Weighted sum objective for cost-HHI trade-off
* """"""""""""""""""""""""""""""""""""""""""""""
***
EQ_WS_OBJ..
    WS_OBJ =E= (lambda_ws * (COST_TOTAL / cost_max_total))
                 + ((1 - lambda_ws) * hhi_scale * HHI_APPROX_TOTAL);

* Set variable bounds
* Lower bounds allow variables to be zero
HHI_APPROX.LO(location,commodity,level,year,time,tec) = 0;
COM_TOTAL.LO(location,commodity,level,year,time) = 0;
TEC_TOTAL.LO(location,commodity,level,year,time,tec) = 0;