classdef Console
    properties
        ignoreErrors
        rhxClient

        killFlag = false
    end

    methods
        %% constructor
        function obj = Console(rhxClient, args)
            arguments
                rhxClient RHXClient
                args.IgnoreErrors logical = true
            end

            obj.ignoreErrors = args.IgnoreErrors;
            obj.rhxClient = rhxClient;
        end

        %% core functions
        function run(obj)
            fprintf("Running console. \n=====================\n\n");
            
            while ~obj.killFlag
                command = input("Enter a command (type exit or press Ctrl+C to exit): ", "s");
                obj = obj.parseCommand(convertCharsToStrings(command));
            end
        end

        function obj = parseCommand(obj, command)
            if lower(command) == "exit"
                obj.killFlag = true;
                fprintf("Bye\n");
            else
                splitCommand = split(command, " ");
                if numel(splitCommand) > 1
                    verb = splitCommand(1);
                    params = splitCommand(2:end);
                else
                    verb = splitCommand(1);
                    params = [];
                end

                if verb == "List-Commands" || verb == "Help"
                    fprintf("Sorry, no help implemented yet!\n");
                end

                if verb == "Stim"
                    obj.manualStimTrigger(params);
                end

                if verb == "Stim-Conf"
                    obj.configureStimulation(params);
                end

                if verb == "Toggle-Stim"
                    obj.toggleStimulation(params);
                end
            end
        end

        %% commands
        function obj = manualStimTrigger(obj, params)
            if numel(params) ~= 1
                fprintf("Invalid number of parameters\n");
                return;
            end

            fprintf("Stimulating with key %s\n", params(1));
            obj.rhxClient.inOnlyCommand(sprintf("execute ManualStimTriggerPulse %s", params(1)));
            fprintf("Stimulation comand sent. Will wait for potential error...\n");

            stimError = obj.rhxClient.flushOutput();
            if stimError ~= ""
                fprintf("Stimulation failed. Details: %s\n", stimError);
            else
                fprintf("No error\n");
            end
        end

        function obj = configureStimulation(obj, params)
            if isempty(params)
                fprintf("Parameter configuration cannot be called without arguments\n");
                return;
            end

            % define allowed keys

            % parse parameters
            keys = [];
            values = [];

            for i = 1:numel(params)
                splitParam = split(params(i), "=");
                if numel(splitParam) ~= 2
                    warning("Warning: parameter with value %s has invalid syntax!", params(i));
                    continue
                end

                keys = [keys, splitParam(1)];
                values = [values, splitParam(2)];
            end

            paramDict = dictionary(keys, values);

            % check that the channel has been specified
            if ~isKey(paramDict, "Channel")
                fprintf("No channel specified.\n");
                return;
            end

            % display for the user's convenience
            fprintf("Parsed parameters:\n");
            disp(paramDict);

            % pass to server
            if contains(lookup(paramDict, "Channel"), "ANALOG-OUT")
                fprintf("Sending configuration parameters for manual (analog) stimulation of %s\n", lookup(paramDict, "Channel"));
                obj.rhxClient.configureAnalogOutStimulation(lookup(paramDict, "Channel"), paramDict);
            else
                fprintf("Sending configuration parameters for amplifier stimulation of %s\n", lookup(paramDict, "Channel"));
                obj.rhxClient.configureAmplifierStimulation(lookup(paramDict, "Channel"), paramDict);
            end
            
        end

        function obj = toggleStimulation(obj, params)
            if numel(params) ~= 2
                fprintf("Expected exactly 2 parameters: channel and stim toggle state.\n");
                return;
            end

            if lower(params(2)) == "on"
                obj.rhxClient.toggleStimEnable(params(1), true);
            elseif lower(params(2)) == "off"
                obj.rhxClient.toggleStimEnable(params(1), false);
            else
                fprintf("Ambiguous stimulation state '%s'\n", params(2));
            end
        end
    end
end