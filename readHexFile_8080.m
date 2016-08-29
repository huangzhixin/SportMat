tic
clear all;
close all;

% Define filenames and path
dir = 'data/';
dataName1 = 'data1.txt';
dataName2 = 'data2.txt';
dataName3 = 'data3.txt';

exportName = 'data.mat';

%%
disp('Loading files');
fid1 = fopen(strcat(dir,dataName1));                    %strcat 用于字符串合并
if(fid1 == -1)
    disp(strcat('fopen ', dir, dataName1, 'failed'));
    return;
end
fid2 = fopen(strcat(dir,dataName2));
if(fid1 == -1)
    disp(strcat('fopen ', dir, dataName2, 'failed'));
    return;
end
fid3 = fopen(strcat(dir,dataName3));
if(fid1 == -1)
    disp(strcat('fopen ', dir, dataName3, 'failed'));
    return;
end



%%
disp('Scanning data');                                %类似于printf
clear C1 C2 C3 R1 R2 R3;

formatCell='%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c%6c'; %32 nodes                         % 32个node 不知何意
FM = formatCell;                                      % %6c表示每6个字符做一个cell单元

%见讲硬件的论文，ADC的分辨率是24bit 也就是3B， 2的24次方就是16进制的16的6次方，
%因为结构是4路父选择器和32路子多路选择器，这里的32node因该是读一次其中一种父多路选择器

for i=1:127                                           % 128 * 32 ???
    FM=strcat(FM,formatCell);
end
C1 = textscan(fid1, strcat('%2s%2s%2s%3s', FM, '%s%s', '%*[^\n]'),'bufsize', 63140000,'delimiter',':', 'endofline','\n', 'emptyvalue',0);

%textscan 与 C 的用法 http://cn.mathworks.com/help/matlab/ref/textscan.html
%用法见http://blog.sina.com.cn/s/blog_9e67285801010buf.html
% x = textscan(fid, '%2s %2s %2s %2s %2s'); 
% %2s读两个字符串
% %s Read series of characters, until find white spac
% %c 读若干个字符包括空格
 
T = str2num(char(C1{1}))*(60*60*1000)+str2num(char(C1{2}))*(60*1000)+str2num(char(C1{3}))*(1000)+str2num(char(C1{4}));  %这个是时间！！！！！！
DT=diff(T);                   %DT是他们的时间间隔
%X = [1 1 2 3 5 8 13 21];
%Y = diff(X)
%Y =     0     1     1     2     3     5     8

R1=zeros(size(C1{1},1),4096);%prelocate size(C1{1},1)指的是C中第一列所有的行数 32*128=4096
L1=char(C1{4101});
for i=1:1:4096               %前4个是数据头，所以直接i+4
    if size(C1{i+4})<size(C1{1},1)               %一个是数组，一个是数字这样也可以比较？
        R1(1:end-1,i)=hex2dec((char(C1{i+4})));  %16进制变十进制数
    
    else
        R1(:,i) = hex2dec(char(C1{i+4}));
    end
end
disp('33%');
C2 = textscan(fid2, strcat('%2s%2s%2s%3s', FM, '%s%s', '%*[^\n]'),'bufsize', 631400,'delimiter',':', 'endofline','\n', 'emptyvalue',0);
R2=zeros(size(C2{1},1),4096);%prelocate
for i=1:1:4096
    if size(C2{i+4})<size(C2{1},1)
        R2(1:end-1,i)=hex2dec((char(C2{i+4})));
    
    else
        R2(:,i) = hex2dec(char(C2{i+4}));
    end
end
disp('66%');
C3 = textscan(fid3, strcat('%2s%2s%2s%3s', FM, '%s%s', '%*[^\n]'),'bufsize', 631400,'delimiter',':', 'endofline','\n', 'emptyvalue',0);
R3=zeros(size(C3{1},1),4096);%prelocate
for i=1:1:4096
    if size(C3{i+4})<size(C3{1},1)
        R3(1:end-1,i)=hex2dec((char(C3{i+4})));
    
    else
        R3(:,i) = hex2dec(char(C3{i+4}));
    end
end
fclose(fid1);
fclose(fid2);
fclose(fid3);
disp('99%');

%%combine three with minimum length
%%为什么要合并这三个文件？？？？
length_min=min([size(R1,1),size(R2,1),size(R3,1)]);
clear R;
R(1:length_min,:)=[R1(1:length_min,:),R2(1:length_min,:),R3(1:length_min,:)];

%size = lenth_min*(4096*3) 

time_ms = T(1:length_min);
%%
%reshape them and crop from 128x128 to 80x80
stream_cropped = zeros(size(R,1),80,80); %prelocate
for i=1:size(R,1)                               %这个是帧的总数目
    frame1 = reshape(R(i,1:4096),32,128);       %合并的目的应该在于同一个时间有3个frame
    frame2 = reshape(R(i,4097:8192),32,128);    
    frame3 = reshape(R(i,8193:12288),32,128);
    frame = [frame1; frame2; frame3];           %size= (32*3) * 128,这是为了
                                                %把同一个时间的frame凑成一幅画，但是这
                                                %里为何不是128*128呢？？
    frame_cropped = frame(1:80,1:80);           %为何只裁剪前80个数据？？？
    stream_cropped(i,:,:)=frame_cropped;
 %   surf(frame_cropped);
 %  pause(0.05);
end

%%
disp('Saving Data');
data = permute(stream_cropped, [2 3 1]);        %重新排列3维数组,原来是length-min*80*80，现在是80*80*length_min）
save(strcat(dir,exportName),'data','time_ms');
disp ('Free memory');
clear all;
toc
