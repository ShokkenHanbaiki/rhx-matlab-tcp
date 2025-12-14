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
                    params = "";
                end

                if verb == "Stim"
                    obj.manualStimTrigger(params);
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
    end
end