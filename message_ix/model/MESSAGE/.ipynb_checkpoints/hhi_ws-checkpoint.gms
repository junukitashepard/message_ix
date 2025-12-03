***
* MESSAGE supplement to add HHI weighted sum workflow
* ====================================================
*
* This code implements a weighted sum approach for multi-objective optimization
* balancing system cost minimization and HHI (diversity) minimization.
* User parameter lambda_ws ∈ [0,1] controls the trade-off:
*   - lambda_ws = 1: pure cost minimization
*   - lambda_ws = 0: pure diversity maximization (HHI minimization)
*   - Sweep lambda_ws to trace Pareto frontier
*
* HHI is calculated based on LOCATION of output (not node)
***
* Equation definitions
* --------------------
Equations
    EQ_COST_TOTAL                   Aggregate total costs
    EQ_COM_TOTAL                    Total commodity flow at each location-level
    EQ_TEC_TOTAL                    Total technology flow for each location-level-commodity
    EQ_HHI_COUNT                    Total number of location-level-commodities to average system-wide HHI
    EQ_HHI_S                        Rotated cone constraint for SOCP
    EQ_PSEUDO_HHI_TOTAL             Sum of all Pseudo_HHI_S variables
    EQ_COM_TOTAL_SUM                Sum of all COM_TOTAL variables
    EQ_PSEUDO_HHI_BOUND             Bound Pseudo_HHI by COM_TOTAL_SUM and hhi_max_total
    EQ_WS_OBJ                       Weighted sum objective for cost-HHI trade-off
;

* Define a small tolerance parameter for detecting non-zero commodity flows
Scalar eps_commodity "Minimum commodity flow to activate HHI constraint" / 1e-6 /;

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
* Equation EQ_HHI_S
* """"""""""""""""""""""""""""""
* Rotated second-order cone constraint in canonical form
* 2*Pseudo_HHI_S*COM_TOTAL >= TEC_TOTAL^2 with Pseudo_HHI_S, COM_TOTAL >= 0
* Only active when COM_TOTAL could be non-zero (i.e., when technologies exist)
* This allows COM_TOTAL to be zero without numerical issues in the SOCP solver
***
EQ_HHI_S(location,commodity,level,year,time,tec)$(
    include_commodity_hhi(location,commodity,level)
    AND SUM((node,vintage,mode,time2)$(
        map_tec_lifetime(location,tec,vintage,year)
        AND map_tec_act(location,tec,year,mode,time)
        AND output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
    ), 1)
)..
    2 * Pseudo_HHI_S(location,commodity,level,year,time,tec)
        * COM_TOTAL(location,commodity,level,year,time) =G=
            sqr(TEC_TOTAL(location,commodity,level,year,time,tec));

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
* Equation EQ_PSEUDO_HHI_TOTAL
* """"""""""""""""""""""""""""""
* Sum Pseudo_HHI_S across all technologies and periods
***
EQ_PSEUDO_HHI_TOTAL..
    Pseudo_HHI_TOTAL =E=
        SUM((location,commodity,level,year,time,tec)$(
            include_commodity_hhi(location,commodity,level)),
            Pseudo_HHI_S(location,commodity,level,year,time,tec));

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
* Equation EQ_PSEUDO_HHI_BOUND
* """"""""""""""""""""""""""""""
* Upper bound on weighted-average HHI across periods
* Factor of 2 correction: Pseudo_HHI_TOTAL = 0.5 * sum_t(HHI[t] * COM_TOTAL[t])
* So bound uses hhi_max_total/2 to enforce actual HHI ≤ hhi_max_total
***
EQ_PSEUDO_HHI_BOUND..
    Pseudo_HHI_TOTAL =L= COM_TOTAL_SUM * (hhi_max_total / 2);

***
* Weighted sum objective for cost-HHI trade-off
* """"""""""""""""""""""""""""""""""""""""""""""
* Objective: minimize lambda_ws * (COST/cost_max) + (1-lambda_ws) * hhi_scale * Pseudo_HHI
* Cost term normalized, HHI term scaled for comparability
* User provides hhi_scale to balance units (e.g., 1/expected_demand if cost in $/GWa)
* User sweeps lambda_ws ∈ [0,1] to trace Pareto frontier
***
EQ_WS_OBJ..
    WS_OBJ =E= (lambda_ws * (COST_TOTAL / cost_max_total))
                 + ((1 - lambda_ws) * hhi_scale * Pseudo_HHI_TOTAL);

* Set variable bounds for SOCP
* Lower bounds allow variables to be zero
Pseudo_HHI_S.LO(location,commodity,level,year,time,tec) = 0;
COM_TOTAL.LO(location,commodity,level,year,time) = 0;
TEC_TOTAL.LO(location,commodity,level,year,time,tec) = 0;