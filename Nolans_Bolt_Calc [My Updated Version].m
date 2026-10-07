%%tank_finder.m
clear; close all; clc;

%----------------USER INPUTS-------------------
%Design decisions that went into Givens:
% - aluminum casing
% - tensile yield strength for aluminum 
% - ABS fuel grain


% Given values:
sigma_y_Al = ?;       % Pa (Al-6061 T6 tensile yield stress), to be sourced from manufacturer
tau_Al = ?;           % Pa (Al-6061 T6 shear yield stress), to be sourced from manufacturer
rho_al = 2700; % kg/m^3 (density of aluminum)
rho_abs = 1115; %density of abs


%Design decisions that went into Design Derived values:
% - Chamber pressure is chosen as a determined value to drive remainder of
%   design.
%   We reduce pressure from nitrous oxide from 1000 psi to 500 psi across
%   oxidizer piping, any remaining is bled when injecting into Combustion
%   Chamber
% - Factor of Safety is chosen due to safety concerns
% - Fuel mass of ABS is derived from Fuel Grain team (CHECK, currently
% running 1.44 kg (derived from multiplying MFR of fuel with hot fire time
% from masterdoc)
% - 

%Design Derived values:
chamber_pressure = 3447000;      % Pa (internal pressure in psi: 500)
MinFS = 2;                    % minimum factor of safety required across all structural elements
fuel_mass=1.44; %kg


%Variations to optimize on (USER INPUT):

ODs=[1,2,3,4,5];  %List of ODs we want to look at (placeholders)
wall_thick={[1,2,3],[1,2,3],[1,2,3],[1,2,3],[1,2,3]}; %List of wall thicknesses (order must match the order of ODs, placeholders)

ODs_m=ODs*0.0254;
wall_thick_m = cellfun(@(x) x(:)*0.0254, wall_thick, 'UniformOutput', false);

iter_dict = dictionary(ODs_m,wall_thick_m); %Pair the ODs with their thicknesses

keys_iter=keys(iter_dict); %we isolate just the keys so we can reference them later without knowing what they are

n_bolts_list=[8,10,12];

bolt_diam_in = [1/8, 3/16, 5/16];    % common small bolt sizes
bolt_diam_m = bolt_diam_in(:) * 0.0254; %convert them to meters
%Place holder bolt strengths
bolt_sigma_y=[1,2,3];                 % tensile yield strength Pa of bolts MUST BE PAIRED with bolt_diam_in.  Source strength from vendor
bolt_tau=[1,2,3];                     % shear yield strength Pa of bolts MUST BE PAIRED with bolt_diam_in.

bolt_strengths = num2cell([bolt_sigma_y(:), bolt_tau(:)],2); %pair bolt strengths, tensile first
bolt_dict = dictionary(bolt_diam_m,bolt_strengths); %pair the relevant diameters to their strengths
keys_bolt=keys(bolt_dict);  %we isolate just the keys so we can reference them later without knowing what they are



%Results storage
res = struct('OD',[],'t',[],'ID',[],'Dmean',[],'L',[],'bolt_d',[],'dis',[],'pre_CC_l',[],'post_CC_L',[],'n',[],'mass_shell',[],'sigma_hoop',[],'FS_hoop',[],'FS_bearing',[],'FS_tear',[],'FS_shear',[]);
idx=0;

for iter = 1:numel(iter_dict)
    
    OD_i = keys_iter(iter);             %OD is defined from dict
    thicknesses_i=iter_dict(OD_i);      %Pull out all thicknesses for the current OD

    if iscell(thicknesses_i)                %If the thickness is a cell convert it to a vector
        thicknesses_i = thicknesses_i{1};
    end
    for iter_thick = 1:numel(thicknesses_i)     %Loop through each thickness for the current OD
        thick_i = thicknesses_i(iter_thick);  
        ID_i = OD_i- 2*thick_i;         %ID is defined from OD and thickness

        if ID_i <= 0 %ensure the inner diameter isn't equal to or less than zero
            continue; %invalid geometry
        end

        % Compute fuel volume and required tank length (just for the fuel,
        % so ignoring pre and post combustion chamber sections, as well as
        % any overlap with bulkheads
        V_fuel = fuel_mass / rho_abs;           % m^3
        L_i = V_fuel / (pi * (ID_i/2)^2);        % m

        %Ensure the tank length is between 0 and 1 m
        if L_i <= 0 || L_i > 1.0
            continue;  
        end

        % Mean diameter for thin-wall hoop stress
        D_mean = (OD_i + ID_i) / 2;
    
        % Calculate thin-wall hoop stress with current design
        sigma_hoop = chamber_pressure * D_mean / (2 * thick_i);

        %Calculate the FS for hoop stress
        FS_hoop = sigma_y_Al / sigma_hoop;

        % Reject current design if hoop FS below minimum
        if FS_hoop < MinFS
            continue;
        end

        % Compute mass of the Aluminum casing
        vol_shell = pi * (OD_i^2 - ID_i^2) / 4 * L_i;
        mass_shell = vol_shell * rho_al;

        % Internal pressure axial force on endcaps
        endcap_area = pi * (ID_i/2)^2;
        F_total = chamber_pressure * endcap_area;  % N

        % Loop through each bolt type in bolt_dict
        for iter_bolt = 1:numel(bolt_dict)
           bolt_diam = keys_bolt(iter_bolt);
           %Bolt strength definition:
           bolt_strength=bolt_dict(bolt_diam);
           sigma_bolt = bolt_strength(1);
           tau_bolt=bolt_strength(2);

           % Calculate bolt shear area from given diameter
           A_bolt = pi * (bolt_diam/2)^2;  

            % Loop through the varying number of bolts in n_list
            for cur_bolt_num = 1:length(n_bolts_list)
                num_bolts = n_bolts_list(cur_bolt_num);

                % Divides the force needed to keep the end cap on by the number
                % of bolts retaining the force
                F_per_bolt = F_total / num_bolts;

                % Bearing stress
                sigma_bearing = F_per_bolt / (bolt_diam * thick_i);
                FS_bearing = sigma_y_Al / sigma_bearing;


                %Distance from Edge of Bolt Hole to Edge of Tank (calculation method
                %prioritizes safety and manufacturabilit
                dis = ceil((2 * bolt_diam) / 0.005) * 0.005;


                % Tear Out stress
                al_tau_tear = F_per_bolt / (2 * dis * thick_i);
                FS_tear = tau_Al / al_tau_tear;


                % Bolt shear stress
                tau_bolt_act = F_per_bolt / A_bolt;
                FS_shear = tau_bolt / tau_bolt_act;

                % Store results if all FS are acceptable
                if FS_bearing >= MinFS && FS_tear >= MinFS && FS_shear >= MinFS
                    idx = idx + 1;
                    res(idx).OD = OD_i;
                    res(idx).t = thick_i;
                    res(idx).ID = ID_i;
                    res(idx).Dmean = D_mean;
                    res(idx).L = L_i;
                    res(idx).bolt_d = bolt_diam;
                    res(idx).dis=dis;
                    res(idx).n = num_bolts;
                    res(idx).pre_CC_l=(ID_i/2);
                    res(idx).post_CC_L=(ID_i);
                    res(idx).mass_shell = mass_shell;
                    res(idx).sigma_hoop = sigma_hoop;
                    res(idx).FS_hoop = FS_hoop;
                    res(idx).FS_bearing = FS_bearing;
                    res(idx).FS_tear = FS_tear;
                    res(idx).FS_shear = FS_shear;
                end 
            end %cur_bolt_num
        end %iter_bolt
    end %iter_thick
end %iter
%% ---------- Report ----------
if idx == 0
    fprintf('No feasible tube designs found. Try larger wall thicknesses, larger OD, higher n, or adjust dis.\n');
    return;
end

T = struct2table(res);
T_sorted = sortrows(T,'mass_shell');

n_print = min(10,height(T_sorted));
fprintf('Top %d feasible tube designs (sorted by shell mass):\n', n_print);
fprintf(['OD(mm)  t(mm)  ID(mm)  Dmean(mm)  FuelL(mm)  ' ...
         'bolt_d(in)  dis(mm)  n  pre_CC_l(mm)  post_CC_L(mm)  ' ...
         'mass_shell(kg)  FS_hoop  FS_bear  FS_tear  FS_shear\n']);

for k = 1:n_print
    row = T_sorted(k,:);

    fprintf(['%6.1f  %5.2f  %6.2f  %8.2f  %8.1f  ' ...
             '%10.3f  %7.2f  %2d  %11.2f  %12.2f  ' ...
             '%14.4f  %8.2f  %7.2f  %7.2f  %8.2f\n'], ...
        row.OD*1000, ...
        row.t*1000, ...
        row.ID*1000, ...
        row.Dmean*1000, ...
        row.L*1000, ...
        row.bolt_d/0.0254, ...
        row.dis*1000, ...
        row.n, ...
        row.pre_CC_l*1000, ...
        row.post_CC_L*1000, ...
        row.mass_shell, ...
        row.FS_hoop, ...
        row.FS_bearing, ...
        row.FS_tear, ...
        row.FS_shear);
end
tank_options = T_sorted;  % full table returned to workspace

% Quick plot
figure;

scatter(T_sorted.Dmean*1000, T_sorted.mass_shell, 40, 'filled');
xlabel('Mean Diameter (mm)'); ylabel('Shell mass (kg)');
title('Feasible tube designs: shell mass vs mean diameter');
grid on;
    





