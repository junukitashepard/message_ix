***
* MESSAGE supplement to add HHI MCMA workflow
* ===========================================
*
* This code will add a HHI MCMA workflow to the MESSAGE model.
* The workflow will be used to optimize the system-wide HHI while minimizing the total costs.
* 1. Calculate the total costs and HHI for the system
* 2. Calculate the membership functions for the cost and HHI
* 3. Calculate the MCMA constraint
* 4. Solve the optimization problem
***
* Equation definitions
* --------------------
Equations
    EQ_COST_TOTAL                   Aggregate total costs
    EQ_COM_TOTAL                    Total commodity flow at each node-level
    EQ_TEC_TOTAL                    Total technology flow for each node-level-commodity
    EQ_HHI_COUNT                    Total number of node-level-commodities to average system-wide HHI
    EQ_HHI_TOTAL                    aggregate HHI across nodes and commodities
    EQ_HHI_S                        share
    EQ_MEMBERSHIP_COST              cost membership function
    EQ_MEMBERSHIP_HHI               HHI membership function
    EQ_MCMA_CONSTRAINT              max-min constraint
;
* Set up HHI limit workflow
* --------------------------
* Equation EQ_COST_TOTAL
* """"""""""""""""""""""
* This equation is the same as the objective function, for use in the MCMA.
***
EQ_COST_TOTAL..
    COST_TOTAL =E= SUM((node,year), df_period(year) * COST_NODAL(node,year));

***
* Equation EQ_COM_TOTAL
* """""""""""""""""""""""""""
* This equation calculates the denominator of the HHI (total commodity at node)
***
EQ_COM_TOTAL(node,commodity,level,year,time)$(
    include_commodity_hhi(node,commodity,level)
)..
    COM_TOTAL(node,commodity,level,year,time) =E=
        SUM((location,tec,vintage,mode,time2)$(
            map_tec_lifetime(location,tec,vintage,year)
            AND map_tec_act(location,tec,year,mode,time)
            AND output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
        ),
            output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
            * duration_time_rel(time2,time)
            * ACT(location,tec,vintage,year,mode,time2)
        ) + 1e-6;

***
* Equation EQ_TEC_TOTAL
* """"""""""""""""""""""""""""""
* This equation calculates the numerator of HHI (commodity by technology-node-level)
***
EQ_TEC_TOTAL(node,commodity,level,year,time,tec)$(
    include_commodity_hhi(node,commodity,level)
)..
    TEC_TOTAL(node,commodity,level,year,time,tec) =E=
        SUM((location,vintage,mode,time2)$(
            map_tec_lifetime(location,tec,vintage,year)
            AND map_tec_act(location,tec,year,mode,time)
            AND output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
        ),
            output(location,tec,vintage,year,mode,node,commodity,level,time,time2)
            * duration_time_rel(time2,time)
            * ACT(location,tec,vintage,year,mode,time2)
        );

***
* Equation EQ_HHI_S
* """"""""""""""""""""""""""""""
* This equation calculates the technology share
***
EQ_HHI_S(node,commodity,level,year,time,tec)$(
    include_commodity_hhi(node,commodity,level)
)..
    HHI_S(node,commodity,level,year,time,tec)*
        COM_TOTAL(node,commodity,level,year,time) =E=
            TEC_TOTAL(node,commodity,level,year,time,tec);

***
* Equation EQ_SYSTEM_HHI
* """""""""""""""""""""""
* This equation averages the HHI across the whole system
***
EQ_HHI_COUNT..
    HHI_COUNT =E=
        SUM((node,commodity,level,year,time)$(
            include_commodity_hhi(node,commodity,level)), 1);
        
EQ_HHI_TOTAL..
    HHI_TOTAL*HHI_COUNT =E=
        SUM((node,commodity,level,year,time)$(
            include_commodity_hhi(node,commodity,level)),
            SUM(tec$(
                include_commodity_hhi(node,commodity,level)),
                SQR(HHI_S(node,commodity,level,year,time,tec))));

***
* Equations for membership functions for use in MCMA
* """"""""""""""""""""""""""""""""""""""""""""""""""
* These equations define the memberships used in the MCMA (i.e., cost and HHI)
***
***
* Equation EQ_SYSTEM_HHI
* """""""""""""""""""""""
* This equation sums the HHI across the whole system
***
EQ_MEMBERSHIP_COST..
    MEMBER('obj1') =E= (cost_max_total - COST_TOTAL)/(cost_max_total - cost_base_total);

EQ_MEMBERSHIP_HHI..
    MEMBER('obj2') =E= (hhi_max_total - HHI_TOTAL)/(hhi_max_total - hhi_min_total);

EQ_MCMA_CONSTRAINT(member_index)..
    MCMA - MEMBER(member_index) =L= 0;

* Set MCMA bounds
MCMA.LO = 0;