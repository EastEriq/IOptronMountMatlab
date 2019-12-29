function [ok,I]=watch_conditions(I,lowest_height,report_fid)
% keep on watch and report if any of the following events happen:
ok=true;
try
    %  If no problem, just report routinely the position
    logreport(report_fid,'     (%g,%g)H (%g,%g)eq',I.Az,I.Alt,I.RA,I.Dec);
    %  current position below lowest_height
    %   This test is meant as a failsafe detection before a mount crash
    %   due to completely wrong targets, misinterpreded commands or mismatches
    %   between actual movement and driving pulses. However, the condition
    %   may sometimes be innocuous; and in fact, large movements on both
    %   axes may produce an instantaneous elevation below the threshold.
    if I.Alt<lowest_height
        ok=false;
        %    -> recovery: immediate abort; GoHome; report position error;
        %       FullHoming
        I.Abort;
        logreport(report_fid,'Height too low! rehoming');
        I.GoHome
        start_homing=now;
        homing_timeout=60; % 180°/(3°/sec)
        % try to bring at index position, with a timeout
        while ~strcmp(I.Status.motion,'at home') && now-start_homing<homing_timeout
            pause(1)
        end
        if now-start_homing>homing_timeout
        else
            logreport(report_fid,'  (az,alt) homing discrepancy: %g", %g"',...
                (I.Az-90)*3600,(I.Alt-90)*3600);
            I.FullHoming
            ok=true; % if homing succeeded, all is fine
        end
    end    
    %  TODO goto not reached but position not approaching target
    %    -> recovery: same as above
catch
    logreport(report_fid,'Communication ERROR!');
    %  loss of communication
    %    -> recovery: try reconnect, possibly on a new virtual port
    try
        I=IOptronMount('');
        if I.Az==0 && I.Alt==0 %legal for IOptron, not flagging power loss
            % TODO is there a case in which FullHoming is demanded, instead?
            logreport(report_fid,'  Az=0,Alt=0: rehoming')
            I.FullHoming
            ok=true;
        elseif isempty(I.Az) || isempty(I.Alt)
            logreport(report_fid,'  positions not read from device')
            ok=false;
        else
            logreport(report_fid,' communication restored on %s',I.Port.Port)
            ok=true;
        end
    catch
        logreport(report_fid,'Could not reconnect on any serial port')
        ok=false;
    end
end