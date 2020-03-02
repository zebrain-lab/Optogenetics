%% add all files to matlab path 
[scriptPath,~,~] = fileparts(mfilename('fullpath'));
path = genpath(scriptPath);
addpath(path);
       
%% check that dll are in the system path

%% launch program
XCiteComPort = 'COM9';
DMDindex = 0;

OP = OptogeneticsGUI(XCiteComPort,DMDindex);