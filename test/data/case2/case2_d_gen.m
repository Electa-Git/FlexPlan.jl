function mpc = case2_d_gen
mpc.version = '2';
mpc.baseMVA = 1.0;
mpc.time_elapsed = 1.0;

%% bus data
% bus_i bus_type    pd   qd   gs   gs area   vm   va base_kv zone  vmax  vmin
mpc.bus = [
      1        3  10.0  2.0  0.0  0.0    1  1.0  0.0    20.0    1  1.05  0.95;
      2        1   0.0  0.0  0.0  0.0    1  1.0  0.0    20.0    1  1.05  0.95;
];

%% dispatchable generator data
% gen_bus    pg   qg  qmax   qmin   vg mbase gen_status  pmax pmin
mpc.gen = [
        1  10.0  0.0  10.0  -10.0  1.0   1.0          1  10.0  0.0;
];

% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     2  50.0  0.0;
];

%% non-dispatchable generator data
%column_names% gen_bus  pref  qmax   qmin gen_status cost_gen cost_curt
mpc.ndgen = [
                     1  10.0  10.0  -10.0          1     50.0    1000.0;
];

%% branch data
% f_bus t_bus   br_r   br_x br_b rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.001  0.001  0.0   25.0   25.0   25.0 0.0   0.0         1  -60.0   60.0;
];

%% load additional data
%column_names% load_id pf_angle pshift_up_rel_max pshift_down_rel_max tshift_up tshift_down eshift_rel_max pred_rel_max ered_rel_max cost_shift cost_red cost_curt  cost_inv flex co2_cost lifetime
mpc.load_extra = [
                     1   0.1974               0.5                 1.0         4           4            1.0         0.25         0.05       10.0    100.0   10000.0  100000.0    0      0.0       10;
];
