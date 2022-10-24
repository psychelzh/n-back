function [status, exception, recordings] = start(stim_type, phase, run, opts)
%START_NBACK Starts stimuli presentation for n-back test
%   Detailed explanation goes here
arguments
    stim_type {mustBeTextScalar, mustBeMember(stim_type, ["loc", "dig"])} = "loc"
    phase {mustBeTextScalar, mustBeMember(phase, ["prac", "prac0", "prac1", "prac2", "test"])} = "prac"
    run {mustBeInteger, mustBePositive} = 1
    opts.id (1, 1) {mustBeInteger, mustBeNonnegative} = 0
    opts.SaveData (1, 1) {mustBeNumericOrLogical} = true
    opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = true
end

import exp.init_config

% ---- set default error related outputs ----
status = 0;
exception = [];

% ---- set experiment timing parameters (predefined here, all in secs) ----
timing = struct( ...
    'block_cue_secs', 4, ...
    'stim_secs', 2.5, ...
    'blank_secs', 0.5, ...
    'feedback_secs', 0.5);

% ----prepare config and data recording table ----
config = init_config(phase);
config = config(config.run_id == run, :);
rec_vars = {'acc', 'rt', 'resp', 'resp_raw'};
rec_init = table('Size', [height(config), length(rec_vars)], ...
    'VariableTypes', [repelem("doublenan", 2), repelem("string", 2)], ...
    'VariableNames', rec_vars);
recordings = horzcat(config, rec_init);

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen_to_display = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% do not skip synchronization test to make sure timing is accurate
old_sync = Screen('Preference', 'SkipSyncTests', double(opts.SkipSyncTests));
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen_to_display));
% PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('space'), ...
    'exit', KbName('Escape'), ...
    'same', KbName('LeftArrow'), ...
    'diff', KbName('RightArrow'));

% ---- stimuli presentation ----
try
    % the flag to determine if the experiment should exit early
    early_exit = false;
    % open a window and set its background color as gray
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen_to_display, BlackIndex(screen_to_display));
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);
    % prepare stimuli rectangle
    rect_size = round(0.625 * RectHeight(window_rect));
    [center(1), center(2)] = RectCenter(window_rect);
    base_rect = [0, 0, rect_size, rect_size];
    stim_rect = CenterRectOnPoint(base_rect, center(1), center(2));
    % prepare block cue textures
    n_cues = 3;
    tex_cues = nan(1, n_cues);
    for i = 1:n_cues
        cue_file = fullfile('instractor', sprintf('instrator_%dback.png', i - 1));
        tex_cues(i) = image_to_tex(cue_file, window_ptr);
    end
    % preprare stimuli textures
    n_stims = 9;
    tex_stims = nan(1, n_stims);
    for i = 1:n_stims
        stim_file = fullfile('stimuli', sprintf('stim_%s_%d.png', stim_type, i));
        tex_stims(i) = image_to_tex(stim_file, window_ptr);
    end

    % display welcome/instr screen and wait for a press of 's' to start
    switch phase
        case "prac"
            instr = '下面我们进行综合练习';
        case "prac0"
            instr = '下面我们练习0-back';
        case "prac1"
            instr = '下面我们练习1-back';
        case "prac2"
            instr = '下面我们练习2-back';
        case "test"
            instr = '下面我们进行正式测试';
    end
    DrawFormattedText(window_ptr, double([instr, '\n按空格键开始']), ...
        'center', 'center', get_color('white'));
    Screen('Flip', window_ptr);
    % here we should detect for a key press and release
    while ~early_exit
        [resp_timestamp, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            start_time = resp_timestamp;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end

    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
        this_trial = config(trial_order, :);
        % new block starts with block cue
        if trial_order == 1 || ...
                this_trial.block_id ~= config.block_id(trial_order - 1)
            start_time_block = GetSecs;
            while ~early_exit
                Screen('DrawTexture', window_ptr, tex_cues(this_trial.task_load + 1), [], stim_rect);
                vbl = Screen('Flip', window_ptr);
                [~, ~, key_code] = KbCheck(-1);
                if key_code(keys.exit)
                    early_exit = true;
                    break
                end
                if vbl >= start_time_block + timing.block_cue_secs - 0.5 * ifi
                    break
                end
            end
        end

        % basic routine
        resp_collected = collect_response(this_trial);
        resp_result = analyze_response(resp_collected);

        % record response
        recordings.acc(trial_order) = this_trial.cresp == resp_result.name;
        recordings.rt(trial_order) = resp_result.time;
        recordings.resp(trial_order) = resp_result.name;
        recordings.resp_raw(trial_order) = resp_result.raw;

        % give feedback when in practice
        if phase ~= "test"
            show_feedback(this_trial, resp_result)
        end

    end
catch exception
    status = 1;
end

if early_exit
    status = 2;
end

% --- post presentation jobs
Screen('Close');
sca;
% enable character input and show mouse cursor
ListenChar;
ShowCursor;

% restore preferences
Screen('Preference', 'VisualDebugLevel', old_visdb);
Screen('Preference', 'SkipSyncTests', old_sync);
Screen('Preference', 'TextRenderer', old_text_render);
Priority(old_pri);

if opts.SaveData
    writetable(recordings, fullfile('data', ...
        sprintf('nback_stim-%s_phase-%s_sub-%03d_run-%d_time-%s.csv', ...
        stim_type, phase, opts.id, run, ...
        datetime("now", "Format", "yyyyMMdd-HHmmss"))))
end

if ~isempty(exception)
    rethrow(exception)
end

    function resp_collected = collect_response(trial)
        % present stimuli
        resp_made = false;
        resp_code = nan;
        stim_onset_stamp = nan;
        resp_timestamp = nan;
        start_time_trial = GetSecs;
        while ~early_exit
            [key_pressed, timestamp, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end
            if key_pressed
                if ~resp_made
                    resp_code = key_code;
                    resp_timestamp = timestamp;
                end
                resp_made = true;
            end
            if timestamp < start_time_trial + timing.stim_secs
                Screen('DrawTexture', window_ptr, tex_stims(trial.stim), [], stim_rect)
                vbl = Screen('Flip', window_ptr);
                if isnan(stim_onset_stamp)
                    stim_onset_stamp = vbl;
                end
            else
                vbl = Screen('Flip', window_ptr);
            end
            if vbl >= start_time_trial + timing.stim_secs + timing.blank_secs - 0.5 * ifi
                break
            end
        end
        resp_collected = struct( ...
            'made', resp_made, ...
            'code', resp_code, ...
            'time', resp_timestamp - stim_onset_stamp);
    end

    function resp_result = analyze_response(resp_collected)
        if ~resp_collected.made
            resp_raw = "";
            resp_name = "none";
            resp_time = 0;
        else
            % use "|" as delimiter for the KeyName of "|" is "\\"
            resp_code = resp_collected.code;
            resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'same', 'diff'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                resp_name = "invalid";
            else
                resp_name = valid_names{valid_codes == find(resp_code)};
            end
            resp_time = resp_collected.time;
        end
        resp_result = struct( ...
            'raw', resp_raw, ...
            'name', resp_name, ...
            'time', resp_time);
    end

    function show_feedback(trial, resp_result)
        start_time = GetSecs;
        while ~early_exit
            [~, ~, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end

            if trial.cresp ~= resp_result.name
                fb.color = get_color('red');
                if resp_result.name == "none"
                    fb.text = '超时';
                elseif trial.cresp == "none"
                    fb.text = '前两个试次不能作答';
                else
                    fb.text = '错误';
                end
            else
                fb.color = get_color('green');
                fb.text = '正确';
            end
            DrawFormattedText(window_ptr, double(fb.text), 'center', 'center', fb.color);
            vbl = Screen('Flip', window_ptr);
            if vbl >= start_time + timing.feedback_secs - 0.5 * ifi
                break
            end
        end
    end
end

function tex = image_to_tex(file, win)
[stim_data, ~, stim_alpha] = imread(file);
stim_data(:, :, 4) = stim_alpha;
tex = Screen('MakeTexture', win, stim_data);
end
