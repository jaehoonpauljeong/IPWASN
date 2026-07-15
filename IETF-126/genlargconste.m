% Script to generate a 1000-satellite TLE file (Fixed)
fileName = 'largeConstellation.tle';
fileID = fopen(fileName, 'w');
numPlanes = 40;
satsPerPlane = 25;
inc = 53.0; 
alt = 550;  
mu = 398600.4418; % km^3/s^2
Re = 6378.137;
% Mean motion in revolutions per day
n = (86400) / (2 * pi * sqrt((alt + Re)^3 / mu)); 

count = 1;
for p = 1:numPlanes
    raan = (p-1) * (360/numPlanes);
    for s = 1:satsPerPlane
        meanAnomaly = (s-1) * (360/satsPerPlane);

        % 0. Satellite Name (Line 0)
        fprintf(fileID, 'SAT %04d\n', count);

        % 1. Line 1
        % Fixed widths are vital. Format: 1 [CatID]U [Designator] [Epoch] ...
        line1_partial = sprintf('1 %05dU 26001A   26113.58333333  .00000000  00000-0  00000-0 0  999', count);
        line1 = [line1_partial num2str(calculateTLEChecksum(line1_partial))];
        fprintf(fileID, '%s\n', line1);

        % 2. Line 2
        % Format requires very specific decimal placements
        line2_partial = sprintf('2 %05d %8.4f %8.4f 0001000   0.0000 %8.4f %11.8f    0', ...
            count, inc, raan, meanAnomaly, n);
        % Ensure line2_partial is exactly 68 chars before checksum
        line2_partial = sprintf('%-68s', line2_partial); 
        line2 = [line2_partial num2str(calculateTLEChecksum(line2_partial))];
        fprintf(fileID, '%s\n', line2);

        count = count + 1;
    end
end
fclose(fileID);
disp('largeConstellation.tle has been generated successfully.');

function checksum = calculateTLEChecksum(line)
% TLE Checksum: Sum digits, count '-' as 1, ignore all other chars. Modulo 10.
s = 0;
for i = 1:min(length(line), 68)
    c = line(i);
    if isstrprop(c, 'digit')
        s = s + str2double(c);
    elseif c == '-'
        s = s + 1;
    end
end
checksum = mod(s, 10);
end