clear;clc;close all

%% Inputs
% Simulation parameters
dt = .5;                        % hours
time = 0:dt:24;

% Cars to be charged
num_cars = 15;
capacities = 100*ones(1,num_cars);          % kWh
start_soes = randi(60,1,num_cars);          % percent 0-100
end_soes = (100 - start_soes) ...
    .* rand(1,num_cars) + start_soes;       % percent 0-100
max_charge_pwr = 100*ones(1,num_cars);      % kW
start_times = 7+(13-7)*rand(1,num_cars);    % hours from midnight
charge_times = randi(11,1,num_cars);        % hours
stop_times = charge_times + start_times;    % hours from midnight

% Grid externalities
max_grid_pwr = 80;                      % kW
non_charging_grid_pwr = zeros(1,25);    % kW - as fn of hours from midnight
global CO2_footprint                    % gross global, fixme plz
CO2_footprint = load_CO2_data(time);    % lbs CO2 / kWh

%% Optimization problem definition
num_timesteps = length(time);
P_size = [num_timesteps, num_cars];
P = optimvar('P', P_size, 'LowerBound',0,'UpperBound',max(max_charge_pwr));
obj = objective(P);
prob = optimproblem('Objective',obj);

%% Optimization problem constraints
% prevent overload on the grid
non_charging_grid_pwr = interp1(0:24, non_charging_grid_pwr, time);
max_grid_pwr_constr = sum(P,2) + non_charging_grid_pwr' <= max_grid_pwr;
prob.Constraints.maxGridPwr = max_grid_pwr_constr;   

% obey vehicle hardware limits
max_car_pwr_constr = P <= repmat(max_charge_pwr,num_timesteps,1);
prob.Constraints.maxCarPwr = max_car_pwr_constr;     

% energy delivered must meet start/end soe
energies = (end_soes - start_soes) .* capacities / 100;
for car = 1:num_cars
    energy_constr = trapz(time,P(:,car)) == energies(car);
    constr_name = ['energy' num2str(car)];
    prob.Constraints.(constr_name) = energy_constr;          
end

% power must be zero when car not plugged in
time_mat = repmat(time', [1 num_cars]);
idxs_not_charging = time_mat < start_times | time_mat > stop_times;
time_constr = P(idxs_not_charging) == 0;
prob.Constraints.time = time_constr;               

%% Run optimizer
P0 = zeros(P_size);
x0.P = P0;
sol = solve(prob,x0);

%% Plot results
close all
figure; hold all
for car=1:num_cars
    plot(time, sol.P(:,car),'DisplayName',['Car ' num2str(car)])
end
plot(time, sum(sol.P,2),'DisplayName','Total')
xlabel('Time (hours)')
ylabel('Power (kW)')
legend
improvePlot

%% Helper functions
% Optimization objective function
function cost = objective(P)

    num_cars = size(P,2);
    
    grid_power = sum(P,2);
    grid_variance = variance(grid_power);
    
    car_variance = optimexpr(1, num_cars);
    for car = 1:num_cars
        car_power = P(:,car);
        car_variance(car) = variance(car_power);
    end
    
    global CO2_footprint
    dirtiness = sum(grid_power' .* CO2_footprint);
    
    a = 1; b = 1; c = 1;
    cost = a * grid_variance + b * sum(car_variance) + c * dirtiness;
end

function v = variance(x)
% because the matlab default function var doesn't accept optimvar inputs
    n = length(x);
    v = sum((x - sum(x)./n).^2) ./ (n-1); 
end

