function [hdr,data] = data_pulse_compress(param,hdr,data)
% [hdr,data] = data_pulse_compress(param,hdr,data)

wfs = param.radar.wfs;

if param.load.raw_data && param.load.pulse_comp
  error('Pulse compression (param.load.pulse_comp) cannot be enabled with raw data loading (param.load.raw_data).');
end

hdr.custom = [];

physical_constants;

[output_dir,radar_type,radar_name] = ct_output_dir(param.radar_name);

for img = 1:length(param.load.imgs)
  for wf_adc = 1:size(param.load.imgs{img},1)
    wf = param.load.imgs{img}(wf_adc,1);
    adc = param.load.imgs{img}(wf_adc,2);
    BW_window_max_warning_printed = false;
    BW_window_min_warning_printed = false;
    
    %% Pre-pulse compression filter
    % ===================================================================
    if strcmpi(radar_type,'deramp')
      if strcmpi(wfs(wf).prepulse_H.type,'filtfilt')
        data{img}(:,:,wf_adc) = single(filtfilt(wfs(wf).prepulse_H.B,1,double(data{img}(:,:,wf_adc))));
      end
    end
    
    %% Burst RFI removal
    % ===================================================================
    
    %% Coherent noise: Pulsed
    % ===================================================================
    if strcmpi(radar_type,'pulsed')
      if strcmpi(wfs(wf).coh_noise_method,'analysis')
        noise_fn_dir = fileparts(ct_filename_out(param,wfs(wf).coh_noise_arg.fn, ''));
        noise_fn = fullfile(noise_fn_dir,sprintf('coh_noise_simp_%s_wf_%d_adc_%d.mat', param.day_seg, wf, adc));
        
        fprintf('  Load coh_noise: %s (%s)\n', noise_fn, datestr(now));
        noise = load(noise_fn);
        
        cmd = noise.param_collate.analysis.cmd{noise.param_collate.collate_coh_noise.cmd_idx};
        cmd.pulse_comp = true; % HACK: DO NOT COMMIT. NEEDS TO BE REMOVED
        
        hdr.custom.coh_noise(1:length(noise.datestr),1,img,wf_adc) = noise.datestr;
        noise.Nx = length(noise.gps_time);
        
        % Nt by Nx_dft matrix
        noise.dft(~isfinite(noise.dft)) = 0;
        
        % Adjust coherent noise dft for changes in adc_gains relative to
        % when the coherent noise was loaded and estimated.
        noise.dft = noise.dft * 10.^((wfs(wf).adc_gains_dB(adc)-noise.param_analysis.radar.wfs(wf).adc_gains_dB(adc))/20);
        
        % Adjust the coherent noise Tsys, chan_equal_dB, chan_equal_deg for
        % changes relative to when the coherent noise was loaded and
        % estimated.
        noise.dft = noise.dft * 10.^(( ...
            noise.param_analysis.radar.wfs(wf).chan_equal_dB(param.radar.wfs(wf).rx_paths(adc)) ...
                         - param.radar.wfs(wf).chan_equal_dB(param.radar.wfs(wf).rx_paths(adc)) )/20) ...
                .* exp(1i*( ...
            noise.param_analysis.radar.wfs(wf).chan_equal_deg(param.radar.wfs(wf).rx_paths(adc)) ...
                         - param.radar.wfs(wf).chan_equal_deg(param.radar.wfs(wf).rx_paths(adc)) )/180*pi);
        
        % Correct any changes in Tsys
        Tsys = param.radar.wfs(wf).Tsys(param.radar.wfs(wf).rx_paths(adc));
        Tsys_old = noise.param_analysis.radar.wfs(wf).Tsys(param.radar.wfs(wf).rx_paths(adc));
        dTsys = Tsys-Tsys_old;
        noise.Nt = size(noise.dft,1);
        noise.freq = noise.fc + 1/(noise.dt*noise.Nt) * ifftshift(-floor(noise.Nt/2):floor((noise.Nt-1)/2)).';
        if dTsys ~= 0
          % Positive dTsys means Tsys > Tsys_old and we should reduce the
          % time delay to all targets by dTsys.
          noise.dft = ifft(fft(noise.dft) .* exp(1i*2*pi*noise.freq*dTsys));
        end
        
        recs = interp1(noise.gps_time, noise.recs, hdr.gps_time, 'linear', 'extrap');
        
        if ~cmd.pulse_comp
          if 0
            % Debug Code
        
            cn.data = zeros([size(noise.dft,1) numel(recs)],'single');
            for dft_idx = 1:length(noise.dft_freqs)
              % mf: matched filter
              % noise.dft(bin,dft_idx): Coefficient for the matched filter
              mf = exp(1i*2*pi/noise.Nx*noise.dft_freqs(dft_idx) .* recs);
              for bin = 1:size(noise.dft,1)
                cn.data(bin,:) = cn.data(bin,:)-noise.dft(bin,dft_idx) * mf;
              end
            end
            
            figure(1); clf;
            imagesc(lp( bsxfun(@minus, data{img}(1:wfs(wf).Nt,:), mean(data{img}(1:wfs(wf).Nt,:),2) )  ))
            figure(2); clf;
            imagesc(lp( data{img}(1:wfs(wf).Nt,:,wf_adc) ))
            figure(3); clf;
            imagesc(lp( cn.data ))
            figure(4); clf;
            plot(lp(mean(data{img}(1:wfs(wf).Nt,:,wf_adc),2)))
            legend('Mean','CN');
          end
        
          for dft_idx = 1:length(noise.dft_freqs)
            % mf: matched filter
            % noise.dft(bin,dft_idx): Coefficient for the matched filter
            mf = exp(1i*2*pi/noise.Nx*noise.dft_freqs(dft_idx) .* recs);
            for bin = 1:size(noise.dft,1)
              data{img}(bin,:,wf_adc) = data{img}(bin,:,wf_adc)-noise.dft(bin,dft_idx) * mf;
            end
          end
        end
        
      elseif strcmpi(wfs(wf).coh_noise_method,'estimated')
        % Apply coherent noise methods that require estimates derived now
        
        if wfs(wf).coh_noise_arg.DC_remove_en
          data{img}(1:wfs(wf).Nt_raw,:,wf_adc) = bsxfun(@minus, data{img}(1:wfs(wf).Nt_raw,:,wf_adc), ...
            mean(data{img}(1:wfs(wf).Nt_raw,:,wf_adc),2));
        end
        
        if length(wfs(wf).coh_noise_arg.B_coh_noise) > 1
          if length(wfs(wf).coh_noise_arg.A_coh_noise) > 1
            % Use filtfilt (feedback)
            data{img}(1:wfs(wf).Nt_raw,:,wf_adc) = single(filtfilt(wfs(wf).coh_noise_arg.B_coh_noise, ...
              wfs(wf).coh_noise_arg.A_coh_noise, double(data{img}(1:wfs(wf).Nt_raw,:,wf_adc).'))).';
          else
            % Use fir_dec (no feedback)
            data{img}(1:wfs(wf).Nt_raw,:,wf_adc) = fir_dec(data{img}(1:wfs(wf).Nt_raw,:,wf_adc),wfs(wf).coh_noise_arg.B_coh_noise,1);
          end
        end
        
      end
    end
    
    %% Coherent noise: Deramp
    % ===================================================================
    if strcmpi(radar_type,'deramp')
      
      if strcmpi(wfs(wf).coh_noise_method,'analysis')
        noise_fn_dir = fileparts(ct_filename_out(param,wfs(wf).coh_noise_arg.fn, ''));
        noise_fn = fullfile(noise_fn_dir,sprintf('coh_noise_simp_%s_wf_%d_adc_%d.mat', param.day_seg, wf, adc));
        
        fprintf('  Load coh_noise: %s (%s)\n', noise_fn, datestr(now));
        noise = load(noise_fn);
        
        cmd = noise.param_collate.analysis.cmd{noise.param_collate.collate_coh_noise.cmd_idx};
        cmd.pulse_comp = true; % HACK: DO NOT COMMIT. NEEDS TO BE REMOVED
        
        hdr.custom.coh_noise(1:length(noise.datestr),1,img,wf_adc) = noise.datestr;
        noise.Nx = length(noise.gps_time);
        
        % Nt by Nx_dft matrix
        noise.dft(~isfinite(noise.dft)) = 0;
        
        % Adjust coherent noise dft for changes in adc_gains relative to
        % when the coherent noise was loaded and estimated.
        noise.dft = noise.dft * 10.^((wfs(wf).adc_gains_dB(adc)-noise.param_analysis.radar.wfs(wf).adc_gains_dB(adc))/20);
        
        % Adjust the coherent noise Tsys, chan_equal_dB, chan_equal_deg for
        % changes relative to when the coherent noise was loaded and
        % estimated.
        noise.dft = noise.dft * 10.^(( ...
            noise.param_analysis.radar.wfs(wf).chan_equal_dB(param.radar.wfs(wf).rx_paths(adc)) ...
                         - param.radar.wfs(wf).chan_equal_dB(param.radar.wfs(wf).rx_paths(adc)) )/20) ...
                .* exp(1i*( ...
            noise.param_analysis.radar.wfs(wf).chan_equal_deg(param.radar.wfs(wf).rx_paths(adc)) ...
                         - param.radar.wfs(wf).chan_equal_deg(param.radar.wfs(wf).rx_paths(adc)) )/180*pi);
        
        % Correct any changes in Tsys
        Tsys = param.radar.wfs(wf).Tsys(param.radar.wfs(wf).rx_paths(adc));
        Tsys_old = noise.param_analysis.radar.wfs(wf).Tsys(param.radar.wfs(wf).rx_paths(adc));
        dTsys = Tsys-Tsys_old;
        noise.Nt = size(noise.dft,1);
        noise.freq = noise.fc + 1/(noise.dt*noise.Nt) * ifftshift(-floor(noise.Nt/2):floor((noise.Nt-1)/2)).';
        if dTsys ~= 0
          % Positive dTsys means Tsys > Tsys_old and we should reduce the
          % time delay to all targets by dTsys.
          noise.dft = ifft(fft(noise.dft) .* exp(1i*2*pi*noise.freq*dTsys));
        end
        
        
        recs = interp1(noise.gps_time, noise.recs, hdr.gps_time, 'linear', 'extrap');
        
        if 0
          % Debug Code
          imagesc(lp( bsxfun(@minus, data{img}(1:wfs(wf).Nt,:), mean(data{img}(1:wfs(wf).Nt,:),2) )  ))
          figure(1); clf;
          plot(lp(mean(data{img}(1:wfs(wf).Nt,:),2)))
          hold on
          plot(lp(noise.dft))
        end
        
        cn.data = zeros([size(noise.dft,1) numel(recs)],'single');
        for dft_idx = 1:length(noise.dft_freqs)
          % mf: matched filter
          % noise.dft(bin,dft_idx): Coefficient for the matched filter
          mf = exp(1i*2*pi/noise.Nx*noise.dft_freqs(dft_idx) .* recs);
          for bin = 1:size(noise.dft,1)
            cn.data(bin,:) = cn.data(bin,:)-noise.dft(bin,dft_idx) * mf;
          end
        end
      end
    end
    
    
    %% Pulse compress
    % ===================================================================
    if param.load.pulse_comp == 1
      
      %% Pulse compress: Pulsed
      if strcmpi(radar_type,'pulsed')
        % Digital down conversion

        blocks = round(linspace(1,size(data{img},2)+1,8)); blocks = unique(blocks);
        for block = 1:length(blocks)-1
          rlines = blocks(block) : blocks(block+1)-1;
          
          % Digital down conversion
          data{img}(1:wfs(wf).Nt_raw,rlines,wf_adc) = bsxfun(@times,data{img}(1:wfs(wf).Nt_raw,rlines,wf_adc), ...
            exp(-1i*2*pi*(wfs(wf).fc-wfs(wf).DDC_freq)*wfs(wf).time_raw));
          
          % Pulse compression
          %   Apply matched filter and transform back to time domain
          tmp_data = circshift(ifft(bsxfun(@times,fft(data{img}(1:wfs(wf).Nt_raw,rlines,wf_adc), wfs(wf).Nt_pc),wfs(wf).ref{adc})),wfs(wf).pad_length,1);
          
          % Decimation
          data{img}(1:wfs(wf).Nt,rlines,wf_adc) = single(resample(double(tmp_data), wfs(wf).ft_dec(1), wfs(wf).ft_dec(2)));
          
        end
        
        if wf_adc == 1
          hdr.time{img} = wfs(wf).time;
          hdr.freq{img} = wfs(wf).freq;
        end
        
        
      elseif strcmpi(radar_type,'deramp')
        %% Pulse compress: Deramp
        if 0
          % ENABLE_FOR_DEBUG
          % Create simulated data
          clear;
          img = 1;
          rec = 1;
          wf = 1;
          wf_adc = 1;
          hdr.DDC_dec{img}(rec) = 1;
          hdr.DDC_freq{img}(rec) = 0e6;
          hdr.nyquist_zone_signal{img}(rec) = 1;
          wfs(wf).fs_raw = 250e6;
          wfs(wf).BW_window = [2.7e9 17.5e9];
          wfs(wf).f0 = 2e9;
          wfs(wf).f1 = 18e9;
          wfs(wf).Tpd = 240e-6;
          wfs(wf).td_mean = 3e-6;
          BW = wfs(wf).f1-wfs(wf).f0;
          wfs(wf).chirp_rate = BW/wfs(wf).Tpd;
          hdr.surface(rec) = 3e-6;
          hdr.t_ref{img}(rec) = 0e-6;
          wfs(wf).ft_wind = @hanning;
          tguard = 1e-6;
          td_max = 4e-6;
          td_min = 1e-6;
          tref = hdr.t_ref{img}(rec);
          hdr.t0_raw{img}(rec) = -tguard + min(td_max,tref);
          wfs(wf).Tadc_adjust = 0;
          fs_nyquist = max(wfs(wf).f0,wfs(wf).f1)*5;
          Mt_oversample = ceil(fs_nyquist/wfs(wf).fs_raw);
          fs_rf = Mt_oversample*wfs(wf).fs_raw;
          Nt_rf = round((wfs(wf).Tpd + max(td_max,tref) - min(td_min,tref) + 2*tguard)*fs_rf/Mt_oversample)*Mt_oversample;
          hdr.Nt{img}(rec) = Nt_rf / Mt_oversample;
          
          t0 = hdr.t0_raw{img}(1);
          fs_raw_dec = wfs(wf).fs_raw ./ hdr.DDC_dec{img}(1);
          dt_raw = 1/fs_raw_dec;
          time_raw_no_trim = (t0:dt_raw:t0+dt_raw*(hdr.Nt{img}(rec)-1)).';
          if 0
            tds = hdr.surface(rec) + 1/BW/5*(0:11);
            hdr.surface = tds;
            %hdr.surface(:) = hdr.surface(1);% Enable or disable this line to simulate errors in surface estimate
          else
            time_raw_no_trim_transition = hdr.surface(rec)+(wfs(wf).BW_window(1) - wfs(wf).f0)/wfs(wf).chirp_rate;
            idx = find(time_raw_no_trim>time_raw_no_trim_transition,1);
            
            % Update surface to lie on a IF sample boundary
            hdr.surface = time_raw_no_trim(idx)-(wfs(wf).BW_window(1)-wfs(wf).f0)/wfs(wf).chirp_rate;
            
            tds = hdr.surface(1) + 1/wfs(wf).fs_raw*(0 + [-100-1/3 -30 -10 -4/3 -1/3 0 1/3 4/3 10 30 100+1/3]);
            %tds = hdr.surface(1) + 1/BW/5*[-2 -1 0 1 2];
            hdr.surface = tds;
            hdr.surface(:) = hdr.surface(1);% Enable or disable this line to simulate errors in surface estimate
          end
          Tpd = wfs(wf).Tpd;
          f0 = wfs(wf).f0;
          f1 = wfs(wf).f1;
          alpha = wfs(wf).chirp_rate;
          fs_rf = Mt_oversample*wfs(wf).fs_raw;
          time = hdr.t0_raw{img}(rec) + 1/fs_rf * (0:Nt_rf-1).';
          for rec = 1:length(tds)
            fprintf('Simulating %d of %d\n', rec, length(tds));
            td = tds(rec);
            
            f_rf = wfs(wf).f0 + wfs(wf).chirp_rate*(time_raw_no_trim - hdr.surface(rec));
            window_start_idx = find(f_rf >= wfs(wf).BW_window(1),1);
            fprintf('  window_start_idx: %d\n', window_start_idx);
            
            hdr.DDC_dec{img}(rec) = hdr.DDC_dec{img}(1);
            hdr.DDC_freq{img}(rec) = hdr.DDC_freq{img}(1);
            hdr.nyquist_zone_signal{img}(rec) = hdr.nyquist_zone_signal{img}(1);
            hdr.t_ref{img}(rec) = hdr.t_ref{img}(1);
            hdr.t0_raw{img}(rec) = hdr.t0_raw{img}(1);
            hdr.Nt{img}(rec) = hdr.Nt{img}(1);
            
            s = tukeywin_cont((time-Tpd/2-td)/Tpd,0) .* cos(2*pi*f0*(time-td) + pi*alpha*(time-td).^2);
            r = tukeywin_cont((time-Tpd/2-tref)/Tpd,0) .* cos(2*pi*f0*(time-tref) + pi*alpha*(time-tref).^2);
            s_if = s.*r; clear r s;
            s_if_theory = 0.5*tukeywin_cont((time-Tpd/2-td/2-tref/2)/(Tpd-abs(tref-td)),0) ...
              .* (cos(2*pi*f0*(time-td) + pi*alpha*(time-td).^2 - (2*pi*f0*(time-tref) + pi*alpha*(time-tref).^2)) ...
              + cos(2*pi*f0*(time-td) + pi*alpha*(time-td).^2 + (2*pi*f0*(time-tref) + pi*alpha*(time-tref).^2)));
            
            [Bfilt,Afilt] = butter(6, wfs(wf).fs_raw*hdr.nyquist_zone_signal{img}(rec) / (fs_rf/2));
            s_if = filtfilt(Bfilt,Afilt,s_if);
            s_if_theory = 0.5*tukeywin_cont((time-Tpd/2-td/2-tref/2)/(Tpd-abs(tref-td)),0) ...
              .* cos(2*pi*f0*(time-td) + pi*alpha*(time-td).^2 - (2*pi*f0*(time-tref) + pi*alpha*(time-tref).^2));
            
            s_if = s_if(1:Mt_oversample:end);
            
            data{img}(:,rec,wf_adc) = s_if;
          end
          store_data = data;
          store_Nt = hdr.Nt{img};
          
        elseif 0
          % ENABLE_FOR_DEBUG
          % Use previously generated simulated data
          data = store_data;
          hdr.Nt{img} = store_Nt;
        end
        
        freq_axes_changed = false;
        for rec = 1:size(data{img},2)
          
          % Check to see if axes has changed since last record
          if rec == 1 ...
              || hdr.DDC_dec{img}(rec) ~= hdr.DDC_dec{img}(rec-1) ...
              || hdr.DDC_freq{img}(rec) ~= hdr.DDC_freq{img}(rec-1) ...
              || hdr.nyquist_zone_signal{img}(rec) ~= hdr.nyquist_zone_signal{img}(rec-1)
            
            freq_axes_changed = true;
            
            %% Pulse compress: Output time
            % The output time axes for every choice of DDC_dec must have
            % the same sample spacing. We compute the resampling ratio
            % required to achieve this in the pulse compressed time domain.
            if 0
              % ENABLE_FOR_DEBUG_OUTPUT_TIME_SAMPLING
              wf = 1;
              img = 1;
              rec = 1;
              wfs(wf).fs_raw = 250e6;
              wfs(wf).chirp_rate = 16e9/240e-6;
              wfs(wf).BW_window = [2.7e9 17.5e9];
              hdr.DDC_dec{img}(rec) = 5;
              
              wfs(wf).f0 = 2e9;
              wfs(wf).f1 = 18e9;
              wfs(wf).Tpd = 240e-6;
              BW = wfs(wf).f1-wfs(wf).f0;
              wfs(wf).chirp_rate = BW/wfs(wf).Tpd;
              hdr.t_ref{img}(rec) = 0e-6;
              tguard = 1e-6;
              td_max = 4e-6;
              td_min = 1e-6;
              tref = hdr.t_ref{img}(rec);
              hdr.t0_raw{img}(rec) = -tguard + min(td_max,tref);
              wfs(wf).Tadc_adjust = 0;
              fs_nyquist = max(wfs(wf).f0,wfs(wf).f1)*5;
              Mt_oversample = ceil(fs_nyquist/wfs(wf).fs_raw);
              fs_rf = Mt_oversample*wfs(wf).fs_raw;
              Nt_rf = round((wfs(wf).Tpd + max(td_max,tref) - min(td_min,tref) + 2*tguard)*fs_rf/Mt_oversample)*Mt_oversample;
              hdr.Nt{img}(rec) = Nt_rf / Mt_oversample;
            end
            % In case the decimation length does not align with the desired
            % length, Nt_desired, we determine what resampling is required
            % and store this in p,q.
            Nt_desired = round(wfs(wf).fs_raw/wfs(wf).chirp_rate*diff(wfs(wf).BW_window)/2)*2;
            fs_raw_dec = wfs(wf).fs_raw ./ hdr.DDC_dec{img}(rec);
            Nt_raw_trim = round(fs_raw_dec/wfs(wf).chirp_rate*diff(wfs(wf).BW_window)/2)*2;
            if 0
              % Debug: Test how fast different data record lengths are
              for Nt_raw_trim_test=Nt_raw_trim+(0:10)
                Nt_raw_trim_test
                tic; for run = 1:4; fft(rand(Nt_raw_trim_test,2000)); fft(rand(floor(Nt_raw_trim_test/2)+1,2000)); end; toc;
              end
            end
            [p,q] = rat(Nt_raw_trim*hdr.DDC_dec{img}(rec) / Nt_desired);
            % Create raw time domain window
            H_Nt = wfs(wf).ft_wind(Nt_raw_trim);
            % Create original raw time axis
            t0 = hdr.t0_raw{img}(rec) + wfs(wf).Tadc_adjust;
            dt_raw = 1/fs_raw_dec;
            time_raw_no_trim = (t0:dt_raw:t0+dt_raw*(hdr.Nt{img}(rec)-1)).';
            % Create RF frequency axis for minimum delay to surface expected
            f_rf = wfs(wf).f0 + wfs(wf).chirp_rate*(time_raw_no_trim - wfs(wf).td_mean);
            window_start_idx_norm = find(f_rf >= wfs(wf).BW_window(1),1);
            
            if 0
              % ENABLE_FOR_DEBUG_OUTPUT_TIME_SAMPLING
              df_before_resample = 1 / (Nt_raw_trim/wfs(wf).fs_raw*hdr.DDC_dec{img}(rec))
              df_after_resample = df_before_resample * p / q
              df_desired = 1 / (Nt_desired/wfs(wf).fs_raw)
              Nt_desired
              Nt_raw_trim
              p
              q
            end
            
            %% Pulse compress: IF->Delay
            % =============================================================
            if 0
              % ENABLE_FOR_DEBUG_FREQ_MAP
              img = 1;
              rec = 1;
              hdr.Nt{img}(rec) = 10000;
              hdr.DDC_dec{img}(rec) = 3;
              wfs(wf).fs_raw = 100e6;
              hdr.nyquist_zone_signal{img}(rec) = 1;
              hdr.DDC_freq{img}(rec) = 95e6;
            end
            
            df_raw = wfs(wf).fs_raw/hdr.DDC_dec{img}(rec)/Nt_raw_trim;
            
            % nz: Nyquist zone containing signal spectrum (just renaming
            %   variable for convenience). The assumption is that the
            %   signal does not cross nyquist zones.
            nz = hdr.nyquist_zone_signal{img}(rec);
            
            % f_nz0: Lowest frequency in terms of ADC input frequency of the
            %   nyquist zone which contains the signal
            f_nz0 = wfs(wf).fs_raw * floor(nz/2);
            
            % freq_raw: Frequency axis of raw data
            freq_raw =  f_nz0 + mod(hdr.DDC_freq{img}(rec) ...
              + df_raw*ifftshift(-floor(Nt_raw_trim/2):floor((Nt_raw_trim-1)/2)).', wfs(wf).fs_raw);
            freq_raw_valid = freq_raw;
            
            % conjugate_bins: logical mask indicating which bins are
            % conjugated, this is also used to determine how frequencies
            % are wrapped in the nyquist zone when real only sampling is
            % used (for DFT there are 1 or 2 bins which are real-only and
            % these are marked to be conjugated by using >= and <=; since
            % conjugation of these real only bins makes no difference the
            % only reason to do this is because of the nyquist zone
            % wrapping)
            conjugate_bins = ~(freq_raw_valid >= nz*wfs(wf).fs_raw/2 ...
              & freq_raw_valid <= (1+nz)*wfs(wf).fs_raw/2);
            
            % freq_raw_valid: modified to handle wrapping at Nyquist
            % boundaries
            if mod(nz,2)
              freq_raw_valid(conjugate_bins) = nz*wfs(wf).fs_raw - freq_raw_valid(conjugate_bins);
            else
              freq_raw_valid(conjugate_bins) = (nz+1)*wfs(wf).fs_raw - freq_raw_valid(conjugate_bins);
            end
            
            % freq_raw_valid: reduce rounding errors so that unique will
            % work properly
            freq_raw_valid = df_raw*round(freq_raw_valid/df_raw);
            
            % Only keep the unique frequency bins
            [~,unique_idxs,return_idxs] = unique(freq_raw_valid);
            
            freq_raw_unique = freq_raw_valid(unique_idxs);
            conjugate_unique = conjugate_bins(unique_idxs);
            % unique_idxs(~valid_bins);
            
            if 0
              % ENABLE_FOR_DEBUG_FREQ_MAP
              figure(1);
              clf;
              plot(freq_raw_valid,'.')
              hold on
              freq_raw_valid(conjugate_bins) = NaN;
              plot(freq_raw_valid,'r.')
              grid on
              xlabel('Bin (original order)');
              ylabel('Frequency (Hz)');
              legend('conj','-','location','best');
              
              figure(2);
              clf;
              plot(freq_raw_unique,'.')
              hold on
              tmp = freq_raw_unique;
              tmp(~conjugate_unique) = NaN;
              plot(tmp,'r.')
              grid on
              xlabel('Bin (reordered)');
              ylabel('Frequency (Hz)');
            end
            
            %% Pulse compress: IF->Delay (Coh Noise)
            if strcmpi(wfs(wf).coh_noise_method,'analysis')
              % =============================================================
              
              cn.df_raw = wfs(wf).fs_raw/hdr.DDC_dec{img}(rec)/Nt_raw_trim;
              
              % nz: Nyquist zone containing signal spectrum (just renaming
              %   variable for convenience). The assumption is that the
              %   signal does not cross nyquist zones.
              cn.nz = double(hdr.nyquist_zone_hw{img}(rec));
              
              % f_nz0: Lowest frequency in terms of ADC input frequency of the
              %   nyquist zone which contains the signal
              cn.f_nz0 = wfs(wf).fs_raw * floor(cn.nz/2);
              
              cn.freq_raw =  cn.f_nz0 + mod(hdr.DDC_freq{img}(rec) ...
                + cn.df_raw*ifftshift(-floor(Nt_raw_trim/2):floor((Nt_raw_trim-1)/2)).', wfs(wf).fs_raw);
              cn.freq_raw_valid = cn.freq_raw;
              
              cn.conjugate_bins = ~(cn.freq_raw_valid >= cn.nz*wfs(wf).fs_raw/2 ...
                & cn.freq_raw_valid <= (1+cn.nz)*wfs(wf).fs_raw/2);
              
              if mod(cn.nz,2)
                cn.freq_raw_valid(cn.conjugate_bins) = cn.nz*wfs(wf).fs_raw - cn.freq_raw_valid(cn.conjugate_bins);
              else
                cn.freq_raw_valid(cn.conjugate_bins) = (cn.nz+1)*wfs(wf).fs_raw - cn.freq_raw_valid(cn.conjugate_bins);
              end
              
              cn.freq_raw_valid = cn.df_raw*round(cn.freq_raw_valid/cn.df_raw);
              
              [~,cn.unique_idxs,cn.return_idxs] = unique(cn.freq_raw_valid);
              
              cn.freq_raw_unique = cn.freq_raw_valid(cn.unique_idxs);
              cn.conjugate_unique = cn.conjugate_bins(cn.unique_idxs);
            end
            
          end
          
          % Check to see if reference time offset has changed since last record
          if freq_axes_changed ...
              || hdr.t_ref{img}(rec) ~= hdr.t_ref{img}(rec-1)
            
            freq_axes_changed = false; % Reset state
            
            %% Pulse compress: Time axis
            
            % Convert IF frequency to time delay and account for reference
            % deramp time offset, hdr.t_ref
            time = freq_raw_unique/wfs(wf).chirp_rate + hdr.t_ref{img}(rec);
            
            % Ensure that start time is a multiple of dt
            dt = time(2)-time(1);
            time_correction = dt - mod(time(1),dt);
            time = time + time_correction;
            
            fc = sum(wfs(wf).BW_window)/2;
            Nt = length(time);
            T = Nt*dt;
            df = 1/T;
            freq = fc + df * ifftshift(-floor(Nt/2) : floor((Nt-1)/2)).';
            
            deskew = exp(-1i*pi*wfs(wf).chirp_rate*(time-wfs(wf).td_mean).^2);
            deskew_shift = 1i*2*pi*(0:Nt_raw_trim-1).'/Nt_raw_trim;
            time_correction = exp(1i*2*pi*freq*time_correction);
            
            %% Pulse compress: Time axis (Coh Noise)
            if strcmpi(wfs(wf).coh_noise_method,'analysis')
              
              % Convert IF frequency to time delay and account for reference
              % deramp time offset, hdr.t_ref
              cn.time = cn.freq_raw_unique/wfs(wf).chirp_rate + hdr.t_ref{img}(rec);
              
              % Ensure that start time is a multiple of dt
              cn.dt = cn.time(2)-cn.time(1);
              cn.time_correction = cn.dt - mod(cn.time(1),cn.dt);
              cn.time = cn.time + cn.time_correction;
              
              fc = sum(wfs(wf).BW_window)/2;
              Nt = length(cn.time);
              T = Nt*dt;
              df = 1/T;
              cn.freq = fc + df * ifftshift(-floor(Nt/2) : floor((Nt-1)/2)).';
              
              % cn.deskew: handled differently below
              % cn.deskew_shift: handled differently below
              cn.time_correction = exp(1i*2*pi*cn.freq*cn.time_correction);
              
              
              % Handle changes between when the noise file was created and
              % this current processing.
              % 1. Check for a fast-time sample interval discrepancy
              if abs(noise.dt-cn.dt)/cn.dt > 1e-6
                error('There is a fast-time sample interval discrepancy between the current processing settings (%g) and those used to generate the coherent noise file (%g).', dt, noise.dt);
              end
              % 2. Ensure that the t_ref difference is a multiple of cn.dt
              %    when the coherent noise was loaded and estimated.
              delta_t_ref_bin = (noise.param_analysis.radar.wfs(wf).t_ref - wfs(wf).t_ref)/cn.dt;
              if abs(round(delta_t_ref_bin)-delta_t_ref_bin) > 1e-3
                error('There is a fast-time reference time delay discrepancy between the current processing settings (%g) and those used to generate the coherent noise file (%g). Changes in t_ref require recreating the coherent noise file or the changes must be a multiple of a time bin (%g).', ...
                  wfs(wf).t_ref, noise.param_analysis.radar.wfs(wf).t_ref, cn.dt);
              end
              delta_t_ref_bin = round(delta_t_ref_bin);
              
              % Apply a time correction so the deskew matches the original
              % time axis used when the noise data were estimated. Only the
              % deskew is different, the cn.time_correction is required to not
              % change or else a new noise file is required.
              cn.time = cn.time + delta_t_ref_bin * cn.dt;
              
              cn.deskew = exp(-1i*pi*wfs(wf).chirp_rate*(cn.time-wfs(wf).td_mean).^2);
              cn.deskew_shift = 1i*2*pi*(0:Nt_raw_trim-1).'/Nt_raw_trim;
            end
          end
          
          % Get the start time for this record
          hdr.t0{img}(rec) = time(1);
          
          % Convert raw time into instantaneous frequency for the surface bin
          f_rf = wfs(wf).f0 + wfs(wf).chirp_rate*(time_raw_no_trim - hdr.surface(rec));
          if wfs(wf).BW_window(2) > max(f_rf)
            if ~BW_window_max_warning_printed
              BW_window_max_warning_printed = true;
              warning('BW_window (%g) is more than maximum measured RF frequency (%g) with surface twtt %g.', ...
                wfs(wf).BW_window(2), max(f_rf), hdr.surface(rec))
            end
            % Mark record as bad, but keep 2 bins to simplify later code
            %hdr.Nt{img}(rec) = 0;
            %continue
          end
          if wfs(wf).BW_window(1) < min(f_rf)
            if ~BW_window_min_warning_printed
              BW_window_min_warning_printed = true;
              warning('BW_window (%g) is less than minimum measured RF frequency (%g) with surface twtt %g.', ...
                wfs(wf).BW_window(1), min(f_rf), hdr.surface(rec))
            end
            % Mark record as bad, but keep 2 bins to simplify later code
            %hdr.Nt{img}(rec) = 2;
            %data{img}(1:hdr.Nt{img}(rec),rec,wf_adc) = NaN;
            %continue
          end
          
          % Create the window for the particular range line
          window_start_idx = find(f_rf >= wfs(wf).BW_window(1),1);
          window_start_idx = window_start_idx_norm;
          H_idxs = window_start_idx : window_start_idx+Nt_raw_trim-1;
          if 0
            % ENABLE_FOR_DEBUG
            fprintf('window_start_idx: %d window_start_idx_norm: %d\n', ...
              window_start_idx, window_start_idx_norm);
          end
          
          % Window and Pulse compress
          if 0
            % Debug: Verify pulse compression window is correct
            clf;
            plot(lp(data{img}(H_idxs,rec,wf_adc)));
            hold on;
            plot(lp(data{img}(H_idxs,rec,wf_adc) .* H_Nt));
          end
          
          
          % FFT (raw deramped time to regular time) and window
          tmp = fft(data{img}(H_idxs,rec,wf_adc) .* H_Nt);
          
          % Deskew of the residual video phase (not the standard because we
          % actually move the window to track the td)
          %tmp = tmp .* exp(deskew_shift*(window_start_idx_norm-window_start_idx));
          
          % Remove coherent noise
          if strcmpi(wfs(wf).coh_noise_method,'analysis')
            if 0
              % Debug: Create fake coherent noise based on current data
              %   Adjust the rec range to grab multiple range lines for
              %   better average:
              tmp = fft(mean(data{img}(H_idxs,rec+(0:99),wf_adc),2) .* H_Nt);
              cn.tmp = tmp(cn.unique_idxs);
              cn.tmp(cn.conjugate_unique) = conj(cn.tmp(cn.conjugate_unique));
              cn.tmp = ifftshift(fft(conj(cn.tmp)));
              cn.tmp = cn.tmp .* cn.time_correction;
              cn.tmp = ifft(cn.tmp);
              cn.tmp = -cn.tmp .* cn.deskew;
              cn.tmp(end) = 0;
            else
              start_bin = 1 + round(cn.time(1)/cn.dt) - noise.start_bin;
              cn.tmp = cn.data(start_bin + (0:length(cn.time)-2),rec);
              cn.tmp(end+1) = 0; % Add invalid sample back in
            end
            
            % Coherent noise is fully pulse compressed. The nyquist_zone
            % set in hardware is always used for the coherent noise
            % processing even if the setting is wrong. Three steps:
            % 1: Fully pulse compress the data in the hardware nyquist zone
            % 2: Subtract the coherent noise away
            % 3: If the hardware and actual nyquist zone are different,
            %    then invert the pulse compression and repulse compress in the
            %    actual nyquist zone.
            
            % 1: Fully pulse compress the data in the hardware nyquist zone
            %    (see below for full description of pulse compression
            %    steps)
            tmp = tmp(cn.unique_idxs);
            tmp(cn.conjugate_unique) = conj(tmp(cn.conjugate_unique));
            tmp = ifftshift(fft(conj(tmp)));
            tmp = tmp .* cn.time_correction;
            tmp = ifft(tmp);
            tmp = tmp .* cn.deskew;
            tmp(end) = 0;
            if p~=q
              tmp = resample(tmp,p,q);
            end
            
            if 0
              % Debug
              figure(1); clf;
              plot(real(tmp));
              hold on;
              plot(real(-cn.tmp),'--');
              
              figure(2); clf;
              plot(imag(tmp));
              hold on;
              plot(imag(-cn.tmp),'--');
            end
            
            % 2: Subtract the coherent noise away
            tmp = tmp + cn.tmp;
            
            % 3: If the hardware and actual nyquist zone are different,
            %    then invert the pulse compression and repulse compress in the
            %    actual nyquist zone.
            if nz ~= double(hdr.nyquist_zone_hw{img}(rec))
              % Reverse Pulse Compression:
              % Undo tmp = resample(tmp,p,q);
              if p~=q
                tmp = resample(tmp,q,p);
              end
              % Do not undo tmp(end) = 0;
              % Undo tmp = tmp .* deskew;
              tmp = tmp ./ cn.deskew;
              % Undo tmp = ifft(tmp);
              tmp = fft(tmp);
              % Undo tmp = tmp .* time_correction;
              tmp = tmp ./ cn.time_correction;
              % Undo tmp = ifftshift(fft(conj(tmp)));
              tmp = conj(ifft(fftshift(tmp)));
              % Undo tmp = tmp(unique_idxs);
              tmp = tmp(cn.return_idxs);
              % Undo tmp(conjugate_unique) = conj(tmp(conjugate_unique));
              tmp(cn.conjugate_bins) = conj(tmp(cn.conjugate_bins));
              
              % Pulse compression (see below for full description)
              tmp = tmp(unique_idxs);
              tmp(conjugate_unique) = conj(tmp(conjugate_unique));
              tmp = ifftshift(fft(conj(tmp)));
              tmp = tmp .* time_correction;
              tmp = ifft(tmp);
              tmp = tmp .* deskew;
              % tmp(end) = 0; % Skip since it was not undone
              if p~=q
                tmp = resample(tmp,p,q);
              end
              
            % 4: If only the delta t_ref is different,  then invert the
            %    coherent noise deskew and then apply the new deskew.
            elseif delta_t_ref_bin ~= 0
              %
              tmp = tmp ./ cn.deskew .* deskew;
            end
            
          else
            % FULL DESCRIPTION OF PULSE COMPRESSION STEPS
            
            % Reorder result in case it is wrapped
            tmp = tmp(unique_idxs);
            % Some of the frequency bins are conjugated versions of the
            % signal
            tmp(conjugate_unique) = conj(tmp(conjugate_unique));
            
            % Complex baseband data (shifts by ~Tpd/2)
            tmp = ifftshift(fft(conj(tmp)));
            
            % Modulate the raw data to adjust the start time to always be a
            % multiple of wfs(wf).dt. Since we want this adjustment to be a
            % pure time shift and not introduce any phase shift in the other
            % domain, we make sure the phase is zero in the center of the
            % window: -time_raw(1+floor(Nt/2))
            tmp = tmp .* time_correction;
            
            % Return to time domain
            tmp = ifft(tmp);
            
            % Deskew of the residual video phase (second stage)
            tmp = tmp .* deskew;
            
            % Last sample set to zero (invalid sample)
            tmp(end) = 0;
            
            % Resample data so it aligns to constant time step
            if p~=q
              tmp = resample(tmp,p,q);
            end
          end
          
          % Update the data matrix with the pulse compressed waveform and
          % handle nz_trim
          if length(param.radar.wfs(wf).nz_trim) >= nz+1
            tmp = tmp(1+param.radar.wfs(wf).nz_trim{nz+1}(1) : end-1-param.radar.wfs(wf).nz_trim{nz+1}(2));
            hdr.t0{img}(rec) = hdr.t0{img}(rec) + dt*param.radar.wfs(wf).nz_trim{nz+1}(1);
          else
            tmp = tmp(1 : end-1);
          end
          hdr.Nt{img}(rec) = length(tmp);
          data{img}(1:hdr.Nt{img}(rec),rec,wf_adc) = tmp;
        end
        
        if 0
          % ENABLE_FOR_DEBUG
          figure(1); clf;
          Mt = 10;
          data_oversampled = interpft(data{img}(1:hdr.Nt{img}(rec),:,wf_adc), hdr.Nt{img}(rec)*Mt);
          [~,idx] = max(data_oversampled);
          time_oversampled = time(1) + dt/Mt* (0:length(time)*Mt-1).';
          plot((time_oversampled(idx).' - tds)/dt)
          grid on;
          xlabel('Record');
          ylabel('Time error (\Delta_t)');
          
          figure(2); clf;
          phase_sim = max(data{img}(1:hdr.Nt{img}(rec),:,wf_adc));
          plot(angle(phase_sim./phase_sim(1)),'+-');
          hold on
          fc_window = mean(wfs(wf).BW_window);
          phase_theory = exp(-1i*2*pi*fc_window*tds);
          plot(angle(phase_theory./phase_theory(1)),'.--');
          xlabel('Range bin');
          ylabel('Phase (rad)');
          legend('Simulated','Theory');
          grid on;
        end
        
        % Create a matrix of data with constant time rows, fill invalid samples with NaN
        if wf_adc == 1
          if all(isnan(hdr.t0{img}))
            % All records are bad
            idx_start = 0;
            wfs(wf).Nt = 0;
            dt = 1;
          else
            idx_start = min(round(hdr.t0{img}/dt));
            wfs(wf).Nt = max(round(hdr.t0{img}/dt) + hdr.Nt{img})-idx_start;
          end
          hdr.time{img} = idx_start*dt + dt*(0:wfs(wf).Nt-1).';
          fc = sum(wfs(wf).BW_window)/2;
          T = wfs(wf).Nt*dt;
          df = 1/T;
          hdr.freq{img} = fc + df * ifftshift(-floor(wfs(wf).Nt/2) : floor((wfs(wf).Nt-1)/2)).';
        end
        % Method of copying to make this more efficient for very large
        % complex (real/imag) arrays. Lots of small matrix operations on
        % huge complex matrices is very slow in matlab. Real only matrices
        % are very fast though.
        blocks = round(linspace(1,size(data{img},2)+1,8)); blocks = unique(blocks);
        for block = 1:length(blocks)-1
          rlines = blocks(block) : blocks(block+1)-1;
          reD = real(data{img}(:,rlines,wf_adc));
          imD = imag(data{img}(:,rlines,wf_adc));
          for rec = 1:length(rlines)
            if isnan(hdr.t0{img}(rlines(rec)))
              % This is a bad record
              cur_idx_start = 1;
              cur_idx_stop = 0;
            else
              cur_idx_start = round(hdr.t0{img}(rlines(rec))/dt) - idx_start + 1;
              cur_idx_stop = round(hdr.t0{img}(rlines(rec))/dt) - idx_start + hdr.Nt{img}(rlines(rec));
            end
            
            reD(cur_idx_start : cur_idx_stop,rec,wf_adc) = reD(1:hdr.Nt{img}(rlines(rec)),rec,wf_adc);
            reD(1:cur_idx_start-1,rec,wf_adc) = NaN;
            reD(cur_idx_stop+1 : wfs(wf).Nt,rec,wf_adc) = NaN;
          end
          for rec = 1:length(rlines)
            if isnan(hdr.t0{img}(rlines(rec)))
              % This is a bad record
              cur_idx_start = 1;
              cur_idx_stop = 0;
            else
              cur_idx_start = round(hdr.t0{img}(rlines(rec))/dt) - idx_start + 1;
              cur_idx_stop = round(hdr.t0{img}(rlines(rec))/dt) - idx_start + hdr.Nt{img}(rlines(rec));
            end
            
            imD(cur_idx_start : cur_idx_stop,rec,wf_adc) = imD(1:hdr.Nt{img}(rlines(rec)),rec,wf_adc);
            imD(1:cur_idx_start-1,rec,wf_adc) = NaN;
            imD(cur_idx_stop+1 : wfs(wf).Nt,rec,wf_adc) = NaN;
          end
          data{img}(1:wfs(wf).Nt,rlines,wf_adc) = reD(1:wfs(wf).Nt,:) + 1i*imD(1:wfs(wf).Nt,:);
        end
        clear reD imD;
        
      elseif strcmpi(radar_type,'stepped')
        
      end
      
    else
      if wf_adc == 1
        if strcmpi(radar_type,'pulsed')
          hdr.time{img} = wfs(wf).time_raw;
          hdr.freq{img} = wfs(wf).freq_raw;
          
        elseif strcmpi(radar_type,'deramp')
          % Time axis is not valid if DDC or time offset changes
          hdr.time{img} = hdr.t0{img}(1) + 1/wfs(wf).fs_raw*(0:hdr.Nt{img}-1).';
          % Frequency is not valid
          df = wfs(wf).fs_raw / hdr.Nt{img};
          hdr.freq{img} = df*(0:hdr.Nt{img}-1).';
          
        elseif strcmpi(radar_type,'stepped')
        end
      end
    end
    
    %% Coherent noise: Deramp
    % ===================================================================
    if strcmpi(radar_type,'deramp')
      
      if strcmpi(wfs(wf).coh_noise_method,'estimated')
        % Apply coherent noise methods that require estimates derived now
        
        if wfs(wf).coh_noise_arg.DC_remove_en
          data{img}(1:wfs(wf).Nt,:,wf_adc) = bsxfun(@minus, data{img}(1:wfs(wf).Nt,:,wf_adc), ...
            mean(data{img}(1:wfs(wf).Nt,:,wf_adc),2));
        end
        
        if length(wfs(wf).coh_noise_arg.B_coh_noise) > 1
          if length(wfs(wf).coh_noise_arg.A_coh_noise) > 1
            % Use filtfilt (feedback)
            data{img}(1:wfs(wf).Nt,:,wf_adc) = single(filtfilt(wfs(wf).coh_noise_arg.B_coh_noise, ...
              wfs(wf).coh_noise_arg.A_coh_noise, double(data{img}(1:wfs(wf).Nt,:,wf_adc).'))).';
          else
            % Use fir_dec (no feedback)
            data{img}(1:wfs(wf).Nt,:,wf_adc) = fir_dec(data{img}(1:wfs(wf).Nt,:,wf_adc),wfs(wf).coh_noise_arg.B_coh_noise,1);
          end
        end
        
      end
    end
    
    %% Coherent noise: Pulsed
    % ===================================================================
    if 0
      % Debug Test Code
      before = data{img}(1:size(noise.dft,1),:,wf_adc);
    end
    if strcmpi(radar_type,'pulsed')
      if strcmpi(wfs(wf).coh_noise_method,'analysis')
        for dft_idx = 1:length(noise.dft_freqs)
          % mf: matched filter
          % noise.dft(bin,dft_idx): Coefficient for the matched filter
          mf = exp(1i*2*pi/noise.Nx*noise.dft_freqs(dft_idx) .* recs);
          for bin = 1:size(noise.dft,1)
            data{img}(bin,:,wf_adc) = data{img}(bin,:,wf_adc)-noise.dft(bin,dft_idx) * mf;
          end
        end
      end
    end
    if 0
      % Debug Test Code
      after = data{img}(1:size(noise.dft,1),:,wf_adc);
      Nfir = 21;
      beforef = fir_dec(before,Nfir);
      afterf = fir_dec(after,Nfir);
      figure(1); clf;
      imagesc(lp(beforef));
      cc=caxis;
      figure(2); clf;
      imagesc(lp(afterf));
      caxis(cc);
      figure(3); clf;
      rline = round(min(8000-1,size(afterf,2))/Nfir) + 1;
      plot(lp(beforef(:,rline)));
      hold on;
      plot(lp(afterf(:,rline)));
    end

    %% Deconvolution
    % ===================================================================
    if param.load.pulse_comp == 1 && wfs(wf).deconv.en && wfs(wf).Nt > 0
      deconv_fn = fullfile(fileparts(ct_filename_out(param,wfs(wf).deconv.fn, '')), ...
        sprintf('deconv_%s_wf_%d_adc_%d.mat',param.day_seg, wf, adc));
      fprintf('  Loading deconvolution: %s (%s)\n', deconv_fn, datestr(now));
      deconv = load(deconv_fn);
      deconv_date_str = deconv.param_collate_deconv_final.sw_version.cur_date_time;
      hdr.custom.deconv(1:length(deconv_date_str),1,img,wf_adc) = deconv_date_str;
      
      deconv_map_idxs = interp1(deconv.map_gps_time,deconv.map_idxs,hdr.gps_time,'nearest','extrap');
      max_score = interp1(deconv.map_gps_time,deconv.max_score,hdr.gps_time,'nearest','extrap');
      
      unique_idxs = unique(deconv_map_idxs);
      
      cmd = deconv.param_collate_deconv.analysis.cmd{deconv.param_collate_deconv.collate_deconv.cmd_idx};
      if wf_adc > 1 && abs(deconv_fc - (cmd.f0+cmd.f1)/2)/deconv_fc > 1e-6
        error('Deconvolution center frequency must be the same for all wf-adc pairs in the image. Was %g and is now %g.', deconv_fc, (cmd.f0+cmd.f1)/2);
      end
      % Prepare variables
      fc = hdr.freq{img}(1);
      
      % Prepare variables to baseband data to new center frequency (in
      % case the deconvolution filter subbands)
      deconv_fc = (cmd.f0+cmd.f1)/2;
      df = hdr.freq{img}(2)-hdr.freq{img}(1);
      BW = df * wfs(wf).Nt;
      deconv_dfc = deconv_fc - fc;
      hdr.freq{img} = mod(hdr.freq{img} + deconv_dfc-wfs(wf).BW_window(1), BW)+wfs(wf).BW_window(1);
      
      for unique_idxs_idx = 1:length(unique_idxs)
        % deconv_mask: Create logical mask corresponding to range lines that use this deconv waveform
        deconv_map_idx = unique_idxs(unique_idxs_idx);
        deconv_mask = deconv_map_idx == deconv_map_idxs;
        % deconv_mask = deconv_map_idx == deconv_map_idxs ...
        %   & max_score > deconv.param_collate_deconv_final.collate_deconv.min_score;
        
        if wfs(wf).Nt <= 2 || ~any(deconv_mask)
          % Range lines are bad (Nt <= 2), or no matching range lines that
          % have a good enough score to justify deconvolution.
          continue;
        end
        
        % Get the reference function
        h_nonnegative = deconv.ref_nonnegative{deconv_map_idx};
        h_negative = deconv.ref_negative{deconv_map_idx};
        h_mult_factor = deconv.ref_mult_factor(deconv_map_idx);
        h_ref_length = length(h_nonnegative)+length(h_negative)-1;
        
        % Adjust deconvolution signal to match sample rline
        h_filled = [h_nonnegative; zeros(wfs(wf).Nt-1,1); h_negative];
        
        % Is dt different? Error
        dt = hdr.time{img}(2)-hdr.time{img}(1);
        if abs(deconv.dt-dt)/dt > 1e-6
          error('There is fast-time sample interval discrepancy between the current processing settings (%g) and those used to generate the deconvolution file (%g).', dt, deconv.dt);
        end
        
        % Is fc different? Multiply time domain by exp(1i*2*pi*dfc*deconv_time)
        dfc = fc - deconv.fc(deconv_map_idx);
        if dfc/fc > 1e-6
          deconv_time = t0 + dt*(0:Nt-1).';
          h_filled = h_filled .* exp(1i*2*pi*dfc*deconv_time);
        end
        deconv_LO = exp(-1i*2*pi*(dfc+deconv_dfc) * hdr.time{img});
        
        % Adjust length of FFT to avoid circular convolution
        deconv_Nt = wfs(wf).Nt + h_ref_length;
        deconv_freq = fftshift(fc + 1/(deconv_Nt*dt) * ifftshift(-floor(deconv_Nt/2) : floor((deconv_Nt-1)/2)).');
        
        % Take FFT of deconvolution impulse response
        h_filled = fft(h_filled);
        
        % Create inverse filter relative to window
        Nt_shorten = find(cmd.f0 <= deconv_freq,1);
        Nt_shorten(2) = deconv_Nt - find(cmd.f1 >= deconv_freq,1,'last');
        Nt_Hwind = deconv_Nt - sum(Nt_shorten);
        Hwind = deconv.ref_window(Nt_Hwind);
        Hwind_filled = ifftshift([zeros(Nt_shorten(1),1); Hwind; zeros(Nt_shorten(end),1)]);
        h_filled_inverse = Hwind_filled ./ h_filled;
        
        % Normalize deconvolution
        h_filled_inverse = h_filled_inverse * h_mult_factor * abs(h_nonnegative(1)./max(deconv.impulse_response{deconv_map_idx}));
        
        % Apply deconvolution filter
        deconv_mask_idxs = find(deconv_mask);
        blocks = round(linspace(1,length(deconv_mask_idxs)+1,8)); blocks = unique(blocks);
        for block = 1:length(blocks)-1
          rlines = deconv_mask_idxs(blocks(block) : blocks(block+1)-1);
          % Matched filter
          data{img}(1:wfs(wf).Nt+h_ref_length,rlines,wf_adc) = ifft(bsxfun(@times, fft(data{img}(1:wfs(wf).Nt,rlines,wf_adc),deconv_Nt), h_filled_inverse));
          % Down conversion to new deconvolution center frequency
          data{img}(1:wfs(wf).Nt,rlines,wf_adc) = bsxfun(@times, data{img}(1:wfs(wf).Nt,rlines,wf_adc), deconv_LO);
        end
        
      end
      
    end
    
  end
  
  if param.load.pulse_comp == 1
    data{img} = data{img}(1:wfs(wf).Nt,:,:);
  end
end
