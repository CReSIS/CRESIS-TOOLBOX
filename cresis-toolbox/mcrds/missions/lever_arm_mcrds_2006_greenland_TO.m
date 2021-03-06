function [phase_center] = lever_arm_mcords_2006_Greenland_TO(tx_weights, rxchannel)
% [phase_center] = lever_arm_mcrds_2006_greenland_TO(tx_weights, rxchannel)
%
% Returns lever arm position for 2006 Greenland TO data.
%
% tx_weights = transmit amplitude weightings (from the radar_config file)
%   These are amplitude weights, not power weights.
% rxchannel = receive channel to return phase_center for (scalar,
%   positive integer)
%
% phase_center = lever arm to phase center of measurement defined by
%   tx_weights and rxchannel
%
% =========================================================================
% REMARKS:
% 
% 1). Lever arm refers to a (3 x 1) vector that expresses the position of 
%     each phase center relative to the INS unit in the coordinate
%     system of the plane's body (Xb, Yb, Zb).  This is a righthanded,
%     orthoganol system that agrees with aerospace convention.  +Xb points
%     from the plane's center of gravity towards its nose.  +Yb points from
%     the plane's center of gravity along the right wing.  +Zb points from
%     the plane's center of gravity down towards the Earth's surface.
% 
% 2). The lever arm of the Nth receive channel is defined using the 
%     following syntax:
%
%     LArx_N = [Xb_N; Yb_N; Zb_N]
% 
% 3). Values were determined using the following assumptions:
%     (i).  The origin of the (Xb, Yb, Zb) coordinate system is the INS
%           unit, which is assumed to be a point on the floor of the Twin
%           Otter fuselage at 225 inches aft and lying on the plane's 
%           centerline. 
% ========================================================================

if ~exist('rxchannel','var') || isempty(rxchannel)
  rxchannel = 1:5;
end

% absoulute value of components

gps.x = 0*0.0254;
gps.y = 4*0.0254;
gps.z = 0*0.0254;

LArx(1,:)   = [ 28    28    28    28    28 ]*0.0254 - gps.x;  % m
LArx(2,:)   = [ 153.9 203.1 253.1 290.6 328 ]*0.0254 - gps.y; % m
LArx(3,:)   = [ 25.5 23 20.875 19.5 18.125]*0.0254 - gps.z; % m

LAtx(1,:)   = [ 28    28    28    28    28 ]*0.0254 - gps.x; % m
LAtx(2,:)   = -[ 153.9 203.1 253.1 290.6 328 ]*0.0254 - gps.y; % m
LAtx(3,:)   = [ 24 21.75 19.5 17.625 15.75 ]*0.0254 - gps.z; % m

% Amplitude (not power) weightings for transmit side. 
if rxchannel == 0
  rxchannel = 3;
  tx_weights = ones(1,size(LAtx,2));
end
magsum       = sum(tx_weights);

% Weighted average of Xb, Yb and Zb components
LAtx_pc(1,1)    = dot(LAtx(1,:),tx_weights)/magsum;
LAtx_pc(2,1)    = dot(LAtx(2,:),tx_weights)/magsum;
LAtx_pc(3,1)    = dot(LAtx(3,:),tx_weights)/magsum;

phase_center = (LArx(:,rxchannel) + repmat(LAtx_pc,[1 size(rxchannel,2)]))./2;

return