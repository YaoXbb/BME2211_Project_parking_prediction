function compare_parking_models
file = 'BME2211 Parking Lot data_reformated.xlsx';

%% 1. Build Long table (same rules as earlier) ------------------
opts = detectImportOptions(file,'VariableNamingRule','preserve');
Traw = readtable(file,opts);
Traw.Properties.VariableNames(1:2) = {'Lot','Restriction'};

vacCols = Traw.Properties.VariableNames(3:end);
Long = table(string.empty,string.empty,string.empty,double.empty,...
             'VariableNames',{'Lot','Restriction','TimeOfDay','VacantSpots'});

for c = vacCols
    hdr = lower(c{1});
    if contains(hdr,{'handicap','accessible','ada'}),  continue, end

    vals = double(str2double(string(Traw{:,c})));
    if contains(hdr,'morning'), tod="morning";
    elseif contains(hdr,{'midday','noon'}), tod="midday";
    elseif contains(hdr,{'night','evening'}), tod="night";
    else, continue
    end

    Long = [Long; table( string(Traw.Lot), string(lower(Traw.Restriction)), ...
                         repmat(tod,height(Traw),1), vals, ...
                         'VariableNames',Long.Properties.VariableNames)];
end

Long.Available = Long.VacantSpots > 0;

%% 2. ---------- BASELINE LOOK-UP MODEL -------------------------
times = ["morning","midday","night"];
lots  = unique(Long.Lot);
P = NaN(numel(lots),numel(times));
for i = 1:numel(lots)
    for j = 1:numel(times)
        idx = Long.Lot==lots(i) & Long.TimeOfDay==times(j);
        P(i,j) = mean(Long.Available(idx));
    end
end

% predictions for every row
prob_base = NaN(height(Long),1);
for k = 1:height(Long)
    li = find(lots==Long.Lot(k));
    ti = find(times==Long.TimeOfDay(k));
    prob_base(k) = P(li,ti);
end
pred_base = prob_base >= .5;

%% 3. ---------- LOGISTIC REGRESSION MODEL ----------------------
Long.Lot        = categorical(Long.Lot);
Long.TimeOfDay  = categorical(Long.TimeOfDay);

mdl = fitglm(Long,'Available~Lot*TimeOfDay','Distribution','binomial');
prob_log  = predict(mdl,Long);
pred_log  = prob_log >= .5;

%% 4. ---------- METRICS ----------------------------------------
acc  = @(yhat) mean(yhat == Long.Available);
ll   = @(p) -mean(Long.Available.*log(max(eps,p)) + ...
                (1-Long.Available).*log(max(eps,1-p))); % log-loss

results = table({'Baseline';'Logistic'}, ...
                [acc(pred_base); acc(pred_log)], ...
                [ll(prob_base);  ll(prob_log)], ...
                'VariableNames',{'Model','Accuracy','LogLoss'});
disp(results)

fprintf('\nConfusion matrix (baseline):\n')
disp(confusionmat(Long.Available,pred_base))

fprintf('\nConfusion matrix (logistic):\n')
disp(confusionmat(Long.Available,pred_log))

end
