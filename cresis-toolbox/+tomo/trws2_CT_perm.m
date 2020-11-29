function [surface, debug] = trws2_CT_perm(image, at_slope, at_weight, max_loops, ct_bounds, traversal_method, ft_bounds_top, ft_bounds_bottom, skip_cols)

  if nargin < 6
    traversal_method = 1;
  end
  if nargin < 8
    % Missing at least bottom surface
    skip_cols = false;
  elseif nargin == 8
    % Both surfaces present
    skip_cols = true;
  end
  % otherwise, just use given skip_cols

  NOISE_FLOOR = -40;

  % Remove data entirely outside ft_bounds
  min_bound = min(ft_bounds_top(:)) + 1;
  ft_bounds_top = ft_bounds_top - min_bound + 1;
  max_bound = max(ft_bounds_bottom(:)) + 1;
  ft_bounds_bottom = ft_bounds_bottom - min_bound + 1;
  new_image = image(min_bound:max_bound, :, :);
  
  [nt, nsv, nx] = size(new_image);
  new_image = echo_norm(new_image, struct('scale', [NOISE_FLOOR 90]));

  for rline = 1:nx
    for doa_bin = 1:nsv
      new_image(1:nt < ft_bounds_top(doa_bin, rline), doa_bin, rline) = NOISE_FLOOR;
      new_image(1:nt > ft_bounds_bottom(doa_bin, rline), doa_bin, rline) = NOISE_FLOOR;
    end
  end 

  new_image = permute(new_image, [2 1 3]);
  ct_slope = zeros(size(new_image, 2), size(new_image, 3));
  ct_weight = ones(1, size(new_image, 2))*at_weight(1);

  if ~skip_cols
    [surface, debug] = tomo.trws2(single(new_image), single(at_slope), ...
      single(at_weight), single(ct_slope), single(ct_weight), uint32(max_loops), ...
      uint32(ct_bounds), uint32(traversal_method), uint32(ft_bounds_top), uint32(ft_bounds_bottom));
  else
    [surface, debug] = tomo.trws2(single(new_image), single(at_slope), ...
      single(at_weight), single(ct_slope), single(ct_weight), uint32(max_loops), ...
      uint32(ct_bounds), uint32(traversal_method));
  end
  
  debug = permute(debug, [2 1 3]);
  debug = [nan(min_bound - 1, nsv, nx); debug; nan(size(image, 1) - max_bound, nsv, nx)];
  
  for rline = 1:nx
    for doa_bin = 1:nsv
      surface(1:nt < ft_bounds_top(doa_bin, rline), rline) = NaN;
      surface(1:nt > ft_bounds_bottom(doa_bin, rline), rline) = NaN;
    end
  end 
  
  surface = [nan(min_bound - 1, nx); surface; nan(size(image, 1) - max_bound, nx)];
end