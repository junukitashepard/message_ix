***
* MESSAGE supplement to add HHI hard constraint
* =============================================
*
* This code will add a HHI hard constraint to the MESSAGE model.
* This expects hhi_limit(node,commodity,level,year,time) in [0,1].
* If your data are 0..100 or 0..10000, pre-scale them in data prep.
***
*Alias (year_all, year);
***
* Equation definitions
* --------------------
Equations
    DEF_Y_MARKET
    DEF_Y_TEC   
    DEF_HHI_LIMIT
;
* Set up HHI limit workflow
* --------------------------
* Equation DEF_Y_MARKET
* """"""""""""""""""""""
* This equation is the total market flow at each node-level-commodity.
* Total market = sum of outputs to (node,commodity,level,time)
***
DEF_Y_MARKET(node,commodity,level,year,time)$(
    year(year) AND hhi_limit(node,commodity,level,year,time) > 0
    )..
    
    Y_MARKET(node,commodity,level,year,time)
    =E=
    SUM( (location,tec,vintage,mode,time2)$(
            output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
        AND map_tec_act(location,tec,year,mode,time2)
        AND map_tec_lifetime(location,tec,vintage,year)
        ),
        ACT(location,tec,vintage,year,mode,time2)
      * output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
      * duration_time_rel(time,time2)
    );
Y_MARKET.lo(node,commodity,level,year,time) = 1e-6;

* Equation DEF_Y_MARKET
* """"""""""""""""""""""
* This equation is the total technology flow for each node-level-commodity.
* Total technology = sum of outputs to (node,commodity,level,time,tec)
* Tech-level aggregation BEFORE squaring (prevents artificial dilution by splitting)
***
DEF_Y_TEC(node,commodity,level,year,time,tec)$(
    year(year) AND hhi_limit(node,commodity,level,year,time) > 0
    )..
    
    Y_TEC(node,commodity,level,year,time,tec)
    =E=
    SUM( (location,vintage,mode,time2)$(
            output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
        AND map_tec_act(location,tec,year,mode,time2)
        AND map_tec_lifetime(location,tec,vintage,year)
        ),
        ACT(location,tec,vintage,year,mode,time2)
      * output(location,tec,vintage,year,mode,node,commodity,level,time2,time)
      * duration_time_rel(time,time2)
    );
Y_TEC.lo(node,commodity,level,year,time,tec) = 1e-6;

* Equation DEF_HHI_LIMIT
* """"""""""""""""""""""
* This equation is the HHI limit for each node-level-commodity.
* HHI = sum of squared technology flows for each node-level-commodity
* HHI <= hhi_limit * (Total market)^2
***
DEF_HHI_LIMIT(node,commodity,level,year,time)$(
    year(year) AND hhi_limit(node,commodity,level,year,time) > 0
    )..
    SUM(tec, sqr( Y_TEC(node,commodity,level,year,time,tec)))
    =L=
    hhi_limit(node,commodity,level,year,time)
  * sqr( Y_MARKET(node,commodity,level,year,time));
