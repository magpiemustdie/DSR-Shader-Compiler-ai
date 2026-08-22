# FRPG_Fil_Dof_GaussY — Pseudocode

DOF vertical Gaussian blur (9-tap). Identical shader to GaussX — direction determined by VS UV offsets.

## Inputs/Outputs/Algorithm
Identical to `Dof_GaussX`; the direction (horizontal vs vertical) is controlled by vertex shader UV offset calculation.
