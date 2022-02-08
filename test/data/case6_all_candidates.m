% Garver system - Transmission Network Estimation Using Linear Programming, IEEE trans. on power appratus and sys
% Power system transmission network expansion planning using AC model by Rider, MJ and Garcia, AV and Romero, R
%modification: gen cost is changed. A low value is set to penalize power losses but not dominate the objective.
function mpc = case6
mpc.version = '2';
mpc.baseMVA = 100.0;

%% bus data
%   bus_i   type    Pd  Qd  Gs  Bs  area    Vm      Va  baseKV  zone    Vmax    Vmin lat lon
mpc.bus = [
    1    3   80    16    0.0     0.0      1     1.10000    -0.00000    240.0     1      1.05000     0.95000;
    2    1   240     48  0.0     0.0      1     0.92617     7.25883    240.0     1      1.05000     0.95000;
    3    2   40    8     0.0     0.0        1       0.90000    -17.26710     240.0   1      1.05000 0.95000;
    4    1   160     32  0.0     0.0      1     1.10000    -0.00000    240.0     1      1.05000     0.95000;
    5    1   240     48  0.0     0.0      1     0.92617     7.25883    240.0     1      1.05000     0.95000;
    6    2    0    0     0.0     0.0      1     0.90000    -17.26710     240.0   1      1.05000     0.95000;
];

%% generator data
%   bus Pg      Qg  Qmax    Qmin    Vg  mBase       status  Pmax    Pmin    pc1 pc2 qlcmin qlcmax qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q apf
mpc.gen = [
    1    148     54   48.0   -10.0   1.1         100.0   1   150.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
    3    170     -8  101.0   -10.0   0.92617     100.0   1   180.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
    3    170     -8  101.0   -10.0   0.92617     100.0   1   180.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
    6    0.0     -4  183.0   -10.0   0.9         100.0   1   120.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
    6    0.0     -4  183.0   -10.0   0.9         100.0   1   240.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
    6    0.0     -4  183.0   -10.0   0.9         100.0   1   240.0   0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0     0.0;
];

%column_names% gen_id emission_factor
mpc.generator_emission_factors = [
    1 0.1;
    2 0.1;
    3 0.0;
    4 0.1;
    5 0.0;
    6 0.0;
]

mpc.gencost = [
    2    0.0     0.0     3     0       0.02    0;
    2    0.0     0.0     3     0       0.02    0;
    2    0.0     0.0     3     0       0.01    0;
    2    0.0     0.0     3     0       0.02    0;
    2    0.0     0.0     3     0       0.01    0;
    2    0.0     0.0     3     0       0.01    0;
];

%% branch data
%   fbus    tbus    r   x   b   rateA   rateB   rateC   ratio   angle
%   status angmin angmax
mpc.branch = [
    1   2   0.040   0.400   0.00   100  100  100  0  0  1 -60  60;
    1   4   0.060   0.600   0.00   80   80   80   0  0  1 -60  60;
    2   3   0.020   0.200   0.00   100  100  100  0  0  1 -60  60;
    2   4   0.040   0.400   0.00   100  100  100  0  0  1 -60  60;
];
%column_names% f_bus    t_bus   br_r    br_x    br_b    rate_a  rate_b  rate_c  tap shift   br_status   angmin  angmax  construction_cost co2_cost lifetime
mpc.ne_branch = [
  1  3   0.020   0.200   0.00   100  100  100  0  0  1 -60  60 5 0.5 60;
  3  4   0.020   0.200   0.00   100  100  100  0  0  1 -60  60 3 0.5 60;
];


%% existing dc bus data
%column_names%   busdc_i grid    Pdc     Vdc     basekVdc    Vdcmax  Vdcmin Cdc
mpc.busdc = [
1              1       0       1       320         1.1     0.9  0;
2              1       0       1       320         1.1     0.9  0;
3              1       0       1       320         1.1     0.9  0;
4              1       0       1       320         1.1     0.9  0;
];

%% existing converters
%column_names%   busdc_i busac_i type_dc type_ac P_g   Q_g  islcc  Vtar rtf xtf  transformer tm   bf filter    rc      xc  reactor   basekVac Vmmax   Vmmin   Imax    status   LossA LossB  LossCrec LossCinv  droop Pdcset    Vdcset  dVdcset Pacmax Pacmin Qacmax Qacmin
mpc.convdc = [
1       5   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 110 -110 50 -50;
2       5   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 110 -110 50 -50;
3       1   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 110 -110 50 -50;
4       3   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 110 -110 50 -50;
];

%% existing dc branches
%column_names%   fbusdc  tbusdc  r      l        c   rateA   rateB   rateC status
mpc.branchdc = [
    1    3   0.01    0.00    0.00  100.0     0.0     0.0     1.0;
    2    4   0.01    0.00    0.00  100.0     0.0     0.0     1.0;
 ];

%% candidate dc bus data
%column_names%   busdc_i grid    Pdc     Vdc     basekVdc    Vdcmax  Vdcmin  Cdc
mpc.busdc_ne = [
5              1       0       1       320         1.1     0.9     0;
6              1       0       1       320         1.1     0.9     0;
7              1       0       1       320         1.1     0.9     0;
8              1       0       1       320         1.1     0.9     0;
];

%% candidate branches
%column_names%   fbusdc  tbusdc  r      l        c   rateA   rateB   rateC status cost co2_cost lifetime
mpc.branchdc_ne = [
    5    6   0.01    0.00    0.00  330.0     0.0     0.0     1.0     2.3 0.5 40;
    5    7   0.01    0.00    0.00  330.0     0.0     0.0     1.0     2   0.5 40;
    5    8   0.01    0.00    0.00  330.0     0.0     0.0     1.0     3.5 0.5 40;
 ];

%% candidate converters
%column_names%   busdc_i busac_i type_dc type_ac P_g   Q_g  islcc  Vtar rtf xtf  transformer tm   bf filter    rc      xc  reactor   basekVac Vmmax   Vmmin   Imax    status   LossA LossB  LossCrec LossCinv  droop Pdcset    Vdcset  dVdcset Pacmax Pacmin Qacmax Qacmin cost co2_cost lifetime
mpc.convdc_ne = [
5       6   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5 30;
5       6   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5 30;
5       6   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 660 -660 50 -50 5 0.5 30;
6       3   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  300         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5 30;
7       4   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5 30;
8       5   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5 30;
];

% hours
mpc.time_elapsed = 1.0

%% storage data
%   storage_bus ps qs energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  p_loss  q_loss  status
mpc.storage = [
     5   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250.0   -50.0   70.0    0.1     0.0     0.0     0.0     0;
];

%% storage additional data
%column_names%  max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate
mpc.storage_extra = [
2400 0 0 1e-4;
];


%% storage data
%column_names%   storage_bus ps qs energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  p_loss  q_loss  status eq_cost inst_cost co2_cost max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate lifetime
mpc.ne_storage = [
     2   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     2.5     0.5     1 2400 0 0 1e-4 10;
     5   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     2.5     0.5     1 2400 0 0 1e-4 10;
];



%% load additional data
%column_names% load_id ered_rel_max pred_rel_max pshift_up_rel_max pshift_down_rel_max tshift_up tshift_down cost_red cost_shift cost_curt cost_inv flex co2_cost lifetime
mpc.load_extra = [
1 1 1 0.3 0.3 2 2 0.1 0.00 10 0.0 1 0.5 10;
2 1 1 0.3 0.3 2 2 0.1 0.00 10 0.0 1 0.5 10;
3 1 1 0.3 0.3 2 2 0.1 0.00 10 0.0 1 0.5 10;
4 1 1 0.3 0.3 2 2 0.1 0.00 10 0.0 1 0.5 10;
5 1 1 0.3 0.3 2 2 0.1 0.00 10 0.0 1 0.5 10;
];
