%% plot_logged_data.m
% Reads a data log file and plots voltage (ch1) and current (ch2) over time,
% scaled to physical units using adjustable calibration constants.
%
% File format:
%   Lines before "Logging data..." are header/metadata.
%   Data columns: Time, [instant,mean,min,max,count,freq,stdev,shape] x N channels
%   Lines beginning with "END" (case-insensitive) terminate data reading.

% =========================================================================
%% USER-ADJUSTABLE CALIBRATION CONSTANTS
% =========================================================================
% Zero offsets (raw ADC counts at zero signal).
% These are used as starting estimates; the script will also offer to
% auto-calculate them from the data (periods where signal is near zero).
V_zero  = 1951;    % raw count = 0 V
I_zero  = 2052;    % raw count = 0 mA

% Scale factors (raw counts per unit)
V_scale = 41;      % counts per Volt
I_scale = 846;     % counts per mA

% Auto-zero: if true, refine V_zero / I_zero from the data automatically
% (uses the median of samples whose mean is within AUTO_ZERO_WINDOW counts
%  of the initial V_zero / I_zero estimates).
AUTO_ZERO        = true;
AUTO_ZERO_WINDOW = 10;   % counts — samples within this range of estimate are "zero"

% =========================================================================
%% ASK FOR FILENAME
% =========================================================================
[fname, fpath] = uigetfile( ...
    {'*.txt;*.csv;*.log', 'Data Files (*.txt, *.csv, *.log)'; ...
     '*.*',               'All Files (*.*)'}, ...
    'Select data log file');
if isequal(fname, 0)
    disp('No file selected. Exiting.');
    return;
end
fullpath = fullfile(fpath, fname);

% =========================================================================
%% READ FILE AND COLLECT DATA LINES
% =========================================================================
fid = fopen(fullpath, 'r');
if fid == -1
    error('Could not open file: %s', fullpath);
end

raw_lines = {};
in_data   = false;

while ~feof(fid)
    line = strtrim(fgetl(fid));
    if ~ischar(line), continue; end

    if ~in_data
        if contains(lower(line), 'logging data')
            in_data = true;
        end
        continue;
    end

    % Stop at END marker
    if strncmpi(line, 'END', 3), break; end

    % Skip blank / separator-only lines
    if isempty(line) || all(ismember(line, '-=~ ')), continue; end

    % Skip non-numeric header lines (data lines start with a digit or sign)
    if isempty(regexp(line, '^\s*[\d.+-]', 'once')), continue; end

    raw_lines{end+1} = line; %#ok<SAGROW>
end
fclose(fid);

if isempty(raw_lines)
    error('No numeric data lines found after "Logging data..." in %s', fullpath);
end

% =========================================================================
%% PARSE INTO NUMERIC MATRIX (with error correction)
% =========================================================================
num_lines = numel(raw_lines);

% Pass 1: determine expected column count from the modal count
col_counts = zeros(num_lines, 1);
for k = 1:num_lines
    v = str2double(strsplit(raw_lines{k}, ','));
    col_counts(k) = sum(~isnan(v));
end
expected_cols = mode(col_counts(col_counts > 0));

% Pass 2: build matrix
data_matrix = [];
skipped     = 0;
for k = 1:num_lines
    v = str2double(strtrim(strsplit(raw_lines{k}, ',')));

    last_num = find(~isnan(v), 1, 'last');
    if isempty(last_num), skipped = skipped+1; continue; end
    v = v(1:last_num);

    if numel(v) < 0.8 * expected_cols
        skipped = skipped + 1;
        fprintf('  Skipping line %d (%d/%d valid cols): %s\n', ...
                k, numel(v), expected_cols, raw_lines{k});
        continue;
    end
    if numel(v) < expected_cols
        v(end+1:expected_cols) = NaN;
    elseif numel(v) > expected_cols
        v = v(1:expected_cols);
    end
    data_matrix(end+1, :) = v; %#ok<SAGROW>
end

if skipped > 0
    fprintf('  %d line(s) skipped due to insufficient data.\n', skipped);
end
if isempty(data_matrix)
    error('No valid data rows could be parsed.');
end
fprintf('Loaded %d rows x %d columns from "%s".\n', ...
        size(data_matrix,1), size(data_matrix,2), fname);

% =========================================================================
%% EXTRACT CHANNELS
% Column order per channel: instant(1) mean(2) min(3) max(4) count(5) freq(6) stdev(7) shape(8)
% =========================================================================
FIELDS_PER_CH = 8;
F_MEAN  = 2; F_MIN = 3; F_MAX = 4; F_FREQ = 6; F_STD = 7;

time_col  = data_matrix(:, 1);
rest_cols = data_matrix(:, 2:end);

num_ch = floor(size(rest_cols, 2) / FIELDS_PER_CH);
if num_ch < 2
    error('Expected at least 2 channels (voltage + current); only %d found.', num_ch);
end
fprintf('Detected %d data channel(s). Using ch1=Voltage, ch2=Current.\n', num_ch);

% Helper: extract one channel's fields (pad if columns are missing)
get_ch = @(ch) padarray( ...
    rest_cols(:, (ch-1)*FIELDS_PER_CH+1 : min(ch*FIELDS_PER_CH, size(rest_cols,2))), ...
    [0, max(0, FIELDS_PER_CH - min(ch*FIELDS_PER_CH,size(rest_cols,2)) + (ch-1)*FIELDS_PER_CH)], ...
    NaN, 'post');

ch1 = rest_cols(:, 1:8);               % Voltage channel raw
ch2 = rest_cols(:, 9:16);             % Current channel raw
if size(ch1,2) < FIELDS_PER_CH, ch1(:,end+1:FIELDS_PER_CH) = NaN; end
if size(ch2,2) < FIELDS_PER_CH, ch2(:,end+1:FIELDS_PER_CH) = NaN; end

% =========================================================================
%% AUTO-ZERO REFINEMENT
% =========================================================================
if AUTO_ZERO
    % Voltage: find rows where mean is close to V_zero estimate
    v_mean_raw = ch1(:, F_MEAN);
    zero_mask_v = abs(v_mean_raw - V_zero) <= AUTO_ZERO_WINDOW;
    if sum(zero_mask_v) >= 3
        V_zero_refined = median(v_mean_raw(zero_mask_v));
        fprintf('Auto-zero: V_zero refined from %.1f to %.4f (using %d samples)\n', ...
                V_zero, V_zero_refined, sum(zero_mask_v));
        V_zero = V_zero_refined;
    else
        fprintf('Auto-zero: not enough near-zero voltage samples; keeping V_zero=%.1f\n', V_zero);
    end

    % Current: find rows where mean is close to I_zero estimate
    i_mean_raw = ch2(:, F_MEAN);
    zero_mask_i = abs(i_mean_raw - I_zero) <= AUTO_ZERO_WINDOW;
    if sum(zero_mask_i) >= 3
        I_zero_refined = median(i_mean_raw(zero_mask_i));
        fprintf('Auto-zero: I_zero refined from %.1f to %.4f (using %d samples)\n', ...
                I_zero, I_zero_refined, sum(zero_mask_i));
        I_zero = I_zero_refined;
    else
        fprintf('Auto-zero: not enough near-zero current samples; keeping I_zero=%.1f\n', I_zero);
    end
end

% =========================================================================
%% SCALE TO PHYSICAL UNITS
% =========================================================================
scale_V = @(x) (x - V_zero) / V_scale;   % -> Volts
scale_I = @(x) (x - I_zero) / I_scale;   % -> mA

V_mean = scale_V(ch1(:, F_MEAN));
V_min  = scale_V(ch1(:, F_MIN));
V_max  = scale_V(ch1(:, F_MAX));
V_std  = ch1(:, F_STD) / V_scale;         % stdev: scale but no offset shift

I_mean = scale_I(ch2(:, F_MEAN));
I_min  = scale_I(ch2(:, F_MIN));
I_max  = scale_I(ch2(:, F_MAX));
I_std  = ch2(:, F_STD) / I_scale;

freq_V = ch1(:, F_FREQ);
freq_I = ch2(:, F_FREQ);

% =========================================================================
%% PLOT
% =========================================================================
col_V    = [0.18  0.45  0.80];   % blue  — voltage
col_I    = [0.85  0.33  0.10];   % orange-red — current
col_freq = [0.47  0.67  0.19];   % green — frequency
col_std  = [0.60  0.20  0.60];   % purple — std dev
alpha_band = 0.20;

fig = figure('Name', sprintf('Data — %s', fname), ...
             'NumberTitle', 'off', ...
             'Units', 'normalized', 'Position', [0.05 0.05 0.88 0.88]);

% ---- helper: draw shaded min-max band + mean line ----
function draw_band(ax, t, y_mn, y_mean, y_mx, col, alpha_val)
    axes(ax); hold(ax, 'on');
    t_patch = [t; flipud(t)];
    y_patch = [y_mn; flipud(y_mx)];
    % Remove rows where any value is NaN to avoid patch artefacts
    bad = isnan(t_patch) | isnan(y_patch);
    t_patch(bad) = []; y_patch(bad) = [];
    patch(ax, t_patch, y_patch, col, ...
          'FaceAlpha', alpha_val, 'EdgeColor', 'none', ...
          'HandleVisibility', 'off');
    plot(ax, t, y_mx,   '-', 'Color', col*0.75, 'LineWidth', 0.8, ...
         'DisplayName', 'Max');
    plot(ax, t, y_mn,   '-', 'Color', col*0.75, 'LineWidth', 0.8, ...
         'DisplayName', 'Min');
    plot(ax, t, y_mean, '--','Color', col,       'LineWidth', 1.6, ...
         'DisplayName', 'Mean');
end

% ---- Subplot 1: Voltage ----
ax1 = subplot(3,1,1);
draw_band(ax1, time_col, V_min, V_mean, V_max, col_V, alpha_band);
grid(ax1, 'on');
ylabel(ax1, 'Voltage (V)');
title(ax1, 'Voltage');
legend(ax1, 'Max','Min','Mean', 'Location','best');
ax1.XTickLabel = {};

% ---- Subplot 2: Current ----
ax2 = subplot(3,1,2);
draw_band(ax2, time_col, I_min, I_mean, I_max, col_I, alpha_band);
grid(ax2, 'on');
ylabel(ax2, 'Current (mA)');
title(ax2, 'Current');
legend(ax2, 'Max','Min','Mean', 'Location','best');
ax2.XTickLabel = {};

% ---- Subplot 3: Frequency & Std Dev ----
ax3 = subplot(3,1,3);
yyaxis(ax3, 'left');
plot(ax3, time_col, freq_V, '-',  'Color', col_freq,      'LineWidth', 1.5, ...
     'DisplayName', 'Freq V');
hold(ax3, 'on');
plot(ax3, time_col, freq_I, '--', 'Color', col_freq*0.65, 'LineWidth', 1.5, ...
     'DisplayName', 'Freq I');
ylabel(ax3, 'Frequency (Hz)');

yyaxis(ax3, 'right');
plot(ax3, time_col, V_std, '-',  'Color', col_std,      'LineWidth', 1.2, ...
     'DisplayName', 'SD V (V)');
plot(ax3, time_col, I_std, '--', 'Color', col_std*0.65, 'LineWidth', 1.2, ...
     'DisplayName', 'SD I (mA)');
ylabel(ax3, 'Std Dev (V / mA)');

grid(ax3, 'on');
xlabel(ax3, 'Time (s)');
title(ax3, 'Frequency & Std Dev');
legend(ax3, 'Freq V','Freq I','SD V','SD I', 'Location','best');

% ---- Link x-axes so pan/zoom is synchronised ----
linkaxes([ax1, ax2, ax3], 'x');

% ---- Title ----
sgtitle(sprintf('%s\n  V: zero=%.2f, scale=%.1f cts/V  |  I: zero=%.2f, scale=%.1f cts/mA', ...
        fname, V_zero, V_scale, I_zero, I_scale), ...
        'Interpreter', 'none', 'FontSize', 10);

fprintf('Done. Calibration applied — V_zero=%.4f, V_scale=%.2f | I_zero=%.4f, I_scale=%.2f\n', ...
        V_zero, V_scale, I_zero, I_scale);
