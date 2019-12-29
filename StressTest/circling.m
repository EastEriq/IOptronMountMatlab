function circling(I,alt)

finishup = onCleanup(@() I.Abort);

for az=0:15:360
    fprintf('%g: ',az);
    I.Alt=alt; I.Az=az;
    while ~strcmp(I.Status.motion,'stopped')
        pause(.5)
    end
    pause(2)
    fprintf('(RA=%f,dec=%f),  (Az,alt) error: %g", %g"\n',...
        I.RA,I.Dec,(mod(I.Az-az+180,360)-180)*3600, (I.Alt-alt)*3600 );
end