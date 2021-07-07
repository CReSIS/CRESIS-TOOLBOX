function [ctrl_chain,param] = layer_tracker(param,param_override)
% [ctrl_chain,param] = layer_tracker(param,param_override)
%
% Check input parameters and create tracking tasks for running on a cluster
% with layer_tracker. See run_layer_tracker for an example of routine
% tracking of echograms. See run_layer_tracker_tune for an example of
% hyperparameter tuning to improve tracking parameters. The function
% "layer_tracker_task" does the actual tracking and
% "layer_tracker_combine_task" combines the tracking results and stores them
% into standard layer storage locations (either the OPS database or
% layerdata files).
%
% First stage temporary outputs stored in:
% /cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_layer_tracker_tmp/CSARP_layer/20140313_08/
% Second stage output stored in any format supported by opsCopyLayers and
% input parameters control where the final combiend output goes.
%
% Comparing four different methods for example might store the outputs like this:
%   layer_tracker_001/t001_lsm.mat, ..., layer_tracker_00N/t001_lsm.mat
%   layer_tracker_001/t002_mcmc.mat, ..., layer_tracker_00N/t002_mcmc.mat
%   layer_tracker_001/t003_stereo.mat, ..., layer_tracker_00N/t003_stereo.mat
%   layer_tracker_001/t004_viterbi.mat, ..., layer_tracker_00N/t004_viterbi.mat
% Layers in the files (all combined into one file during combine):
%   t001_lsm_surface_001, ..., t001_lsm_surface_016, t001_lsm_bottom_001, ..., t001_lsm_bottom_016
%   t002_mcmc_surface, t002_mcmc_bottom
%   t003_stereo_surface, t003_stereo_bottom
%   t004_viterbi_bottom
%
% Comparing the same method with four different sets of parameters:
%   layer_tracker_001/t001_lsm.mat, ..., layer_tracker_00N/t001_lsm.mat
%   layer_tracker_001/t002_lsm.mat, ..., layer_tracker_00N/t001_lsm.mat
%   layer_tracker_001/t003_lsm.mat, ..., layer_tracker_00N/t001_lsm.mat
%   layer_tracker_001/t004_lsm.mat, ..., layer_tracker_00N/t001_lsm.mat
% Layers in the files (all combined into one file during combine):
%   t001_lsm_surface_001, ..., t001_lsm_surface_016, t001_lsm_bottom_001, ..., t001_lsm_bottom_016
%   t002_lsm_surface_001, ..., t002_lsm_surface_016, t002_lsm_bottom_001, ..., t002_lsm_bottom_016
%   t003_lsm_surface_001, ..., t003_lsm_surface_016, t003_lsm_bottom_001, ..., t003_lsm_bottom_016
%   t004_lsm_surface_001, ..., t004_lsm_surface_016, t004_lsm_bottom_001, ..., t004_lsm_bottom_016
%
% Authors: Anjali Pare, John Paden
%
% See also: layer_tracker.m, layer_tracker_combine_task.m,
% layer_tracker_task.m, layer_tracker_profile.m, run_layer_tracker.m,
% run_layer_tracker_tune.m

%% General Setup
% =====================================================================
param = merge_structs(param, param_override);

fprintf('=====================================================================\n');
fprintf('%s: %s (%s)\n', mfilename, param.day_seg, datestr(now));
fprintf('=====================================================================\n');

%% Input Checks: cmd
% =====================================================================

% Remove frames that do not exist from param.cmd.frms list
frames = frames_load(param);
param.cmd.frms = frames_param_cmd_frms(param,frames);

%% Input Checks: layer_tracker
% =====================================================================

layer_tracker_input_check;

%% Set up Cluster
% ===================================================================

ctrl = cluster_new_batch(param);
%cluster_compile({'layer_tracker_task'},ctrl.cluster.hidden_depend_funs,ctrl.cluster.force_compile,ctrl);
cluster_compile({'layer_tracker_task','layer_tracker_combine_task'},ctrl.cluster.hidden_depend_funs,ctrl.cluster.force_compile,ctrl);
ctrl_chain = {};

%% layer_tracker
% =========================================================================
% =========================================================================

% Cluster setup
% -------------------------------------------------------------------------

sparam.argsin{1} = param;
sparam.task_function = 'layer_tracker_task';
sparam.num_args_out = 1;
sparam.argsin{1}.load.echogram_img = param.layer_tracker.echogram_img;
sparam.cpu_time = 60;
sparam.mem = 500e6;
sparam.notes = '';


track = param.layer_tracker.track{1};
temp = [];
crossover_temp = [];
track.gps_time = [];
frm_filenames = {};
in_fn_dir = ct_filename_out(param,param.layer_tracker.echogram_source,'');
frm_str = [];
frm_nam = [];
lat = [];
long = [];


for frm_idx = 1:length(param.cmd.frms)
  frm = param.cmd.frms(frm_idx);
  % Load the previous frame
  data_fn = fullfile(in_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  if ~ismember(data_fn,frm_filenames)
    frm_filenames{end+1} = data_fn;
    frm_str{end+1} = sprintf('%s_%03d',param.day_seg,frm);
  end
  
  frm = param.cmd.frms(frm_idx)-1;
  data_fn = fullfile(in_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  if ~ismember(data_fn,frm_filenames)
    frm_filenames{end+1} = data_fn;
    frm_str{end+1} = sprintf('%s_%03d',param.day_seg,frm);
  end
  
  frm = param.cmd.frms(frm_idx)+1;
  data_fn = fullfile(in_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  if ~ismember(data_fn,frm_filenames)
    frm_filenames{end+1} = data_fn;
    frm_str{end+1} = sprintf('%s_%03d',param.day_seg,frm);
  end
end


for frm_idx = 1:length(frm_filenames)
  %   frm = param.cmd.frms(frm_idx);
  %   data_fn = fullfile(in_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  data_fn = frm_filenames{frm_idx};
  if exist(data_fn,'file')
    mdata = load(data_fn, 'GPS_time','Time','Latitude','Longitude');
    Nx = length(mdata.GPS_time);
    %% Ice Mask
    if track.ice_mask.en
      if strcmp(track.ice_mask.type,'bin')
        mask = load(track.ice_mask.mat_fn,'R','X','Y','proj');
        [fid,msg] = fopen(track.ice_mask.fn,'r');
        if fid < 1
          fprintf('Could not open file %s\n', track.ice_mask.fn);
          error(msg);
        end
        mask.mask = logical(fread(fid,[length(mask.Y),length(mask.X)],'uint8'));
        fclose(fid);
      else
        [mask.mask,mask.R,~] = geotiffread(track.ice_mask.fn);
        mask.proj = geotiffinfo(track.ice_mask.fn);
      end
      [mask.x, mask.y] = projfwd(mask.proj, mdata.Latitude, mdata.Longitude);
      mask.X = mask.R(3,1) + mask.R(2,1)*(1:size(mask.mask,2));
      mask.Y = mask.R(3,2) + mask.R(1,2)*(1:size(mask.mask,1));
      [mask.X,mask.Y] = meshgrid(mask.X,mask.Y);
      ice_mask.mask = round(interp2(mask.X, mask.Y, double(mask.mask), mask.x, mask.y));
      ice_mask.mask(isnan(ice_mask.mask)) = 1;
      temp = cat(2,ice_mask.mask,temp);
      track.gps_time = cat(2,mdata.GPS_time,track.gps_time);
    else
      temp = cat(2,temp,ones(1,Nx));
      track.gps_time = cat(2,mdata.GPS_time,track.gps_time);
    end
    %% Crossovers
    if track.crossover.en
      sys = ct_output_dir(param.radar_name);
      ops_param = [];
      ops_param.properties.search_str = frm_str{frm_idx};
      ops_param.properties.location = param.post.ops.location;
      ops_param.properties.season = param.season_name;
      [status,ops_data_segment] = opsGetFrameSearch(sys,ops_param);
      if status == 1
        ops_param = [];
        ops_param.properties.location = param.post.ops.location;
        ops_param.properties.lyr_name = track.crossover.name;
        ops_param.properties.frame = frm_str{frm_idx};
        ops_param.properties.segment_id = ops_data_segment.properties.segment_id;
        [status,ops_data] = opsGetCrossovers(sys,ops_param);
        if status == 1
          ops_data.properties.twtt = ops_data.properties.twtt(:).';
          ops_data.properties.source_point_path_id = double(ops_data.properties.source_point_path_id(:).');
          ops_data.properties.cross_point_path_id = double(ops_data.properties.cross_point_path_id(:).');
          ops_data.properties.source_elev = ops_data.properties.source_elev.';
          ops_data.properties.cross_elev = ops_data.properties.cross_elev.';
          
          % Get the OPS
          ops_param = [];
          ops_param.properties.location = param.post.ops.location;
          ops_param.properties.point_path_id = [ops_data.properties.source_point_path_id ops_data.properties.cross_point_path_id];
          [status,ops_data_gps_time] = opsGetPath(sys,ops_param);
          
          source_gps_time = zeros(size(ops_data.properties.source_point_path_id));
          crossover_gps_time = zeros(size(ops_data.properties.source_point_path_id));
          good_mask = true(size(ops_data.properties.source_point_path_id));
          % Ensure crossover season is good
          for idx = 1:length(ops_data.properties.source_point_path_id)
            match_idx = find(ops_data.properties.source_point_path_id(idx) == ops_data_gps_time.properties.id,1);
            source_gps_time(idx) = ops_data_gps_time.properties.gps_time(match_idx);
            match_idx = find(ops_data.properties.cross_point_path_id(idx) == ops_data_gps_time.properties.id,1);
            crossover_gps_time(idx) = ops_data_gps_time.properties.gps_time(match_idx);
            if any(strcmp(ops_data.properties.season_name{idx}, track.crossover.season_names_bad))
              good_mask(idx) = false;
            end
          end
          % Ensure crossover gps_time is good
          good_mask = good_mask & track.crossover.gps_time_good_eval(crossover_gps_time);
          % Convert crossover twtt to source twtt and then convert from twtt
          % to rows/bins
          cols = round(interp1(mdata.GPS_time,1:length(mdata.GPS_time), source_gps_time(good_mask)));
          rows = round(interp1(mdata.Time,1:length(mdata.Time), ops_data.properties.twtt(good_mask) ...
            + (ops_data.properties.source_elev(good_mask) - ops_data.properties.cross_elev(good_mask))*2/c ));
          % crossover_temp{end+1} = [cols; rows];
          crossovers = [cols; rows; track.crossover.cutoff*ones(size(cols))];
          crossovers = crossovers(:,isfinite(cols));
          crossover_temp{end+1} = crossovers;
        end
      end
    else
      crossover_temp{end+1} = zeros(3,0);
    end
    frm_nam{end+1} = frm_str{frm_idx};
    
    %% Track: Load ocean mask, land DEM, sea surface DEM
    track.init.method = 'dem';
    long = cat(2,mdata.Longitude,long);
    lat = cat(2,mdata.Latitude,lat);
  end
end

%% Track: Load ocean mask, land DEM, sea surface DEM
  if isfield(track,'init') && strcmpi(track.init.method,'dem')
    global gdem;
    if isempty(gdem) || ~isa(gdem,'dem_class') || ~isvalid(gdem)
      gdem = dem_class(param,500);
    end
    gdem.set_res(500);
    gdem.ocean_mask_mode = 'l';
    
    gdem_str = sprintf('%s:%s:%s_%03d_%03d',param.radar_name,param.season_name,param.day_seg,param.cmd.frms([1 end]));
    if ~strcmpi(gdem_str,gdem.name)
      gdem.set_vector(lat,long,gdem_str);
    end
  end
  
  if strcmpi(track.init.method,'dem')
    gdem.set_vector(lat,long);
    [land_dem,msl,ocean_mask] = gdem.get_vector_dem();
  end

%% Loading reference trajectory
records = records_load(param);
records_reference_trajectory_load(param,records);%
%
%%
sparam.argsin{1}.ice_mask.mask = temp;
sparam.argsin{1}.ice_mask.gps_time = track.gps_time;
sparam.argsin{1}.crossovers = crossover_temp;
sparam.argsin{1}.frm_nam = frm_nam;
sparam.argsin{1}.dem.land_dem = land_dem;
sparam.argsin{1}.dem.ocean_mask = ocean_mask;
sparam.argsin{1}.dem.msl = msl;
% end
cpu_time_mult = zeros(size(param.layer_tracker.track));
mem_mult = zeros(size(param.layer_tracker.track));
for track_idx = 1:length(param.layer_tracker.track)
  switch param.layer_tracker.track{track_idx}.method
    case 'viterbi'
      cpu_time_mult(track_idx) = 11e-6;
      mem_mult(track_idx) = 64;
      
    case 'lsm'
      cpu_time_mult(track_idx) = 5.5e-7*max(param.layer_tracker.track{track_idx}.lsm.storeIter);
      mem_mult(track_idx) = 80;
      
    otherwise
      cpu_time_mult(track_idx) = 11e-6;
      mem_mult(track_idx) = 64;
  end
end

%% layer_tracker: Loop to create tasks
% -------------------------------------------------------------------------
in_fn_dir = ct_filename_out(param,param.layer_tracker.echogram_source,'');
if strcmp(param.layer_tracker.layer_params.source,'ops')
  tmp_out_fn_dir_dir = ct_filename_out(param,'ops','layer_tracker_tmp');
  param.layer_tracker.layer_params.layerdata_source = 'ops'; % Only used for stdout
else
  tmp_out_fn_dir_dir = ct_filename_out(param,param.layer_tracker.layer_params.layerdata_source,'layer_tracker_tmp'); %/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_layer_tracker_tmp/CSARP_layer_tune_vit_seg4_NC/20140313_09
end
mem_combine = 0;
cputime_combine = 0;
frm_idx = 1;
idx = 1;

while frm_idx <= length(param.cmd.frms)
  Nx = 0;
  Nt = 0;
  
  start_frm_idx = frm_idx;
  frms = [];
  subblock_idx = 1;
  while subblock_idx <= param.layer_tracker.block_size_frms
    if frm_idx > param.cmd.frms
      break;
    end
    frm = param.cmd.frms(frm_idx);
    % Check proc_mode from frames file that contains this frames type and
    % make sure the user has specified to process this frame type
    if ~ct_proc_frame(frames.proc_mode(frm),param.layer_tracker.frm_types)
      fprintf('Skipping %s_%03i (no process frame)\n', param.day_seg, frm);
      if subblock_idx == 1
        % No frames added to the block yet, so just keep going
        frm_idx = frm_idx + 1;
        continue;
      else
        break;
      end
    end
    % Add frame to this block
    frm_idx = frm_idx + 1;
    frms(end+1) = frm;
    
    % Compute matrix size
    % ---------------------------------------------------------------------
    if param.layer_tracker.echogram_img == 0
      data_fn = fullfile(in_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
    else
      data_fn = fullfile(in_fn_dir,sprintf('Data_img_%02d_%s_%03d.mat',param.layer_tracker.echogram_img,param.day_seg,frm));
    end
    try
      mdata = load(data_fn, 'GPS_time','Time');
      if (subblock_idx==1)
        max_time = mdata.Time(end);
        min_time = mdata.Time(1);
      else
        if(max_time <= mdata.Time(end))
          max_time = mdata.Time(end);
        end
        if(min_time >= mdata.Time(1))
          min_time = mdata.Time(1);
        end
      end
      Nx = Nx + length(mdata.GPS_time);
    catch ME
      warning('Failed to load %s!!!!!!:\n  %s', data_fn, ME.getReport);
      mdata.Time = [0 1e-6];
      min_time = 0;
      max_time = 0;
      % keyboard % Uncomment for debugging why file loading failed
    end
    subblock_idx = subblock_idx + 1;
  end
  dt = mdata.Time(2) - mdata.Time(1);
  Nt = 1 + (max_time-min_time)/dt;
  
  for track_idx = 1:param.layer_tracker.track_per_task:length(param.layer_tracker.track)
    dparam = [];
    dparam.file_success = {};
    dparam.argsin{1}.layer_tracker.frms = frms;
    
    tracks_in_task = track_idx:min(track_idx-1+param.layer_tracker.track_per_task,length(param.layer_tracker.track));
    
    dparam.argsin{1}.layer_tracker.tracks_in_task = tracks_in_task;
    
    % File Success
    % ---------------------------------------------------------------------
    for track_idx = tracks_in_task
      tmp_out_fn_name = sprintf('%s_%s.mat', param.layer_tracker.track{track_idx}.name, param.layer_tracker.track{track_idx}.method);
      for frm = frms
        tmp_out_fn = fullfile(tmp_out_fn_dir_dir,sprintf('layer_tracker_%03d', frm),tmp_out_fn_name);
        dparam.file_success{end+1} = tmp_out_fn;
        if ~ctrl.cluster.rerun_only && exist(tmp_out_fn,'file')
          delete(tmp_out_fn);
        end
      end
    end
    
    % Notes
    % ---------------------------------------------------------------------
    dparam.notes = sprintf('%s %s:%s:%s %s %s:%d-%d %s %d-%d (%d of %d)', ...
      sparam.task_function, param.radar_name, param.season_name, ...
      param.layer_tracker.echogram_source, param.layer_tracker.layer_params.layerdata_source, ...
      param.layer_tracker.track{tracks_in_task(1)}.method, tracks_in_task([1 end]), param.day_seg, ...
      dparam.argsin{1}.layer_tracker.frms([1 end]), start_frm_idx, length(param.cmd.frms));
    
    % Rerun only check
    % ---------------------------------------------------------------------
    if ctrl.cluster.rerun_only
      if ~cluster_file_success(dparam.file_success)
        fprintf('  Already exists [rerun_only skipping]: %s (%s)\n', ...
          dparam.notes, datestr(now));
        continue;
      end
    end
    
    % CPU time and memory
    % ---------------------------------------------------------------------
    dparam.cpu_time = sum(cpu_time_mult(tracks_in_task)) * Nx * Nt;
    dparam.mem = 800e6 + max(mem_mult(tracks_in_task)) * Nx * Nt;
    if strcmp(track.init.method,'dem')
      % Add extra time and memory for DEM
      dparam.cpu_time = dparam.cpu_time + 120;
      dparam.mem = dparam.mem + 2e9;
    end
    mem_combine = mem_combine + 256*Nx*length(tracks_in_task);
    cputime_combine = cputime_combine + 1e-2*Nx*length(tracks_in_task);
    
    % Create task
    % ---------------------------------------------------------------------
    ctrl = cluster_new_task(ctrl,sparam,dparam,'dparam_save',0);
  end
end

ctrl = cluster_save_dparam(ctrl);
ctrl_chain{end+1} = ctrl;
fprintf('Done %s\n',datestr(now));

%% layer_tracker_combine
% =========================================================================
% =========================================================================
ctrl = cluster_new_batch(param);

sparam = [];
sparam.argsin{1} = param;
sparam.task_function = 'layer_tracker_combine_task';
sparam.num_args_out = 1;

records_fn = ct_filename_support(param,'','records');
file_info = dir(records_fn);
sparam.cpu_time = 30 + cputime_combine;
sparam.mem = 500e6 + 1.5*mem_combine + 1.5*file_info.bytes;
sparam.notes = '';

if strcmp(param.layer_tracker.layer_params.source,'ops')
  sparam.file_success = {};
else
  sparam.file_success = {};
  out_fn_dir = ct_filename_out(param,param.layer_tracker.layer_params.layerdata_source);
  for frm = param.cmd.frms
    % Check proc_mode from frames file that contains this frames type and
    % make sure the user has specified to process this frame type
    if ~ct_proc_frame(frames.proc_mode(frm),param.layer_tracker.frm_types)
      continue;
    end
    out_fn = fullfile(out_fn_dir,sprintf('Data_%s_%03d.mat',param.day_seg,frm));
    sparam.file_success{end+1} = out_fn;
  end
end

ctrl = cluster_new_task(ctrl,sparam,[]);
ctrl_chain{end+1} = ctrl;
fprintf('Done %s\n',datestr(now));

