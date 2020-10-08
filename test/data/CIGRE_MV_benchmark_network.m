function mpc = CIGRE_MV_benchmark_network
% CIGRE_MV_BENCHMARK_NETWORK Returns MATPOWER case for the CIGRE medium-voltage benchmark network
% 
% References:
% [1] K. Strunz, Ehsan Abbasi, Robert Fletcher, Nikos D. Hatziargyriou, Reza Iravani, and Géza Joos, 
% "TF C6.04.02?: TB 575 -- Benchmark Systems for Network Integration of Renewable and Distributed 
% Energy Resources", CIGRE, TF C6.04.02, 2014.
% [2] K. Rudion, A. Orths, Z. A. Styczynski, and K. Strunz, "Design of benchmark of medium voltage 
% distribution network for investigation of DG integration", in 2006 IEEE Power Engineering 
% Society General Meeting, Jun. 2006. DOI: 10.1109/PES.2006.1709447.
% [3] Fraunhofer IEE and University of Kassel, "CIGRE Networks", pandapower v2.4.0, 2020. 
% https://pandapower.readthedocs.io/en/v2.4.0/networks/cigre.html (accessed Oct. 07, 2020).
%
% TODO: Verify provenance of data set and consistency with original data set

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 25;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	15	3	0	0	0	0	1	1	0	110	1	1.06	0.94;
	1	1	19.839	4.63713605	0	0	1	1	0	20	1	1.06	0.94;
	2	1	0	0	0	0	1	1	0	20	1	1.06	0.94;
	3	1	0.5017	0.208882313	0	0	1	1	0	20	1	1.06	0.94;
	4	1	0.43165	0.108181687	0	0	1	1	0	20	1	1.06	0.94;
	5	1	0.7275	0.182328687	0	0	1	1	0	20	1	1.06	0.94;
	6	1	0.54805	0.137354277	0	0	1	1	0	20	1	1.06	0.94;
	7	1	0.0765	0.047410442	0	0	1	1	0	20	1	1.06	0.94;
	8	1	0.58685	0.147078474	0	0	1	1	0	20	1	1.06	0.94;
	9	1	0.57375	0.355578314	0	0	1	1	0	20	1	1.06	0.94;
	10	1	0.5433	0.161264024	0	0	1	1	0	20	1	1.06	0.94;
	11	1	0.3298	0.082655671	0	0	1	1	0	20	1	1.06	0.94;
	12	1	20.01	4.69334103	0	0	1	1	0	20	1	1.06	0.94;
	13	1	0.034	0.021071308	0	0	1	1	0	20	1	1.06	0.94;
	14	1	0.54005	0.257712805	0	0	1	1	0	20	1	1.06	0.94;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin	Pc1	Pc2	Qc1min	Qc1max	Qc2min	Qc2max	ramp_agc	ramp_10	ramp_30	ramp_q	apf
mpc.gen = [
	15	0	0	300	-300	1.035	100	1	805.2	0	0	0	0	0	0	0	0	0	0	0	0;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	2	0.04705625	0.035825	2e-05	0	0	0	0	0	1	-360	360;
	2	3	0.07375625	0.05615	2e-05	0	0	0	0	0	1	-360	360;
	3	4	0.01018125	0.00775	2e-05	0	0	0	0	0	1	-360	360;
	4	5	0.00934375	0.0071125	2e-05	0	0	0	0	0	1	-360	360;
	5	6	0.0257	0.0195625	2e-05	0	0	0	0	0	1	-360	360;
	6	7	0.00400625	0.00305	2e-05	0	0	0	0	0	1	-360	360;
	7	8	0.02786875	0.02099375	2e-05	0	0	0	0	0	1	-360	360;
	8	9	0.0053375	0.0040625	2e-05	0	0	0	0	0	1	-360	360;
	9	10	0.01285	0.00978125	2e-05	0	0	0	0	0	1	-360	360;
	10	11	0.00550625	0.00419375	2e-05	0	0	0	0	0	1	-360	360;
	11	4	0.008175	0.006225	2e-05	0	0	0	0	0	1	-360	360;
	3	8	0.02169375	0.0165125	2e-05	0	0	0	0	0	1	-360	360;
	12	13	0.139	0.1119625	0	0	0	0	0	0	1	-360	360;
	13	14	0.08499375	0.06845625	0	0	0	0	0	0	1	-360	360;
	14	8	0.05685	0.04579375	0	0	0	0	0	0	1	-360	360;
	15	1	0.001	0.12	0	0	0	0	1	0	1	-360	360;
	15	12	0.001	0.12	0	0	0	0	1	0	1	-360	360;
];

%%-----  OPF Data  -----%%
%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	0	0	3	0.01	40	0;
];
