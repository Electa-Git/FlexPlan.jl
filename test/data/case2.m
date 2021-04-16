% 2-bus network
%
% Load at bus 2 requires 10 MW. In optimal solution, 8 MW are provided by the generator at bus 1,
% set at its max; the load lowers its consumption to 8 MW by activating its flexibility.
% Optimal cost: 38 (power generation: 8; load flexibility: 10; not consumed energy: 20).

function mpc = case2
mpc.version = '2';
mpc.baseMVA = 1.0;

% bus_i type    pd   qd   gs   bs bus_area     vm      va base_kv zone  vmax  vmin
mpc.bus = [
      1    3   0.0  0.0  0.0  0.0        1  1.000    0.00   240.0    1  1.05  0.95;
      2    1  10.0  0.0  0.0  0.0        1  1.000    0.00   240.0    1  1.05  0.95;
];

% gen_bus     pg    qg   qmax   qmin     vg  mBase gen_status   pmax pmin  pc1  pc2 qc1min qc1max qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q  apf
mpc.gen = [
        1    0.0   0.0  100.0 -100.0    1.0    1.0          1    8.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
];

% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     2   1.0  0.0;
];

% f_bus t_bus    br_r   br_x  br_b rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.0001  0.000  0.00    100    100    100   0     0         1    -60     60;
];

mpc.time_elapsed = 1.0

%column_names% load_id e_nce_max p_red_max p_shift_up_max p_shift_down_max p_shift_down_tot_max t_grace_up t_grace_down cost_reduction cost_shift_up cost_shift_down cost_curt cost_inv flex co2_cost
mpc.load_extra = [
                     1    1000.0       1.0            0.0              0.0                  0.0          0            0           10.0           0.0             1.0     100.0       10    1      0.0;
];
