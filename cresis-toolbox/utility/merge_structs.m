function S_out = merge_structs(S_in,S_over,truncate_flag)
% S_out = merge_structs(S_in,S_over,truncate_flag)
%
% Merges two structures. S_over takes precedence.
%
% S_in: input struct
% S_over: struct which will override any fields in S_in
% truncate_flag: Default is true. In the case of a structure array, if
%   S_over has fewer elements than S_in, S_out will be truncated to the
%   number of elements in S_over.
%
% S_out = merged structure
%
% Example: See bottom of file
%
% Authors: Huan Zhao, John Paden

% Input check
if ~exist('truncate_flag','var')
  truncate_flag = true;
end

% Handle simple cases
if isempty(S_over)
  S_out = S_in;
  return;
end
if isempty(S_in) || ~isa(S_in,class(S_over)) || ~isstruct(S_over)
  S_out = S_over;
  return;
end

% Setup to merge structs
S_out = S_in;
outputfields = fieldnames(S_out);
overfields = fieldnames(S_over);

% Truncate output to the number of elements in the override structure
if truncate_flag && numel(S_over) < numel(S_out)
  S_out = S_out(1:numel(S_over));
end

for idx = 1:numel(S_over)
  if idx > numel(S_out)
    S_out(idx) = S_over(idx)
  else
    % Traverse the structure as a tree where leafs are copied/overwritten
    % and branches/children (type == struct) are dealt with recursively.
    for x = 1:length(overfields)
      found = false;
      for y = 1:length(outputfields)
        if strcmp(overfields{x},outputfields{y})
          % If the override has a field that IS present in S_in
          if isstruct(getfield(S_over(idx),overfields{x}))
            % Recursively call the function for children structs
            S_out(idx).(outputfields{y}) = merge_structs(getfield(S_out(idx), outputfields{y}),getfield(S_over(idx), overfields{x}));
          else
            % Just overwrite the field if the S_out field is not a struct
            % (i.e. it is a leaf)
            S_out(idx).(outputfields{y}) = getfield(S_over(idx), overfields{x});
          end
          found=true;
          break;
        end
        
      end
      if ~found
        % If the override has a field that IS NOT present in S_in
        S_out(idx).(overfields{x}) = getfield(S_over(idx), overfields{x});
      end
    end
  end
end

return ;

% ==================================================================
% ==================================================================
% Examples
% ==================================================================
% ==================================================================

S_in.A = 1;
S_in.B = 2;
S_in.C(1).D = 4;
S_in.C(1).D2 = 4.2;
S_in.C(2).D = 3;
S_over.A = 5;
S_over.C.D = 42;
S_over.C.E = 6;
S_over.F = 7;
S_out = merge_structs(S_in,S_over)

