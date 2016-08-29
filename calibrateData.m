%% Calibration function for magic8080

function [calibratedData,clabel,ctime] = calibrateData(data,label,time)

    %% Repair broken frames using interpolation (using predefined threshold)
    disp('Repair broken frames ');
    data = repairFrames(data);
    
    N = sqrt(size(data,2));                  %data每行6400列，所以N是80
    
    %% Remove DC
    % DC value is mean of empty frames
    % a frame is detected empty when std of frame is low (under threshold).
    disp('Remove DC ');
    thres = 1.6E5;
    s = std(data,[],2);                       %算每行的标准差
    frameDC = mean(data(s < thres,:));
    data = data - repmat(frameDC,size(data,1),1);      %这个函数叫堆叠矩阵，把这个矩阵看成一个元素，然后把它拼成m*n的大矩阵，这个的最终结果是每行也就是每帧减去这个DC
    
    %% Row voltage correction 
    % calculate correction term using min in row
    % median filter before correction calculation for robustness
    disp('Row voltage correction');
    for i = 1:size(data,1)
       frame = reshape(data(i,:),N,N);
       frameF = medfilt2(frame,[3 3]);                 %用于消澡的中值滤波器，这个滤波器返回的是滤波后的图像
       rowMin = min(frameF,[],2);                      %滤波后该帧图像每一行的最小值
       
       correctionFrame = repmat(rowMin,1,N);           %rowMin是N*1的矩阵，通过repmat，变成每行都是相同的值，
       newFrame = frame - correctionFrame;             %过程能明白，但是这样做的道理是什么。。。。。。。。
       
       data(i,:) = reshape(newFrame,1,N*N);            %再把每帧图像变成一维
    end
    
    calibratedData = data;
    
    clabel = label;
    clabel(clabel == 11) = 0;   %% Remove label 11
    ctime = time;

end

function data = repairFrames(data)

    thres = 10E6;
    % detect position of broken frames
    brokenFrames = min(data,[],2) < thres;           %返回每一行的最小值，这里指的是每一帧的最小值   ，如果这一行的最小值小于thres，则返回1，大于返回0
	%brokenFrames 类似为[1;0;0;1;1......]
    %C = max(A,[],dim)
    %返回A中有dim指定的维数范围中的最大值。 1是寻找每列，2是寻找每行

    brokenStartPos = find(diff(brokenFrames) > 0);
    brokenEndPos = find(diff(brokenFrames) < 0);
    %关于这个问题网上很多都是结合find函数使用来寻找的，其实直接使用min或者max函数即可。就是使用min或者max返回的第二个参数。比如寻找矩阵A中每一行的最小值，以及最小值的位置。

    %[mnA, ind] = min(A, [], 2);即可，其中ind为最小值在每一行的序号
	%等运行的时候做一下测试
    lenData = size(data,1);
    
    
    if(length(brokenStartPos) < length(brokenEndPos))
        % case first frame is broken, set values to 0
        data(1:brokenEndPos(1),:) = 0; 
        brokenEndPos = brokenEndPos(2:end);
    elseif(length(brokenStartPos) > length(brokenEndPos))
        %case last frame is broken, set values to 0
       data(brokenStartPos(end):lenData,:) = 0;
       brokenStartPos = brokenStartPos(1:end-1);
    end
    
    % interpolate broken frames
    for i = 1:length(brokenStartPos)                  %brokenStartPos和brokenEndPos 都是一个n*1的矩阵，他们成对出现，他们的每一行分别代表着broken frames的起始帧的index到结束帧的index
        from = brokenStartPos(i);
        to = brokenEndPos(i)+1;
        
        v = data(from:to,:);
        step = 1/(size(v,1)-1);
        xq = 1:step:2;
        vq = interp1(1:2,[v(1,:); v(end,:)],xq);      %线性内插http://blog.csdn.net/fengfuhui/article/details/7708828
        
        data(from:to,:) = vq;
    end
end

%     figure('color','w'); 
%     subplot(121);
%     imagesc(frame,[-5E5 20E5]);
%     subplot(122);
%     imagesc(frame - correctionFrame,[-5E5 20E5]);
%     
