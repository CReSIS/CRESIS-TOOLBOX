function [theta,sv] = array_proc_sv(fc, yAnt, zAnt, sv_arg, LUT, LUT_roll)
% [theta,sv] = array_proc_sv(fc, yAnt, zAnt, sv_arg, LUT, LUT_roll)
%
% Function specified in sv_fh column of array worksheet of param
% spreadsheet for use with array_proc.
%
% sv_arg: Several Options:
%   sv_arg is a struct:
%     .theta: theta vector (radians) of angles at which steering vectors
%       will be made.
%   sv_arg is numeric scalar:
%     Contains the number of uniformily sampled in wavenumber space
%     steering vectors that will be created.
% fc: center frequency (Hz)
%   To adjust the dielectric of the steering vectors, pass in the effective
%   center frequency after considering the dielectric. For example:
%     fc_effective = fc_actual*sqrt(relative_dielectric)
% yAnt,zAnt: phase centers from lever arm (note this includes tx and
%   rx positions, so nyquist sampling is quarter wavelength for the
%   phase centers because of two way propagation... i.e. k = 4*pi*fc/c)
%   These are Ny by 1 vectors
% LUT_roll: roll information (aircraft attitude)
% LUT: measured steering vectors lookup table (relative to zero-roll)
%
% sv = steering vector of size Ny by Nsv
% theta = incidence angle vector of size 1 by Nsv, defined by atan2(ky,kz)
%
% y is increasing to the right
% z is increasing downwards
% sv = sqrt(1/length(yAnt)) * exp(1i*(-zAnt*kz + yAnt*ky));
% A positive ky with a positive y (y points to the left) implies a positive
% phase for the steering vector. This means the measurement is closer to
% the target the bigger y gets (i.e. the more to the left you go)
% and therefore positive ky implies a target from the left. Positive ky
% corresponds to positive theta.
% kz is always positive. A positive z is always moving away from the target.
%
% Author: John Paden

%% Initialization
if ~exist('LUT','var')
  LUT = [];
end

if ~exist('LUT_roll','var')
  LUT_roll = [];
end

%% Calculate k
% Creation of linear steering vector for 2D arbitrary array
c = 2.997924580003452e+08; % physical_constants too slow
% Wavenumber for two way propagation
k = 4*pi*fc/c;

%% Calculate ky, kz, and theta
if isstruct(sv_arg)
  theta = sv_arg.theta;
  
  % shape doas into row vector
  theta = theta(:).';
  
  ky = k*sin(theta);
  kz = k*cos(theta);
  
else
  Nsv = sv_arg;
  % Choose equally spaced y-dimension (cross-track) wavenumbers
  dNsv = 2/Nsv;
  ky = dNsv *k* [0 : floor((Nsv-1)/2), -floor(Nsv/2) : -1];
  
  % Determine z-dimension (elevation) dimension wavenumbers for each ky
  kz = sqrt(k^2 - ky.^2);
  
  % Calculate the angle of arrival for each ky
  theta = atan2(ky,kz);
  
end
%% Return now if only theta is needed
if nargout < 2
  return;
end

%% Create nominal sv table
% Take the outer product of the antenna positions with the trig(theta)
% to create 2D matrix. Normalize the steering vector lengths.
sv = sqrt(1/length(yAnt)) * exp(1i*(-zAnt*kz + yAnt*ky));
% Equivalent: sv = sqrt(1/length(yAnt)) * exp(1i*k*(-zAnt*cos(theta) + yAnt*sin(theta)));

%% Apply sv correction

if ~isempty(LUT) && ~isempty(LUT_roll)
  theta_lut = theta - LUT_roll;
  sv_real = real(LUT.sv);
  sv_imag = imag(LUT.sv);
  sv_corr = (interp1(LUT.doa, sv_real, theta_lut,'linear','extrap') + 1i*interp1(LUT.doa, sv_imag,theta_lut,'linear','extrap')).';
  
%   sv = sqrt(1/length(yAnt)) * exp(1i*(-zAnt*kz + yAnt*ky));
  sv = sv .* sv_corr;
end


