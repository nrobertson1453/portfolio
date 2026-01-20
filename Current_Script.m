%% tank_optimizer_tube.m
% Optimize a hollow tube (annular cylinder) tank:
% - uses mean diameter for thin-wall hoop stress
% - computes annular shell volume (outer minus inner)
% - performs bolt checks (bearing, tear, shear)
% - optimizes over stocked OD & wall options, bolt diameters, bolt count, with length constrained to 0-1 m
%
% Units: SI (m, Pa, kg). Change inputs below as needed.

clear; close all; clc;

%% ---------------- User inputs ----------------
% Given values
sigma_y_Al = 3.1*10^8;       % Pa (Al-6061 T6 yield)
chamber_pressure = 3447000;      % Pa (internal pressure)
MinFS = 2;                    % minimum factor of safety required (hoop + bolts)
rho_al = 2700; % kg/m^3 (density of aluminum)
rho_abs = 1115; %density of abs
fuel_mass=0.179668639101; %kg
OD= 0.0825; %m

% Bolt variables (user-changeable)
n_list = [8 10 12];  % bolts per end (vector to search)
dis = 0.01;  % m -- distance (from bolt row to tank top). set as desired.

% Bolt diameters to search (inches -> meters)
bolt_diam_in = [1/8, 3/16, 5/16];    % common small bolt sizes
bolt_diam_m = bolt_diam_in * 0.0254;

% Standard stocked tube OD (mm) and wall (mm) lists -- replace with vendor list if desired
wall_mm = [1.5875, 3.175];                  % common walls (mm)


wall = wall_mm/1000;  % m

%% ---------- material properties for bolts (approx) ----------
% For shear capacity of steel bolts (used for FS_shear)
sigma_y_steel = 400e6;   % Pa (adjust for actual bolt grade)
tau_st = 0.577 * sigma_y_steel;  % conservative conversion

%% ---------- results storage ----------
res = struct('OD',[],'t',[],'ID',[],'Dmean',[],'FuelLength',[],'bolt_d',[],'n',[],'mass_shell',[],'sigma_hoop',[],'FS_hoop',[],'FS_bearing',[],'FS_tear',[],'FS_shear',[]);
idx = 0;

%% ---------- Search loop ----------
rho_fuel = rho_abs;   % define the fuel density being used
tank_pressure = chamber_pressure;  % unify variable naming

for it = 1:length(wall)
    % Geometry setup
    OD_i = OD;             % outer diameter is fixed
    t_i  = wall(it);       % current wall thickness
    ID_i = OD_i - 2*t_i;   % inner diameter

    if ID_i <= 0
        continue;  % invalid geometry
    end

    % Compute fuel volume and required tank length
    V_fuel = fuel_mass / rho_fuel;           % m^3
    L_i = V_fuel / (pi * (ID_i/2)^2);        % m

    if L_i <= 0 || L_i > 1.0
        continue;  % enforce physical range
    end

    % Mean diameter for thin-wall hoop stress
    D_mean = (OD_i + ID_i) / 2;

    % Thin-wall hoop stress check
    sigma_hoop = chamber_pressure * D_mean / (2 * t_i);
    FS_hoop = sigma_y_Al / sigma_hoop;

    if FS_hoop < MinFS
        continue;  % reject if hoop FS below minimum
    end

    % Compute mass of the shell
    vol_shell = pi * (OD_i^2 - ID_i^2) / 4 * L_i;
    mass_shell = vol_shell * rho_al;

    % Internal pressure axial force on endcaps
    endcap_area = pi * (ID_i/2)^2;
    F_total = chamber_pressure * endcap_area;  % N

    % Iterate through bolt sizes and counts
    for ib = 1:length(bolt_diam_m)
        b_d = bolt_diam_m(ib);
        A_bolt = pi * (b_d/2)^2;  % bolt shear area

        for in_idx = 1:length(n_list)
            n_b = n_list(in_idx);
            if n_b <= 0
                continue;
            end

            % Force distribution per bolt
            F_per_bolt = F_total / n_b;

            % Bearing stress
            sigma_bearing = F_per_bolt / (b_d * t_i);
            FS_bearing = sigma_y_Al / sigma_bearing;

            % Tear (tensile) stress
            sigma_t = F_total / (2 * n_b * dis * t_i);
            tau_conv = 0.577 * sigma_y_Al;
            FS_tear = tau_conv / sigma_t;

            % Bolt shear stress
            sigma_s = F_per_bolt / A_bolt;
            FS_shear = tau_st / sigma_s;

            % Store results if all FS are acceptable
            if FS_bearing >= MinFS && FS_tear >= MinFS && FS_shear >= MinFS
                idx = idx + 1;
                res(idx).OD = OD_i;
                res(idx).t = t_i;
                res(idx).ID = ID_i;
                res(idx).Dmean = D_mean;
                res(idx).L = L_i;
                res(idx).bolt_d = b_d;
                res(idx).n = n_b;
                res(idx).pre_CC_l=(ID_i/2);
                res(idx).post_CC_L=(ID_i);
                res(idx).mass_shell = mass_shell;
                res(idx).sigma_hoop = sigma_hoop;
                res(idx).FS_hoop = FS_hoop;
                res(idx).FS_bearing = FS_bearing;
                res(idx).FS_tear = FS_tear;
                res(idx).FS_shear = FS_shear;
            end
        end
    end
end
%% ---------- Report ----------
if idx == 0
    fprintf('No feasible tube designs found. Try larger wall thicknesses, larger OD, higher n, or adjust dis.\n');
    return;
end

T = struct2table(res);
T_sorted = sortrows(T,'mass_shell');

n_print = min(10,height(T_sorted));
fprintf('Top %d feasible tube designs (sorted by shell mass):\n', n_print);
fprintf('OD(mm)  t(mm)  ID(mm)  Dmean(mm)  FuelL(mm)  bolt_d(in)  n  pre_CC_l  post_CC_L  mass_shell(kg)  FS_hoop  FS_bear  FS_tear  FS_shear\n');
for k = 1:n_print
    row = T_sorted(k,:);
    fprintf('%6.1f  %5.2f  %6.2f  %8.2f  %6.1f   %6.3f      %2d  %10.4f      %5.2f    %5.2f    %5.2f    %5.2f\n', ...
        row.OD*1000, row.t*1000, row.ID*1000, row.Dmean*1000, row.L*1000, row.bolt_d/0.0254, row.n, row.mass_shell, row.FS_hoop, row.FS_bearing, row.FS_tear, row.FS_shear);
end

tank_options = T_sorted;  % full table returned to workspace

% Quick plot
figure;

scatter(T_sorted.Dmean*1000, T_sorted.mass_shell, 40, 'filled');
xlabel('Mean Diameter (mm)'); ylabel('Shell mass (kg)');
title('Feasible tube designs: shell mass vs mean diameter');
grid on;
