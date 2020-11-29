%% CONSTANTS
FIGURE_NUM = 1;
SAVE_PATH = 'C:/Users/mathe/Documents/MATLAB/TRWS_CT results/output images/';
SAVE_IMAGE = false; % Save the normalized (output) image
SAVE_SURF = false; % Save the output surface
SAVE_FIG = true; % Save the created figure
SAVE_IMAGESC = true; % Save the imagesc of the produced layer. PLOT_IMAGESC must be true.
SAVE_NAME = 'sim_test/1'; % name of save files and directory
RNG_SEED = 1;
TOP_LAYER_GUARD = 0; % Number of FT-bins to ignore after the top surface bounds
BOTTOM_LAYER_GUARD = 0; % Number of FT-bins to ignore before the bottom surface bounds
NOISE_FLOOR = -40; % Value to assign to the noise floor for use with echo_norm

% Start index
St  = NaN;
Ssv = NaN;
Sx  = NaN;

% End index
Et  = 500;
Esv = NaN;
Ex  = 500;

% Num sampled points (resolutions)
Nt  = NaN;
Nsv = NaN;
Nx  = NaN;

MAX_LOOPS = 4; % Number of iterations of TRWS to perform
AT_WEIGHT = 1; % Along track weight used in TRWS2
USE_ORIGINAL_TRAVERSAL = true; % Use original 4-perm traversal method for trws2. Only used when trws2_bounded is called.
DONT_SKIP_COLS = false; % Do not skip columns which are outside the surface bounds. Only used when trws2_bounded is called.

PLOT_INDICES = false; % Plot indices on which dt is performed
INDEX_LOOP_NUM = 0; % Plot index traversal order for this loop num
MAX_TICKS = 10; % Max number of axis tick labels
ANNOTATION_MAX_CHAR_WIDTH = 15; % Number of chars to allow on a line before inserting a space.

PLOT_POINTS = false; % Plot data points as sphere's if PLOT_MAX_POINTS is false
PLOT_THRESHOLD = 'auto'; % The minimum intensity to plot if PLOT_POINTS is true. 'auto' selects the greatest AUTO_THRESHOLD_MAX_POINTS points;
AUTO_THRESHOLD_MAX_POINTS = 2000; % Number of points to plot when PLOT_THRESHOLD is set to 'auto'

PLOT_MAX_POINTS = false; % Plot maximum data point in the CT dimension for each (AT, FT) row. Overrides PLOT_POINTS
MAX_POINTS_NUM = 3; % Number of max points to plot for every (AT, FT) row.
MAX_POINTS_SKIP = 1; % Number of rows to skip between each plot for max points

PLOT_MAX_SURF = true; % Plot the maximum points as a surface. (LOAD_DATA must be true. Does not plot found surface when this is true)
NUM_MAX_SURF = 1; % Number of max sufaces to plot (1st uses maximum points, 2nd uses next greatest points, etc.)
COLOR_MAX_SURF = 'none';

LOAD_DATA = true; % Use image data to plot intensities
RELOAD_DATA = false; % When false, only load trws_data if not already loaded. Ignored if LOAD_DATA is false
FIND_SURF = true; % Calls TRWS when true. Overridden by presets below. correct_surface must be set manually when false.
COLOR_SURF_DATA = 'ct_bins_absolute'; % Color the surface with intensity values from given variable. generally 'trws_data_norm' for output image or 'trws_data' for input image. 'none' for solid coloring. 'ct_bins' for coloring based on surface bin. 'ct_bins_absolute' for coloring based on possible bins.;
SIMULATE_SURF = false; % Calls trws2_sim_2D to create surface instead of mex function. FIND_SURF must be false.

USE_SURF_BOUNDS = true; % Bound results with surface layers
USE_BOTTOM_LAYER = false; % Use the bottom layer as the bottom boundary surface. USE_SURF_BOUNDS must be true. Useful for Greenland data.
RELOAD_BOTTOM_LAYER = false; % Force reload of layer information with opsLoadLayers even if already present.
PLOT_CT_BOUNDS = false; % Plot the CT-slope surface boundaries
PLOT_FT_BOUNDS = true; % Plot the FT-slope surface boundaries

MAKE_DATA_POSITIVE = false; % Subtract the min value from the data to make the min 0. Useful when loading sim data.
NORMALIZE_DATA = true; % Normalize data for display identically to the normalization used by trws2_CT_perm.m. LOAD_DATA must be true.
USE_DEBUG_MATRIX = false; % Get the final image values from the TRWS2 algorithm and use these to plot points, etc. Replaces normalized data with debug data.
PLOT_HISTOGRAM = false; % Plot a histogram of the data
PLOT_IMAGESC = true; % Plot an imagesc of the surface
ABSOLUTE_IMAGESC_COLORS = true; % Set colors relative to total number of CT bins rather than max and min bins of surface 

%% DISPLAY VARS
DISPLAY_VARS = {'RNG_SEED', 'TOP_LAYER_GUARD', 'BOTTOM_LAYER_GUARD', 'NOISE_FLOOR', 'St', 'Ssv', 'Sx', 'Et', 'Esv', 'Ex', 'Nt', 'Nsv', 'Nx', ...
  'MAX_LOOPS', 'AT_WEIGHT', 'USE_ORIGINAL_TRAVERSAL', 'DONT_SKIP_COLS', 'PLOT_CT_BOUNDS', 'PLOT_FT_BOUNDS', 'NORMALIZE_DATA', 'MAKE_DATA_POSITIVE', 'USE_DEBUG_MATRIX', ... 
  'COLOR_SURF_DATA', 'SAVE_IMAGE', 'SAVE_SURF', 'SIMULATE_SURF', 'SAVE_FIG', 'SAVE_IMAGESC', 'PLOT_IMAGESC', 'SAVE_NAME', 'SAVE_PATH'};

if PLOT_POINTS
  DISPLAY_VARS{end + 1} = 'PLOT_POINTS';
  DISPLAY_VARS{end + 1} = 'PLOT_THRESHOLD';
  if strcmp(PLOT_THRESHOLD, 'auto')
    DISPLAY_VARS{end + 1} = 'AUTO_THRESHOLD_MAX_POINTS';
  end
end
if PLOT_MAX_POINTS
  DISPLAY_VARS{end + 1} = 'PLOT_MAX_POINTS';
  DISPLAY_VARS{end + 1} = 'MAX_POINTS_NUM';
  DISPLAY_VARS{end + 1} = 'MAX_POINTS_SKIP';
end
if PLOT_MAX_SURF
  DISPLAY_VARS{end + 1} = 'PLOT_MAX_SURF';
  DISPLAY_VARS{end + 1} = 'NUM_MAX_SURF';
  DISPLAY_VARS{end + 1} = 'COLOR_MAX_SURF';
end
if LOAD_DATA
  DISPLAY_VARS{end + 1} = 'LOAD_DATA';
  DISPLAY_VARS{end + 1} = 'echogram_fn';
end
if FIND_SURF
  DISPLAY_VARS{end + 1} = 'FIND_SURF';
  DISPLAY_VARS{end + 1} = 'trws_run_time';
else
  DISPLAY_VARS{end + 1} = 'surf_fn';
end
if USE_SURF_BOUNDS
  DISPLAY_VARS{end + 1} = 'USE_SURF_BOUNDS';
  if USE_BOTTOM_LAYER
    DISPLAY_VARS{end + 1} = 'USE_BOTTOM_LAYER';
    DISPLAY_VARS{end + 1} = 'RELOAD_BOTTOM_LAYER';
  end
end

%% DATA VARS
param.radar_name = 'rds';
param.radar.lever_arm_fh = '@lever_arm';
surfdata_source = 'surfData_paden';
out_type = 'music3D_paden';
param.season_name = '2019_Antarctica_Ground';
param.day_seg = '20200107_01';
frm = 1;

%% PRESETS
if 0
  % Find surface of antarctica data
  echogram_fn = fullfile(ct_filename_out(param,out_type,''),sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  
  FIND_SURF = true;
  LOAD_DATA = true;
elseif 0
  % Load surface from file
  surf_fn = 'C:/Users/mathe/Documents/MATLAB/TRWS_CT results/perm Antarctica/output images/forward send 2 perms vert crop 4 pass input crop/surf.mat';
  correct_surface = load(surf_fn);
  correct_surface = correct_surface.correct_surface;
  echogram_fn = fullfile(ct_filename_out(param,out_type,''),sprintf('Data_%s_%03d.mat',param.day_seg,frm));
  FIND_SURF = false;
  LOAD_DATA = true;
  %     Nt  = NaN;
  %     Nsv = NaN;
  %     Nx  = NaN;
  SAVE_FIG = false;
  SAVE_SURF = false;
  SAVE_IMAGE = false;
  Esv = 64;
elseif 1
  % Find surface of Greenland data
  param.season_name = '2014_Greenland_P3';
  param.day_seg = '20140502_01';
  out_type = 'multipass';
  frm = 41;
  echogram_fn = fullfile(ct_filename_out(param,out_type,''), 'summit_2012_2014_allwf_2012_music.mat');
  FIND_SURF = true;
  LOAD_DATA = true;
  
  USE_BOTTOM_LAYER = true;
  if ~exist('params', 'var') || RELOAD_BOTTOM_LAYER
    params = read_param_xls(ct_filename_param('rds_param_2014_Greenland_P3.xls'), '20140502_01');
    params = ct_set_params(params,'cmd.generic',1);
  end
  layer_params.name = 'bottom';
  layer_params.source = 'layerdata';
  layer_params.layerdata_source = 'layer';
  layer_params.existence_check = false;
elseif 0
  % Load surface from simulator
  surf_fn = 'C:/Users/mathe/Documents/MATLAB/TRWS_CT results/paden_sim/output images/result/surf.mat';
  correct_surface = load(surf_fn);
  correct_surface = squeeze(correct_surface.correct_surface);
  echogram_fn = 'C:/Users/mathe/Documents/MATLAB/TRWS_CT results/paden_sim/output images/result/image.mat';

  Nt  = NaN;
  Nsv = NaN;
  Nx  = NaN;
  
  FIND_SURF = false;
  LOAD_DATA = true;
  
  SAVE_FIG = false;
  SAVE_SURF = false;
  SAVE_IMAGE = false;
  
  MAKE_DATA_POSITIVE = true;
  RELOAD_DATA = true;
  NORMALIZE_DATA = false;
elseif 0
  % Create surface from Greenland data in simulator
  SIMULATE_SURF = true;
  FIND_SURF = false;
  LOAD_DATA = true;
  USE_SURF_BOUNDS = false;
  
  param.season_name = '2014_Greenland_P3';
  param.day_seg = '20140502_01';
  out_type = 'multipass';
  frm = 41;
  echogram_fn = fullfile(ct_filename_out(param,out_type,''), 'summit_2012_2014_allwf_2012_music.mat');
end

%% LOAD IMAGE DATA
if LOAD_DATA
  if ~exist('mdata', 'var') || RELOAD_DATA
    mdata = load(echogram_fn);
  end
  trws_data = mdata.Tomo.img;
  if MAKE_DATA_POSITIVE
    trws_data = trws_data - min(trws_data(:)) +.1;
  end
  trws_data = 10*log10(trws_data);
end

%% Create length vars

% Set default start index
if ~exist('St', 'var') || isnan(St) || isempty(St)
  St  = 1;
end
if ~exist('Ssv', 'var') || isnan(Ssv) || isempty(Ssv)
  Ssv = 1;
end
if ~exist('Sx', 'var') || isnan(Sx) || isempty(Sx)
  Sx  = 1;
end

% Set default end indices
if ~exist('Et', 'var') || isnan(Et) || isempty(Et)
  if LOAD_DATA
    Et = size(trws_data, 1);
  else
    Et = size(correct_surface, 1);
  end
end
if ~exist('Esv', 'var') || isnan(Esv) || isempty(Esv)
  if ~LOAD_DATA
    error('Cannot automatically determine Esv without loading echo_gram.');
  end
  Esv = size(trws_data, 2);
end
if ~exist('Ex', 'var') || isnan(Ex) || isempty(Ex)
  if LOAD_DATA
    Ex = size(trws_data, 3);
  else
    Ex = size(correct_surface, 2);
  end
end

% Set default resolutions
if ~exist('Nt', 'var') || isnan(Nt) || isempty(Nt)
  Nt  = Et-St+1;
end
if ~exist('Nsv', 'var') || isnan(Nsv) || isempty(Nsv)
  Nsv = Esv-Ssv+1;
end
if ~exist('Nx', 'var') || isnan(Nx) || isempty(Nx)
  Nx  = Ex-Sx+1;
end

% Calculate step size
Tt  = round((Et-St)/Nt);
Tsv = round((Esv-Ssv)/Nsv);
Tx  = round((Ex-Sx)/Nx);

Tt  = max(Tt, 1);
Tsv = max(Tsv, 1);
Tx  = max(Tx, 1);

%% LOAD SURFACES
if USE_SURF_BOUNDS
  if USE_BOTTOM_LAYER
    if ~LOAD_DATA
      error('LOAD_DATA must be true when USE_BOTTOM_LAYER is true in order to load the top surface from mdata.');
    end
    if ~exist('bottom_layer', 'var') || RELOAD_BOTTOM_LAYER
      [bottom_layer, new_layer_params] = opsLoadLayers(merge_structs(params, gRadar), layer_params);
    end
    bottom_surface.y = repmat(bottom_layer.elev(bottom_layer.frm == 41), [Nsv, Nx]);
    top_surface.y = repmat(mdata.Surface, [Nsv, Nx]);
  else
    surfdata_fn = fullfile(ct_filename_out(param,surfdata_source,''),sprintf('Data_%s_%03d.mat',param.day_seg,frm));
    surfaces = tomo.surfdata.update_file(surfdata_fn,surfdata_fn,echogram_fn);
    surface_names = {surfaces.surf.name};
    top_surface = surfaces.surf(strcmp(surface_names, 'top'));
    bottom_surface = surfaces.surf(strcmp(surface_names, 'bottom'));
    
  end
end

%% RESAMPLE DATA
% Correct num sampled points to match step size constraint
Nt  = length(St:Tt:Et);
Nsv = length(Ssv:Tsv:Esv);
Nx  = length(Sx:Tx:Ex);

% Resample and window data to given start and end indices and resolutions
min_bound = 1;
max_bound = Nt;
if LOAD_DATA
  trws_data = trws_data(St:Tt:Et, Ssv:Tsv:Esv, Sx:Tx:Ex);
  trws_data_norm = trws_data;
  
  % Position FT-slope surface bounds
  if USE_SURF_BOUNDS
    min_bounds = interp1(mdata.Time, 1:length(mdata.Time), top_surface.y, 'nearest', 'extrap')+TOP_LAYER_GUARD;
    max_bounds = interp1(mdata.Time, 1:length(mdata.Time), bottom_surface.y, 'nearest', 'extrap')-BOTTOM_LAYER_GUARD;
    min_bounds = min_bounds(Ssv:Tsv:Esv, Sx:Tx:Ex) - St + 1;
    max_bounds = max_bounds(Ssv:Tsv:Esv, Sx:Tx:Ex) - St + 1;
    min_bounds = interp1(St:Tt:Et, 1:length(St:Tt:Et), min_bounds, 'nearest');
    max_bounds = interp1(St:Tt:Et, 1:length(St:Tt:Et), max_bounds, 'nearest');
    max_bounds(isnan(max_bounds)) = Et - St;
    min_bounds(isnan(min_bounds)) = 1;
    min_bound = min(min_bounds(:));
    max_bound = max(max_bounds(:));
  end
end

if ~LOAD_DATA || ~USE_SURF_BOUNDS
  min_bounds = ones(Nsv, Nx)*1;
  max_bounds = ones(Nsv, Nx)*Nt;
end

%% PERFORM TRWS
% Create default slopes, weights, and bounds
at_slope  = zeros(1, Nx);
CT_bounds = ones(2, Nx);
CT_bounds(2, :) = Nsv;

% Setup binary debug switches
traversal_method = 0;
if ~USE_ORIGINAL_TRAVERSAL
  traversal_method = 1;
end

% Perform TRWS and save surface
debug = [];
trws_run_time = nan;
if FIND_SURF
  tic;
  
  if USE_DEBUG_MATRIX
    [correct_surface, debug] = tomo.trws2_CT_perm(single(trws_data),single(at_slope), ...
      single(AT_WEIGHT), uint32(MAX_LOOPS), uint32(CT_bounds-1), traversal_method, min_bounds-1, max_bounds-1, ~DONT_SKIP_COLS);
    trws_data_norm = max(debug(:)) - debug + .01;
  else
    correct_surface = tomo.trws2_CT_perm(single(trws_data),single(at_slope), ...
      single(AT_WEIGHT), uint32(MAX_LOOPS), uint32(CT_bounds-1), traversal_method, min_bounds-1, max_bounds-1, ~DONT_SKIP_COLS);
  end
  trws_run_time = toc
elseif SIMULATE_SURF
  correct_surface = squeeze(trws_sim_2D(permute(trws_data, [2 1 3]), MAX_LOOPS));
else
  correct_surface = correct_surface(St:Tt:Et, Sx:Tx:Ex);
end


%% NORMALIZE IMAGE DATA
if LOAD_DATA
  % Normalize data
  if NORMALIZE_DATA && ~USE_DEBUG_MATRIX
    trws_data_norm = echo_norm(trws_data_norm, struct('scale', [NOISE_FLOOR 90]));
    for rline = 1:Nx
      for doa_bin = 1:Nsv
        trws_data_norm(1:Nt < min_bounds(doa_bin, rline), doa_bin, rline) = NOISE_FLOOR;
        trws_data_norm(1:Nt > max_bounds(doa_bin, rline), doa_bin, rline) = NOISE_FLOOR;
      end
    end 
    trws_data_norm = [nan(min_bound - 1, Nsv, Nx); trws_data_norm(min_bound:max_bound, :, :); nan(size(trws_data_norm, 1) - max_bound, Nsv, Nx)];
  end
  
  min_intensity = min(trws_data_norm(:));
  max_intensity = max(trws_data_norm(:)) - min_intensity;
  trws_data_norm = (trws_data_norm - min_intensity + .01)/max_intensity*10;
  
  %% HISTOGRAM
  if PLOT_HISTOGRAM
    figure;
    histogram(trws_data_norm(:));
    title(sprintf('loops: %d', MAX_LOOPS));
  end

  %% MAX SURFACE
  if PLOT_MAX_SURF
    max_surfs = {};
    max_surf_vals = {};
    for w_idx = 1:Nx
      for d_idx = 1:Nt
        points = trws_data_norm(d_idx, :, w_idx);
        points = points(~isnan(points));
        num_points = NUM_MAX_SURF;
        if numel(points) < NUM_MAX_SURF
            num_points = numel(points);
        end
        
        [sorted_points, indices] = sort(points);
        range = (numel(indices)-num_points + 1):length(indices);
        greatest_points = indices(range);
        values = sorted_points(range);
        for max_surf_num = 1:NUM_MAX_SURF
          if max_surf_num > num_points
            max_surfs{max_surf_num}(d_idx, w_idx) = nan;
            max_surf_vals{max_surf_num}(d_idx, w_idx) = nan;
          else
            max_surfs{max_surf_num}(d_idx, w_idx) = greatest_points(max_surf_num);
            max_surf_vals{max_surf_num}(d_idx, w_idx) = values(max_surf_num);
          end
        end
      end
    end
  end
end

%% CREATE FIGURE
if ~isnan(FIGURE_NUM)
  fig = figure(FIGURE_NUM);
else
  fig = figure;
end

clf;
hold on;

Z = 1:Nt;
Y = 1:Nsv;
X = 1:Nx;

xlims = [1 Nx];
zlims = [0 Nsv];


clear surf;

%% PLOT MAX SURF
smallest = min(trws_data_norm(:));
largest = max(trws_data_norm(:));
if LOAD_DATA && PLOT_MAX_SURF
  max_surf_handles = {};
  for max_surf_num = 1:NUM_MAX_SURF
    
    max_surf_handles{end + 1} = surf(max_surfs{max_surf_num}, 'FaceAlpha', .3, 'FaceColor', 'black', 'LineStyle', 'none');
    %% COLOR MAX SURFACE
    if ~strcmp(COLOR_MAX_SURF, 'none')
      color_data = eval(COLOR_MAX_SURF);
      intensities = nan(Nt, Nx);
      for d = 1:Nt
        for w = 1:Nx
          h = max_surfs{max_surf_num}(d, w);
          if isnan(h)
            continue
          end
          intensities(d, w) = color_data(d, h, w);
        end
      end
      set(max_surf_handles{end}, 'CData', intensities);
      set(max_surf_handles{end}, 'FaceColor', 'interp');
      caxis([min(color_data(:)) max(color_data(:))]);
    end
    
    set(max_surf_handles{end}, 'CData', max_surf_vals{max_surf_num});
    caxis([smallest largest]);
  end
  c_bar = colorbar;
  ylabel(c_bar, 'Normalized Intensity');
end

%% PLOT SURFACE
h_correct_surf = surf(correct_surface, 'FaceAlpha', .6, 'FaceColor', 'black', 'LineStyle', 'none');
%   set(h_correct_surf, 'CData', get(h_correct_surf, 'ZData'));

%% PLOT CT BOUNDS
if PLOT_CT_BOUNDS && USE_SURF_BOUNDS
  blue   = [86 , 135, 214]./255;
  orange = [232, 145, 90 ]./255;
  surf(X, Z, repmat(CT_bounds(1, :), Nt, 1), 'FaceColor', blue, 'LineStyle', 'none', 'FaceAlpha', 0.1);
  surf(X, Z, repmat(CT_bounds(2, :), Nt, 1), 'FaceColor', orange, 'LineStyle', 'none', 'FaceAlpha', 0.1);
end

%% Set up camera view and axes
xlim(xlims);
x_points = round(linspace(1, Nx, min(Nx, MAX_TICKS)));
xticks(x_points);
x_labels = (x_points-1)*Tx+Sx;
xticklabels(x_labels);
xlabel('X : Along-Track (Nx, DIM 2)');
set(gca, 'XColor', 'b');
set(gca, 'xdir', 'reverse');

zlim(zlims);
z_points = round(linspace(0, Nsv, min(Nsv, MAX_TICKS)));
zticks(z_points);
z_labels = (z_points-1)*Tsv+Ssv;
zticklabels(z_labels);
zlabel('Z : Cross-Track (Nsv. DIM 1)');
set(gca, 'ZColor', 'g');

ylims = [min_bound max_bound];
ylim(ylims);
y_points = round(linspace(min_bound, max_bound, min(Nt, MAX_TICKS)));
yticks(y_points);
y_labels = (y_points-1)*Tt+St;
yticklabels(y_labels);
ylabel('Y : Fast-Time (Nt, DIM 0)');
set(gca, 'YColor', 'r');
set(gca, 'ydir', 'reverse');

view([40 90 15]);
camorbit(90, 0, 'data', [0 0 1]);
camorbit(90, 0, 'data', [1 0 0]);
cameratoolbar('SetCoordSys', 'y');
cameratoolbar('SetMode', 'orbit');

camva(10);
% colormap(bone);

%% COLOR SURFACE

% Create ct_bins and ct_bins_absolute for use with coloring if chosen by
% user
ct_bin_range = Ssv:Tsv:Esv;
ct_bins_absolute = repmat(ct_bin_range, [Nt 1 Nx]);
ct_bin_min = min(correct_surface(:));
ct_bin_max = max(correct_surface(:));
ct_bins = ct_bins_absolute;
ct_bins(ct_bins_absolute < ct_bin_min) = ct_bin_min;
ct_bins(ct_bins_absolute > ct_bin_max) = ct_bin_max;

if ~strcmp(COLOR_SURF_DATA, 'none')
  color_data = eval(COLOR_SURF_DATA);
  intensities = nan(Nt, Nx);
  for d = 1:Nt
    for w = 1:Nx
      h = correct_surface(d, w);
      if isnan(h)
        continue
      end
      intensities(d, w) = color_data(d, h, w);
    end
  end
  set(h_correct_surf, 'CData', intensities);
  set(h_correct_surf, 'FaceColor', 'interp');
  caxis([min(color_data(:)) max(color_data(:))]);
  c_bar = colorbar;
  if strcmp(COLOR_SURF_DATA, 'ct_bins') || strcmp(COLOR_SURF_DATA, 'ct_bins_absolute')
    ylabel(c_bar, 'CT Bin');
  else
    ylabel(c_bar, 'Input Intensity');
  end
end

%% PLOT FT BOUNDS
if PLOT_FT_BOUNDS
  % Remove data entirely outside ft_bounds
  ylim(zlims);
  zlim(ylims);
  minh = surf(min_bounds, 'FaceColor', 'none', 'LineStyle', ':', 'FaceAlpha', 0.1);
  rotate(minh, [1 0 0], 90, [0 Nt 0]);
  set(minh, 'YData', Nt - get(minh, 'YData'));
  % set(minh, 'CData', get(minh, 'YData'));
  set(minh, 'ZData', get(minh, 'ZData') - min(get(minh, 'ZData')) + 1);
  maxh = surf(max_bounds, 'FaceColor', 'none', 'LineStyle', ':', 'FaceAlpha', 0.1);
  rotate(maxh, [1 0 0], 90, [0 Nt 0]);
  set(maxh, 'YData', Nt - get(maxh, 'YData'));
  set(maxh, 'ZData', get(maxh, 'ZData') - min(get(maxh, 'ZData')) + 1);
  % set(maxh, 'CData', get(maxh, 'YData'));
  ylim(ylims);
  zlim(zlims);
end

%% Plot max points if PLOT_MAX_POINTS is true
if PLOT_MAX_POINTS && LOAD_DATA
  for w_idx = 1:MAX_POINTS_SKIP:Nx
    for d_idx = 1:MAX_POINTS_SKIP:Nt
      points = trws_data_norm(d_idx, :, w_idx);
      points = points(~isnan(points));
      num_points = MAX_POINTS_NUM;
      if numel(points) < MAX_POINTS_NUM && numel(points) > 0
        num_points = numel(points); % Only a few points that are not NaN
      elseif numel(points) == 0
        continue; % All points in this row are NaN
      end
        
      [sorted_points, indices] = sort(points);
      greatest_points = indices((numel(indices)-num_points + 1):end);
      intensities = points(greatest_points);
      color = 'm';
      for point = 1:numel(intensities)
        if point == numel(intensities)
          if PLOT_MAX_SURF
            continue;
          end
          color = 'r';
        end
        plot3(w_idx, d_idx, greatest_points(point), sprintf('%s.', color), 'MarkerSize', intensities(point));
      end
    end
  end
end

%% Set threshold for plot_points if set to auto
if PLOT_POINTS && strcmp(PLOT_THRESHOLD, 'auto') && LOAD_DATA
  sorted_data = trws_data_norm(~isnan(trws_data_norm));
  [values, indices] = sort(sorted_data(:));
  PLOT_THRESHOLD = values(numel(values)-AUTO_THRESHOLD_MAX_POINTS+1);  

%   [counts, edges] = histcounts(trws_data_norm(:), 'BinMethod', 'sqrt');
%   [~, biggest] = max(counts);
%   if biggest < numel(counts)
%     biggest = biggest + 1;
%   end
%   PLOT_THRESHOLD = edges(biggest)
end

%% Plot indices and points

Nsvs_center = floor(Nsv/2);
Nsvs_array = [Nsvs_center:-1:1 (Nsvs_center+1):Nsv];

for w_idx = 1:Nx
  if mod(INDEX_LOOP_NUM, 2) == 1
    w = Nx-w_idx;
  else
    w = w_idx-1;
  end
  for h_idx = 1:Nsv
    if mod(floor(INDEX_LOOP_NUM/2), 2) == 1
      h = Nsv-h_idx;
    else
      h = h_idx-1;
    end
    
    for d_idx = 1:Nt
      d = d_idx-1;
      
      % Plot points
      if PLOT_POINTS && ~PLOT_MAX_POINTS && LOAD_DATA
        intensity = trws_data_norm(d_idx, h_idx, w_idx);
        color = 'b';
        if intensity > 1
          color = 'r';
        end
        if intensity >= PLOT_THRESHOLD
          plot3(w_idx, d_idx, h_idx, sprintf('%s.', color), 'MarkerSize', intensity);
        end
      end
      
      if h_idx == 1 && PLOT_INDICES
        text(w_idx, d_idx, h_idx, sprintf('%d', d+w*Nt + 1));
      end
    end
  end
end

%% Add variable values to plot
current_axes = gca;
current_axes.Position(3) = .5;
current_axes.Position(1) = .3;

str = '';
for display_cell = DISPLAY_VARS
  display_var = display_cell{1};
  value = eval(display_var);
  display_var = format_word(display_var, ANNOTATION_MAX_CHAR_WIDTH);
  
  template = '';
  switch class(value)
    case 'logical'
      if value
        line = sprintf('\\bf%s\\rm\n', display_var);
      else
        line = '';
      end
    case 'double'
      template = '%.2f';
    case 'integer'
      template = '%d';
    case 'char'
      template = '%s';
    case 'string'
      template = '%s';
    otherwise
      warning('No template for %s (class %s)', display_var, class(value));
      continue;
  end
  if template
    display_val = format_word(sprintf(template, value), ANNOTATION_MAX_CHAR_WIDTH);
    line = sprintf('\\bf%s\\rm = %s\n', display_var, display_val);
  end
  str = sprintf('%s%s', str, line);
end
annotation('textbox', [0, 0, 0.3, 1], 'String', str, 'Interpreter', 'tex', 'FontSize', 6, 'LineStyle', 'none', 'FitBoxToText', 'off');

%% Create imagesc of surface
if PLOT_IMAGESC
  if ~isnan(FIGURE_NUM)
    fig2 = figure(FIGURE_NUM + 1);
  else
    fig2 = figure;
  end
  h_imagesc = imagesc(correct_surface);
  c_bar = colorbar;
  ylabel(c_bar, 'CT Bin');
  if ABSOLUTE_IMAGESC_COLORS
      caxis([Ssv Esv]);
  end

  % Set up camera view and axes
  xlim(xlims);
  xticks(x_points);
  xticklabels(x_labels);
  xlabel('X : Along-Track (Nx, DIM 2)');
  set(gca, 'XColor', 'b');

  ylim(ylims);
  yticks(y_points);
  yticklabels(y_labels);
  ylabel('Y : Fast-Time (Nt, DIM 0)');
  set(gca, 'YColor', 'r');
  set(gca, 'ydir', 'reverse');

  % Add variable values to imagesc
  current_axes = gca;
  current_axes.Position(3) = .5;
  current_axes.Position(1) = .3;
  annotation('textbox', [0, 0, 0.3, 1], 'String', str, 'Interpreter', 'tex', 'FontSize', 6, 'LineStyle', 'none', 'FitBoxToText', 'off');
end

%% SAVE OUTPUTS

path_parts = SAVE_PATH;
for path_part = strsplit(SAVE_NAME, '/')
  path_parts = [path_parts path_part{1} '/'];
  if exist(path_parts, 'dir') ~= 7 % 7 is a folder
    mkdir(path_parts);
  end
end
  
output_path = [SAVE_PATH SAVE_NAME '/'];

if SAVE_IMAGE
  Tomo.img = trws_data_norm;
  Time = mdata.Time(St:Tt:Et);
  save([output_path 'image.mat'], 'Tomo', 'Time');
end
if SAVE_SURF
  save([output_path 'surf.mat'], 'correct_surface');
end
if SAVE_FIG
  savefig(fig, [output_path 'surf.fig']);
end
if SAVE_IMAGESC && PLOT_IMAGESC
  savefig(fig2, [output_path 'imagesc.fig']);
end

function new_word = format_word(word, max_width)
  % Break up long entries
    new_word = '';
    no_break_run = 0;
    for c = 1:length(word)
      if no_break_run >= max_width
        new_word = [new_word sprintf('\t')];
        no_break_run = 0;
      end
      
      character = word(c);
      if character ~= ' '
        no_break_run = no_break_run + 1;
      end
      if strcmp(character, '_')
        character = '\_';
      end
      if strcmp(character, '\')
        character = '\\';
      end
      new_word = [new_word character];
    end
end
