function mpc = cigre_mv_eu_unit_test
% cigre_mv_eu_unit_test Returns MATPOWER case for the CIGRE medium-voltage benchmark network with edits
%
% References:
% [1] CIGRE TF C6.04.02, "Benchmark Systems for Network Integration of Renewable and
% Distributed Energy Resources", CIGRE, Technical Brochure 575, 2014.
%
% EDITS:
% - branch: angmin and angmax set to -60 and 60 degrees respectively to comply with
%   PowerModels' requirements;
% - generator: batteries are not considered;
% - added generator cost data: linear in active power, zero-cost reactive power, equal
%   prices for distributed generators, grid exchanges cost twice;
% - a fixed 1.0 tap ratio is assigned to the transformer of branch 17;
% - added candidate branches:
%   | id |  buses  | branch type |    investment type   |
%   |----|---------|-------------|----------------------|
%   |  1 | (15, 1) | transformer |      replacement     |
%   |  2 | (15,12) | transformer | addition in parallel |
%   |  3 | (12,13) |     line    |      replacement     |
%   |  4 | (12,13) |     line    |      replacement     |
%   |  5 | (13,14) |     line    | addition in parallel |
% - 2 MVDC converters are attached to bus 1 and 12, respectively, and connected through a DC
%   branch using a symmetric monopolar configuration;
% - 1 candidate MVDC converter is placed at bus 12 and connected to the converter at bus 1
%   through a candidate DC branch using a symmetric monopolar configuration;
% - the investment costs are scaled down to represent a single hour for the purpose of using
%   this test case in a single-period optimization.

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 1.0;

%% conversion ratio between energy and power
mpc.time_elapsed = 1.0

%% bus data
% bus_i type      pd       qd   gs   bs bus_area   vm   va base_kv zone    vmax    vmin
mpc.bus = [
     1    1   19.839    4.637    0    0        1    1    0      20    1    1.05    0.95;
     2    1    0.000    0.000    0    0        1    1    0      20    1    1.05    0.95;
     3    2    0.502    0.209    0    0        1    1    0      20    1    1.05    0.95;
     4    2    0.432    0.108    0    0        1    1    0      20    1    1.05    0.95;
     5    2    0.728    0.182    0    0        1    1    0      20    1    1.05    0.95;
     6    2    0.548    0.137    0    0        1    1    0      20    1    1.05    0.95;
     7    2    0.077    0.047    0    0        1    1    0      20    1    1.05    0.95;
     8    2    0.587    0.147    0    0        1    1    0      20    1    1.05    0.95;
     9    2    0.574    0.356    0    0        1    1    0      20    1    1.05    0.95;
    10    2    0.543    0.161    0    0        1    1    0      20    1    1.05    0.95;
    11    2    0.330    0.083    0    0        1    1    0      20    1    1.05    0.95;
    12    1   20.010    4.693    0    0        1    1    0      20    1    1.05    0.95;
    13    1    0.034    0.021    0    0        1    1    0      20    1    1.05    0.95;
    14    1    0.540    0.258    0    0        1    1    0      20    1    1.05    0.95;
    15    3    0.000    0.000    0    0        1    1    0     220    1    1.00    1.00;
];

%% generator data
% The last generator (bus 15) is a fictitious unit that represents the coupling with the HV network.
% gen_bus     pg     qg     qmax      qmin vg mBase gen_status    pmax     pmin pc1 pc2 qc1min qc1max qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q apf
mpc.gen = [
        3  0.012  0.000    0.005    -0.005  1     1          1    0.02      0.0   0   0      0      0      0      0        0       0       0      0   0;
        4  0.012  0.000    0.005    -0.005  1     1          1    0.02      0.0   0   0      0      0      0      0        0       0       0      0   0;
        5  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
        5  0.013  0.000    0.006    -0.006  1     1          1    0.033     0.0   0   0      0      0      0      0        0       0       0      0   0;
        6  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
        7  1.500  0.000    0.654    -0.654  1     1          1    1.50      0.0   0   0      0      0      0      0        0       0       0      0   0;
        8  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
        9  0.019  0.000    0.008    -0.008  1     1          1    0.03      0.0   0   0      0      0      0      0        0       0       0      0   0;
        9  0.310  0.000    0.135    -0.135  1     1          1    0.31      0.0   0   0      0      0      0      0        0       0       0      0   0;
        9  0.214  0.000    0.093    -0.093  1     1          1    0.212     0.0   0   0      0      0      0      0        0       0       0      0   0;
       10  0.025  0.000    0.011    -0.011  1     1          1    0.04      0.0   0   0      0      0      0      0        0       0       0      0   0;
       10  0.006  0.000    0.003    -0.003  1     1          1    0.014     0.0   0   0      0      0      0      0        0       0       0      0   0;
       11  0.006  0.000    0.003    -0.003  1     1          1    0.01      0.0   0   0      0      0      0      0        0       0       0      0   0;
       15  0.000  0.000  100.0    -100.0    1     1          1  100.0    -100.0   0   0      0      0      0      0        0       0       0      0   0;
];

%% generator cost data
% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2   50.0  0.0;
      2     0.0      0.0     2  100.0  0.0;
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

%% add new columns to "branch" table
%column_names% tm_min tm_max
mpc.branch_oltc = [
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.0    0.0;
                  0.9    1.1;
                  1.0    1.0;
];

%% network expansion branch data
%column_names% f_bus t_bus     br_r       br_x         br_b    rate_a rate_b rate_c tap shift br_status angmin angmax construction_cost replace tm_min tm_max lifetime
mpc.ne_branch = [
                  15     1  0.0002375   0.0023875   0.000000     50     50     50     1     0         1    -60     60              0.8        1    0.9    1.1       30;
                  15    12  0.000475    0.004775    0.000000     25     25     25     1     0         1    -60     60              0.75       0    1.0    1.0       30;
                  12    13  0.003062363 0.002237175 0.003102216  15     15     15     0     0         1    -60     60              0.73       1    0.0    0.0       60;
                  12    13  0.003062363 0.002237175 0.003102216  15     15     15     0     0         1    -60     60              0.78       1    0.0    0.0       60;
                  13    14  0.003744975 0.00273585  0.003793712   7.5    7.5    7.5   0     0         1    -60     60              0.45       0    0.0    0.0       60;
];

%% existing DC buses
%column_names% busdc_i grid Pdc Vdc basekVdc Vdcmax Vdcmin Cdc
mpc.busdc = [
                     1    1   0   1       15    1.1    0.9   0;
                     2    1   0   1       15    1.1    0.9   0;
];

%% candidate DC buses
%column_names% busdc_i grid Pdc Vdc basekVdc Vdcmax Vdcmin Cdc
mpc.busdc_ne = [
                     3    1   0   1       15    1.1    0.9   0;
];

%% existing DC branches
%column_names% fbusdc tbusdc      r     l     c  rateA rateB rateC status
mpc.branchdc = [
                    1      2  0.015  0.00  0.00   25.0   0.0   0.0      1;
];

%% candidate DC branches
%column_names% fbusdc tbusdc      r     l     c  rateA rateB rateC status    cost co2_cost lifetime
mpc.branchdc_ne = [
                    1      3   0.01  0.00  0.00   25.0   0.0   0.0      1    1.43      0.0       40; % Cost: 50 k€/km, 10 km length
];

%% existing converters
%column_names% busdc_i busac_i type_dc type_ac  P_g  Q_g islcc Vtar    rtf   xtf transformer tm    bf filter     rc    xc reactor basekVac Vmmax Vmmin  Imax status  LossA LossB LossCrec LossCinv  droop Pdcset Vdcset dVdcset Pacmax Pacmin Qacmax Qacmin
mpc.convdc = [
                     1       1       2       1  0.0  0.0     0  1.0  0.001  0.02           1  1  0.05      1  0.001  0.02       1       15   1.1   0.9  70.8      1  0.05    0.1     0.04     0.04  0.005    0.0    1.0     0.0     50    -50     50    -50;
                     2      12       3       1  0.0  0.0     0  1.0  0.001  0.02           1  1  0.05      1  0.001  0.02       1       15   1.1   0.9  35.4      1  0.025   0.1     0.08     0.08  0.005    0.0    1.0     0.0     25    -25     25    -25;
];

%% candidate converters
%column_names% busdc_i busac_i type_dc type_ac  P_g  Q_g islcc Vtar    rtf   xtf transformer tm    bf filter     rc    xc reactor basekVac Vmmax Vmmin  Imax status  LossA LossB LossCrec LossCinv  droop Pdcset Vdcset dVdcset Pacmax Pacmin Qacmax Qacmin   cost co2_cost lifetime
mpc.convdc_ne = [
                     3      12       3       1  0.0  0.0     0  1.0  0.001  0.02           1  1  0.05      1  0.001  0.02       1       15   1.1   0.9  35.4      1  0.025   0.1     0.08     0.08  0.005    0.0    1.0     0.0     25    -25     25    -25  28.54        0       20; % Cost: 100 k€/MW
];

%% flexible load data
%column_names% load_id pf_angle ered_rel_max pred_rel_max pshift_up_rel_max pshift_down_rel_max eshift_rel_max tshift_up tshift_down cost_red cost_shift cost_curt cost_inv flex co2_cost lifetime
mpc.load_extra = [
                     1    0.230          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     2    0.395          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     3    0.245          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     4    0.245          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     5    0.245          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     6    0.548          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     7    0.245          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     8    0.555          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                     9    0.288          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                    10    0.246          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                    11    0.230          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                    12    0.553          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
                    13    0.446          0.0          0.0               0.0                 0.0            0.0         0           0      0.0        0.0   10000.0        0    0      0.0       10;
];
