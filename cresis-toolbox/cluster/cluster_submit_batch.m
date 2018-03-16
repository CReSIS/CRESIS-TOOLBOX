function out = cluster_submit_batch(fun,block,argsin,num_args_out,cpu_time)
% out = cluster_submit_batch(fun,block,argsin,num_args_out,notes,cpu_time)
%
% Runs an arbitrary job called "fun" with inputs "argsin". Introduces
% about 30 seconds of overhead as long as a compile is not necessary.
%
% INPUTS:
% fun: string containing the function name (e.g. 'hanning') that the task
%   will run
% argsin: cell vector of input arguments to the task (e.g. {10,'arg2'})
% num_args_out: number of output arguments
% notes: string containing notes about the task
% cpu_time: expected maximum cpu time in seconds
% mem: expected maximum memory usage in bytes
%
% OUTPUTS:
% out: if block = true, cell vector of output arguments from the task
% out: if block = false, cluster control structure for the batch
%
% EXAMPLES:
% % Blocking example:
% cluster_submit_batch('hanning',true,{10},1,60);
%
% % Non-blocking example:
% ctrl = cluster_submit_batch('hanning',false,{10},1,60);
% ctrl_chain = {{ctrl}};
% while any(isfinite(cluster_chain_stage(ctrl_chain)))
%   pause(1);
%   ctrl_chain = cluster_run(ctrl_chain,false);
% end
% [in,out] = cluster_print(ctrl_chain{1}{1}.batch_id,1,0);
% cluster_cleanup(ctrl_chain{1}{1}.batch_id);
%
% out = cluster_submit_batch('hanning',true,{10},1,60)
%
% Author: John Paden
%
% See also: cluster_chain_stage, cluster_cleanup, cluster_compile
%   cluster_exec_job, cluster_get_batch, cluster_get_batch_list, 
%   cluster_hold, cluster_job, cluster_new_batch, cluster_new_task,
%   cluster_print, cluster_run, cluster_submit_batch, cluster_submit_task,
%   cluster_update_batch, cluster_update_task

ctrl = cluster_new_batch;

cluster_compile(fun,[],0,ctrl);

param.task_function = fun;
param.argsin = argsin;
param.num_args_out = num_args_out;
param.cpu_time = cpu_time;
ctrl = cluster_new_task(ctrl,param,[]);

fprintf('Submitting %s\n', ctrl.batch_dir);

ctrl_chain = {{ctrl}};

ctrl_chain = cluster_run(ctrl_chain,block);

if block
  [in,out] = cluster_print(ctrl_chain{1}{1}.batch_id,1,0);
  cluster_cleanup(ctrl);
else
  out = ctrl;
  
end

return;