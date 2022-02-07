function mpc = case2_d_flex
mpc.version = '2';
mpc.baseMVA = 1.0;
mpc.time_elapsed = 1.0;

%% bus data
% bus_i bus_type    pd   qd   gs   gs area   vm   va base_kv zone  vmax  vmin
mpc.bus = [
      1        3  10.0  2.0  0.0  0.0    1  1.0  0.0    20.0    1  1.05  0.95;
      2        1   0.0  0.0  0.0  0.0    1  1.0  0.0    20.0    1  1.05  0.95;
];

%% generator data
% gen_bus    pg   qg  qmax   qmin   vg mbase gen_status  pmax pmin
mpc.gen = [
        1  10.0  0.0  10.0  -10.0  1.0   1.0          1  10.0  0.0;
];

% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     2  50.0  0.0;
];

%% branch data
% f_bus t_bus   br_r   br_x br_b rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.001  0.001  0.0   25.0   25.0   25.0 0.0   0.0         1  -60.0   60.0;
];

%% storage data
% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating  qmin qmax    r    x p_loss q_loss status
mpc.storage = [
            1  0.0  0.0    2.0           4.0           1.0              1.0               0.9                  0.9            2.0  -1.0  1.0  0.0  0.0    0.0    0.0      1;
];

%% storage additional data
%column_names% max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate
mpc.storage_extra = [
                                 0.0                      0.0                       0.0                1e-3;
];

%% candidate storage data
%column_names% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating  qmin qmax    r    x p_loss q_loss status max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate    eq_cost inst_cost co2_cost lifetime
mpc.ne_storage = [
                         1  0.0  0.0    2.0           4.0           1.0              1.0               0.9                  0.9            2.0  -1.0  1.0  0.0  0.0    0.0    0.0      1                   0.0                      0.0                       0.0                1e-3  1400000.0       0.0      0.0       10;
];

%% load additional data
%column_names% load_id pf_angle pshift_up_rel_max pshift_down_rel_max tshift_up tshift_down eshift_rel_max pred_rel_max ered_rel_max cost_shift_up cost_shift_down cost_red cost_curt  cost_inv flex co2_cost lifetime
mpc.load_extra = [
                     1   0.1974               0.5                 1.0         4           4            1.0         0.25         0.05           0.0            10.0    100.0   10000.0  100000.0    0      0.0       10;
];
