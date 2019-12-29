% class I=IoptronMount already instantiated
test_duration=4*60; % in seconds
lowest_height=15; % elevation in degrees
minimal_height=5; % if the scope is pointing dangerously low, interrupt and rehome
start_time=now;
I.Abort
report_fid=1; % report on stdout;
%report_fid=fopen('random_position.log','w'); %  otherwise

% list of target pointing positions:
% random in horizontal coordinates
npos=200;
az=rand(1,npos)*360;
alt=rand(1,npos)*(90-lowest_height)+lowest_height;

dwell_time=6;

i=1;
while i<=min(numel(az),numel(alt)) && (now-start_time)*3600*24<test_duration
    try
        % avoid a priori invalid targets
        if alt(i)<minimal_height
            logreport(report_fid,'Target #%d (%g,%g)H invalid, SKIPPING',i,az(i),alt(i))
            i=i+1;
            continue
        end
        % send the scope to the chosen position in horizontal coordinates
        logreport(report_fid,'Target #%d: (%g,%g)H ', i,az(i),alt(i));
        % coarse and fine in one shot
        I.Az=az(i); I.Alt=alt(i);
        while ~strcmp(I.Status.motion,'stopped') &&...
                ~strcmp(I.Status.motion,'at home')
            [ok,I]=watch_conditions(I,minimal_height,report_fid);
            pause(1)
        end
        % pause and report positioning errors
        logreport(report_fid,'   pausing for %g seconds',dwell_time)
        pause(dwell_time)
        logreport(report_fid,...
            '(RA=%f,dec=%f), final (Az,alt) discrepancy: %g", %g"',...
             I.RA,I.Dec,(mod(I.Az-az(i)+180,360)-180)*3600, (I.Alt-alt(i))*3600 );
        if ok
            i=i+1;
        end
    catch
        % if something failed, it may be because of lost connection.
        %  watch_conditions has a reconnection attempt built in
        [ok,I]=watch_conditions(I,minimal_height,report_fid);
    end
end

logreport(report_fid,'TEST COMPLETED')

if report_fid~=1
    fclose(report_fid);
end
