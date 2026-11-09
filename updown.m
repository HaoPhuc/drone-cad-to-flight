
function updown()

    % ==========================================
    % MODEL CONFIGURATION
    % ==========================================

    modelName = 'updown';
    blockPath = [modelName '/z_ref'];

    % ==========================================
    % REFERENCE CONFIGURATION
    % ==========================================

    stepZ = 0.05;    % meters per key press

    % ==========================================
    % CHECK MODEL AND BLOCK
    % ==========================================

    if ~bdIsLoaded(modelName)
        error('Model is not loaded: %s', modelName);
    end

    if getSimulinkBlockHandle(blockPath) == -1
        error('Cannot find block: %s', blockPath);
    end

    % Read initial reference from Constant block
    zRef = str2double(get_param(blockPath, 'Value'));

    if ~isfinite(zRef)
        error('Set Constant Value to a numeric value, e.g. 0.5');
    end

    % Enable real-time pacing
    set_param(modelName, ...
        'EnablePacing', 'on', ...
        'PacingRate', '1');

    % ==========================================
    % CREATE KEYBOARD CONTROL WINDOW
    % ==========================================

    fig = figure( ...
        'Name', 'Drone Z Reference Controller', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Resize', 'off', ...
        'Position', [400 400 320 150], ...
        'WindowKeyPressFcn', @onKeyPress);

    statusText = uicontrol(fig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.05 0.15 0.90 0.75], ...
        'FontSize', 13, ...
        'String', '');

    updateDisplay();

    % ==========================================
    % KEYBOARD CALLBACK
    % ==========================================

    function onKeyPress(~, event)

        switch event.Key

            case 'uparrow'
                newZ = zRef + stepZ;

            case 'downarrow'
                newZ = zRef - stepZ;

            otherwise
                return;

        end

        % Only change reference while simulation runs
        simStatus = get_param(modelName, 'SimulationStatus');

        if ~any(strcmp(simStatus, {'running', 'paused'}))
            set(statusText, 'String', ...
                'Start Simulink simulation first.');
            return;
        end

        % Directly update the Constant block parameter
        try

            set_param(blockPath, ...
                'Value', sprintf('%.15g', newZ));

            zRef = newZ;

            updateDisplay();

        catch ME

            set(statusText, 'String', ...
                sprintf('Update error:\n%s', ME.message));

            warning('%s', ME.message);

        end

    end

    % ==========================================
    % DISPLAY CURRENT REFERENCE
    % ==========================================

    function updateDisplay()

        set(statusText, 'String', sprintf([ ...
            'DRONE Z REFERENCE\n\n' ...
            'Z ref = %.2f m\n\n' ...
            'UP   : +%.2f m\n' ...
            'DOWN : -%.2f m'], ...
            zRef, stepZ, stepZ));

    end

end
