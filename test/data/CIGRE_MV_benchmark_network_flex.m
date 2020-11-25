function mpc = CIGRE_MV_benchmark_network
% CIGRE_MV_BENCHMARK_NETWORK Returns MATPOWER case for the CIGRE medium-voltage benchmark network
% 
% References:
% [1] CIGRE TF C6.04.02, "Benchmark Systems for Network Integration of Renewable and Distributed 
% Energy Resources", CIGRE, Technical Brochure 575, 2014.
%
% EDITS:
% - branch data: angmin and angmax set to -60 and 60 degrees respectively to comply with
%   PowerModels' requirements.

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 1;

%% bus data
% bus_i type      pd       qd   gs   bs bus_area   vm   va base_kv zone    vmax    vmin
mpc.bus = [
     1    1   19.839    4.637    0    0        1    1    0      20    1    1.05    0.95;
     2    1    0.000    0.000    0    0        1    1    0      20    1    1.05    0.95;
     3    1    0.502    0.209    0    0        1    1    0      20    1    1.05    0.95;
     4    1    0.432    0.108    0    0        1    1    0      20    1    1.05    0.95;
     5    1    0.728    0.182    0    0        1    1    0      20    1    1.05    0.95;
     6    1    0.548    0.137    0    0        1    1    0      20    1    1.05    0.95;
     7    1    0.077    0.047    0    0        1    1    0      20    1    1.05    0.95;
     8    1    0.587    0.147    0    0        1    1    0      20    1    1.05    0.95;
     9    1    0.574    0.356    0    0        1    1    0      20    1    1.05    0.95;
    10    1    0.543    0.161    0    0        1    1    0      20    1    1.05    0.95;
    11    1    0.330    0.083    0    0        1    1    0      20    1    1.05    0.95;
    12    1   20.010    4.693    0    0        1    1    0      20    1    1.05    0.95;
    13    1    0.034    0.021    0    0        1    1    0      20    1    1.05    0.95;
    14    1    0.540    0.258    0    0        1    1    0      20    1    1.05    0.95;
    15    3    0.000    0.000    0    0        1    1    0     220    1    1.5     0.5 ;
];

%% generator data
% The last generator (bus 15) is a fictitious unit that represents the coupling with the HV network.
% gen_bus     pg     qg     qmax      qmin vg mBase gen_status    pmax     pmin pc1 pc2 qc1min qc1max qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q apf
mpc.gen = [
%        3  0.012  0.000    0.005    -0.005  1     1          1    0.02      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        4  0.012  0.000    0.005    -0.005  1     1          1    0.02      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        5  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        5  0.554  0.000    0.241    -0.241  1     1          1    0.60      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        5  0.013  0.000    0.006    -0.006  1     1          1    0.033     0.0   0   0      0      0      0      0        0       0       0      0   0;
%        6  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        7  1.500  0.000    0.654    -0.654  1     1          1    1.50      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        8  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        9  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        9  0.310  0.000    0.135    -0.135  1     1          1    0.31      0.0   0   0      0      0      0      0        0       0       0      0   0;
%        9  0.214  0.000    0.093    -0.093  1     1          1    0.212     0.0   0   0      0      0      0      0        0       0       0      0   0;
%       10  0.025  0.000    0.011    -0.011  1     1          1    0.04      0.0   0   0      0      0      0      0        0       0       0      0   0;
%       10  0.185  0.000    0.081    -0.081  1     1          1    0.20      0.0   0   0      0      0      0      0        0       0       0      0   0;
%       10  0.006  0.000    0.003    -0.003  1     1          1    0.014     0.0   0   0      0      0      0      0        0       0       0      0   0;
%       11  0.006  0.000    0.003    -0.003  1     1          1    0.01      0.0   0   0      0      0      0      0        0       0       0      0   0;
       15  0.000  0.000  100.0    -100.0    1     1          1  100.0    -100.0   0   0      0      0      0      0        0       0       0      0   0;
];

mpc.gencost = [
	2	 0.0	 0.0	 3	   0	   0.01    0;
];


%% branch data
% f_bus t_bus     br_r        br_x         br_b    rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.00353205   0.0050478   0.053572104   9      9      9     0     0         1    -60     60;
      2     3  0.00553605   0.0079118   0.083967624   9      9      9     0     0         1    -60     60;
      3     4  0.000764025  0.0010919   0.011588292   9      9      9     0     0         1    -60     60;
      4     5  0.0007014    0.0010024   0.010638432   9      9      9     0     0         1    -60     60;
      5     6  0.00192885   0.0027566   0.029255688   9      9      9     0     0         1    -60     60;
      6     7  0.0003006    0.0004296   0.004559328   9      9      9     0     0         0    -60     60;
      7     8  0.002091675  0.0029893   0.031725324   9      9      9     0     0         1    -60     60;
      8     9  0.0004008    0.0005728   0.006079104   9      9      9     0     0         1    -60     60;
      9    10  0.000964425  0.0013783   0.014627844   9      9      9     0     0         1    -60     60;
     10    11  0.000413325  0.0005907   0.006269076   9      9      9     0     0         1    -60     60;
     11     4  0.000613725  0.0008771   0.009308628   9      9      9     0     0         0    -60     60;
      3     8  0.00162825   0.002327    0.02469636    9      9      9     0     0         1    -60     60;
     12    13  0.006124725  0.00447435  0.006204432   7.5    7.5    7.5   0     0         1    -60     60;
     13    14  0.003744975  0.00273585  0.003793712   7.5    7.5    7.5   0     0         1    -60     60;
     14     8  0.002505     0.001830    0.0025376     7.5    7.5    7.5   0     0         0    -60     60;
     15     1  0.000475     0.004775    0.000000     25     25     25     1     0         1    -60     60;
     15    12  0.000475     0.004775    0.000000     25     25     25     1     0         1    -60     60;
];


%column_names% f_bus	t_bus	br_r	br_x	br_b	rate_a	rate_b	rate_c	tap	shift	br_status	angmin	angmax	construction_cost
mpc.ne_branch = [
	15	1	6.4e-05	0.00480000135	0	250	250	250	0	0	1	-360	360	5;
];

%% existing dc bus data
%column_names%   busdc_i grid    Pdc     Vdc     basekVdc    Vdcmax  Vdcmin Cdc
mpc.busdc = [
1              1       0       1       20         1.1     0.9  0;
2              1       0       1       20         1.1     0.9  0;
];

% existing converters
%column_names%   busdc_i busac_i type_dc type_ac P_g   Q_g  islcc  Vtar rtf xtf  transformer tm   bf filter    rc      xc  reactor   basekVac Vmmax   Vmmin   Imax    status   LossA LossB  LossCrec LossCinv  droop Pdcset    Vdcset  dVdcset Pacmax Pacmin Qacmax Qacmin
mpc.convdc = [
1       1   1       1       -360    -1.66   		0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1     	1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 110 -110 50 -50;
];

%% existing dc branches
%column_names%   fbusdc  tbusdc  r      l        c   rateA   rateB   rateC status
mpc.branchdc = [
	1	 2	 0.01	 0.00	 0.00  100.0	 0.0	 0.0	 1.0;
];

%% candidate dc bus data
%column_names%   busdc_i grid    Pdc     Vdc     basekVdc    Vdcmax  Vdcmin  Cdc
mpc.busdc_ne = [
3              1       0       1       20         1.1     0.9     0;
];

%% candidate dc branches
%column_names%   fbusdc  tbusdc  r      l        c   rateA   rateB   rateC status cost co2_cost
mpc.branchdc_ne = [
   1    3   0.01    0.00    0.00  330.0     0.0     0.0     1.0     2.3 0.5;
];

%% candidate converters
%column_names%   busdc_i busac_i type_dc type_ac P_g   Q_g  islcc  Vtar rtf xtf  transformer tm   bf filter    rc      xc  reactor   basekVac Vmmax   Vmmin   Imax    status   LossA LossB  LossCrec LossCinv  droop Pdcset    Vdcset  dVdcset Pacmax Pacmin Qacmax Qacmin cost co2_cost
mpc.convdc_ne = [
3       2   1       1       -360    -1.66           0 1.0        0.01  0.01 1 1 0.01 1 0.01   0.01 1  320         1.1     0.9     15     1      1.1033 0.887  2.885    2.885       0.0050    -52.7   1.0079   0 330 -330 50 -50 3 0.5;
];

%% storage data
%   storage_bus ps qs energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  p_loss  q_loss  status
mpc.storage = [
     5   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250.0   -50.0   70.0    0.1     0.0     0.0     0.0     0;
];

%% storage additional data
%column_names%  max_energy_absorption stationary_energy_inflow stationary_energy_outflow
mpc.storage_extra = [
2400 0 0;
];

%% candidate storage data
%column_names%   storage_bus ps qs energy  energy_rating charge_rating  discharge_rating  charge_efficiency  discharge_efficiency  thermal_rating  qmin  qmax  r  x  p_loss  q_loss  status eq_cost inst_cost co2_cost max_energy_absorption stationary_energy_inflow stationary_energy_outflow discharge_rate
mpc.ne_storage = [
    5   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     2.5     0.5     1 2400 0 0 0.001;
];

%% load additional data
%column_names% load_id e_nce_max p_red_max p_red_min p_shift_up_max p_shift_up_tot_max p_shift_down_max p_shift_down_tot_max t_grace_up t_grace_down cost_reduction cost_shift_up cost_shift_down cost_curt cost_inv flex co2_cost
mpc.load_extra = [
1 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
2 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
3 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
4 1000 0.5 0 0.5 1000 1.0 1000 10 10 0.1 0.00 0.00 10 0.0 1 0.5;
5 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
6 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
7 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
8 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
9 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
10 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
11 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
12 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
13 0 0 0 0 0 0 0 0 0 0 0 0 1 0 0 0.5;
];