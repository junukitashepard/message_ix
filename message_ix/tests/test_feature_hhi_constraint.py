""" Tests for Herfindahl-Hirschman Index (HHI) MCDA feature

Uses the Westeros tutorial scenario to test HHI MCDA feature.
"""
import numpy as np
import pandas as pd
import pytest
from ixmp import Platform

from message_ix import Scenario, make_df
from message_ix.testing import make_westeros

# Pull and clone scenario for testing
def _hhi_limit_westeros_test(
    hhi_limit: float = 0.7) -> Scenario:

    """Pull and clone the Westeros scenario and add hhi limit
    
    Parameters
    ----------
    mp : Platform
        Platform on which to pull and clone the Westeros scenario
    hhi_limit : float
        HHI hard constraint [0,1]

    Returns
    -------
    Scenario
        Cloned Westeros scenario with hhi limit.
    """
    
    mp = Platform()
    base = make_westeros(mp, emissions=True, solve=False)
    scen = base.clone(model='hhi_test', scenario='Westeros_limit', keep_solution = False)
    scen.set_as_default()

    with scen.transact("Add hhi limit"):
        hhi_limit_df = pd.DataFrame(
            {"node": "Westeros", 
            "commodity": "electricity", 
            "level": "secondary", 
            "year_all": 700,
            "time": "year",
            "value": hhi_limit, }, index=[0])
        scen.add_par("hhi_limit", hhi_limit_df)

    scen.solve(gams_args=["--HHI_CONSTRAINT=0"], quiet=True)
    #scen.solve()
    # Extract HHI_TOTAL
    print(f"HHI_TOTAL: {scen.var('HHI_TOTAL')['lvl']}")

    # Extract activity
    activity = scen.var('ACT')
    activity = activity[(activity['year_act'] == 700) & (activity['technology'].isin(['coal_ppl', 'wind_ppl']))]
    print("Activity in 700")
    print(f"{activity}")

    return scen

# Build and run the scenario
hhi_westeros = _hhi_limit_westeros_test()