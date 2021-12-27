function mpc = case67_tnep_2040
%CASE67_TNEP_2040

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	1	3	0	0	0	0	1	1	0	380	1	1.1	0.9;
	2	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	3	1	0	0	0	0	1	1	0	380	1	1.1	0.9;
	4	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	5	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	6	1	630.3	76	0	0	1	1	0	380	1	1.1	0.9;
	7	1	0	0	0	0	1	1	0	380	1	1.1	0.9;
	8	1	947.1	73	0	0	1	1	0	380	1	1.1	0.9;
	9	1	613.8	74	0	0	1	1	0	380	1	1.1	0.9;
	10	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	11	1	894.3	55	0	0	1	1	0	380	1	1.1	0.9;
	12	1	564.3	87	0	0	1	1	0	380	1	1.1	0.9;
	13	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	14	1	656.7	60	0	0	1	1	0	380	1	1.1	0.9;
	15	1	372.9	52.5	0	0	1	1	0	380	1	1.1	0.9;
	16	1	125.4	7	0	0	1	1	0	380	1	1.1	0.9;
	17	1	907.5	106	0	0	1	1	0	380	1	1.1	0.9;
	18	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	19	1	544.5	46	0	0	1	1	0	380	1	1.1	0.9;
	20	1	587.4	82.5	0	0	1	1	0	380	1	1.1	0.9;
	21	1	0	0	0	0	1	1	0	380	1	1.1	0.9;
	22	1	99	7	0	0	1	1	0	380	1	1.1	0.9;
	23	1	0	0	0	0	1	1	0	380	1	1.1	0.9;
	24	1	105.6	7	0	0	1	1	0	380	1	1.1	0.9;
	25	2	0	0	0	0	1	1	0	380	1	1.1	0.9;
	26	1	1303.5	89	0	0	2	1	0	380	1	1.1	0.9;
	27	1	0	0	0	0	2	1	0	380	1	1.1	0.9;
	28	1	2194.5	99	0	0	2	1	0	380	1	1.1	0.9;
	29	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	30	1	877.8	100	0	0	2	1	0	380	1	1.1	0.9;
	31	1	2788.5	119	0	0	2	1	0	380	1	1.1	0.9;
	32	1	1095.6	137	0	0	2	1	0	380	1	1.1	0.9;
	33	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	34	1	1782	158	0	0	2	1	0	380	1	1.1	0.9;
	35	1	1518	97	0	0	2	1	0	380	1	1.1	0.9;
	36	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	37	1	1488.3	190	0	0	2	1	0	380	1	1.1	0.9;
	38	1	495	0	0	0	2	1	0	380	1	1.1	0.9;
	39	1	2075.7	87	0	0	2	1	0	380	1	1.1	0.9;
	40	1	0	0	0	0	2	1	0	380	1	1.1	0.9;
	41	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	42	1	2834.7	180	0	0	2	1	0	380	1	1.1	0.9;
	43	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	44	1	1564.2	92	0	0	2	1	0	380	1	1.1	0.9;
	45	1	2204.4	109	0	0	2	1	0	380	1	1.1	0.9;
	46	1	2026.2	95	0	0	2	1	0	380	1	1.1	0.9;
	47	1	267.3	0	0	0	2	1	0	380	1	1.1	0.9;
	48	1	0	0	0	0	2	1	0	380	1	1.1	0.9;
	49	1	0	0	0	0	2	1	0	380	1	1.1	0.9;
	50	2	0	0	0	0	2	1	0	380	1	1.1	0.9;
	51	1	1419	123	0	0	3	1	0	380	1	1.1	0.9;
	52	1	1019.7	102	0	0	3	1	0	380	1	1.1	0.9;
	53	1	330	30	0	0	3	1	0	380	1	1.1	0.9;
	54	1	0	0	0	0	3	1	0	380	1	1.1	0.9;
	55	1	999.9	110	0	0	3	1	0	380	1	1.1	0.9;
	56	2	0	0	0	0	3	1	0	380	1	1.1	0.9;
	57	1	0	0	0	0	3	1	0	380	1	1.1	0.9;
	58	1	1069.2	157	0	0	3	1	0	380	1	1.1	0.9;
	59	2	0	0	0	0	3	1	0	380	1	1.1	0.9;
	60	1	379.5	42	0	0	3	1	0	380	1	1.1	0.9;
	61	1	617.1	75	0	0	3	1	0	380	1	1.1	0.9;
	62	1	1052.7	95	0	0	3	1	0	380	1	1.1	0.9;
	63	2	0	0	0	0	3	1	0	380	1	1.1	0.9;
	64	2	0	0	0	0	3	1	0	380	1	1.1	0.9;
	65	1	1039.5	97	0	0	3	1	0	380	1	1.1	0.9;
	66	2	0	0	0	0	3	1	0	380	1	1.1	0.9;
	67	2	0	0	0	0	4	1	0	380	1	1.1	0.9;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin	Pc1	Pc2	Qc1min	Qc1max	Qc2min	Qc2max	ramp_agc	ramp_10	ramp_30	ramp_q	apf
mpc.gen = [
	1	700	23	1000	-500	1.0526	100	1	3000	0	0	0	0	0	0	0	0	0	0	0	0;
	2	1500	100	100	100	1.0526	100	1	4500	0	0	0	0	0	0	0	0	0	0	0	0;
	4	523	140	350	-350	1.0526	100	1	1680	0	0	0	0	0	0	0	0	0	0	0	0;
	5	1200	100	100	100	1.0526	100	1	3600	0	0	0	0	0	0	0	0	0	0	0	0;
	10	436	105	350	-350	1.0526	100	1	1680	0	0	0	0	0	0	0	0	0	0	0	0;
	13	541	117	300	-300	1.0526	100	1	1890	0	0	0	0	0	0	0	0	0	0	0	0;
	18	681	-35	400	-400	1.0263	100	1	2160	0	0	0	0	0	0	0	0	0	0	0	0;
	25	469	59	250	-250	1.0395	100	1	1680	0	0	0	0	0	0	0	0	0	0	0	0;
	29	500	101	350	-350	1.0263	100	1	1890	0	0	0	0	0	0	0	0	0	0	0	0;
	33	496	306	500	-500	1.0263	100	1	3060	0	0	0	0	0	0	0	0	0	0	0	0;
	36	512	249	400	-400	1.0263	100	1	2160	0	0	0	0	0	0	0	0	0	0	0	0;
	41	350	238	450	-450	1.0395	100	1	2550	0	0	0	0	0	0	0	0	0	0	0	0;
	43	574	223	500	-250	1.0263	100	1	2160	0	0	0	0	0	0	0	0	0	0	0	0;
	50	581	150	400	-400	1.0395	100	1	2160	0	0	0	0	0	0	0	0	0	0	0	0;
	56	496	56	250	-250	1.0395	100	1	1680	0	0	0	0	0	0	0	0	0	0	0	0;
	59	431	206	350	-350	1.0447	100	1	2160	0	0	0	0	0	0	0	0	0	0	0	0;
	63	488	152	250	-300	1.0447	100	1	1560	0	0	0	0	0	0	0	0	0	0	0	0;
	64	300	61	250	-400	1.0474	100	1	1680	0	0	0	0	0	0	0	0	0	0	0	0;
	66	537	143	300	-400	1.0447	100	1	1890	0	0	0	0	0	0	0	0	0	0	0	0;
	67	800	0	0	0	1.0526	100	1	2400	0	0	0	0	0	0	0	0	0	0	0	0;
	23	800	0	0	0	1.0526	100	1	2400	0	0	0	0	0	0	0	0	0	0	0	0;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	5	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	1	7	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	1	8	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	1	14	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	2	3	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	2	9	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	2	12	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	3	4	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	3	10	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	3	12	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	3	9	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	4	14	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	4	19	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	5	6	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	5	7	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	5	8	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	6	7	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	7	15	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	7	16	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	8	9	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	10	11	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	10	22	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	11	12	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	11	13	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	12	13	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	13	53	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	14	15	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	14	18	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	16	17	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	16	18	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	17	24	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	18	24	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	19	20	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	19	23	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	20	21	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	21	25	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	21	22	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	21	23	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	22	25	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	18	20	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	24	49	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	25	43	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	26	27	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	26	31	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	26	40	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	27	28	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	28	35	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	28	37	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	29	39	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	29	44	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	30	31	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	31	27	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	30	26	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	32	40	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	41	40	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	43	44	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	33	51	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	33	34	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	34	51	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	35	33	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	35	36	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	35	47	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	29	35	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	36	37	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	36	38	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	37	38	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	39	40	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	39	43	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	41	42	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	42	43	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	42	49	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	43	49	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	44	45	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	44	48	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	45	46	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	45	50	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	47	48	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	46	48	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	47	50	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	47	51	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	47	59	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	52	53	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	52	54	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	63	55	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	22	56	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	54	65	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	55	57	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	58	61	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	56	59	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	57	58	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	56	58	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	58	60	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	62	66	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	61	62	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	52	64	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	62	63	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	59	60	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	63	57	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	65	66	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	66	54	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	66	64	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
	30	32	0.00207756	0.01800554	0.61242207	900	900	900	0	0	1	-30	30;
];

%%-----  OPF Data  -----%%
%% area data
%	area	refbus
mpc.areas = [
	1	2;
];

%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	0	0	2	8	0;
	2	0	0	2	5	0;
	2	0	0	2	8	0;
	2	0	0	2	5	0;
	2	0	0	2	8	0;
	2	0	0	2	8	0;
	2	0	0	2	8	0;
	2	0	0	2	8	0;
	2	0	0	2	40	0;
	2	0	0	2	40	0;
	2	0	0	2	40	0;
	2	0	0	2	40	0;
	2	0	0	2	40	0;
	2	0	0	2	40	0;
	2	0	0	2	20	0;
	2	0	0	2	20	0;
	2	0	0	2	20	0;
	2	0	0	2	20	0;
	2	0	0	2	20	0;
	2	0	0	2	5	0;
	2	0	0	2	5	0;
];

%% dc grid topology
%colunm_names% dcpoles
mpc.dcpol=2;
% numbers of poles (1=monopolar grid, 2=bipolar grid)
%% bus data
%column_names%   busdc_i  grid    Pdc     Vdc     basekVdc  Vdcmax  Vdcmin  Cdc
mpc.busdc = [
    			1       1       0       1       500       1.05     0.95     0;
    			2       1       0       1       500       1.05     0.95     0;
];

%% converters
%column_names%    busdc_i busac_i type_dc type_ac P_g   Q_g   islcc  Vtar   rtf 	xtf  transformer tm   bf 	filter    rc     xc   reactor   basekVac   Vmmax   Vmmin      Imax    status   LossA  LossB  LossCrec LossCinv  droop      Pdcset    Vdcset  dVdcset Pacmax  Pacmin   Qacmax  Qacmin
mpc.convdc = [
    				1       7   		2       1       -550   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000  	-2000  		1000 		-1000;
					2       40   		3       1       1000   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000  		1000 		-1000;
];


%% branches
%column_names%   fbusdc  tbusdc  r        l   c   rateA   rateB   rateC   status
mpc.branchdc = [
    				1       2       0.0012   0   0   1575    1575    1575     1;
 ];

%column_names%   busdc_i  grid    Pdc     Vdc     basekVdc  Vdcmax  Vdcmin  Cdc
mpc.busdc_ne = [
				3       1       0       1       500       1.05     0.95     0;
				4       1       0       1       500       1.05     0.95     0;
				5       1       0       1       500       1.05     0.95     0;
				6       1       0       1       500       1.05     0.95     0;
				7       1       0       1       500       1.05     0.95     0;
				8       1       0       1       500       1.05     0.95     0;
				9       1       0       1       500       1.05     0.95     0;
];


%% converters
%column_names%    busdc_i busac_i type_dc type_ac P_g   Q_g   islcc  Vtar   rtf 	xtf  transformer tm   bf 	filter    rc     xc   reactor   basekVac   Vmmax   Vmmin      Imax    status   LossA  LossB  LossCrec LossCinv  droop      Pdcset    Vdcset  dVdcset Pacmax  Pacmin   Qacmax  Qacmin cost co2_cost lifetime
mpc.convdc_ne = [
                  	3       3   		3       1       -550   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000 		1000 		-1000 160000000 1000 30;
					4       23   		3       1       -600   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000 		1000 		-1000 160000000 1000 30;
					5       48   		3       1       1000   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000  		1000 		-1000 160000000 1000 30;
					6       54   		3       1       50     0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000 		1000 		-1000 160000000 1000 30;
					7       57   		3       1       -550   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000 		1000 		-1000 160000000 1000 30;
					8       27   		3       1       1000   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 2000 	-2000  		1000 		-1000 160000000 1000 30;
					9       67   		1       1       -800   0    0 			1     0.01  0.01 0 						1 	0.01 0 				0.01   0.01 0  				500         1.05     0.95     1.1     1        0.0   0.0     0.0       0.0      0.0050     0.0       1.0000   0 		 1000  	-1000   	1000 		-1000 240000000 1000 30; %offshore
];

%% branches
%column_names%   fbusdc  tbusdc  r        l   c   rateA   rateB   rateC   status cost co2_cost lifetime
mpc.branchdc_ne = [
    				4       5       0.0012   0   0   1575    1575    1575     1 550000000 2000       60;   % cost assumption: OHL
					6       7       0.0012   0   0   1575    1575    1575     1 105000000 2000       60;   % cost assumption: OHL
					1       3       0.0012   0   0   1575    1575    1575     1 132000000 2000       60;   % cost assumption: OHL
					2       8       0.0012   0   0   1575    1575    1575     1 260000000 2000       60;   % cost assumption: OHL
					8       5       0.0012   0   0   1575    1575    1575     1 186000000 2000       60;   % cost assumption: OHL
					4       6       0.0012   0   0   1575    1575    1575     1 211000000 2000       60;   % cost assumption: OHL
					2       4       0.0012   0   0   1575    1575    1575     1 600000000 2000       60;   % cost assumption: OHL
					5       7       0.0012   0   0   1575    1575    1575     1 650000000 2000       60;   % cost assumption: OHL
					3       9       0.0012   0   0   1575    1575    1575     1 300000000 2000       40;   % offshore cable
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
     26   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     250000000     50000000     1 2400 0 0 0.001 10;
     42   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     250000000     50000000     1 2400 0 0 0.001 10;
	 45   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     250000000     50000000     1 2400 0 0 0.001 10;
	 51   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     250000000     50000000     1 2400 0 0 0.001 10;
	 62   0.0     0.0     0.0     1000.0  200.0   250.0   0.9     0.9     250     -50.0   70.0    0.1     0.0     0.0     0.0      1     250000000     50000000     1 2400 0 0 0.001 10;
];


%% load additional data
%column_names% load_id e_nce_max p_red_max p_shift_up_max p_shift_down_max p_shift_down_tot_max t_grace_up t_grace_down cost_reduction cost_shift_up cost_shift_down cost_curt cost_inv flex co2_cost lifetime
mpc.load_extra = [
 1 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  630300.0 1 0.5 10;
 2 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  947100.0 1 0.5 10;
 3 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  613800.0 1 0.5 10;
 4 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  894300.0 1 0.5 10;
 5 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  564300.0 1 0.5 10;
 6 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  656700.0 1 0.5 10;
 7 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  372900.0 1 0.5 10;
 8 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  125400.0 1 0.5 10;
 9 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  907500.0 1 0.5 10;
10 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  544500.0 1 0.5 10;
11 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  587400.0 1 0.5 10;
12 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0   99000.0 1 0.5 10;
13 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  105600.0 1 0.5 10;
14 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1303500.0 1 0.5 10;
15 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2194500.0 1 0.5 10;
16 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  877800.0 1 0.5 10;
17 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2788500.0 1 0.5 10;
18 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1095600.0 1 0.5 10;
19 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1782000.0 1 0.5 10;
20 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1518000.0 1 0.5 10;
21 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1488300.0 1 0.5 10;
22 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  495000.0 1 0.5 10;
23 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2075700.0 1 0.5 10;
24 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2834700.0 1 0.5 10;
25 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1564200.0 1 0.5 10;
26 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2204400.0 1 0.5 10;
27 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 2026200.0 1 0.5 10;
28 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  267300.0 1 0.5 10;
29 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1419000.0 1 0.5 10;
30 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1019700.0 1 0.5 10;
31 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  330000.0 1 0.5 10;
32 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  999900.0 1 0.5 10;
33 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1069200.0 1 0.5 10;
34 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  379500.0 1 0.5 10;
35 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0  617100.0 1 0.5 10;
36 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1052700.0 1 0.5 10;
37 100 0.3 0.3 1.0 100 10 10 100.0 0.0 10.0 10000.0 1039500.0 1 0.5 10;
];
