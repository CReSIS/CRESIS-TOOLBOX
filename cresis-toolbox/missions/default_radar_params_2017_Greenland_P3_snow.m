function param = default_radar_params_2017_Greenland_P3_snow
% param = default_radar_params_2017_Greenland_P3_snow
%
% Snow: 2017_Greenland_P3
%
% Creates base "param" struct
% Creates defaults cell array for each type of radar setting
%
% Author: John Paden

%% Preprocess parameters
param.season_name = '2017_Greenland_P3';
param.radar_name = 'snow8';

param.config.file.version = 8;
param.config.file.prefix = param.radar_name;
param.config.file.suffix = '.bin';
param.config.max_time_gap = 10;
param.config.min_seg_size = 2;

param.config.daq_type = 'cresis';
param.config.wg_type = 'cresis';
param.config.header_load_func = @basic_load_fmcw8;
param.config.board_map = {''};
param.config.tx_map = {''};

param.config.daq.xml_version = -1; % No XML file available
param.config.file.version = 8;
param.config.file.prefix = param.radar_name;
param.config.file.suffix = '.bin';
param.config.max_time_gap = 10;
param.config.min_seg_size = 2;

% param.config.ni.clk = 125e6;
param.config.cresis.clk = 125e6;

%% Command worksheet
default.cmd.records = 1;
default.cmd.qlook = 1;
default.cmd.generic = 1;

%% Records worksheet
default.records.file.boards = [1];
default.records.frames.geotiff_fn = 'greenland/Landsat-7/Greenland_natural_150m.tif';
default.records.frames.mode = 2;
default.records.gps.time_offset = 1;
default.records.gps.en = 1;

%% Qlook worksheet
default.qlook.img_comb = [];
default.qlook.imgs = {[1 1]};
default.qlook.out_path = '';
default.qlook.block_size = 2000;
default.qlook.motion_comp = 0;
default.qlook.dec = 4;
default.qlook.inc_dec = 5;
default.qlook.surf.en = 1;
default.qlook.surf.min_bin = 1e-6;
default.qlook.surf.method = 'threshold';
default.qlook.surf.threshold = 17;
default.qlook.surf.filter_len = 7;
default.qlook.surf.sidelobe = 19;
default.qlook.surf.max_diff = 1.2e-7;
default.qlook.surf.noise_rng = [100 -700 -300];
default.qlook.surf.search_rng = [0:9];

%% SAR worksheet
default.sar.out_path = '';
default.sar.imgs = default.qlook.imgs;
default.sar.frm_types = {0,[0 1],0,0,-1};
default.sar.chunk_len = 2000;
default.sar.frm_overlap = 0;
default.sar.coh_noise_removal = 0;
default.sar.combine_rx = 0;
default.sar.time_of_full_support = inf;
default.sar.pulse_rfi.en = [];
default.sar.pulse_rfi.inc_ave= [];
default.sar.pulse_rfi.thresh_scale = [];
default.sar.trim_vals = [];
default.sar.pulse_comp = 1;
default.sar.ft_dec = 1;
default.sar.ft_wind = @hanning;
default.sar.ft_wind_time = 0;
default.sar.lever_arm_fh = @lever_arm;
default.sar.mocomp.en = 1;
default.sar.mocomp.type = 2;
default.sar.mocomp.filter = {@butter  [2]  [0.1000]};
default.sar.mocomp.uniform_en = 1;
default.sar.sar_type = 'fk';
default.sar.sigma_x = 1;
default.sar.sub_aperture_steering = 0;
default.sar.st_wind = @hanning;
default.sar.start_eps = 3.15;

%% Array worksheet
default.array.in_path = '';
default.array.array_path = '';
default.array.out_path = '';
default.array.imgs = default.qlook.imgs;
default.array.img_comb = default.qlook.img_comb;
default.array.method = 'standard';
default.array.window = @hanning;
default.array.bin_rng = 0;
default.array.rline_rng = -5:5;
default.array.dbin = 1;
default.array.dline = 6;
default.array.DCM = [];
default.array.Nsv = 1;
default.array.theta_rng = [0 0];
default.array.sv_fh = @array_proc_sv;
default.array.diag_load = 0;
default.array.Nsig = 2;

%% Radar worksheet
default.radar.prf = 1/256e-6;
default.radar.fs = 250e6;
default.radar.adc_bits = 14;
default.radar.Vpp_scale = 2; % Digital receiver gain is 5, full scale Vpp is 2
default.radar.Tadc_adjust = []; % System time delay: leave this empty or set it to zero at first, determine this value later using data over surface with known height or from surface multiple
default.radar.lever_arm_fh = @lever_arm;
chan_equal_Tsys = [0]/1e9;
chan_equal_dB = [0];
chan_equal_deg = [0];
for wf = 1:1
  default.radar.wfs(wf).tx_weights = 1; % Watts
  default.radar.wfs(wf).adc_gains_dB = 95.8; % Radiometric calibration to 1/R^2
  default.radar.wfs(wf).rx_paths = [1]; % ADC to rx path mapping
  default.radar.wfs(wf).ref_fn = '';
  default.radar.wfs(wf).chan_equal_Tsys = chan_equal_Tsys;
  default.radar.wfs(wf).chan_equal_dB = chan_equal_dB;
  default.radar.wfs(wf).chan_equal_deg = chan_equal_deg;
  default.radar.wfs(wf).adcs = [1];
  default.radar.wfs(wf).nz_trim = {[0 0],[0 2],[0 0],[0 0]};
  default.radar.wfs(wf).nz_valid = [0 1 2 3];
end

%% Post worksheet
default.post.data_dirs = {'qlook'};
default.post.layer_dir = 'layerData';
default.post.maps_en = 1;
default.post.echo_en = 1;
default.post.layers_en = 0;
default.post.data_en = 0;
default.post.csv_en = 1;
default.post.concat_en = 1;
default.post.pdf_en = 1;
default.post.map.location = 'Greenland';
default.post.map.type = 'combined';
default.post.echo.elev_comp = 2;
default.post.echo.depth = '[min(Surface_Depth)-2 max(Surface_Depth)+25]';
% default.post.echo.elev_comp = 3;
% default.post.echo.depth = '[min(Surface_Elev)-25 max(Surface_Elev)+2]';
default.post.echo.er_ice = round((1+0.51*0.3)^3 * 100)/100;
default.post.ops.location = 'arctic';
  
%% Radar Settings

defaults = {};

% Survey Mode 2-18 GHz
default.radar.wfs(1).f0 = 2e9;
default.radar.wfs(1).f1 = 18e9;
default.radar.wfs(1).Tpd = 240e-6;
default.radar.wfs(1).BW_window = [2.7e9 17.5e9];
default.radar.wfs(1).t_ref = -0.000000040063;

default.config_regexp = '.*';
default.name = 'Survey Mode 2-18 GHz';
defaults{end+1} = default;

% Survey Mode 2-8 GHz
default.radar.wfs(1).f0 = 2e9;
default.radar.wfs(1).f1 = 18e9;
default.radar.wfs(1).Tpd = 240e-6;
default.radar.wfs(1).BW_window = [2.7e9 17.5e9];
default.radar.wfs(1).t_ref = -0.000000040063;

default.config_regexp = '.*';
default.name = 'Survey Mode 2-8 GHz';
defaults{end+1} = default;

% Survey Mode 2-14 GHz, dual waveform
default.radar.wfs(1).f0 = 2e9;
default.radar.wfs(1).f1 = 14e9;
default.radar.wfs(1).Tpd = 200e-6;
default.radar.wfs(1).BW_window = [2.7e9 13.5e9];
default.radar.wfs(1).t_ref = -0.000000040063;

default.config_regexp = '.*';
default.name = 'Survey Mode 2-14 GHz Dual Waveform';
defaults{end+1} = default;

%% Add default settings

param.config.defaults = defaults;
