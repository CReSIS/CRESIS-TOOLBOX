Nt  = 10;
Nsv = 20;
Nx  = 30;
MAX_LOOPS = 10;

% 'None' displays no indices
% 'ALL' displays index numbers for every cell
% 'FT' displays traversal order     for a fast-time-based search
% 'CT' displays traversal order for a cross-track-based search
INDEX_LABEL = 'None';
% 'NONE' does not plot a surface
% 'FT' plots a surface normal to the fast-time axis
% 'CT' plots a surface normal to the cross-track axis
SURFACE = 'CT';
% Display traversal order for even loops of TRWS
INDEX_EVEN_LOOP = true;

% Display on this figure
FIGURE_NUM = 1;

trws_data = zeros(Nt, Nsv, Nx);


Z = 1:Nt;
Y = 1:Nsv;
X = 1:Nx;

if strcmp(SURFACE, 'FT')
    trws_data(3, :, :) = 10;
    trws_data(2, 3:4, 2:6) = 10;
    trws_data(2, 3, 4) = 10;
    trws_data(1, 4, 4) = 30;
    
    bounds = ones(2, Nx);
    bounds(2, :) = Nt;
%     bounds(1, 3:5) = 2;

    min_bounds = ones(Nt, Nx);
    max_bounds = ones(Nt, Nx)*Nsv;
elseif strcmp(SURFACE, 'CT')
%     trws_data(:, 2, :) = 10;
%     trws_data(3:4, 3, 2:3) = 20;
%     trws_data(3, 4, 3) = 40;
    trws_data(1:4, 2, 5) = 20;
    
    bounds = ones(2, Nx);
    bounds(2, :) = Nt;
    
    min_bounds = ones(Nsv, Nx);
    max_bounds = ones(Nsv, Nx)*Nt;
    max_bounds(2, :) = Nt-1;
%     max_bounds(2, 5) = 3;
    
elseif ~strcmp(SURFACE, 'NONE')
    error('Invalid surface selection.');
end
    
% trws_data = reshape(1:Nt*Nsv*Nx, Nt, Nsv, Nx);


if ~strcmp(SURFACE, 'NONE')
    at_slope  = zeros(1, Nx);
    at_weight = 1;
    ct_slope  = zeros(Nsv, Nx);
    ct_weight = ones(1, Nsv);

    if strcmp(SURFACE, 'FT')
        correct_surface = tomo.trws2(single(trws_data),single(at_slope), ...
          single(at_weight),single(ct_slope),single(ct_weight), ...
          uint32(MAX_LOOPS), uint32(bounds - 1), 1, uint32(min_bounds - 1), uint32(max_bounds - 1));
    else
        correct_surface = tomo.trws2_CT_perm(trws_data, at_slope, at_weight, MAX_LOOPS, bounds - 1, 1, min_bounds - 1, max_bounds - 1);
    end
end

figure(FIGURE_NUM);
clf;
hold on;

if ~strcmp(SURFACE, 'CT')
    if ~strcmp(SURFACE, 'NONE')
        surf(X, Y, correct_surface, 'FaceAlpha', .2);
        surf(X, Y, repmat(bounds(1, :), Nsv, 1), 'FaceColor', [86, 135, 214]./255, 'LineStyle', 'none', 'FaceAlpha', 0.2);
        surf(X, Y, repmat(bounds(2, :), Nsv, 1), 'FaceColor', [232, 145, 90]./255, 'LineStyle', 'none', 'FaceAlpha', 0.2);
    end
    xlim([1 Nx]);
%     xticks(1:Nx);
    xlabel('X : Along-Track (Nx, DIM 2)');
    set(gca, 'XColor', 'b');
    set(gca, 'xdir', 'reverse');

    ylim([1 Nsv]);
%     yticks(1:Nsv);
    ylabel('Y : Cross-Track (Nsv. DIM 1)');
    set(gca, 'YColor', 'g');
    set(gca, 'ydir', 'reverse');

    zlim([0 Nt]);
%     zticks(0:Nt);
    zlabel('Z : Fast-Time (Nt, DIM 0)');
    set(gca, 'ZColor', 'r');
    set(gca, 'zdir', 'reverse');

    view([-45 90 90]);
    cameratoolbar('SetCoordSys', 'none');
    cameratoolbar('SetMode', 'nomode');
    rotate3d on;
else
    if ~strcmp(SURFACE, 'NONE')
        surf(X, Z, correct_surface, 'FaceAlpha', .2);
        blue   = [86 , 135, 214]./255;
        orange = [232, 145, 90 ]./255;
        surf(X, Z, repmat(bounds(1, :), Nt, 1), 'FaceColor', blue, 'LineStyle', 'none', 'FaceAlpha', 0.1);
        surf(X, Z, repmat(bounds(2, :), Nt, 1), 'FaceColor', orange, 'LineStyle', 'none', 'FaceAlpha', 0.1);
    end
    xlim([1 Nx]);
%     xticks(1:Nx);
    xlabel('X : Along-Track (Nx, DIM 2)');
    set(gca, 'XColor', 'b');
    set(gca, 'xdir', 'reverse');

    zlims = [0 Nsv];
    zlim(zlims);
%     zticks(0:Nsv);
    zlabel('Z : Cross-Track (Nsv. DIM 1)');
    set(gca, 'ZColor', 'g');
    
    ylims = [1 Nt];
    ylim(ylims);
%     yticks(1:Nt);
    ylabel('Y : Fast-Time (Nt, DIM 0)');
    set(gca, 'YColor', 'r');
    set(gca, 'ydir', 'reverse');
    
    view([90 45 90]);
    camorbit(90, 0, 'data', [0 0 1]);
    camorbit(90, 0, 'data', [1 0 0]);
    cameratoolbar('SetCoordSys', 'y');
    cameratoolbar('SetMode', 'orbit');
    
    ylim(zlims);
    zlim(ylims);
    minh = surf(min_bounds, 'FaceColor', '#304163', 'LineStyle', '-', 'FaceAlpha', 0.3);
    rotate(minh, [1 0 0], 90, [0 Nt 0]);
    set(minh, 'YData', Nt - get(minh, 'YData'));
    set(minh, 'ZData', get(minh, 'ZData') - min(get(minh, 'ZData')) + 1);
    maxh = surf(max_bounds, 'FaceColor', '#87763d', 'LineStyle', '-', 'FaceAlpha', 0.3);
    rotate(maxh, [1 0 0], 90, [0 Nt 0]);
    set(maxh, 'YData', Nt - get(maxh, 'YData'));
    set(maxh, 'ZData', get(maxh, 'ZData') - min(get(maxh, 'ZData')) + 1);
    ylim(ylims);
    zlim(zlims);
end
camva(10);
colormap(bone);

Nsvs_center = floor(Nsv/2);
Nsvs_array = [Nsvs_center:-1:1 (Nsvs_center+1):Nsv];

for w_idx = 1:Nx
    if ~INDEX_EVEN_LOOP
        w = Nx-w_idx;
    else
        w = w_idx-1;
    end
    for h_idx = 1:Nsv
        h = Nsvs_array(h_idx)-1;
        
        for d_idx = 1:Nt
            d = d_idx-1;
            
            intensity = trws_data(d_idx, h_idx, w_idx);
            color = 'b';
            if intensity > 1
                color = 'r';
            end
            if intensity > 0
                if ~strcmp(SURFACE, 'CT')
                    plot3(w_idx, h_idx, d_idx, sprintf('%s.', color), 'MarkerSize', intensity);
                else
                    plot3(w_idx, d_idx, h_idx, sprintf('%s.', color), 'MarkerSize', intensity);
                end
            end
                   
            msg_idx = NaN;
           
            if strcmp(INDEX_LABEL, 'ALL')
                msg_idx = d+(h_idx-1)*Nt+w*Nsv*Nt + 1;
            elseif strcmp(INDEX_LABEL, 'FT') && d_idx == 1
%                 idx = (h + w*Nsv)*Nt;
                msg_idx = h + w*Nsv + 1;
            elseif strcmp(INDEX_LABEL, 'CT') && h_idx == 1
%                 idx = d+w*Nsv*Nt;
                msg_idx = d+w*Nt;
            end
            
            if ~isnan(msg_idx)
                if ~strcmp(SURFACE, 'CT')
                    text(w_idx, h_idx, d_idx, sprintf('%d', msg_idx));
                else
                    text(w_idx, d_idx, h_idx, sprintf('%d', msg_idx));
                end
            end
        end
    end
end
