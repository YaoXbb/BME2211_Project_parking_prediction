function cluster_parking_availability(k)
% Cluster parking lots by %-availability in three time windows
if nargin<1, k = 2; end
file = 'BME2211 Parking Lot data_reformated.xlsx';

%% 1. read sheet -------------------------------------------------
opts = detectImportOptions(file,'VariableNamingRule','preserve');
Traw = readtable(file,opts);
Traw.Properties.VariableNames(1:2) = {'Lot','Restriction'};

headers = opts.VariableNames;

% ---------- PATCH: locate TotalSpaces column -------------------
capIdx = find( ...
    contains(lower(headers),{'total','capacity','spaces'}), 1);

if isempty(capIdx)
    fprintf('\nAvailable columns:\n')
    for i = 1:numel(headers)
        fprintf('  %2d) %s\n',i,headers{i});
    end
    capIdx = input(['\n❓  Which column is TOTAL NORMAL SPACES? ' ...
                    '(enter number): ']);
end
TotalSpaces = double(str2double(string(Traw{:,capIdx})));
% ----------------------------------------------------------------

vacCols = setdiff(3:numel(headers), capIdx);          % all survey columns
Long = table(string.empty,string.empty,string.empty,double.empty,double.empty,...
             'VariableNames',{'Lot','TimeOfDay','VacantSpots','TotalSpaces','PctOpen'});

for c = vacCols
    hdr = lower(headers{c});
    if contains(hdr,{'handicap','accessible','ada'}), continue, end

    vals = double(str2double(string(Traw{:,c})));

    if contains(hdr,'morning'),   tod = "morning";
    elseif contains(hdr,{'midday','noon'}), tod = "midday";
    elseif contains(hdr,{'night','evening'}), tod = "night";
    else, continue
    end

    Long = [Long; table( ...
        string(Traw.Lot), ...
        repmat(tod,height(Traw),1), ...
        vals, ...
        TotalSpaces, ...
        vals./TotalSpaces*100, ...
        'VariableNames',Long.Properties.VariableNames)];
end
%% 2. feature matrix: % open for morning/midday/night -----------
times = ["morning","midday","night"];
lots  = unique(Long.Lot,'stable');
X = NaN(numel(lots),3);            % rows=lots, cols=times

for i = 1:numel(lots)
    for j = 1:3
        idx = Long.Lot==lots(i) & Long.TimeOfDay==times(j);
        X(i,j) = mean(Long.PctOpen(idx),'omitnan');
    end
end

%% 3. k-means clustering ---------------------------------------
[grp, C] = kmeans(X, k, 'Replicates',10);

%% 4. 3-D scatter plot -----------------------------------------
figure
scatter3(X(:,1), X(:,2), X(:,3), 120, grp, 'filled')
hold on
text(X(:,1), X(:,2), X(:,3), "  "+lots,'FontSize',9,'VerticalAlignment','middle')
plot3(C(:,1),C(:,2),C(:,3),'kx','MarkerSize',14,'LineWidth',2)   % centroids
grid on, box on
xlabel('% open (morning)'), ylabel('% open (midday)'), zlabel('% open (night)')
title(sprintf('k-means clustering of %% normal spaces open  (k = %d)',k))
view(45,25)
end