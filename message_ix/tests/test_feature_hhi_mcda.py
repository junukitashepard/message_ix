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

    with scen.transact("Add hhi parameters"):
        cost_base_total_df = pd.DataFrame(
            {"time": "year", "value": cost_base_total, }, index=[0])
        scen.add_par("cost_base_total", cost_base_total_df)

        cost_max_total_df = pd.DataFrame(
            {"time": "year", "value": cost_max_total, }, index=[0])
        scen.add_par("cost_max_total", cost_max_total_df)

        hhi_min_total_df = pd.DataFrame(
            {"time": "year", "value": hhi_min_total, }, index=[0])
        scen.add_par("hhi_min_total", hhi_min_total_df)

        hhi_max_total_df = pd.DataFrame(
            {"time": "year", "value": hhi_max_total, }, index=[0])
        scen.add_par("hhi_max_total", hhi_max_total_df)

        include_commodity_hhi_df = pd.DataFrame(
            {"node": "Westeros", "commodity": "electricity", "level": "secondary", "value": 1, }, index=[0])
        scen.add_par("include_commodity_hhi", include_commodity_hhi_df)

    scen.solve(model="MESSAGE", solve_options={"hhi": "1"}, quiet=True)

    # Extract HHI_TOTAL
    print(f"HHI_TOTAL: {scen.var('HHI_TOTAL')['lvl']}")

    # Extract activity
    activity = scen.var('ACT')
    activity = activity[(activity['year_act'] == 700) & (activity['technology'].isin(['coal_ppl', 'wind_ppl']))]
    print("Activity in 700: hhi = 1")
    print(f"{activity}")

    return scen

# Build and run the scenario
hhi_westeros = _hhi_westeros_test()

