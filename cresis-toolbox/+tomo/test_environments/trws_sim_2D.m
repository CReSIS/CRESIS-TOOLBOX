% Modified from Paden's code to allow saving and keyboard control - Reece
function correct_surface = trws_sim_2D(image, num_loops)
SAVE_PATH = 'C:/Users/mathe/Documents/MATLAB/TRWS_CT results/paden_sim/output images/';
SAVE_NAME = 'result'; % name of save files and directory
SAVE = true;
% Not complete, but started work on 2D MRF
rng(0);
mdata = struct();

if nargin == 0
  num_nodes = [32 24];
  num_states = 14;
  num_loops = 16;
  if 0
    mdata.I = ones(num_states,num_nodes(1),num_nodes(2));
  else
    mdata.I = 1*randn(num_states,num_nodes(1),num_nodes(2));
    % Add in surface points
  %   mdata.I(1:5,1:3,:) = mdata.I(1:5,1:3,:) + 3.5;
  %   mdata.I(6,[1],:) = mdata.I(6,[1],:) + [10];
  %   mdata.I(7,[4 10],:) = bsxfun(@plus, mdata.I(7,[4 10],:),[5 7]);
  %   mdata.I(5,[13 15],:) = bsxfun(@plus, mdata.I(5,[13 15],:),[5 7]);
  %   mdata.I(4,[19],:) = mdata.I(4,[19],:) + [4];
  %   % Remove first 8 rows of every column
  %   mdata.I(:,17:32,:) = 1*randn(num_states,16,num_nodes(2));
  %   % Artifact
  %   mdata.I(12,26:28,14:16) = mdata.I(12,26:28,14:16) + 1000;

    mdata.I(1:2, 1:2, :) = randn(2, 2, num_nodes(2))*5;

  end
else 
  SAVE = false;
  mdata.I = image;
  num_nodes = size(image, [2 3]);
  num_states = size(image, 1);
end
mdata.cols = num_nodes(2);
mdata.col = 1;

mdata.msg_up = zeros(num_states,num_nodes(1),num_nodes(2));
mdata.msg_down = zeros(num_states,num_nodes(1),num_nodes(2));
mdata.msg_left = zeros(num_states,num_nodes(1),num_nodes(2));
mdata.msg_right = zeros(num_states,num_nodes(1),num_nodes(2));
old_msg_up = zeros(num_states,num_nodes(1),num_nodes(2));
old_msg_down = zeros(num_states,num_nodes(1),num_nodes(2));
old_msg_left = zeros(num_states,num_nodes(1),num_nodes(2));
old_msg_right = zeros(num_states,num_nodes(1),num_nodes(2));
trws_en = false;
normalize = true;
smooth_scale = 1;

loop_dir = 2;
mdata.h_fig = figure;
set(mdata.h_fig,'WindowKeyPressFcn',@keyboard_input);
mdata.h_fig2 = figure;
set(mdata.h_fig2,'WindowKeyPressFcn',@keyboard_input);

for loop = 0:num_loops-1
  fprintf('loop %d\n', loop);
  for idx = 1:prod(num_nodes)
    %fprintf('  idx %d\n', idx);
    if mod(floor(bitshift(loop,-log2(loop_dir/2))),2) == 0
      node_idx = idx;
    else
      node_idx = prod(num_nodes)+1-idx;
    end
    row_idx = 1 + mod((node_idx-1),num_nodes(1));
    col_idx = 1 + floor((node_idx-1)/num_nodes(1));
    if row_idx < num_nodes(1)
      if 0
        mdata.msg_up(:,row_idx+1,col_idx) = old_msg_up(:,row_idx,col_idx) + mdata.I(:,row_idx,col_idx);
      else
        for state = 1:num_states
          mdata.msg_up(state,row_idx+1,col_idx) = max(mdata.I(:,row_idx,col_idx) + old_msg_left(:,row_idx,col_idx) + old_msg_right(:,row_idx,col_idx) + old_msg_up(:,row_idx,col_idx) - smooth_scale*(state-(1:num_states).').^2);
        end
        if normalize
          mdata.msg_up(:,row_idx+1,col_idx) = mdata.msg_up(:,row_idx+1,col_idx) - max(mdata.msg_up(:,row_idx+1,col_idx));
        end
      end
    end
    if row_idx > 1
      if 0
        mdata.msg_down(:,row_idx-1,col_idx) = old_msg_down(:,row_idx,col_idx) + mdata.I(:,row_idx,col_idx);
      else
        for state = 1:num_states
          mdata.msg_down(state,row_idx-1,col_idx) = max(mdata.I(:,row_idx,col_idx) + old_msg_left(:,row_idx,col_idx) + old_msg_right(:,row_idx,col_idx) + old_msg_down(:,row_idx,col_idx) - smooth_scale*(state-(1:num_states).').^2);
        end
        if normalize
          mdata.msg_down(:,row_idx-1,col_idx) = mdata.msg_down(:,row_idx-1,col_idx) - max(mdata.msg_down(:,row_idx-1,col_idx));
        end
      end
    end;
    if col_idx < num_nodes(2)
      if 0
        mdata.msg_left(:,row_idx,col_idx+1) = old_msg_left(:,row_idx,col_idx) + mdata.I(:,row_idx,col_idx);
      else
        for state = 1:num_states
          mdata.msg_left(state,row_idx,col_idx+1) = max(mdata.I(:,row_idx,col_idx) + old_msg_up(:,row_idx,col_idx) + old_msg_down(:,row_idx,col_idx) + old_msg_left(:,row_idx,col_idx) - smooth_scale*(state-(1:num_states).').^2);
        end
        if normalize
          mdata.msg_left(:,row_idx,col_idx+1) = mdata.msg_left(:,row_idx,col_idx+1) - max(mdata.msg_left(:,row_idx,col_idx+1));
        end
      end
    end
    if col_idx > 1
      if 0
        mdata.msg_right(:,col_idx-1) = old_msg_right(:,col_idx) + mdata.I(:,col_idx);
      else
        for state = 1:num_states
          mdata.msg_right(state,row_idx,col_idx-1) = max(mdata.I(:,row_idx,col_idx) + old_msg_up(:,row_idx,col_idx) + old_msg_down(:,row_idx,col_idx) + old_msg_right(:,row_idx,col_idx) - smooth_scale*(state-(1:num_states).').^2);
        end
        if normalize
          mdata.msg_right(:,row_idx,col_idx-1) = mdata.msg_right(:,row_idx,col_idx-1) - max(mdata.msg_right(:,row_idx,col_idx-1));
        end
      end
    end;
    if trws_en
      old_msg_up = mdata.msg_up;
      old_msg_down = mdata.msg_down;
      old_msg_right = mdata.msg_right;
      old_msg_left = mdata.msg_left;
    end
    
    if 0
      figure(1); clf; imagesc(mdata.msg_left(:,:,1));
      figure(2); clf; imagesc(mdata.msg_right(:,:,1));
      figure(3); clf; imagesc(mdata.msg_up(:,:,1));
      figure(4); clf; imagesc(mdata.msg_down(:,:,1));
    elseif 0
      imagesc(mdata.I(:,:,1) + mdata.msg_left(:,:,1) + mdata.msg_right(:,:,1) + mdata.msg_up(:,:,1) + mdata.msg_down(:,:,1));
    end
  end
  
  old_msg_up = mdata.msg_up;
  old_msg_down = mdata.msg_down;
  old_msg_right = mdata.msg_right;
  old_msg_left = mdata.msg_left;
  [~,mdata.result] = max(mdata.I + mdata.msg_left + mdata.msg_right + mdata.msg_up + mdata.msg_down);
  if 0
    clf;
    for col = 1:num_nodes(2)
      imagesc(mdata.I(:,:,col) + mdata.msg_left(:,:,col) + mdata.msg_right(:,:,col) + mdata.msg_up(:,:,col) + mdata.msg_down(:,:,col));
      hold on
      plot(mdata.result(1,:,col),'k')
      title(sprintf('column %d',col));
      pause
    end
    drawnow;
  end
end

output_matrix = mdata.I + mdata.msg_left + mdata.msg_right + mdata.msg_up + mdata.msg_down;
mdata.limsi = [min(mdata.I(:)) max(mdata.I(:))];
mdata.limso = [min(output_matrix(:)) max(output_matrix(:))];

[mdata.confidence,mdata.result] = max(output_matrix);
set(mdata.h_fig2,'UserData',mdata);
set(mdata.h_fig,'UserData',mdata);
event.Modifier = '';
event.Key = 'rightarrow';
keyboard_input(mdata.h_fig,event);
event.Key = 'leftarrow';
keyboard_input(mdata.h_fig,event);

correct_surface = mdata.result;

if SAVE
  output_path = [SAVE_PATH SAVE_NAME '/'];

  if exist(output_path, 'dir') ~= 7 % 7 is a folder
    mkdir(output_path);
  end
  Tomo.img = permute(mdata.I, [2 1 3]);
  Time = 1:num_states;
  save([output_path 'image.mat'], 'Tomo', 'Time');
  save([output_path 'surf.mat'], 'correct_surface');
end

end

function keyboard_input(h_object,event)

if any(strcmpi(event.Modifier,'shift'))
  step = 10;
else
  step = 1;
end

if ~isempty(event.Key)
  mdata = h_object.UserData;
  
  % see event.Modifier for modifiers
  switch event.Key
      
    case 'rightarrow' % Right arrow
      if mdata.col < mdata.cols+1-step
        mdata.col = mdata.col + step;
      end
      
    case 'leftarrow' % Left arrow
      if mdata.col > step
        mdata.col = mdata.col - step;
      end
      
    otherwise
      return;
  end
  
  figure(mdata.h_fig); clf;
  h_img1 = imagesc(mdata.I(:,:,mdata.col));
  caxis(mdata.limsi);
  cbar1 = colorbar;
  ylabel(cbar1, 'Input Image Intensity');
  ylabel('num\_states (FT rbin)');
  xlabel('num\_nodes(1) (CT DoA bin)');
  title(sprintf('INPUT num\\_nodes(2) column %d (AT rline)',mdata.col));
  hold on
  plot(mdata.result(1,:,mdata.col),'k')
  figure(mdata.h_fig2); clf;
  h_img2 = imagesc(mdata.I(:,:,mdata.col) + mdata.msg_left(:,:,mdata.col) + mdata.msg_right(:,:,mdata.col) + mdata.msg_up(:,:,mdata.col) + mdata.msg_down(:,:,mdata.col));
  caxis(mdata.limso);
  cbar2 = colorbar;
  ylabel(cbar2, 'Output Image Intensity');
  ylabel('num\_states (FT rbin)');
  xlabel('num\_nodes(1) (CT DoA bin)');
  hold on
  plot(mdata.result(1,:,mdata.col),'k')
  title(sprintf('OUTPUT num\\_nodes(2) column %d (AT rline)',mdata.col));
  set(mdata.h_fig2,'UserData',mdata);
  set(mdata.h_fig,'UserData',mdata);
  figure(h_object);
end
end
