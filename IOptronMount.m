classdef IOptronMount <handle
    
    properties % Position
        Az
        Alt
        Dec
        RA
    end
        
    properties(GetAccess=public, SetAccess=private)
        Status
    end

    properties(Hidden) % interrogable, but not of immediate use
        Port
        verbose=true;
    end
 
    methods % Constructor and communication commands
        
        function I=IOptronMount(port) % Constructor
            % Constructor, connect the serial port
            if ~exist('port','var')
                port='';
            end
            I.SetPort(port);
            % check if there is a focuser by querying its motion limits
            try
                model=I.Query('MountInfo');
                I.Az=[]; % temporary, remove
                if ~strcmp(model(1:3),'012')
                    error('no IOptron mount found on '+port+'\n')
                end
            catch
            end
        end
        
        function I=SetPort(I,port)
            if ~exist('port','var') || isempty(port)
                for port=seriallist
                    try
                        % look for one IOptron device on every
                        %  possible serial port. Pity we cannot
                        % look for a named (i.e. SN) unit
                        I.SetPort(port);
                        if ~(isempty(I.Az))
                            I.report('an IOptron mount was found on '+port+'\n')
                            break
                        else
                            I.report('no IOptron mount found on '+port+'\n')
                        end
                    catch
                        I.report('no IOptron mount found on '+port+'\n')
                    end
                end
            end
            try
                delete(instrfind('Port',port))
            catch
            end
            try
                I.Port=serial(port);
                % serial has been deprecated in 2019b in favour of
                %  serialport... all communication code should be
                %  transitioned...
            catch
            end
            try
                if strcmp(I.Port.status,'closed')
                    fopen(I.Port);
                end
            catch
                error(['Port ' I.Port.name ' cannot be opened'])
            end
            set(I.Port,'BaudRate',115200,'Timeout',1);
        end
        
        function resp=Query(I,cmd)
            % Dispose of previous traffic potentially having
            % filled the inbuffer, for an immediate response
            flushinput(I.Port)
            fprintf(I.Port,':%s#',cmd);
            if strcmp(cmd,'Q')
                pause(0.5); % abort requires a longer delay
            else
                pause(0.1);
            end
            resp=char(fread(I.Port,[1,I.Port.BytesAvailable],'char'));
            % possible replies are long strings terminated by #
            %  for get commands, or 0/1 for boolean gets, or setters
            if isempty(resp)
                error('Mount did not respond. Maybe wrong command?')
            end
            if ~strcmp(resp(end),'#') && ...
                   (numel(resp)==1 && ~(resp=='0' || resp=='1'))
                error('Response from mount incomplete')
            end
        end

        
        function Close(I)
            fclose(I.Port);
        end
        
        function delete(I)
            delete(I.Port)
        end
        
    end
    
    methods % getter/setters: Position and status
        
        function S=get.Status(I)
            % state enumerations - let the function error if an out-of
            %  -range value is returned
            gpsstate=["No GPS","no data","valid"];
            motionstate=["stopped","track w/o PEC","slew","auto-guiding",...
                         "meridian flipping","track with PEC","parked",...
                         "at home"];
            trackingrate=["sidereal","lunar","solar","King","custom"];
            keyspeed=["1x","2x","4x","8x","16x","32x","64x","128x",...
                      "256x","512x","max"];
            timesource=["communicated","hand controller","GPS"];
            hemisphere=["South","North"];
            resp=I.Query('GLS');
            S=struct('Lon',str2double(resp(1:9))/360000,...
                     'Lat',str2double(resp(10:17))/360000-90,...
                     'GPS',gpsstate(str2double(resp(18))+1),...
                     'motion',motionstate(str2double(resp(19))+1),...
                     'tracking',trackingrate(str2double(resp(20))+1),...
                     'keyspeed',keyspeed(str2double(resp(21))+1),...
                     'timesource',timesource(str2double(resp(22))+1),...
                     'hempisphere',hemisphere(str2double(resp(23))+1) );
        end

        function AZ=get.Az(I)
            resp=I.Query('GAC');
            AZ=str2double(resp(1:9))/360000;
        end
        
        function ALT=get.Alt(I)
            resp=I.Query('GAC');
            ALT=str2double(resp(10:17))/360000;
        end
        
        function DEC=get.Dec(I)
            resp=I.Query('GEP');
            DEC=str2double(resp(1:9))/360000;
        end
        
        function RA=get.RA(I)
            resp=I.Query('GEP');
            RA=str2double(resp(10:17))/360000;
        end
 
    end
    
    methods % Moving commands.
        
        function Abort(I)
            % emergency stop
            I.Query('Q')
        end
        
        function GoHome(I)
            I.Query('MH')
        end
        
        function FullHoming(I)
            I.Query('MSH')
            % here, poll status and exit only when done
        end
        
    end
    
    methods(Access=private)
        
        % verbose reporting
        function report(I,msg)
            if I.verbose
                fprintf(msg)
            end
        end
        
    end
end