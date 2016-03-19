function ctrl = torque_job_status(ctrl)
% ctrl = torque_job_status(ctrl)
%
% Updates job status information from the torque cluster. Also prints
% out status information when job changes status.
%
% Inputs:
% ctrl = ctrl structure returned from torque_new_batch
%  .job_id_list = Nx1 vector of torque job IDs
%  .job_status = Nx1 vector of job status
%  .out_path_dir = string containing the output directory
%  .error_mask = Nx1 vector of error status
%  .out = up-to-Nx1 vector of cells containing the outputs for each
%    job as they complete (read in from the output.mat files)
%
% Outputs:
% ctrl = updated ctrl structure
%
% C -  Job is completed after having run.
% E -  Job is exiting after having run.
% H -  Job is held.
% Q -  job is queued, eligible to run or routed.
% R -  job is running.
% T -  job is being moved to new location.
% W -  job is waiting for its execution time
%      (-a option) to be reached.
% S -  (Unicos only) job is suspend.
%
% Author: John Paden
%
% See also: torque_batch_list torque_cleanup torque_compile ...
%   torque_create_task torque_hold torque_job_list torque_job_status ...
%   torque_new_batch torque_print torque_rerun

if ~isfield(ctrl.sched,'test_mode')
  ctrl.sched.test_mode = 0;
end

job_status_found = zeros(size(ctrl.job_status));

if ~ctrl.sched.test_mode
  %% Runs qstat command
  cmd = 'qstat';
  status = -1;
  torque_attempts = 0;
  while status ~= 0
    try
      [status,result] = system(cmd);
    catch
      cmd
      warning('system call failed');
      keyboard;
    end
    if status ~= 0
      warning('qstat failed %d %s', status, result);
      torque_attempts = torque_attempts + 1;
      delay_period = 3*2^(torque_attempts-1);
      fprintf('  Delaying %d seconds\n', delay_period)
      pause(delay_period);
      if torque_attempts > 10
        % There is potentially something wrong with the torque scheduler if
        % job submission fails this many times. Look into it before running
        % "dbcont" to keep trying to submit.
        keyboard;
      end
    end
  end
  
  %% Parse qstat command results
  if ~isempty(result)
    qstat_res = textscan(result,'%s %s %s %s %s %s','HeaderLines',2,'Delimiter',sprintf(' \t'),'MultipleDelimsAsOne',1);
    for idx = 1:size(qstat_res{1},1)
      qstat_res{7}(idx) = str2double(strtok(qstat_res{1}{idx},'.'));
    end
    % Loop through all the jobs that qstat returned
    for idx = 1:size(qstat_res{5},1)
      job_ids = find(qstat_res{7}(idx)==ctrl.job_id_list);
      % Qstat returns all jobs, just look at jobs in this batch
      while ~isempty(job_ids)
        job_id = job_ids(1);
        job_ids = job_ids(2:end);
        job_status_found(job_id) = 1;
        if qstat_res{5}{idx} ~= ctrl.job_status(job_id)
          if ctrl.job_status(job_id) ~= 'C'
            new_job_status = qstat_res{5}{idx};
            if new_job_status ~= 'R' && ctrl.job_status(job_id) ~= 'C'
              % Print a message for all changes besides running and exiting
              fprintf(' QJob %d:%d/%d status changed to %s (%s)\n', ctrl.batch_id, job_id, qstat_res{7}(idx), new_job_status, datestr(now))
            end
            ctrl.job_status(job_id) = new_job_status;
            if ctrl.job_status(job_id) == 'C' || ctrl.job_status(job_id) == 'E'
              %% Get the output information
              % There is a bug that sometimes jobs will go into exitting state
              % and never complete in a timely fashion but do have good outputs
              % so we check for these jobs too.
              in_path = fullfile(ctrl.in_path_dir,sprintf('in_%d.mat',job_id));
              clear param; load(in_path,'param');
              if param.conforming
                % Good output implies: output file exists and contains a first
                % output argument containing the number "1"
                out_path = fullfile(ctrl.out_path_dir,sprintf('out_%d.mat',job_id));
                
                torque_attempts = 0;
                try_loading_again = true;
                while try_loading_again
                  if ~exist(out_path,'file')
                    % Output file does not exist
                    ctrl.error_mask(job_id) = 1;
                  else
                    try
                      ctrl.out{job_id} = load(out_path,'argsout');
                    catch
                      ctrl.out{job_id} = [];
                    end
                    if isempty(ctrl.out{job_id})
                      % Corrupt output file, missing argsout, or empty argsout
                      ctrl.error_mask(job_id) = 2;
                    else
                      try
                        if ctrl.out{job_id}.argsout{1} ~= 1
                          % Failure in job's Matlab code (i.e. probably exitted
                          % due to an "error" exception in users code)
                          ctrl.error_mask(job_id) = 3;
                        else
                          % Success!
                          ctrl.error_mask(job_id) = 0;
                          try_loading_again = false;
                          break;
                        end
                      catch
                        % Non-conforming output (e.g. argsout{1} is not double scalar)
                        ctrl.error_mask(job_id) = 4;
                      end
                    end
                  end
                  if torque_attempts < 5
                    fprintf('  Output file not generated yet, trying again...\n');
                    torque_attempts = torque_attempts + 1;
                    delay_period = 3*2^(torque_attempts-1);
                    if exist(fullfile(ctrl.batch_dir,'keyboard'), 'file')
                      % Hold keyboard file exists
                      keyboard
                    end
                    pause(delay_period);
                  else
                    fprintf('    Gave up looking for output file\n');
                    try_loading_again = false; % Give up!
                  end
                end
                
                if ctrl.error_mask(job_id)
                  if exist(out_path,'file')
                    out = load(out_path);
                    error_string = '';
                    if isfield(out,'errorstruct')
                      error_string = sprintf('%s: %s\n', out.errorstruct.identifier, out.errorstruct.message);
                      for stack_idx = 1:length(out.errorstruct.stack)
                        error_string = cat(2,error_string,...
                          sprintf('  %s: %d\n', out.errorstruct.stack(stack_idx).name, out.errorstruct.stack(stack_idx).line));
                      end
                    end
                    warning('Job %d:%d/%d Error:\n%s', ctrl.batch_id, job_id, qstat_res{7}(idx), error_string);
                  else
                    warning('Job %d:%d/%d Error, no output file\n', ctrl.batch_id, job_id, qstat_res{7}(idx));
                    out = [];
                  end
                end
              
            else
              out_path = fullfile(ctrl.out_path_dir,sprintf('out_%d.mat',job_id));
              if ~exist(out_path,'file')
                  % Output file does not exist
                  ctrl.error_mask(job_id) = 1;
                else
                  try
                    ctrl.out{job_id} = load(out_path,'argsout');
                    ctrl.error_mask(job_id) = 0;
                    ctrl.job_status(job_id) = 'C'; % Since things worked, force any 'E' settings to 'C'
                  catch
                    % Corrupt output file, missing argsout
                    ctrl.error_mask(job_id) = 2;
                    ctrl.out{job_id} = [];
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

%% For any jobs not returned by qstat, we assume they have completed
% and have been removed from the queue.
if any(job_status_found==0)
  lost_jobs = find(~job_status_found);
  for job_id = lost_jobs
    if ctrl.job_status(job_id) ~= 'C' && ctrl.job_status(job_id) ~= 'T'
      ctrl.job_status(job_id) = 'C';
      fprintf(' DJob %d:%d/%d status changed to %s (%s)\n', ctrl.batch_id, job_id, ctrl.job_id_list(job_id), 'C', datestr(now))
      in_path = fullfile(ctrl.in_path_dir,sprintf('in_%d.mat',job_id));
      clear param; load(in_path,'param');
      if param.conforming
        % Good output implies: output file exists and contains a first
        % output argument containing the number "1"
        out_path = fullfile(ctrl.out_path_dir,sprintf('out_%d.mat',job_id));
        if ~exist(out_path,'file')
          % Output file does not exist
          ctrl.error_mask(job_id) = 1;
        else
          try
            ctrl.out{job_id} = load(out_path,'argsout');
          catch
            ctrl.out{job_id} = [];
          end
          if isempty(ctrl.out{job_id})
            % Corrupt output file, missing argsout, or empty argsout
            ctrl.error_mask(job_id) = 2;
          else
            try
              if ctrl.out{job_id}.argsout{1} ~= 1
                % Failure in job's Matlab code (i.e. probably exitted
                % due to an "error" exception in users code)
                ctrl.error_mask(job_id) = 3;
              else
                % Success!
                ctrl.error_mask(job_id) = 0;
              end
            catch
              % Non-conforming output (e.g. argsout{1} is not double scalar)
              ctrl.error_mask(job_id) = 4;
            end
          end
        end
      else
        out_path = fullfile(ctrl.out_path_dir,sprintf('out_%d.mat',job_id));
        if ~exist(out_path,'file')
          % Output file does not exist
          ctrl.error_mask(job_id) = 1;
        else
          try
            ctrl.out{job_id} = load(out_path,'argsout');
          catch
            % Corrupt output file, missing argsout
            ctrl.error_mask(job_id) = 2;
            ctrl.out{job_id} = [];
          end
        end
      end
    end
  end
end

torque_broken = true;
if torque_broken && isfield(ctrl.sched,'conforming') && ctrl.sched.conforming
  %% Handle case where torque loses track of a running job that completes
  for job_id = find(ctrl.job_status == 'R')
    out_path = fullfile(ctrl.out_path_dir,sprintf('out_%d.mat',job_id));
    if ~exist(out_path,'file')
      % Output file does not exist
      continue;
    else
      % Output file exists... try a few times to open it and interpret the
      % contents
      fprintf(' RJob %d:%d/%d status changed to %s (%s)\n', ctrl.batch_id, job_id, ctrl.job_id_list(job_id), 'C', datestr(now))
      ctrl.job_status(job_id) = 'C';
      torque_attempts = 0;
      try_loading_again = true;
      while try_loading_again
        try
          ctrl.out{job_id} = load(out_path,'argsout');
        catch
          ctrl.out{job_id} = [];
        end
        if isempty(ctrl.out{job_id})
          % Corrupt output file, missing argsout, or empty argsout
          ctrl.error_mask(job_id) = 2;
        else
          try
            if ctrl.out{job_id}.argsout{1} ~= 1
              % Failure in job's Matlab code (i.e. probably exitted
              % due to an "error" exception in users code)
              ctrl.error_mask(job_id) = 3;
            else
              % Success!
              ctrl.error_mask(job_id) = 0;
              try_loading_again = false;
              break;
            end
          catch
            % Non-conforming output (e.g. argsout{1} is not double scalar)
            ctrl.error_mask(job_id) = 4;
          end
        end
        if torque_attempts < 5
          fprintf('  Output file not generated yet, trying again...\n');
          torque_attempts = torque_attempts + 1;
          delay_period = 3*2^(torque_attempts-1);
          if exist(fullfile(ctrl.batch_dir,'keyboard'), 'file')
            % Hold keyboard file exists
            keyboard
          end
          pause(delay_period);
        else
          fprintf('    Gave up looking for output file\n');
          try_loading_again = false; % Give up!
        end
      end
    end
  end
end

end