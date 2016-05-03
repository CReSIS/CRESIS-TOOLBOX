%% Read GPS files in this directory

adc = defaults{1}.records.file.adcs(1);
board = adc_to_board(param.radar_name,adc);
adc_folder_name = defaults{1}.adc_folder_name;
adc_folder_name = regexprep(adc_folder_name,'%02d',sprintf('%02.0f',adc));
adc_folder_name = regexprep(adc_folder_name,'%d',sprintf('%.0f',adc));
adc_folder_name = regexprep(adc_folder_name,'%b',sprintf('%.0f',board));
data_fns = get_filenames(fullfile(base_dir,adc_folder_name),defaults{1}.data_file_prefix,'','.bin');
finfo = fname_info_mcords2(data_fns{1});
  
[year,month,day] = datevec(finfo.datenum);
param.day_seg = sprintf('%04d%02d%02d_01',year,month,day);
gps_fn = ct_filename_support(param,'','gps',1);
if exist(gps_fn,'file')
  gps = load(gps_fn);
else
  try
    gps_fns = get_filenames(base_dir,'GPS_','','.txt');
    
    for gps_fn_idx = 1:length(gps_fns)
      gps_fn = gps_fns{gps_fn_idx};
      fprintf('  GPS file: %s\n', gps_fn);
      [~,gps_fn_name] = fileparts(gps_fn);
      gps_params.year = str2double(gps_fn_name(5:8));
      gps_params.month = str2double(gps_fn_name(9:10));
      gps_params.day = str2double(gps_fn_name(11:12));
      gps_params.time_reference = 'utc';
      if gps_fn_idx == 1
        gps = read_gps_nmea(gps_fns{gps_fn_idx},gps_params);
      else
        gps_tmp = read_gps_nmea(gps_fns{gps_fn_idx},gps_params);
        gps.gps_time = [gps.gps_time, gps_tmp.gps_time];
        gps.lat = [gps.lat, gps_tmp.lat];
        gps.lon = [gps.lon, gps_tmp.lon];
        gps.elev = [gps.elev, gps_tmp.elev];
        gps.roll = [gps.roll, gps_tmp.roll];
        gps.pitch = [gps.pitch, gps_tmp.pitch];
        gps.heading = [gps.heading, gps_tmp.heading];
      end
    end
  end
end

geotiff_fns = {};
geotiff_fns{1} = ct_filename_gis(param,'antarctica/Landsat-7/Antarctica_LIMA_480m.tif');
geotiff_fns{2} = ct_filename_gis(param,'greenland/Landsat-7/mzl7geo_90m_lzw.tif');

if 0
  fprintf('Select Geotiff:\n');
  for geotiff_idx=1:length(geotiff_fns)
    fprintf(' %d: %s\n', geotiff_idx, geotiff_fns{geotiff_idx});
  end
  geotiff_fn = '';
  while ~exist(geotiff_fn,'file')
    try
      geotiff_idx = input(': ');
      geotiff_fn = geotiff_fns{geotiff_idx};
    end
  end
elseif gps.lat > 0
  geotiff_fn = geotiff_fns{2};
else
  geotiff_fn = geotiff_fns{1};
end

%% Prepare GPS plots
h_geotiff = geotiff(geotiff_fn);

%% Process XML files
% =========================================================================
% Read XML files in this directory
[settings,settings_enc] = read_ni_xml_directory(base_dir,'',false);

% Get raw data files associated with this directory
fn_datenums = [];

% Get the date information out of the filename
for data_fn_idx = 1:length(data_fns)
  fname = fname_info_mcords2(data_fns{data_fn_idx});
  fn_datenums(end+1) = fname.datenum;
end

%% Print out settings from each XML file (and plot if enabled)
fprintf('\nData segments:\n');
for set_idx = 1:length(settings)
  
  if set_idx < length(settings)
    num_files = sum(fn_datenums >= settings(set_idx).datenum & fn_datenums < settings(set_idx+1).datenum);
  else
    num_files = sum(fn_datenums >= settings(set_idx).datenum);
  end
  
  % Print out settings
  if isfield(settings(set_idx),'XML_File_Path')
    [~,settings_fn_name] = fileparts(settings(set_idx).fn);
    fprintf(' %d: %s (%d wfs, %d files)\n', set_idx, ...
      settings(set_idx).XML_File_Path{1}.values{1}, settings(set_idx).DDS_Setup.Wave, num_files);
    if set_idx < length(settings)
      settings(set_idx).match_idxs = find(fn_datenums >= settings(set_idx).datenum & fn_datenums < settings(set_idx+1).datenum);
    else
      settings(set_idx).match_idxs = find(fn_datenums >= settings(set_idx).datenum);
    end
  end
  
  %% Plot GPS information
  % Load in first header from each file, get UTC time SOD, plot
  % position on a map
  hdr_gps_time = [];
  for match_idx = settings(set_idx).match_idxs(1:end-1)
    try
      hdr = defaults{1}.header_load_func(data_fns{match_idx},defaults{1}.header_load_params);
    end
    finfo = fname_info_mcords2(data_fns{match_idx});
    [year,month,day] = datevec(finfo.datenum);
    hdr_gps_time(end+1) = utc_to_gps(datenum_to_epoch(datenum(year,month,day,0,0,hdr.utc_time_sod))) + defaults{1}.vectors.gps.time_offset;
  end
  hdr_gps_time = utc_to_gps(hdr_gps_time);
  
  segment = [];
  segment.name = sprintf('Segment %d',set_idx);
  segment.lat = interp1(gps.gps_time,gps.lat,hdr_gps_time);
  segment.lat = segment.lat(:);
  segment.lon = interp1(gps.gps_time,gps.lon,hdr_gps_time);
  segment.lon = segment.lon(:);
  segment.value_name = {'Filename'};
  segment.value = data_fns(settings(set_idx).match_idxs(1:end-1));
  segment.value = segment.value(:);
  h_geotiff.insert_segment(segment);
end

fig_number = h_geotiff.h_fig.Number;
fn = '';
while isempty(fn)
  fprintf('\nPress enter when done selecting files in figure %d\n\n', fig_number);
  pause;
  g_basic_file_loader_fns = h_geotiff.get_selection();
  if ~isempty(g_basic_file_loader_fns)
    fn = g_basic_file_loader_fns{1};
  end
end

delete(h_geotiff);
