    %% Calibration and precalculation of features and templates  
    % Author: Mathias Sundholm
    % 14.08.2014

    % DEPENDENSIES:
    %% calibrateData.m 
    %   repairs broken frames using interpolation
    %   removes dc and correct row voltage using minimum
    %% labelSegment.m
    %   calculate label start and end position and sequence from label
    %% calcHuFeatures.m  
    %   calculates 7 Hu moments for each frame in recording
    %% calcFrameFeatures.m 
    %   calculates weight, area, pressure (and center of weight X and Y)
    %   for each frame in the recording
    %% calculateTemplates.m
    %   calculates templates for each of the 10 exercises 
    
    close all;
    clear all;
  
    %% Define paths
    filePath = 'data/orkhan2/';
    fileNameRaw = 'data_labeled.mat';
    fileNamePreproc = 'data_preproc.mat';
    data_updated = false; % data is updated
    
    
    adcBitDepth = 24;
    matrixSize = 80;
    
    % define downsample
    downSampleSpacialFactor = 1; % for down sampling from 80x80
    adcBithDepthNew = 24; % bits, original 24 bit
    
    %% ============================================
    % Load data (preprocessed if exist)
    disp('== Loading data ==');
    tic
    
    if (exist([filePath fileNamePreproc],'file'))
        disp('Loading preprocessed data');
        disp([filePath fileNamePreproc]);
        load([filePath fileNamePreproc]);
        toc
    else
        disp('Loading raw data');
        disp([filePath fileNameRaw]);
        load([filePath fileNameRaw]);                                           % 获得data_preproc.mat中的data label time三个矩阵
        toc
        
        % spacial down sampling (simulating smaller matrix)
        tmp = reshape(data, size(data,1), 80,80);
        tmp = tmp(:,1:downSampleSpacialFactor:80,1:downSampleSpacialFactor:80);
        %缩小tmp，比如一个数组为10*10， 如果dSSF为2，则只留下1，3，5，7，9，5*5的tmp
        data2 = reshape(tmp,size(data,1),(80/downSampleSpacialFactor)^2);
        % adc downsampling (simulating lower adc bit)
        data2 = round(data2/2^(adcBitDepth-adcBithDepthNew));
        %data2 是缩小后的数据
        % calibrateData.m
        [calibratedData,label,time] = calibrateData(data2,label,time);
        
        [classStartPos,classEndPos, classSequence] = labelSegment(label);
        class = label;
        data_updated = true;
        
        activity = struct('class',class,...
            'startPos',classStartPos,'endPos',classEndPos,...
            'classSequence',classSequence);
            
    end
    toc

    
    %% ============================================
    % Calculate FrameFeature and Hu Moment Features
    clear frameFeatures 
    disp('== Calculate Frame Features ==');
    tic
    if(~exist('frameFeatures','var'))
        % calcHuFeatures.m
        disp('Calulating Zernike Moments')
        %huFeatures = calcHuFeatures(calibratedData);
        tic
        zernikeFeatures = calcZernikeFeatures(calibratedData);
        toc
        % calcFrameFeatures.m
        frameFeatures = calcFrameFeatures(calibratedData);
        disp('Calulating W A p')
        frameFeatures = [zernikeFeatures(:,1:7) frameFeatures(:,1:3)]; 
        data_updated = true;
    else
        disp('Using pre calculated frameFeatures');
    end
    toc
        
    
    
    %% ============================================
    % Train Templates
    %clear 'templates';
    disp('== Calculate Templates ==');
    %clear templates;
    if(~exist('templates','var'))
         tic;
   
        featureSignal = frameFeatures;

        n = size(featureSignal,2);
        numClasses = length(unique(activity.classSequence));
        templates = [];

        windowSize = 5;
        featureSignal = filter(ones(1,windowSize)/windowSize,1,featureSignal);

%        global showDebugPlots;
%        showDebugPlots = true;

        for i = 1:n
            % calculateTemplates.m
            t = calculateTemplates(featureSignal(:,i),activity.startPos, activity.endPos, activity.classSequence);
            templates = [templates; t];
        end
        data_updated = true;
        toc;
    else
        disp('Using pre calculated templates');
    end
    
    %% ============================================
    %% Split signal into intevals using label
     disp('== Calculate intervals ==');
    if(~exist('interval','var'))
        tic
        classStartPos = activity.startPos;
        classEndPos = activity.endPos;
        classSequence = activity.classSequence;
        class = activity.class;
        
        startPos = classStartPos(1);
        j = 1;
        len = length(classSequence);
        for i = 1:len-1
            currClass = classSequence(i);
            nextClass = classSequence(i+1);

            if(nextClass ~= currClass)
                intervalStartPos(j) = startPos;
                intervalEndPos(j) = classEndPos(i);
                intervalClassSequence(j) = classSequence(i);
                startPos = classStartPos(i+1);
                j = j+1;
            end
        end
        intervalStartPos(j) = startPos;
        intervalEndPos(j) = classEndPos(end);
        intervalClassSequence(j) = classSequence(end);

        intervalClass = zeros(size(class));
        for i = 1:length(intervalStartPos)
            from = intervalStartPos(i);
            to = intervalEndPos(i);
            c = intervalClassSequence(i);
            intervalClass(from:to) = c; 
        end
        data_updated = true;
        toc
        
        interval = struct('class',intervalClass,...
            'startPos',intervalStartPos,'endPos',intervalEndPos,...
            'classSequence',intervalClassSequence);
        
    else
        disp('Using pre calculated intervals');
    end
    
    %% ===========================================
    % Calculate activity features
    % std and mean of each frame feature during the activity
    disp('== Calculate Activity Features ==');
    if(~exist('activity.features','var'))
        [features] = calculateEventFeatures(activity.startPos,activity.endPos,frameFeatures,activity.classSequence);
        activity.features = features;
        data_updated = true;
    else
       disp('Using pre calculated activity features'); 
    end

    
    
    %% ============================================
    % Save to file
    


    
    
    tic
    if(data_updated)
        disp('Saving everything to file:');
        disp([filePath fileNamePreproc]);
        save([filePath fileNamePreproc],...
            'calibratedData', 'time',...
            'activity','interval',...
            'frameFeatures', 'templates'); 
        toc
    else
        disp('Data is already up to date');
    end
    
    figure; plot(frameFeatures);
     
    
    

        
        
        
  




    
    
