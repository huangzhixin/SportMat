%% Label data for magic8080 pressure sensor
% Combines labels in labelFileName with data in dataFileName

%% Saves combined data in format
% data      N*6400  data 
% label     N*1000
% time      N*4     time (h min sec ms)
% time_ms   N*1     time in ms
 
% by Mathias Sundholm

function labelData
    clear all;
    tic
    disp('=== Label Data ===');

    %% EDIT FILENAMES HERE
    pathName = './data/orkhan2/part1/';
    dataFileName = 'data.mat';
    labelFileName = 'labels.txt';
    exportFileName = 'data_labeledtest.mat';


    tic
    disp('Loading data and labels...');
    load([pathName dataFileName]);
    A = importdata([pathName labelFileName]);
    toc

    
    data_lin = reshape(data,6400,size(data,3)); % reshape data to 1D 应该是3维变2维，每帧数据是一维，第二维是所有的帧数，每列一帧
    data_lin = permute(data_lin,[2,1]);         %转置帧数为行，每行一帧
    
    %% RUN CODE (F9) TO FIND SYNC FRAME (MANUALLY)
    if(false)
        % 1. run this to plot the begining of the recording
        range = 1:1500; 
        figure; plot(data_lin(range,:));

        % 2. run this check if you found the correct frame
        frameNr = 542;
        figure; imagesc(data(:,:,frameNr));
    end



    disp('Calculate labels...');
    %% look into data for frame where the syncronization is done
    syncframe = A(1,7);                        %这个数字为labels.txt中第一行第7个数字，这个数字的意思是从第这个数字的那一帧开始，在压力板记录的每帧动作和label记录的时间同步了

    % crop data before sync frame
    data_lin = data_lin(syncframe:end,:);
    time_total = time_ms(syncframe:end,:);
    dataLength = size(data_lin,1);              %裁剪后的帧数

    % reset time to syncpoint
    time_total = time_total - time_total(1);

    %% shift video label timestamps to sync point
    t_sync = time2ms(A(1,1),A(1,2),A(1,3));
    t_label_start = time2ms(A(:,1),A(:,2),A(:,3)) - t_sync;
    t_label_end = time2ms(A(:,4),A(:,5),A(:,6)) - t_sync;
    label_val = A(:,7);
    
    label = zeros(dataLength,1);
    
    j = 2;
    for i = 1:length(time_total)                             %这有何意义呢，不是和label直接被labelval赋值一样么
        if(time_total(i) > t_label_start(j))
            if(time_total(i) < t_label_end(j))
                label(i) = label_val(j);
            else
                if(j < length(t_label_start))
                    j=j+1;
                end
            end
        end 
    end
    
    [t_h, t_min, t_sec] =  ms2time(time_total);
    time = [t_h t_min t_sec];
    
    % save data as 1D so it is easier to use
    data = data_lin;
    time_ms = time_total;
    
    disp('Saving data...');
    tic
    save([pathName exportFileName],'data','time','time_ms','label');
    toc
    
    figure;
    m = (mean(data,2));             %算数据每列的均值，见论文里数据处理
    plot((m-min(m))./(max(m)-min(m)),'r');
    hold on;
    plot(label);
    hold off;

end


% convert time(h min sec) to ms
function ms = time2ms(h, min ,sec)
    ms = (h * 3600 + min * 60 + sec) * 1000;
end

function [h, min, sec] = ms2time(ms)
        %% save new time info
    tt = ms;
    
    % hours
    h = floor(tt/3600000); 
    tt = tt-h*3600000;
    
    % minutes
    min = floor(tt/60000);
    tt = tt-min*60000;
    
    %seconds
    sec = tt/1000; 
end

