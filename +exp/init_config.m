function config = init_config(phase, stim_type)
%INIT_CONFIG Initializing configurations for all tasks

arguments
    phase {mustBeTextScalar, mustBeMember(phase, ["prac", "prac0", "prac1", "prac2", "test"])}
    stim_type {mustBeTextScalar, mustBeMember(stim_type, ["loc", "dig"])} = "loc"
end

trials_each_block = 10;
if contains(phase, "prac")
    switch phase
        case "prac"
            loads = 0:2;
        case "prac0"
            loads = 0;
        case "prac1"
            loads = 1;
        case "prac2"
            loads = 2;
    end
    config = table;
    for i_block = 1:length(loads)
        trials = init_trials(trials_each_block, loads(i_block));
        cur_block = addvars( ...
            trials, ...
            ones(height(trials), 1), ... % run_id
            i_block * ones(height(trials), 1), ... % block_id
            repmat(loads(i_block), height(trials), 1), ... % load
            'NewVariableNames', {'run_id', 'block_id', 'task_load'}, ...
            'Before', 1);
        config = vertcat(config, cur_block); %#ok<AGROW>
    end
else
    config = readtable(fullfile('seq', sprintf('%s_seq_nback.csv', stim_type)), "TextType", "string");
end
end

function trials = init_trials(num_trials, task_load, opts)
arguments
    num_trials {mustBeInteger, mustBePositive} = 10
    task_load {mustBeInteger, mustBeNonnegative, ...
        mustBeLessThan(task_load, num_trials)} = 2
    opts.StimsPool = 1:9 
    opts.Target0 = 5
end

stims_pool = opts.StimsPool;

% we cannot really set lure type for zero and one back
n_filler = task_load;
n_same = fix((num_trials - task_load) / 2);
if task_load == 2
    n_lure = fix((num_trials - task_load) / 4);
else
    n_lure = 0;
end
n_diff = num_trials - n_filler - n_same - n_lure;
stim_conds = [ ...
    repelem("same", n_same), ...
    repelem("lure", n_lure), ...
    repelem("diff", n_diff)];
% ---- randomise conditions ----
cond_okay = false;
while ~cond_okay
    cond_order = [ ...
        repelem("filler", task_load), ...
        stim_conds(randperm(length(stim_conds)))];
    cresp_order = strings(1, length(cond_order));
    for i = 1:length(cond_order)
        if cond_order(i) == "filler"
            cresp_order(i) = "none";
        elseif ismember(cond_order(i), ["lure", "diff"])
            cresp_order(i) = "diff";
        else
            cresp_order(i) = "same";
        end
    end
    % lure/same trials cannot directly follow lure trials
    after_lure = cond_order(circshift(cond_order == "lure", 1));
    if (any(ismember(after_lure, ["lure", "same"])))
        continue
    end
    % require no more than 3 consecutive repetition responses
    cond_okay = validate_consecutive(cresp_order(task_load + 1:end));
end

% --- allocate stimulus ---
order_stim = [ ...
    randsample(stims_pool, task_load, false), ...
    nan(1, num_trials - task_load)];
for i = (task_load + 1):num_trials
    if cond_order(i) == "same"
        if task_load == 0
            order_stim(i) = opts.Target0;
        else
            order_stim(i) = order_stim(i - task_load);
        end
    else
        if cond_order(i) == "lure"
            stims_sample = order_stim(i - (1:(task_load - 1)));
        else
            if task_load == 0
                stims_sample = setdiff(stims_pool, opts.Target0);
            else
                stims_sample = setdiff(stims_pool, ...
                    order_stim(i - (1:task_load)));
            end
        end
        order_stim(i) = randsample(stims_pool, 1, true, ...
            ismember(stims_pool, stims_sample));
    end
end

trials = table( ...
    (1:num_trials)', order_stim', ...
    cond_order', cresp_order', ...
    VariableNames=["trial_id", "stim", "cond", "cresp"]);
end

function tf = validate_consecutive(seq, max_run_value)
arguments
    seq {mustBeVector}
    max_run_value (1, 1) {mustBeInteger, mustBePositive} = 3
end

tf = true;
run_value = missing;
for i = 1:length(seq)
    cur_value = seq(i);
    if run_value ~= cur_value
        run_value = cur_value;
        run_length = 1;
    else
        run_length = run_length + 1;
    end
    if run_length > max_run_value
        tf = false;
        break
    end
end
end
