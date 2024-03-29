% Distribution network
%
% Based on: CIGRE TF C6.04.02, "Benchmark Systems for Network Integration of Renewable and
% Distributed Energy Resources", CIGRE, Technical Brochure 575, 2014.

function mpc = cigre
mpc.version = '2';
mpc.baseMVA = 1.0;

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
    15    3    0.000    0.000    0    0        1    1    0     240    1    1.00    1.00;
];

%% dispatchable generator data
% gen_bus   pg   qg     qmax      qmin vg mBase gen_status     pmax      pmin
mpc.gen = [
       15  0.0  0.0  100.000  -100.000  1     1          1  100.000  -100.000; % slack
];

% model startup shutdown ncost  cost
mpc.gencost = [
      2     0.0      0.0     0    0.0  0.0;
];

%% non-dispatchable generator data
%column_names% gen_bus   pref   qmax    qmin gen_status cost_gen cost_curt
mpc.ndgen = [
                     3  0.020  0.020  -0.020          1     50.0    1000.0; % pv
                     4  0.020  0.020  -0.020          1     50.0    1000.0; % pv
                     5  0.030  0.030  -0.030          1     50.0    1000.0; % pv
                     5  0.033  0.033  -0.033          1     50.0    1000.0; % fuel_cell
                     6  0.030  0.030  -0.030          1     50.0    1000.0; % pv
                     7  1.500  1.500  -1.500          1     50.0    1000.0; % wind
                     8  0.030  0.030  -0.030          1     50.0    1000.0; % pv
                     9  0.030  0.030  -0.030          1     50.0    1000.0; % pv
                     9  0.310  0.310  -0.310          1     50.0    1000.0; % chp_diesel
                     9  0.212  0.212  -0.212          1     50.0    1000.0; % chp_fuel_cell
                    10  0.040  0.040  -0.040          1     50.0    1000.0; % pv
                    10  0.014  0.014  -0.014          1     50.0    1000.0; % fuel_cell
                    11  0.010  0.010  -0.010          1     50.0    1000.0; % pv
];

%% branch data
% UGC: max current 285 A, rated at 2/3 of max current, <http://www.allkabel.eu/high-voltage-cables-3630-kv-na2xs2y-12-20-kv/>
% f_bus t_bus     br_r     br_x     br_b rate_a rate_b rate_c tap shift br_status angmin angmax
mpc.branch = [
      1     2  0.00353  0.00505  0.05357    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      2     3  0.00554  0.00791  0.08397    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      3     4  0.00076  0.00109  0.01159    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      4     5  0.00070  0.00100  0.01064    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      5     6  0.00193  0.00276  0.02926    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      6     7  0.00030  0.00043  0.00456    6.5    6.5    6.5   0     0         0    -60     60; % UGC
      7     8  0.00209  0.00299  0.03173    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      8     9  0.00040  0.00057  0.00608    6.5    6.5    6.5   0     0         1    -60     60; % UGC
      9    10  0.00096  0.00138  0.01463    6.5    6.5    6.5   0     0         1    -60     60; % UGC
     10    11  0.00041  0.00059  0.00627    6.5    6.5    6.5   0     0         1    -60     60; % UGC
     11     4  0.00061  0.00088  0.00931    6.5    6.5    6.5   0     0         0    -60     60; % UGC
      3     8  0.00163  0.00233  0.02470    6.5    6.5    6.5   0     0         1    -60     60; % UGC
     12    13  0.00612  0.00447  0.00620    5.5    5.5    5.5   0     0         1    -60     60; % OHL
     13    14  0.00374  0.00274  0.00379    5.5    5.5    5.5   0     0         1    -60     60; % OHL
     14     8  0.00251  0.00183  0.00254    5.5    5.5    5.5   0     0         0    -60     60; % OHL
     15     1  0.00048  0.00478  0.00000   25.0   25.0   25.0   1     0         1    -60     60; % transformer with OLTC
     15    12  0.00048  0.00478  0.00000   25.0   25.0   25.0   1     0         1    -60     60; % transformer with OLTC
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
                  0.9    1.1;
];

%% network expansion branch data
% UGC cost: 150 k€/km
% OHL cost:  60 k€/km
% OLTC cost:  5 k€/MVA + 100 k€
%column_names% f_bus t_bus     br_r     br_x     br_b rate_a rate_b rate_c tap shift br_status angmin angmax construction_cost replace tm_min tm_max lifetime
mpc.ne_branch = [
                   1     2  0.00177  0.00505  0.05357   13.0   13.0   13.0   0     0         1    -60     60            423000       1    0.0    0.0       40; % UGC
                   2     3  0.00277  0.00791  0.08397   13.0   13.0   13.0   0     0         1    -60     60            663000       1    0.0    0.0       40; % UGC
                   3     4  0.00038  0.00109  0.01159   13.0   13.0   13.0   0     0         1    -60     60             91500       1    0.0    0.0       40; % UGC
                   4     5  0.00035  0.00100  0.01064   13.0   13.0   13.0   0     0         1    -60     60             84000       1    0.0    0.0       40; % UGC
                   5     6  0.00097  0.00276  0.02926   13.0   13.0   13.0   0     0         1    -60     60            231000       1    0.0    0.0       40; % UGC
                   6     7  0.00015  0.00043  0.00456   13.0   13.0   13.0   0     0         0    -60     60             36000       1    0.0    0.0       40; % UGC
                   7     8  0.00105  0.00299  0.03173   13.0   13.0   13.0   0     0         1    -60     60            250500       1    0.0    0.0       40; % UGC
                   8     9  0.00020  0.00057  0.00608   13.0   13.0   13.0   0     0         1    -60     60             48000       1    0.0    0.0       40; % UGC
                   9    10  0.00048  0.00138  0.01463   13.0   13.0   13.0   0     0         1    -60     60            115500       1    0.0    0.0       40; % UGC
                  10    11  0.00021  0.00059  0.00627   13.0   13.0   13.0   0     0         1    -60     60             49500       1    0.0    0.0       40; % UGC
                  11     4  0.00031  0.00088  0.00931   13.0   13.0   13.0   0     0         0    -60     60             73500       1    0.0    0.0       40; % UGC
                   3     8  0.00082  0.00233  0.02470   13.0   13.0   13.0   0     0         1    -60     60            195000       1    0.0    0.0       40; % UGC
                  12    13  0.00306  0.00447  0.00620   11.0   11.0   11.0   0     0         1    -60     60            293400       1    0.0    0.0       60; % OHL
                  13    14  0.00187  0.00274  0.00379   11.0   11.0   11.0   0     0         1    -60     60            179400       1    0.0    0.0       60; % OHL
                  14     8  0.00126  0.00183  0.00254   11.0   11.0   11.0   0     0         0    -60     60            120000       1    0.0    0.0       60; % OHL
                  15     1  0.00024  0.00478  0.00000   50.0   50.0   50.0   1     0         1    -60     60            350000       1    0.9    1.1       30; % transformer with OLTC
                  15    12  0.00024  0.00478  0.00000   50.0   50.0   50.0   1     0         1    -60     60            350000       1    0.9    1.1       30; % transformer with OLTC
];

% hours
mpc.time_elapsed = 1.0

%% storage data
% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating    qmin   qmax    r    x p_loss q_loss status
mpc.storage = [
            5  0.0  0.0    0.0         1.200         0.600            0.600               0.9                  0.9          1.200  -0.600  0.600  0.0  0.0    0.0    0.0      1;
           10  0.0  0.0    0.0         0.400         0.200            0.200               0.9                  0.9          0.400  -0.200  0.200  0.0  0.0    0.0    0.0      1;
           14  0.0  0.0    0.0         2.000         1.000            1.000               0.9                  0.9          2.000  -1.000  1.000  0.0  0.0    0.0    0.0      1;
];

%% storage additional data
%column_names% max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate
mpc.storage_extra = [
                                5256                        0                         0               0.001;
                                1752                        0                         0               0.001;
                                8760                        0                         0               0.001;
];

%% ne_storage data
% Cost of battery storage: 350 k€/MWh
%column_names% storage_bus   ps   qs energy energy_rating charge_rating discharge_rating charge_efficiency discharge_efficiency thermal_rating    qmin   qmax    r    x p_loss q_loss status max_energy_absorption stationary_energy_inflow stationary_energy_outflow self_discharge_rate eq_cost inst_cost co2_cost lifetime
mpc.ne_storage = [
                         5  0.0  0.0    0.0         1.200         0.600            0.600               0.9                  0.9          1.200  -0.600  0.600  0.0  0.0    0.0    0.0      1                  5256                        0                         0               0.001  420000         0      0.0       10;
                        10  0.0  0.0    0.0         0.400         0.200            0.200               0.9                  0.9          0.400  -0.200  0.200  0.0  0.0    0.0    0.0      1                  1752                        0                         0               0.001  140000         0      0.0       10;
                        14  0.0  0.0    0.0         2.000         1.000            1.000               0.9                  0.9          2.000  -1.000  1.000  0.0  0.0    0.0    0.0      1                  8760                        0                         0               0.001  700000         0      0.0       10;
];

%% flexible load data
% Investment cost: 1 k€/MW
%column_names% load_id pf_angle ered_rel_max pred_rel_max pshift_up_rel_max pshift_down_rel_max eshift_rel_max tshift_up tshift_down cost_red cost_shift cost_curt cost_inv flex co2_cost lifetime
mpc.load_extra = [
                     1    0.230          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0    19839    1      0.0       10;
                     2    0.395          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      502    1      0.0       10;
                     3    0.245          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      432    1      0.0       10;
                     4    0.245          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      728    1      0.0       10;
                     5    0.245          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      548    1      0.0       10;
                     6    0.548          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      077    1      0.0       10;
                     7    0.245          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      587    1      0.0       10;
                     8    0.555          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      574    1      0.0       10;
                     9    0.288          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      543    1      0.0       10;
                    10    0.246          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      330    1      0.0       10;
                    11    0.230          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0    20010    1      0.0       10;
                    12    0.553          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      034    1      0.0       10;
                    13    0.446          1.0          0.2               0.5                 0.5            1.0        10          10    100.0       10.0   10000.0      540    1      0.0       10;
];
