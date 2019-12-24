classdef IOptronMount <handle
    
    properties % Position
        Az
        Alt
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
            fprintf(I.Port,':%s#',cmd);
            pause(0.05);
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
    
    methods(Access=private)
        
        % verbose reporting
        function report(I,msg)
            if I.verbose
                fprintf(msg)
            end
        end
        
    end
end