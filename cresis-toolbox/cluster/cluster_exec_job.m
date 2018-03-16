function cluster_exec_job(ctrl,task_ids,run_mode)
% cluster_exec_job(ctrl,task_ids,run_mode)
%
% Re-executes a specific job from the command line (runs it locally).
%
% Inputs:
% ctrl = ctrl structure returned from cluster_new_batch
%  .sched = scheduler structure
%   .worker_fn = path to worker
%  .in_fn_dir = input arguments directory
%  .out_fn_dir = output arguments directory
% task_ids = vector of task IDs, to run
% run_mode = optional scalar integer indicating how to run the job:
%   1: Run job through uncompiled cluster_job.m function
%   2: Run job through compiled cluster_job.m function
%   3: Run job through cluster_job.sh function
%
% Author: John Paden
%
% See also: cluster_chain_stage, cluster_cleanup, cluster_compile
%   cluster_exec_job, cluster_get_batch, cluster_get_batch_list, 
%   cluster_hold, cluster_job, cluster_new_batch, cluster_new_task,
%   cluster_print, cluster_run, cluster_submit_batch, cluster_submit_task,
%   cluster_update_batch, cluster_update_task

if ~exist('run_mode','var') || isempty(run_mode)
  run_mode = 1;
end

% Create input filenames
static_in_fn = fullfile(ctrl.in_fn_dir,'static.mat');
dynamic_in_fn = fullfile(ctrl.in_fn_dir,'dynamic.mat');
% Load input filenames
sparam = load(static_in_fn);
dparam = load(dynamic_in_fn);

for task_idx = 1:length(task_ids)
  task_id = task_ids(task_idx);
  
  if run_mode == 1
    cluster_task_start_time = tic;
    fprintf('  %s: batch %d task %d (%d of %d) (%s)\n', mfilename, ctrl.batch_id, task_id, task_idx, length(task_ids), datestr(now));

    % Create output filename
    out_fn = fullfile(ctrl.out_fn_dir,sprintf('out_%d.mat',task_id));
    
    param = merge_structs(sparam.static_param,dparam.dparam{task_id});
    % Special merge of argsin cell array
    if isfield(sparam.static_param,'argsin')
      sparam_argsin_numel = numel(sparam.static_param.argsin);
    else
      sparam.static_param.argsin = {};
      sparam_argsin_numel = 0;
    end
    if isfield(dparam.dparam{task_id},'argsin')
      dparam_argsin_numel = numel(dparam.dparam{task_id}.argsin);
    else
      dparam.dparam{task_id}.argsin = {};
      dparam_argsin_numel = 0;
    end
    for idx = 1:max(sparam_argsin_numel,dparam_argsin_numel)
      if idx <= sparam_argsin_numel
        if idx <= dparam_argsin_numel
          param.argsin{idx} = merge_structs(sparam.static_param.argsin{idx},dparam.dparam{task_id}.argsin{idx});
        else
          param.argsin{idx} = sparam.static_param.argsin{idx};
        end
      else
        param.argsin{idx} = dparam.dparam{task_id}.argsin{idx};
      end
    end
    
    % Creating command to evaluate
    if param.num_args_out == 0
      eval_cmd = sprintf('%s(',param.task_function);
    else
      eval_cmd = sprintf('[argsout{1:%i}] = %s(',param.num_args_out,param.task_function);
    end
    for argsin_idx = 1:length(param.argsin)
      if argsin_idx < length(param.argsin)
        eval_cmd = sprintf('%sparam.argsin{%i},', eval_cmd, argsin_idx);
      else
        eval_cmd = sprintf('%sparam.argsin{%i}', eval_cmd, argsin_idx);
      end
    end
    eval_cmd = sprintf('%s);', eval_cmd);
    
    argsout = {};
    errorstruct = [];
    fprintf('  %s: Eval %s\n', mfilename, eval_cmd);
    try
      eval(eval_cmd);
    catch errorstruct
    end
    fprintf('  %s: Done eval\n', mfilename);
    cpu_time_actual = toc(cluster_task_start_time);
    save(out_fn,param.file_version,'argsout','errorstruct','cpu_time_actual');
    
  elseif run_mode == 2
    setenv('INPUT_PATH',ctrl.in_fn_dir);
    setenv('OUTPUT_PATH',ctrl.out_fn_dir);
    task_list_str = sprintf('%dd',task_id); task_list_str = task_list_str(1:end-1);
    setenv('TASK_LIST',task_list_str);
    setenv('CUSTOM_CLUSTER','1');
    cluster_job;
    
  elseif run_mode == 3
    setenv('INPUT_PATH',ctrl.in_fn_dir);
    setenv('OUTPUT_PATH',ctrl.out_fn_dir);
    task_list_str = sprintf('%dd',task_id); task_list_str = task_list_str(1:end-1);
    setenv('TASK_LIST',task_list_str);
    setenv('CUSTOM_CLUSTER','1');
    system(ctrl.cluster.cluster_job_fn);
  end
end
return;