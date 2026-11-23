
function fly()

    % ==========================================
    % MODEL CONFIGURATION
    % ==========================================

    modelName = 'fixYawControl';

    blockZ     = [modelName '/z_ref'];
    blockPitch = [modelName '/pitch_ref'];
    blockRoll  = [modelName '/roll_ref'];

    % ==========================================
    % REFERENCE CONFIGURATION
    % ==========================================

    stepZ = 0.05;                  % meters per key press
    stepAngle = deg2rad(0.5);        % radians per key press

    % ==========================================
    % CHECK MODEL AND BLOCKS
    % ==========================================

    if ~bdIsLoaded(modelName)
        error('Model is not loaded: %s', modelName);
    end

    blocks = {blockZ, blockPitch, blockRoll};

    for k = 1:length(blocks)
        if getSimulinkBlockHandle(blocks{k}) == -1
            error('Cannot find block: %s', blocks{k});
        end
    end

    % Read initial references from Constant blocks
    zRef     = readReference(blockZ);
    pitchRef = readReference(blockPitch);
    rollRef  = readReference(blockRoll);

    % Enable real-time pacing
    set_param(modelName, ...
        'EnablePacing', 'on', ...
        'PacingRate', '1');

    % ==========================================
    % CREATE KEYBOARD CONTROL WINDOW
    % ==========================================

    fig = figure( ...
        'Name', 'Drone Reference Controller', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'Position', [400 350 400 280], ...
        'WindowKeyPressFcn', @onKeyPress);

    statusText = uicontrol(fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.05 0.90 0.90], ...
        'FontSize', 11, ...
        'HorizontalAlignment', 'left', ...
        'String', '');

    updateDisplay();

    % ==========================================
    % KEYBOARD CALLBACK
    % ==========================================

    function onKeyPress(~, event)

        % Check simulation status
        simStatus = get_param(modelName, 'SimulationStatus');

        if ~any(strcmp(simStatus, {'running', 'paused'}))
            set(statusText, 'String', ...
                'Start Simulink simulation first.');
            return;
        end

        % Determine reference to update
        switch event.Key

            case 'uparrow'
                targetBlock = blockZ;
                newValue = zRef + stepZ;
                refType = 'z';

            case 'downarrow'
                targetBlock = blockZ;
                newValue = zRef - stepZ;
                refType = 'z';

            case 'w'
                targetBlock = blockPitch;
                newValue = pitchRef - stepAngle;
                refType = 'pitch';

            case 's'
                targetBlock = blockPitch;
                newValue = pitchRef + stepAngle;
                refType = 'pitch';

            case 'a'
                targetBlock = blockRoll;
                newValue = rollRef - stepAngle;
                refType = 'roll';

            case 'd'
                targetBlock = blockRoll;
                newValue = rollRef + stepAngle;
                refType = 'roll';

            otherwise
                return;

        end

        % Update Constant block
        try

            set_param(targetBlock, ...
                'Value', sprintf('%.15g', newValue));

            % Update local reference variable
            switch refType

                case 'z'
                    zRef = newValue;

                case 'pitch'
                    pitchRef = newValue;

                case 'roll'
                    rollRef = newValue;

            end

            updateDisplay();

        catch ME

            set(statusText, 'String', ...
                sprintf('Update error:\n%s', ME.message));

            warning('%s', ME.message);

        end

    end

    % ==========================================
    % READ REFERENCE FROM CONSTANT BLOCK
    % ==========================================

    function value = readReference(blockPath)

        rawValue = get_param(blockPath, 'Value');
        value = str2double(rawValue);

        if ~isscalar(value) || ~isfinite(value)
            error('Constant block must contain a numeric scalar: %s', ...
                blockPath);
        end

    end

    % ==========================================
    % DISPLAY CURRENT REFERENCES
    % ==========================================

    function updateDisplay()

        statusString = sprintf([ ...
            'DRONE REFERENCE CONTROLLER\n\n' ...
            'Altitude Z : %.2f m\n' ...
            'Pitch      : %.2f deg  (%.4f rad)\n' ...
            'Roll       : %.2f deg  (%.4f rad)\n\n' ...
            'UP / DOWN  : Z       +/- %.2f m\n' ...
            'W / S      : Pitch   +/- %.1f deg\n' ...
            'A / D      : Roll    +/- %.1f deg'], ...
            zRef, ...
            rad2deg(pitchRef), pitchRef, ...
            rad2deg(rollRef), rollRef, ...
            stepZ, ...
            rad2deg(stepAngle), ...
            rad2deg(stepAngle));

        set(statusText, 'String', statusString);

    end

end
