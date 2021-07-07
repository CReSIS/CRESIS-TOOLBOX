% script run_layer_tracker
%
% Runs layer_tracker.m
%
% Authors: Anjali Pare, John Paden
%
% See also: layer_tracker.m, layer_tracker_combine_task.m,
% layer_tracker_task.m, layer_tracker_profile.m, run_layer_tracker.m,
% run_layer_tracker_tune.m

%% User Settings
% ----------------------------------------------------------------------
param_override = [];

% params = read_param_xls(ct_filename_param('accum_param_2018_Antarctica_TObas.xls'));
% params = read_param_xls(ct_filename_param('rds_param_2011_Greenland_P3.xls'));
params = read_param_xls(ct_filename_param('rds_param_2014_Greenland_P3.xls'));
% params = read_param_xls(ct_filename_param('rds_param_2018_Greenland_P3.xls'));
% params = read_param_xls(ct_filename_param('snow_param_2012_Greenland_P3.xls'));

params = ct_set_params(params,'cmd.generic',0);
params = ct_set_params(params,'cmd.generic',1,'day_seg','20140313_08');
params = ct_set_params(params,'cmd.frms',[1]); % Specify specific frames (or leave empty/undefined to do all frames)
% params = ct_set_params(params,'cmd.generic',1,'day_seg','20110331_02');
% params = ct_set_params(params,'cmd.frms',19); % Specify specific frames (or leave empty/undefined to do all frames)

 param_override.layer_tracker.debug_plots = {'tracked_images'};
% param_override.layer_tracker.debug_plots = {'tracked_images','visible'}; % Uncomment for debugging

param_override.layer_tracker.echogram_img = 0; % To choose an image besides the base (0) image
% echogram_source: location of echogram data used for tracking
param_override.layer_tracker.echogram_source = 'qlook';
% param_override.layer_tracker.echogram_source = 'CSARP_post/qlook';
% param_override.layer_tracker.echogram_source = 'CSARP_post/mvdr';
param_override.layer_tracker.echogram_source = 'CSARP_post/standard';

% layer_params: layerparams structure of where to store the output using
% opsCopyLayers.m
param_override.layer_tracker.layer_params = [];
% Uncomment to enable layerdata storage
param_override.layer_tracker.layer_params.layerdata_source = 'layer_vitAnj';
% Uncomment to enable OPS storage
% param_override.layer_tracker.layer_params.source = 'ops';

% block_size_frms: Number of frames to be loaded at a time
param_override.layer_tracker.block_size_frms = 1;

% track_per_task: Number of tracks per task
param_override.layer_tracker.track_per_task = inf;

% param_override.layer_tracker.surf_layer = struct('name','surface','source','layerdata','layerdata_source','layer');

%% param.layer_tracker.track options
track = [];

% =========================================================================
% NOTE ON USAGE:
% Enable one set of tracking parameters below
% =========================================================================
track.en = true;
switch ct_output_dir(params(1).radar_name)
  case 'rds'
    %% RDS
    
    %% RDS: Surface tracking
    if 0
      track.profile = 'rds';
      
      track.layer_names                 = {'surface'};
      
      % Override default filter settings
      if 0
        track.filter	= [3 3];
        track.filter_trim	= [3 3];
        track.threshold = 10;
        track.max_rng	= [0 2];
      end
      
      % Use sidelobe rejection
      if 0
        % run_get_echogram_stats output
        sidelobe = load('/N/dcwan/projects/cresis/output/ct_tmp/echogram_stats/rds/2018_Greenland_P3/stats_20180421_01.mat','sidelobe_rows','sidelobe_dB','sidelobe_vals');
        track.sidelobe_rows = [sidelobe.sidelobe_rows(75:98)];
        track.sidelobe_dB = -(sidelobe.sidelobe_dB(75:98,1)-max(sidelobe.sidelobe_dB(:,1))+21);
        track.sidelobe_dB(track.sidelobe_dB<9) = 9;
        track.threshold_rel_max = -max(track.sidelobe_dB);
        track.data_noise_en = true;
      end
      
      % Use feedthrough rejection
      if 0
        % run_get_echogram_stats output
        feedthru = load('/N/dcwan/projects/cresis/output/ct_tmp/echogram_stats/rds/2018_Greenland_P3/stats_20180421_01.mat');
        track.feedthru.time = feedthru.dt*feedthru.bins;
        track.feedthru.power_dB = feedthru.min_means+20;
        bin_mask = track.feedthru.time<2e-6;
        track.feedthru.time = track.feedthru.time(bin_mask);
        track.feedthru.power_dB = track.feedthru.power_dB(bin_mask);
        track.feedthru.power_dB(end) = -inf;
        track.min_bin = 0.5e-6;
        track.data_noise_en = true;
      end
      
      % Use DEM and LIDAR for init
      if 0
        track.init.method	= 'dem';
        track.init.dem_offset = 0;
        track.init.dem_layer.name = 'surface';
        track.init.dem_layer.source = 'lidar';
        track.init.dem_layer.lidar_source = 'atm';
        track.init.max_diff = 1e-6;
        track.init.max_diff_method = 'merge_vectors';
      end
      
      % Use snake method for init
      if 0
        track.init.method	= 'snake';
        track.init.snake_rng	= [-0.5e-6 0.5e-6];
        track.init.max_diff	= 0.5e-6;
      end
      
      % Override default method
      if 0
        track.method = 'snake';
        track.snake_rng	= [-0.15e-6 0.15e-6];
      end
    end
    
<<<<<<< HEAD
    %% RDS: Viterbi
    if 1
=======
    %% RDS: Surface tracking (DEM)
    % Use DEM and LIDAR with no automated tracking (use this when the
    % echogram data are bad and no tracking is possible)
    if 0
      track.profile = 'RDS';
      track.layer_names                 = {'surface_dem'};
      
      % Override default init method
      track.init.method	= 'dem';
      track.init.dem_offset = 0;
      track.init.dem_layer = [];
      track.init.max_diff = 0;
      track.init.max_diff_method = 'merge_vectors';
      
      track.method = ''; % Just use DEM surface
      track.max_rng = [0 0];
      track.medfilt = [];
    end
    
    %% RDS: Viterbi bottom
    if 0
>>>>>>> 22379f92ab59cf9acb19f372394c0cc1774fd2d4
      track.method                      = 'viterbi';
      track.layer_names                 = {'bottomA'};
      
      track.min_bin = struct('name','tomo_top');
      track.max_bin = struct('name','tomo_bottom');
      
      track.crossover.en = true;
      track.crossover.season_names_bad = {'2003_Greenland_P3', '2005_Greenland_P3'}; % Bad seasons to not include
      % track.crossover.gps_time_good_eval = @(x) true; % All cross overs are good
      track.crossover.gps_time_good_eval = @(x) x < datenum_to_epoch(datenum('2014/03/01')); % Cross overs before this date are good
      
      if 0
        track.ice_mask.en = false;
      elseif 1
        % Greenland
        track.ice_mask.en = true;
        track.ice_mask.type = 'geotiff';
        track.ice_mask.fn = ct_filename_gis([], fullfile('greenland','IceMask','GimpIceMask_90m_v1.1.tif'));
      elseif 0
        % Canada
        track.ice_mask.en = true;
        track.ice_mask.type = 'bin';
        track.ice_mask.fn = ct_filename_gis([], fullfile('canada','ice_mask','03_rgi50_ArcticCanadaNorth','03_rgi50_ArcticCanadaNorth.bin'));
        track.ice_mask.mat_fn = ct_filename_gis([], fullfile('canada','ice_mask','03_rgi50_ArcticCanadaNorth','03_rgi50_ArcticCanadaNorth.mat'));
      elseif 0
        % Antarctica
        track.ice_mask.en = true;
        track.ice_mask.type = 'geotiff2';
        track.ice_mask.fn = ct_filename_gis([], fullfile('antarctica/DEM/BEDMAP2/original_data/bedmap2_tiff/bedmap2_icemask_grounded_and_shelves.tif'));
        track.ice_mask.fn2 = ct_filename_gis([], fullfile('antarctica/DEM/BEDMAP2/original_data/bedmap2_tiff/bedmap2_rockmask.tif'));
      end
      track.init.dem_layer = struct('name','surface');
      
      track.viterbi.transition_weight   = 1; % Larger --> smoother
      track.viterbi.gt_cutoff           = 50;
      
      track.mult_suppress.en = true;
      track.init.max_diff    = inf;
      track.detrend          = [];
      track.filter_trim      = [0 120];
      track.norm.scale       = [-40 90];
      track.xcorr            = echo_xcorr_profile('short_unitstep');
    end
    
    %% RDS: MCMC bottom
    if 0
      track.method            = 'mcmc';
      track.layer_names       = {'surface','bottom'};
      track.mcmc.alg          = 'MCMC';
      track.init.max_diff     = inf;
    end
    
    %% RDS: LSM bottom
    if 0
      track.method            = 'lsm';
      track.layer_names       = {'surface','bottom'};
      track.lsm.y             = 220;
      track.lsm.dy            = 10;
      track.lsm.storeIter     = 400;
      track.init.max_diff     = inf;
      track.detrend           = [];
      track.norm.scale        = [-40 90];
      
    end
    
    %% RDS: Stereo bottom
    if 0
      track.method               = 'stereo';
      track.layer_names       = {'surface','bottom'};
      track.stereo.surfaceload   = true;
      track.stereo.crossoverload = true;
      track.stereo.top_smooth    = 1000;
      track.stereo.bottom_smooth = 1000;
      track.stereo.top_peak      = 0.5;
      track.stereo.bottom_peak   = 0.5;
      track.stereo.repulsion     = 10;
      track.stereo.alg           = 'HMM';
      track.init.max_diff    = inf;
    end
    
  case 'accum'
    %% ACCUM
    
    %% ACCUM: Surface tracking
    if 1
      track.profile = 'accum';
      
      track.layer_names                 = {'surface'};
      
      % track.threshold = 5;
      % track.threshold_rel_max = -9;
      % track.init.method	= 'nan'; % May be necessary if bottom is brighter than surface
      
      % Override default init method
      if 0
        track.init.method	= 'dem';
        track.init.dem_offset = 0;
        track.init.dem_layer.name = 'surface';
        track.init.dem_layer.source = 'lidar';
        track.init.dem_layer.lidar_source = 'atm';
        track.init.max_diff = 0.3e-6;
      end
      
      % Override default method
      if 0
        track.method = 'snake';
        track.snake_rng	= [-0.15e-6 0.15e-6];
      end
    end
    
    %% ACCUM: Surface tracking (DEM)
    % Use DEM and LIDAR with no automated tracking (use this when the
    % echogram data are bad and no tracking is possible)
    if 0
      track.profile = 'ACCUM';
      track.layer_names                 = {'surface_dem'};
      
      % Override default init method
      track.init.method	= 'dem';
      track.init.dem_offset = 0;
      track.init.dem_layer = [];
      track.init.max_diff = 0;
      track.init.max_diff_method = 'merge_vectors';
      
      track.method = ''; % Just use DEM surface
      track.max_rng = [0 0];
      track.medfilt = [];
    end
    
    %% ACCUM: Viterbi bottom
    if 1
      track.method                      = 'viterbi';
      track.layer_names                 = {'bottom'};
      
      track.min_bin = struct('name','surface','eval',struct('cmd','s=s+1e-6;'));
      % track.min_bin = struct('name','tomo_top');
      % track.max_bin = struct('name','tomo_bottom');
      
      track.crossover.en = false;
      track.crossover.season_names_bad = {'2003_Greenland_P3', '2005_Greenland_P3'}; % Bad seasons to not include
      % track.crossover.gps_time_good_eval = @(x) true; % All cross overs are good
      track.crossover.gps_time_good_eval = @(x) x > datenum_to_epoch(datenum('2010/01/01')); % Cross overs before this date are good
      
      if 1
        track.ice_mask.en = false;
      elseif 0
        % Greenland
        track.ice_mask.en = true;
        track.ice_mask.type = 'geotiff';
        track.ice_mask.fn = ct_filename_gis([], fullfile('greenland','IceMask','GimpIceMask_90m_v1.1.tif'));
      elseif 0
        % Canada
        track.ice_mask.en = true;
        track.ice_mask.type = 'bin';
        track.ice_mask.fn = ct_filename_gis([], fullfile('canada','ice_mask','03_rgi50_ArcticCanadaNorth','03_rgi50_ArcticCanadaNorth.bin'));
        track.ice_mask.mat_fn = ct_filename_gis([], fullfile('canada','ice_mask','03_rgi50_ArcticCanadaNorth','03_rgi50_ArcticCanadaNorth.mat'));
      elseif 0
        % Antarctica
        track.ice_mask.en = true;
        track.ice_mask.type = 'geotiff2';
        track.ice_mask.fn = ct_filename_gis([], fullfile('antarctica/DEM/BEDMAP2/original_data/bedmap2_tiff/bedmap2_icemask_grounded_and_shelves.tif'));
        track.ice_mask.fn2 = ct_filename_gis([], fullfile('antarctica/DEM/BEDMAP2/original_data/bedmap2_tiff/bedmap2_rockmask.tif'));
      end
      track.init.dem_layer = struct('name','surface');
      
      track.viterbi.transition_weight   = 0.01; % Larger --> smoother
      track.viterbi.gt_cutoff           = 50;
      
      track.mult_suppress.en = true;
      track.init.max_diff    = inf;
      track.init.method      = 'nan';
      track.detrend          = [];
      track.filter_trim      = [0 120];
      track.norm.scale       = [-40 90];
      track.xcorr            = echo_xcorr_profile('xlong_unitstep');
    end
    
  case {'snow','kuband','kaband'}
    %% SNOW (also kaband, kuband)
    
    %% SNOW: Surface tracking
    if 1
      track.profile = 'snow';
      
      track.layer_names                 = {'surface'};
      
      % Use sidelobe rejection
      if 0
        % run_get_echogram_stats output
        sidelobe = load('/cresis/snfs1/dataproducts/ct_data/ct_tmp/echogram_stats/snow/2011_Greenland_P3/stats_20110329_01.mat','sidelobe_rows','sidelobe_dB','sidelobe_vals');
        track.sidelobe_rows = [sidelobe.sidelobe_rows(1:194)];
        track.sidelobe_dB = [-sidelobe.sidelobe_dB(1:194,end)]-sidelobe.sidelobe_vals(end)+4.5;
        track.threshold_rel_max = -max(track.sidelobe_dB);
      end
      
      % Override default init method
      if 0
        track.init.method  = 'dem';
        track.init.dem_offset = 0;
        track.init.dem_layer.name = 'surface';
        track.init.dem_layer.source = 'lidar';
        track.init.dem_layer.lidar_source = 'atm';
        track.init.max_diff = 0.3e-6;
        track.init.max_diff_method = 'merge_vectors';
      elseif 0
        track.init.method  = 'snake';
        track.init.snake_rng = [-15e-9 15e-9];
        track.init.max_diff  = 0.3e-6;
      end
    end
    
    %% SNOW: Surface tracking (DEM)
    % Use DEM and LIDAR with no automated tracking (use this when the
    % echogram data are bad and no tracking is possible)
    if 0
      track.profile = 'snow';
      track.layer_names                 = {'surface_dem'};
      
      % Override default init method
      track.init.method	= 'dem';
      track.init.dem_offset = 0;
      track.init.dem_layer = [];
      track.init.max_diff = 0;
      track.init.max_diff_method = 'merge_vectors';
      
      track.method = ''; % Just use DEM surface
      track.max_rng = [0 0];
      track.medfilt = [];
    end
    
end

param_override.layer_tracker.track = {track};

% dbstop if error;
% param_override.cluster.type = 'torque';
% param_override.cluster.type = 'matlab';
param_override.cluster.type = 'debug';
% param_override.cluster.type = 'slurm';
% param_override.cluster.rerun_only = true;
% param_override.cluster.desired_time_per_job  = 240*60;
% param_override.cluster.cpu_time_mult  = 2;
% param_override.cluster.mem_mult  = 2;

%% Automated Section
% ----------------------------------------------------------------------

% Input checking
global gRadar;
if exist('param_override','var')
  param_override = merge_structs(gRadar,param_override);
else
  param_override = gRadar;
end

ctrl_chain = {};
% Process each of the segments
for param_idx = 1:length(params)
  param = params(param_idx);
  if isfield(param.cmd,'generic') && ~iscell(param.cmd.generic) && ~ischar(param.cmd.generic) && param.cmd.generic
    ctrl_chain{end+1} = layer_tracker(param,param_override);
  end
end

cluster_print_chain(ctrl_chain);

[chain_fn,chain_id] = cluster_save_chain(ctrl_chain);
