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
def _hhi_westeros_test(
    cost_base_total: float = 1,
    cost_max_total: float = 500000,
    hhi_min_total: float = 0,
    hhi_max_total: float = 1) -> Scenario:

    """Pull and clone the Westeros scenario and add hhi parameters
    
    Parameters
    ----------
    mp : Platform
        Platform on which to pull and clone the Westeros scenario
    cost_base_total : float
        Base cost total
    cost_max_total : float
        Maximum cost total
    hhi_min_total : float
        Minimum hhi total
    hhi_max_total : float
        Maximum hhi total

    Returns
    -------
    Scenario
        Cloned Westeros scenario with hhi parameters.
    """
    
    mp = Platform()
    base = make_westeros(mp, emissions=True, solve=False)
    scen = base.clone(model='hhi_test', scenario='Westeros', keep_solution = False)
    scen.set_as_default()

    with scen.transact("Add hhi parameters"):

        scen.init_scalar("cost_base_total", cost_base_total, "USD")
        scen.init_scalar("cost_max_total", cost_max_total, "USD")
        scen.init_scalar("hhi_min_total", hhi_min_total, "???")
        scen.init_scalar("hhi_max_total", hhi_max_total, "???")

        include_commodity_hhi_df = pd.DataFrame(
            {"node": "Westeros", "commodity": "electricity", "level": "secondary", "value": 1, }, index=[0])
        scen.add_par("include_commodity_hhi", include_commodity_hhi_df)

    scen.solve(gams_args=["--HHI_CORE=1"], quiet=True)
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
hhi_westeros = _hhi_westeros_test()

mp = Platform()
scen = Scenario(mp, model='hhi_test', scenario='Westeros')
scen.remove_solution()

with scen.transact("Add hhi parameters"):
    scen.init_scalar("cost_base_total", 1, "USD")

scen.init_scalar("cost_max_total", cost_max_total, "USD")
scen.init_scalar("hhi_min_total", hhi_min_total, "???")
scen.init_scalar("hhi_max_total", hhi_max_total, "???")

include_commodity_hhi_df = pd.DataFrame(
    {"node": "Westeros", "commodity": "electricity", "level": "secondary", "value": 1, }, index=[0])
scen.add_par("include_commodity_hhi", include_commodity_hhi_df)

scen.solve(gams_args=["--HHI_MCMA=1"])