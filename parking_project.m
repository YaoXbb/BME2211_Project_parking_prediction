function parking_project


xlsFile = 'BME2211 Parking Lot data_reformated.xlsx';

% ---------- 1. Read the sheet (keep headers as-is) -------------
opts = detectImportOptions(xlsFile, 'VariableNamingRule','preserve');
Traw = readtable(xlsFile, opts);

% Rename the first two columns so the rest of the code is stable
Traw.Properties.VariableNames(1:2) = {'Lot','Restriction'};

% ---------- 2. Wide → long : one row per observation ----------
vacColNames = Traw.Properties.VariableNames(3:end);
Long = table(string.empty, string.empty, string.empty, double.empty, ...
             'VariableNames', {'Lot','Restriction','TimeOfDay','VacantSpots'});

for c = 1:numel(vacColNames)
    colName = vacColNames{c};                % e.g.  "Thursday morning "
    vals    = Traw{:, colName};

% -------- ADD THIS LINE ----------
vals = double(str2double(string(vals)));   % text → number, blanks → NaN
% ----------------------------------
    lowerHdr = lower(colName);
    % -- NEW: skip handicap / accessible / ADA columns -------------
    if contains(lowerHdr,{'handicap','accessible','ada'})
        continue          % don’t include these in the model
    end

% (rest of the loop continues unchanged)


    % classify into morning / midday / night based on header text
    lowerHdr = lower(colName);
    if contains(lowerHdr,'morning')
        tod = "morning";
    elseif contains(lowerHdr,'midday') || contains(lowerHdr,'noon')
        tod = "midday";
    elseif contains(lowerHdr,'night')  || contains(lowerHdr,'evening')
        tod = "night";
    else
        continue   % skip weird columns
    end

    % append rows
    newRows = table( string(Traw.Lot), ...
                     string(lower(Traw.Restriction)), ...
                     repmat(tod,height(Traw),1), ...
                     vals, ...
                     'VariableNames',Long.Properties.VariableNames);
    Long = [Long; newRows];
end

% ---------- 3. Probability model (VacantSpots > 0) ------------
Long.Available = Long.VacantSpots > 0;

probTbl = groupsummary(Long,{'Lot','TimeOfDay'},'mean','Available');
lots  = unique(probTbl.Lot);
times = ["morning","midday","night"];        % fixed order

P = NaN(numel(lots),numel(times));
for i = 1:height(probTbl)
    li = find(lots == probTbl.Lot(i));
    ti = find(times == probTbl.TimeOfDay(i));
    P(li,ti) = probTbl.mean_Available(i);
end

% ---------- 4. Quick descriptive summary ----------------------
disp('Vacant-spot mean per Lot × TimeOfDay (across 3 days):');
sumTbl = groupsummary(Long,{'Lot','TimeOfDay'},'mean','VacantSpots');
disp(sumTbl);

% ---------- 5. Build role → allowed-lots map ------------------
roleLots.student = unique(Long.Lot(contains(Long.Restriction,'student')));
roleLots.faculty = unique(Long.Lot(contains(Long.Restriction,'faculty')));
roleLots.public  = unique(Long.Lot(contains(Long.Restriction,'public')));

% ---------- 6. Interactive assistant --------------------------
disp('-------------------------------------------------------------')
disp('WPI Parking-Lot Availability Assistant  (Ctrl-C to quit)')
while true
    role = lower(strtrim(input('Are you a student, faculty, or public visitor?  ','s')));
    if isfield(roleLots,role), break; end
end
while true
    tod  = lower(strtrim(input('Arrival time (morning | midday | night):  ','s')));
    if ismember(tod, times), break; end
end
ti = find(times == tod);

% BEFORE the for-loop
allowed = string(roleLots.(role));  

fprintf('\nProbability (≥ 1 open spot) for %s arrival:\n',tod)
bestProb = -inf;  bestLot = "";

% ---- probability loop ----------------------------------------
for lot = allowed(:)'                % iterate over string scalars
    li   = find(lots == lot);        % <-- lots and lot are *both* strings
    prob = P(li,ti);  if isnan(prob), prob = 0; end
    fprintf('  %-12s  %5.1f %%\n',lot,prob*100)

    if prob > bestProb
        bestProb = prob;  bestLot = lot;
    end
end


if bestProb <= 0
    fprintf('\n⚠️  Your allowed lots never had an open space in our 3-day sample.\n')
else
    fprintf('\n👉  Recommended lot:  **%s**  (%.1f %% chance of a space)\n', ...
            bestLot, bestProb*100)
end
end
