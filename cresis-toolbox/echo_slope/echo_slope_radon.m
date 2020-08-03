function [slope, slope_corr] = echo_slope(param, param_override)

%keyboard





%% General Setup
% =====================================================================

param = merge_structs(param, param_override);

% fprintf('=====================================================================\n');
% fprintf('%s: %s (%s)\n', mfilename, param.day_seg, datestr(now));
% fprintf('=====================================================================\n');


max_slope = param.echo_slope.max_slope;
min_slope = param.echo_slope.min_slope;
n = param.echo_slope.n;


%array of theta angles 
theta = linspace(min_slope, max_slope, n);

param.echo_slope.theta = theta;

mdata = load('/cresis/snfs1/dataproducts/ct_data/rds/2014_Greenland_P3/CSARP_post/CSARP_standard/20140508_01/Data_20140508_01_057.mat');

figure(101);
imagesc(lp(mdata.Data))

colormap(1-gray(256))

echo_slope_radon_task(mdata, param);


% xcorr

% %% Input Checks: cmd
% % =====================================================================
% 
% %Remove frames that do not exist from param.cmd.frms list
% frames = frames_load(params);
% params.cmd.frms = frames_param_cmd_frms(params,frames);
% 
%  % Load the current frame
%     frm_str{frm_idx} = sprintf('%s_%03d',param.day_seg,frm);
%     data_fn = fullfile(in_fn_dir, sprintf('Data_%s.mat',frm_str{frm_idx}));
%     %if frm_idx == 1
%       mdata = load_L1B(data_fn);
%       frm_start(frm_idx) = 1;
%       frm_stop(frm_idx) = length(mdata.GPS_time);
%       dt = mdata.Time(2) - mdata.Time(1);





