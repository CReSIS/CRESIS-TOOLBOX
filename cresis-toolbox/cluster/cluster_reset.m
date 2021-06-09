function ctrl_chain = cluster_reset(ctrl_chain)
% ctrl_chain = cluster_reset(ctrl_chain)
%
% Resets tasks in a control chain that failed due to errors and prepares
% the control chain to be submitted to cluster_run again.
%  1. Resets the error mask to zero for tasks with nonzero errors.
%  2. The retries are reset to zero for these tasks.
%  3. The status is set to 'T'
%  4. The tasks are added to the submission queue
%  
% Author: John Paden

if iscell(ctrl_chain)
  %% Traverse chain list
  for chain = 1:numel(ctrl_chain)
    fprintf('Chain %d\n', chain);
    for stage=1:numel(ctrl_chain{chain})
      fprintf('  Stage %d\n', stage);
      [ctrl_chain{chain}{stage}] = cluster_reset(ctrl_chain{chain}{stage});
    end
  end
  
elseif isstruct(ctrl_chain)
  ctrl = ctrl_chain;
  
  error_task_ids = find(ctrl.error_mask);
  if 0 % special case to reset failed and/or queued jobs
    queued_task_ids = regexp(ctrl.job_status,'Q');
    error_task_ids = union(error_task_ids,queued_task_ids);
  end
  ctrl.error_mask(error_task_ids) = 0;
  ctrl.retries(error_task_ids) = 0;
  ctrl.job_status(error_task_ids) = 'T';
  ctrl.submission_queue(end+(1:length(error_task_ids))) = error_task_ids;
  ctrl.submission_queue = unique(ctrl.submission_queue);
  
  % Update output
  ctrl_chain = ctrl;
end
