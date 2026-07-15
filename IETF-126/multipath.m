%% 1. Setup Scenario
startTime = datetime(2026,4,23,14,0,0);
stopTime = startTime + minutes(20); % 20-minute window
sampleTime = 30; % Update path every 30 seconds
sc = satelliteScenario(startTime, stopTime, sampleTime);

% Load Constellation and Nodes
sat = satellite(sc, "largeConstellation.tle"); 
numSats = numel(sat);
gsSource = groundStation(sc, 51.5, -0.1, "Name", "London"); 
%gsTarget = groundStation(sc, -33.8, 151.2, "Name", "Sydney");
gsTarget = groundStation(sc, -33.9, 18.4, "Name", "Cape Town");

%% 2. Active Routing Loop
c = 299792458; 
maxRange = 5000e3;
timeSteps = sc.StartTime : seconds(sampleTime) : sc.StopTime;
numSteps = numel(timeSteps);

fprintf('Calculating Active Routing for %d time steps...\n', numSteps);

% Get all satellite positions: Result is [3 x numSteps x numSats]
[pS_all, ~] = states(sat, "CoordinateFrame", "ecef");

allPaths = cell(numSteps, 1);

for tIdx = 1:numSteps
    currentTime = timeSteps(tIdx);
    % We take all coordinates (1:3), the specific time (tIdx), and all satellites (:)
    pS = reshape(pS_all(:, tIdx, :), 3, numSats); 
    
    numNodes = numSats + 2;
    sourceNode = numSats + 1;
    targetNode = numSats + 2;
    adj = sparse(numNodes, numNodes);
    
    % Satellite-to-Satellite ISL
    for i = 1:numSats
        % Distance from satellite i to all other satellites
        dists = sqrt(sum((pS - pS(:,i)).^2, 1));
        
        % Find neighbors within ISL range
        neighbors = find(dists > 0 & dists < maxRange);
        for j = neighbors
            adj(i, j) = dists(j) / c; 
        end
    end
    
    % Ground Station Access
    [~, el1, r1] = aer(gsSource, sat, currentTime);
    [~, el2, r2] = aer(gsTarget, sat, currentTime);
    
    % Connect Source
    for i = find(el1 >= 10)
        adj(sourceNode, i) = r1(i)/c; adj(i, sourceNode) = r1(i)/c;
    end
    % Connect Target
    for i = find(el2 >= 10)
        adj(targetNode, i) = r2(i)/c; adj(i, targetNode) = r2(i)/c;
    end
    
    % Solve Dijkstra
    G = graph(adj);
    [pathIdx, ~] = shortestpath(G, sourceNode, targetNode);
    
    if ~isempty(pathIdx)
        stepObjects = cell(1, numel(pathIdx));
        for k = 1:numel(pathIdx)
            id = pathIdx(k);
            if id <= numSats, stepObjects{k} = sat(id);
            elseif id == sourceNode, stepObjects{k} = gsSource;
            else, stepObjects{k} = gsTarget; end
        end
        allPaths{tIdx} = stepObjects;
    end
end

%% 3. Signal Visualization
% Open the viewer
v = satelliteScenarioViewer(sc);

% CRITICAL: Give MATLAB a moment to render the window before sending commands
pause(2); 

fprintf('Finalizing %d access paths...\n', numSteps);

for tIdx = 1:numSteps
    if ~isempty(allPaths{tIdx})
        % Create the multi-hop link for this step
        ac = access(allPaths{tIdx}{:});
        ac.LineColor = "yellow";
        ac.LineWidth = 2;
        
        % Manage time-window visibility
        tBegin = timeSteps(tIdx);
        if tIdx < numSteps
            tEnd = timeSteps(tIdx+1);
        else
            tEnd = tBegin + seconds(sampleTime);
        end
        
        try
            ac.StartTime = tBegin;
            ac.EndTime = tEnd;
        catch
            % If your version doesn't support StartTime, it will show the mesh
        end
    end
end

% Robust Camera Positioning
try
    % Method 1: The standard focus command
    view(v, gsSource);
catch
    try
        % Method 2: Focusing on the first satellite in the first path
        firstSat = allPaths{1}{2}; 
        view(v, firstSat);
    catch
        % Method 3: Fallback - just open the viewer and don't force a move
        disp('Note: Automatic camera focus failed; please manual zoom to Earth.');
    end
end

fprintf('Calculation complete. Starting Active Routing animation...\n');
play(sc);