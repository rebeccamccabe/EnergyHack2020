function [lbs_CO2_per_MWh_interp] = load_CO2_data(time)

    filename_start = 'C:\Users\chess\Documents\GitHub\EnergyHack2020\2020Aug5to6_part';

    for i=1:4
        filename = [filename_start num2str(i) '.csv'];
        fileid = fopen(filename);
        d = textscan(fileid, '%s%*[^\n]','Delimiter',',');
        fclose(fileid);
        data.(['d' num2str(i)]) = {d{1}{2:end}};
        data.(['CO2_' num2str(i)]) = readmatrix(filename, 'Range','B2:B1000');
    end
    data.t_tot = [data.d1 data.d2 data.d3 data.d4]';
    
    hours = zeros(size(data.t_tot));
    for i=1:length(data.t_tot)
        d = data.t_tot{i};
        hrs = str2double(d(13:14));
        min = str2double(d(16:17));
        hours(i) = hrs + min/60;
    end
    
    lbs_CO2_per_MWh = [data.CO2_1; data.CO2_2; data.CO2_3; data.CO2_4];
    [hours_sorted, idx] = sort(hours);
    lbs_CO2_per_MWh_sorted = lbs_CO2_per_MWh(idx);
    
    lbs_CO2_per_MWh_filt = movmean(lbs_CO2_per_MWh_sorted, 10);
    lbs_CO2_per_MWh_filt([1 end]) = lbs_CO2_per_MWh_sorted(1,end);
    
%     figure;
%     plot(hours_sorted, lbs_CO2_per_MWh_sorted)
%     hold on
%     plot(hours_sorted, lbs_CO2_per_MWh_filt)
    
    lbs_CO2_per_MWh_interp = interp1(hours_sorted,lbs_CO2_per_MWh_filt,time,'nearest','extrap');
end