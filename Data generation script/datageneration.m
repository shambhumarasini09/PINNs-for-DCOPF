% ==========================================================
% DC-OPF Data Generation with LHS Load Sampling (±x%)
% ==========================================================
clear; clc;

% --- Load case and PTDF ---
mpc = case39;
PTDF = makePTDF(mpc);



nBuses = size(mpc.bus, 1);
nBranches = size(mpc.branch, 1);

% --- Base load data ---
Pd_base = mpc.bus(:, 3);              % base active load (MW)
load_buses = find(Pd_base > 0);       % indices of buses with demand
nLoad = length(load_buses);

% --- Generator and cost data ---
gen_bus = mpc.gen(:, 1);
Pg_max = mpc.gen(:, 9);
Pg_min = mpc.gen(:, 10);
c2 = mpc.gencost(:, 5);
c1 = mpc.gencost(:, 6);
c0 = mpc.gencost(:, 7);

cost_coeffs=[c2,c1,c0];


% --- Sampling parameters ---
Nr_samples = 10000;   % number of scenarios
 x = 0.20;           % ±20% variation
% x = 0;

% --- Generate LHS samples for load buses ---
input_lhs = lhsdesign(Nr_samples, nLoad);   % LHS in [0,1]
Pd_min = (1 - x) * Pd_base(load_buses)';   % row vector
Pd_max = (1 + x) * Pd_base(load_buses)';   % row vector

Pd_samples = Pd_min + input_lhs .* (Pd_max - Pd_min);  % scale to actual load
        % === Power flow limits ===
        PF_max = mpc.branch(:,6);
         PF_max(27)=400;
        PF_min = -PF_max;

% --- Storage for dataset ---
nn_output_target = [];
nn_input_feature=[];

fprintf('Generating %d samples using LHS...\n', Nr_samples);

for k = 1:Nr_samples
    try
        % --- Create full load vector for this scenario ---
        Pd_rand = Pd_base;                  % start with base loads
        Pd_rand(load_buses) = Pd_samples(k,:);  % assign sampled loads
        Pd_total = sum(Pd_rand);

        % === Define optimization variables ===
        pg = sdpvar(nBuses,1);
        is_gen = ismember(mpc.bus(:,1), gen_bus);
        pg(~is_gen) = 0;
        pg_var = pg(is_gen);



        % === Net injections and line flows ===
        NetP = pg - Pd_rand;
        PF = PTDF * NetP;

        % === Objective (quadratic cost) ===
        Objective = sum(c2 .* pg_var.^2 + c1 .* pg_var + c0);

        % === Constraints ===
        Constraints = [
            pg_var <= Pg_max;
            pg_var >= Pg_min;
            PF <= PF_max;
            PF >= PF_min;
            sum(pg_var) == Pd_total
        ];

        % === Solve OPF ===
        options = sdpsettings('verbose',0,'solver','gurobi');
        sol = optimize(Constraints, Objective, options);

        % --- Skip infeasible or failed cases ---
        if sol.problem ~= 0
            continue;
        end

        pg_opt = value(pg_var);
        if any(isnan(pg_opt))
            continue;
        end

        % === Dual variables ===
        dual_pg_max = dual(Constraints(1));
        dual_pg_min = dual(Constraints(2));
        dual_PF_max = dual(Constraints(3));
        dual_PF_min = dual(Constraints(4));
        dual_balance = dual(Constraints(5));

        % === Binding flow duals (nonzero only) ===
        dual_pf_max = zeros(nBranches,1);
        dual_pf_min = zeros(nBranches,1);
        for i = 1:nBranches
            if abs(dual_PF_max(i)) > 1e-8
                dual_pf_max(i) = dual_PF_max(i);
            elseif abs(dual_PF_min(i)) > 1e-8
                dual_pf_min(i) = dual_PF_min(i);
            end
        end

        % === Construct dataset row ===
        % [Pd_at_load_bus_only, pg_opt(1:10), dual_balance, dual_pf]
        % result_row = [Pd_rand(load_buses)' pg_opt(1:10)' dual_balance dual_pf'];
        result_row = [pg_opt(1:10)' dual_balance dual_pf_max' dual_pf_min' dual_pg_max' dual_pg_min'];
        nn_output_target = [nn_output_target; result_row];
        nn_input_feature=[nn_input_feature;Pd_rand(load_buses)'];


    catch
        % Skip runtime errors
        continue;
    end
end

fprintf('Feasible samples: %d\n', size(nn_output_target,1));

% % === Save dataset ===

% writematrix(PTDF, 'PTDF.csv');
% writematrix(cost_coeffs, 'cost_coeffs.csv');
% writematrix(PF_max, 'line_limits.csv');
% writematrix(nn_output_target, 'dcopf_output.csv'); 
% writematrix(nn_input_feature, 'demands_loadbus.csv'); % demand at loadbus
