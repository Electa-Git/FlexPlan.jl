% Transmission network
%
% Based on: Garver system - Transmission Network Estimation Using Linear Programming, IEEE trans. on
% power Apparatus and System.

function mpc = case6
mpc.version = '2';
mpc.baseMVA = 100.0;

%% bus data
% bus_i type   pd  qd   gs   bs bus_area     vm      va base_kv zone  vmax  vmin
mpc.bus = [
      1    3   80  16  0.0  0.0        1  1.100   -0.00   240.0    1  1.05  0.95;
      2    1  240  48  0.0  0.0        1  0.926    7.26   240.0    1  1.05  0.95;
      3    2   40   8  0.0  0.0        1  0.900  -17.27   240.0    1  1.05  0.95;
      4    1  160  32  0.0  0.0        1  1.100   -0.00   240.0    1  1.05  0.95;
      5    1  240  48  0.0  0.0        1  0.926    7.26   240.0    1  1.05  0.95;
      6    2    0   0  0.0  0.0        1  0.900  -17.27   240.0    1  1.05  0.95;
];

%% generator data
% gen_bus     pg    qg   qmax   qmin     vg  mBase gen_status   pmax pmin  pc1  pc2 qc1min qc1max qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q  apf
mpc.gen = [
        1  148.0  54.0   48.0  -10.0  1.1    100.0          1  150.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
        3  170.0  -8.0  101.0  -10.0  0.9    100.0          1  180.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
        3  170.0  -8.0  101.0  -10.0  0.9    100.0          1  180.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
        6    0.0  -4.0  183.0  -10.0  0.9    100.0          1  120.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
        6    0.0  -4.0  183.0  -10.0  0.9    100.0          1  240.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
        6    0.0  -4.0  183.0  -10.0  0.9    100.0          1  240.0  0.0  0.0  0.0    0.0    0.0    0.0    0.0      0.0     0.0     0.0    0.0  0.0;
];

%column_names% gen_id emission_factor
mpc.generator_emission_factors = [
                    1             0.1;
                    2             0.1;
                    3             0.0;
                    4             0.1;
                    5             0.0;
                    6             0.0;
]

% https://en.wikipedia.org/wiki/Cost_of_electricity_by_source
% Wind: 46$ -> 38.6 Euro / MWh 
% Solar: 51$ -> 42.8 Euro / MWh 
% Nat. Gas: 59$ -> 49.6 Euro / MWh 
% Coal: 112$ -> 94.1 Euro / MWh 

% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     2  49.6  0.0; % NG
      2     0.0      0.0     2  94.1  0.0; % Coal
      2     0.0      0.0     2  38.6  0.0; % Wind
      2     0.0      0.0     2  49.6  0.0; % NG
      2     0.0      0.0     2  38.6  0.0; % Wind
      2     0.0      0.0     2  42.8  0.0; % Solar
];

%% branch data
% f_bus t_bus   br_r   br_x  br_b rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.040  0.400  0.00    100    100    100   0     0         1    -60     60;
      1     4  0.060  0.600  0.00     80     80     80   0     0         1    -60     60;
      2     3  0.020  0.200  0.00     50     50     50   0     0         1    -60     60;
      2     4  0.040  0.400  0.00    100    100    100   0     0         1    -60     60;
];

% OHL costs approx. 1 MEuro/km for double circuit OHL 400 kV
% UGC cable cost approx. 4 MEuro / km for double circuit cable 400 kV

%column_names% f_bus t_bus   br_r   br_x  br_b rate_a rate_b rate_c tap shift br_status angmin angmax construction_cost co2_cost replace
mpc.ne_branch = [
                   1     3  0.020  0.200  0.00    100    100    100   0     0         1    -60     60         250000000        0       0;  % 250 km
                   3     4  0.020  0.200  0.00    100    100    100   0     0         1    -60     60         247000000        0       0;  % 247 km
                   4     6  0.020  0.200  0.00    100    100    100   0     0         1    -60     60         588000000        0       0;  % 382 km (straight for dc), 447 km over land
                   2     3  0.040  0.400  0.00    100    100    100   0     0         1    -60     60         508000000        0       1;  % 508 km
];


%% existing dc bus data
%column_names% busdc_i grid Pdc Vdc basekVdc Vdcmax Vdcmin Cdc
mpc.busdc = [
                     1    1   0   1      320    1.1    0.9   0;
                     2    1   0   1      320    1.1    0.9   0;
                     3    1   0   1      320    1.1    0.9   0;
                     4    1   0   1      320    1.1    0.9   0;
];

%% existing converters
%column_names% busdc_i busac_i type_dc type_ac   P_g    Q_g islcc Vtar   rtf   xtf transformer tm    bf filter    rc    xc reactor basekVac Vmmax Vmmin Imax  status   LossA  LossB LossCrec LossCinv   droop Pdcset  Vdcset dVdcset Pacmax Pacmin Qacmax Qacmin
mpc.convdc = [
                     1       5       3       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15       1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    110   -110     50    -50;
                     2       5       3       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15       1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    110   -110     50    -50;
                     3       1       2       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15       1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    110   -110     50    -50;
                     4       3       3       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15       1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    110   -110     50    -50;
];

%% existing dc branches
%column_names% fbusdc tbusdc     r     l     c  rateA rateB rateC status
mpc.branchdc = [
                    1      3  0.01  0.00  0.00  100.0   0.0   0.0    1.0;
                    2      4  0.01  0.00  0.00  100.0   0.0   0.0    1.0;
 ];

%% candidate dc bus data
%column_names% busdc_i grid Pdc Vdc basekVdc Vdcmax Vdcmin Cdc
mpc.busdc_ne = [
                     5    1   0   1      320    1.1    0.9   0;
                     6    1   0   1      320    1.1    0.9   0;
                     7    1   0   1      320    1.1    0.9   0;
                     8    1   0   1      320    1.1    0.9   0;
];

% dc cable cost: Land ~ 2.1 MEuro / km, submarine 1.7 MEuro 

%% candidate branches
%column_names% fbusdc tbusdc     r     l     c  rateA rateB rateC status       cost co2_cost
mpc.branchdc_ne = [
                    5      6  0.01  0.00  0.00  330.0   0.0   0.0    1.0  891000000      0.5;  % 345 + 145 km 
                    5      7  0.01  0.00  0.00  330.0   0.0   0.0    1.0  710200000      0.5;  % 230 + 152 km
                    5      8  0.01  0.00  0.00  330.0   0.0   0.0    1.0  977400000      0.5;  % 360 + 174 km 
 ];

%% candidate converters
%column_names% busdc_i busac_i type_dc type_ac   P_g    Q_g islcc Vtar   rtf   xtf transformer tm    bf filter    rc    xc reactor basekVac Vmmax Vmmin Imax status   LossA  LossB LossCrec LossCinv   droop Pdcset  Vdcset dVdcset Pacmax Pacmin Qacmax Qacmin      cost co2_cost
mpc.convdc_ne = [
                     5       6       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    330   -330     50    -50  40000000      0.5;
                     5       6       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    330   -330     50    -50  40000000      0.5;
                     5       6       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    660   -660     50    -50  80000000      0.5;
                     6       3       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      300   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    330   -330     50    -50  40000000      0.5;
                     7       4       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    330   -330     50    -50  40000000      0.5;
                     8       5       1       1  -360  -1.66     0  1.0  0.01  0.01           1  1  0.01      1  0.01  0.01       1      320   1.1   0.9   15      1  1.1033  0.887    2.885    2.885  0.0050  -52.7  1.0079       0    330   -330     50    -50  40000000      0.5;
];

% hours
mpc.time_elapsed = 1.0

%% storage data
% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating    qmin   qmax    r    x p_loss q_loss status
mpc.storage = [
            5  0.0  0.0    0.0        1000.0         250.0            250.0               0.9                  0.9          500.0  -250.0  250.0  0.0  0.0    0.0    0.0      0;
];

%% storage additional data
%column_names% max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate
mpc.storage_extra = [
                             2190000                        0                         0               0.001;
];

%% storage data
% Cost of battery storage: 350 k€/MWh
%column_names% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating    qmin   qmax    r    x p_loss q_loss status max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate    eq_cost inst_cost co2_cost
mpc.ne_storage = [
                         2  0.0  0.0    0.0        1000.0         250.0            250.0               0.9                  0.9          500.0  -250.0  250.0  0.0  0.0    0.0    0.0      1               2190000                        0                         0               0.001  350000000         0      0.0;
                         5  0.0  0.0    0.0        1000.0         250.0            250.0               0.9                  0.9          500.0  -250.0  250.0  0.0  0.0    0.0    0.0      1               2190000                        0                         0               0.001  350000000         0      0.0;
];


%% load additional data
% Investment cost: 1 k€/MW
%column_names% load_id e_nce_max p_red_max p_shift_up_max p_shift_down_max p_shift_down_tot_max t_grace_up t_grace_down cost_reduction cost_shift_up cost_shift_down cost_curt cost_inv flex co2_cost
mpc.load_extra = [
                     1       100       0.3            0.3              1.0                  100         10           10          100.0           0.0            10.0   10000.0    80000    1      0.0;
                     2       100       0.3            0.3              1.0                  100         10           10          100.0           0.0            10.0   10000.0   240000    1      0.0;
                     3       100       0.3            0.3              1.0                  100         10           10          100.0           0.0            10.0   10000.0    40000    1      0.0;
                     4       100       0.3            0.3              1.0                  100         10           10          100.0           0.0            10.0   10000.0   160000    1      0.0;
                     5       100       0.3            0.3              1.0                  100         10           10          100.0           0.0            10.0   10000.0   240000    1      0.0;
];
