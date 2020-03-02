classdef XciteXLED1 < handle
    properties
        handleSerial
        numRetry      = 5;
        baudRate      = 19200;
        terminator    = 'CR';
    end
    methods
        function obj = XciteXLED1(comPort)
            obj.handleSerial = serial(comPort,...
                                      'BaudRate', obj.baudRate,...
                                      'Terminator', obj.terminator);
            fopen(obj.handleSerial);
        end
        function delete(obj)
            fclose(obj.handleSerial);
        end
        function resp = sendCommand(obj, cmd)
            fprintf(obj.handleSerial,cmd);
            disp(cmd);
            resp = fgetl(obj.handleSerial);
            disp(resp);
            retry = 0;
            while(strcmp(resp,'e') && retry < obj.numRetry)
                fprintf(obj.handleSerial,cmd);
                disp(cmd);
                resp = fgetl(obj.handleSerial);
                disp(resp);
                retry = retry + 1;
            end
        end
        function connect(obj)
            resp = obj.sendCommand('co');
            if strcmp(resp,'e')
                error('XciteXLED1:connect:ComError','XCiteXLED1 communication error');
            end
        end
        function disconnect(obj)
            resp = obj.sendCommand('dc');
            if strcmp(resp,'e')
                error('XciteXLED1:disconnect:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getLedHours(obj)
            resp = obj.sendCommand('lh?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLedHours:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function resp = getSoftwareVersion(obj)
            resp = obj.sendCommand('sv?');
            if strcmp(resp,'e')
                error('XciteXLED1:getSoftwareVersion:ComError','XCiteXLED1 communication error');
            end
        end
        function resp = getUnitStatus(obj)
            resp = obj.sendCommand('us?');
            if strcmp(resp,'e')
                error('XciteXLED1:getUnitStatus:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                l1s = str2num(r{1});
                l2s = str2num(r{2});
                l3s = str2num(r{3});
                l4s = str2num(r{4});
                ss = str2num(r{5});
            end
        end
        function [w,x,y,z] = getLedOff(obj)
            resp = obj.sendCommand('of?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLedOff:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setLedOff(obj, varargin)
            switch nargin
                case 2
                    resp = obj.sendCommand(['of=' num2str(varargin{1})]);
                case 3
                    resp = obj.sendCommand(['of=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2})]);
                case 4
                    resp = obj.sendCommand(['of=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2}) ...
                                     ',' num2str(varargin{3})]);
                case 5
                    resp = obj.sendCommand(['of=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2}) ...
                                     ',' num2str(varargin{3}) ...
                                     ',' num2str(varargin{4})]);
                otherwise
                    error('not a valid number of arguments')
            end
            if strcmp(resp,'e')
                error('XciteXLED1:setLedOff:ComError','XCiteXLED1 communication error');
            end
        end
        function allLedOff(obj)
            resp = obj.sendCommand('of=a');
            if strcmp(resp,'e')
                error('XciteXLED1:allLedOff:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getLedOn(obj)
            resp = obj.sendCommand('on?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLedOn:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setLedOn(obj, varargin)
            switch nargin
                case 2
                    resp = obj.sendCommand(['on=' num2str(varargin{1})]);
                case 3
                    resp = obj.sendCommand(['on=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2})]);
                case 4
                    resp = obj.sendCommand(['on=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2}) ...
                                     ',' num2str(varargin{3})]);
                case 5
                    resp = obj.sendCommand(['on=' num2str(varargin{1}) ...
                                     ',' num2str(varargin{2}) ...
                                     ',' num2str(varargin{3}) ...
                                     ',' num2str(varargin{4})]);
                otherwise
                    error('not a valid number of arguments')
            end
            if strcmp(resp,'e')
                error('XciteXLED1:setLedOn:ComError','XCiteXLED1 communication error');
            end
        end
        function allLedOn(obj)
            resp = obj.sendCommand('on=a');
            if strcmp(resp,'e')
                error('XciteXLED1:allLedOn:ComError','XCiteXLED1 communication error');
            end
        end
        function clearAlarm(obj)
            resp = obj.sendCommand('ca');
            if strcmp(resp,'e')
                error('XciteXLED1:clearAlarm:ComError','XCiteXLED1 communication error');
            end
        end
        function x = getLockFrontPanel(obj)
            resp = obj.sendCommand('lo?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLockFrontPanel:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function lockFrontPanel(obj)
            resp = obj.sendCommand('lo');
            if strcmp(resp,'e')
                error('XciteXLED1:lockFrontPanel:ComError','XCiteXLED1 communication error');
            end
        end
        function unlockFrontPanel(obj)
            resp = obj.sendCommand('ul');
            if strcmp(resp,'e')
                error('XciteXLED1:unlockFrontPanel:ComError','XCiteXLED1 communication error');
            end
        end
        function resp = getSerialNumber(obj)
            resp = obj.sendCommand('sn?');
            if strcmp(resp,'e')
                error('XciteXLED1:getSerialNumber:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getIntensity(obj)
            resp = obj.sendCommand('ip?');
            if strcmp(resp,'e')
                error('XciteXLED1:getIntensity:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setIntensity(obj, w, x, y, z)
            resp = obj.sendCommand(['ip=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setIntensity:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getISGdelayTime(obj)
            resp = obj.sendCommand('dt?');
            if strcmp(resp,'e')
                error('XciteXLED1:getISGdelayTime:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setISGdelayTime(obj, w, x, y, z)
            resp = obj.sendCommand(['dt=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setISGdelayTime:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getISGonTime(obj)
            resp = obj.sendCommand('ot?');
            if strcmp(resp,'e')
                error('XciteXLED1:getISGonTime:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setISGonTime(obj, w, x, y, z)
            resp = obj.sendCommand(['ot=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setISGonTime:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getISGoffTime(obj)
            resp = obj.sendCommand('ft?');
            if strcmp(resp,'e')
                error('XciteXLED1:getISGoffTime:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setISGoffTime(obj, w, x, y, z)
            resp = obj.sendCommand(['ft=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setISGoffTime:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getISGtriggerTime(obj)
            resp = obj.sendCommand('tt?');
            if strcmp(resp,'e')
                error('XciteXLED1:getISGtriggerTime:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setISGtriggerTime(obj, w, x, y, z)
            resp = obj.sendCommand(['tt=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setISGtriggerTime:ComError','XCiteXLED1 communication error');
            end
        end
        function x = getPWM(obj)
            resp = obj.sendCommand('is?');
            if strcmp(resp,'e')
                error('XciteXLED1:getPWM:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function setPWM(obj, x)
            resp = obj.sendCommand(['is=' num2str(x)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setPWM:ComError','XCiteXLED1 communication error');
            end
        end
        function x = getRepeatLoop(obj)
            resp = obj.sendCommand('sc?');
            if strcmp(resp,'e')
                error('XciteXLED1:getRepeatLoop:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function setRepeatLoop(obj, x)
            resp = obj.sendCommand(['sc=' num2str(x)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setRepeatLoop:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getPWMunits(obj)
            resp = obj.sendCommand('su?');
            if strcmp(resp,'e')
                error('XciteXLED1:getPWMunits:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setPWMunits(obj, w, x, y, z)
            resp = obj.sendCommand(['su=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setPWMunits:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getPulseMode(obj)
            resp = obj.sendCommand('pm?');
            if strcmp(resp,'e')
                error('XciteXLED1:getPulseMode:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function setPulseMode(obj, w, x, y, z)
            resp = obj.sendCommand(['pm=' num2str(w) ...
                             ',' num2str(x) ...
                             ',' num2str(y) ...
                             ',' num2str(z)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setPulseMode:ComError','XCiteXLED1 communication error');
            end
        end
        function x = getLCDscreen(obj)
            resp = obj.sendCommand('ss?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLCDscreen:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function x = getLCDbrightness(obj)
            resp = obj.sendCommand('lb?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLCDbrightness:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function setLCDbrightness(obj, x)
            resp = obj.sendCommand(['lb=' num2str(x)]);
            if strcmp(resp,'e')
                error('XciteXLED1:connect:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getLEDtemp(obj)
            resp = obj.sendCommand('gt?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDtemp:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDserialNumber(obj)
            resp = obj.sendCommand('ls?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDserialNumber:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = r{1};
                x = r{2};
                y = r{3};
                z = r{4};
            end
        end
        function [w,x,y,z] = getLEDtype(obj)
            resp = obj.sendCommand('lt?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDtype:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDwaveLength(obj)
            resp = obj.sendCommand('lw?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDwaveLength:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDfwhm(obj)
            resp = obj.sendCommand('lf?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDfwhm:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDmaxTemp(obj)
            resp = obj.sendCommand('mt?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDmaxTemp:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDminTemp(obj)
            resp = obj.sendCommand('nt?');
            if strcmp(resp,'e')
                error('XciteXLED1:connect:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function x = getScreenSaverTimeout(obj)
            resp = obj.sendCommand('st?');
            if strcmp(resp,'e')
                error('XciteXLED1:getScreenSaverTimeout:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function setScreenSaverTimeout(obj, x)
            resp = obj.sendCommand(['st=' num2str(x)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setScreenSaverTimeout:ComError','XCiteXLED1 communication error');
            end
        end
        function  [w,x,y,z] = getLEDmfg(obj)
            resp = obj.sendCommand('md?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDmfg:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = r{1};
                x = r{2};
                y = r{3};
                z = r{4};
            end
        end
        function [w,x,y,z] = getLEDhysteresisTemp(obj)
            resp = obj.sendCommand('th?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDhysteresisTemp:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function [w,x,y,z] = getLEDname(obj)
            resp = obj.sendCommand('ln?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDname:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = r{1};
                x = r{2};
                y = r{3};
                z = r{4};
            end
        end
        function x = getSpeakerVol(obj)
            resp = obj.sendCommand('vo?');
            if strcmp(resp,'e')
                error('XciteXLED1:getSpeakerVol:ComError','XCiteXLED1 communication error');
            else
                x = str2num(resp);
            end
        end
        function setSpeakerVol(obj, x)
            resp = obj.sendCommand(['vo=' num2str(x)]);
            if strcmp(resp,'e')
                error('XciteXLED1:setSpeakerVol:ComError','XCiteXLED1 communication error');
            end
        end
        function [w,x,y,z] = getLEDminPulseWidth(obj)
            resp = obj.sendCommand('mw?');
            if strcmp(resp,'e')
                error('XciteXLED1:getLEDminPulseWidth:ComError','XCiteXLED1 communication error');
            else
                r = strsplit(resp,',');
                w = str2num(r{1});
                x = str2num(r{2});
                y = str2num(r{3});
                z = str2num(r{4});
            end
        end
        function testGet(obj)
            obj.connect();
            obj.getSoftwareVersion();
            obj.getLedHours();
            obj.getUnitStatus();
            obj.getLedOff();
            obj.getLedOn();
            obj.getLockFrontPanel();
            obj.getSerialNumber();
            obj.getIntensity();
            obj.getISGdelayTime();
            obj.getISGonTime();
            obj.getISGoffTime();
            obj.getISGtriggerTime();
            obj.getPWM();
            obj.getRepeatLoop();
            obj.getPWMunits();
            obj.getPulseMode();
            obj.getLCDscreen();
            obj.getLCDbrightness();
            obj.getLEDtemp();
            obj.getLEDserialNumber();
            obj.getLEDtype();
            obj.getLEDwaveLength();
            obj.getLEDfwhm();
            obj.getLEDmaxTemp();
            obj.getLEDminTemp();
            obj.getScreenSaverTimeout();
            obj.getLEDmfg();
            obj.getLEDhysteresisTemp();
            obj.getLEDname();
            obj.getSpeakerVol();
            obj.getLEDminPulseWidth();
            obj.disconnect();
        end
        function testSet(obj)
            obj.connect();
            obj.clearAlarm();
            obj.setLedOn(1, 4);
            pause(2)
            obj.setLedOff(1);
            pause(2)
            obj.setLedOff(4);
            pause(2)
            obj.allLedOn();
            pause(2)
            obj.allLedOff();
            pause(2)
            obj.setIntensity(255, 0, 0, 255);
            obj.setISGdelayTime(1, 1, 1, 1);
            obj.setISGonTime(2, 2, 2, 2);
            obj.setISGoffTime(3, 3, 3, 3);
            obj.setISGtriggerTime(4, 4, 4, 4);
            obj.setPWM(1);
            obj.setRepeatLoop(1);
            obj.setPWMunits(1, 1, 1, 1);
            obj.setPulseMode(1, 1, 1, 3);
            obj.setLCDbrightness(125);
            obj.setScreenSaverTimeout(1000);
            obj.setSpeakerVol(125);
            obj.disconnect();
        end
    end
end
