function fh = figPos(fh, x, y)
    % FIGPOS  Change figure size by some factor
    % INPUTS:     fh    figure handle
    %             x     factor to multiply width by
    %             y     factor to multiply height by
    % To keep x or y constant, input [] or 1
    %
    % SSP 20170302
    % 20170321 - fixed screen position issue
    % 14Oct2017 - removed pixel option, wasn't using it, added misc checks

    if nargin < 3
        y = [];
    end
    
    pos = get(fh, 'Position');
    screenSize = get(0,'ScreenSize');
    
    if ~isempty(x) || x == 1
        pos(3) = pos(3) * x;
        if pos(3) > screenSize(3)
            % Keep figure size under screen size
            pos(3) = screenSize(3);
            pos(1) = screenSize(1);
            % Make sure figure isn't running off screen
        elseif pos(1) + pos(3) >= screenSize(3) - 50
            pos(1) = 50;
        end
    end
    
    if ~isempty(y) || y == 1
        pos(4) = pos(4) * y;
        if pos(4) > screenSize(4)
            pos(4) = screenSize(4);
            pos(2) = screenSize(2);
        elseif pos(2) + pos(4) > screenSize(4) - 50
            pos(2) = 50;
        end
    end

    set(fh, 'Position', pos);