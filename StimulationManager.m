classdef StimulationManager
    properties
        client
        configureCommand

        isAnalog

        stimChannel

        totalPulses = -1
        interPulseIntervalUs = -1
        singlePulseLengthUs = -1

        hasSynchronized = false
        currentStimN = -1

        keyTrigger
    end

    methods
        function obj = configurePulseTrain(obj, client, confCommand, channel, totalPulses, interPulseIntervalUs, isAnalog)
            arguments
                obj StimulationManager
                client RHXClient
                confCommand string
                channel string
                totalPulses single
                interPulseIntervalUs single
                isAnalog logical = false
            end

            obj.configureCommand = confCommand;
            obj.client = client;
            obj.totalPulses = totalPulses;

            obj.interPulseIntervalUs = interPulseIntervalUs;

            obj.isAnalog = isAnalog;
            obj.stimChannel = channel;
        end

        function obj = configureSinglePulse(obj, client, confCommand, channel, isAnalog)
            arguments
                obj StimulationManager
                client RHXClient
                confCommand string
                channel string
                isAnalog logical = false
            end

            obj.configureCommand = confCommand;
            obj.client = client;

            obj.totalPulses = 1;

            obj.isAnalog = isAnalog;
            obj.stimChannel = channel;
        end

        function [obj, err] = synchronizeConfiguration(obj)
            keys = [];
            values = [];

            % break configuration text into a parameter vector
            params = split(obj.configureCommand, " ");
            if lower(params(1)) == "Stim-Conf"
                params(1) = [];
            end

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
            
            if isKey(paramDict, "Channel")
                warning("Will ignore the provided channel %s, will instead use %s as provided during configuration", lookup(paramDict, "Channel"), obj.stimChannel);
            end

            obj.keyTrigger = lookup(paramDict, "Source");
            if ~contains(obj.keyTrigger, "KeyPress")
                error("The key trigger (`Source`) must be a key, F1-F8, written as `KeyPressF1` or similarly");
            end

            if obj.totalPulses > 1
                if ~isKey(paramDict, "NumPulses")
                    paramDict = insert(paramDict, "NumPulses", num2str(min(256, obj.totalPulses)));
                else
                    error("Please don't set the `NumPulses` argument when configuring an automatic stimulation; specify this when initializing a StimulationManager instance");
                end
    
                if isKey(paramDict, "PulseTrainDurationUS")
                    warning("Ignoring `PulseTrainDurationUS` with value %s, will use %d, which was provided in configurePulseTrain()\n", lookup(paramDict, "PulseTrainDurationUS"), obj.interPulseIntervalUs);
                end
                if ~isKey(paramDict, "DurationUS")
                    error("The key `DurationUS` (the duration of a single impulse) is required!");
                end
                paramDict("PulseTrainDurationUS") = num2str(obj.interPulseIntervalUs + str2double(lookup(paramDict, "DurationUS")));

                if isKey(paramDict, "IsPulseTrain")
                    warning("Ignoring `IsPulseTrain` with value %s, since StimulationManager was configured for a pulse train", lookup(paramDict, "IsPulseTrain"));
                end
                paramDict("IsPulseTrain") = "True";

                obj.singlePulseLengthUs = obj.interPulseIntervalUs + str2double(lookup(paramDict, "DurationUS"));
            else
                if isKey(paramDict, "IsPulseTrain")
                    warning("Ignoring `IsPulseTrain` with value %s, since StimulationManager was configured for a single pulse", lookup(paramDict, "IsPulseTrain"));
                end
                paramDict("IsPulseTrain") = "False";
            end

            fprintf("Will synchronize with the following parameters:\n");
            disp(paramDict);

            if obj.isAnalog
                err = obj.client.configureAnalogOutStimulation(obj.stimChannel, paramDict);
            else
                err = obj.client.configureAmplifierStimulation(obj.stimChannel, paramDict);
            end

            if err == ""
               fprintf("Synchronization successful!\n"); 
            else
               fprintf("Synchronization encountered errors: %s\n", err);
            end

            obj.hasSynchronized = true;
            obj.currentStimN = min(256, obj.totalPulses);
        end

        function err = stimulate(obj)
            obj.client.flushOutput(WaitTimeMS=0);

            if obj.totalPulses == 1 % single pulse
                obj.client.inOnlyCommand(sprintf("execute ManualStimTriggerPulse %s", obj.keyTrigger));
            elseif obj.totalPulses > 1 && obj.interPulseIntervalUs <= 1e6 % greater than 1ms
                nStimBatches = ceil(obj.totalPulses / 256); % 256 is the internal RHX limit

                for i = 1:nStimBatches
                    if i == nStimBatches && mod(obj.totalPulses, 256) > 0
                        nStims = mod(obj.totalPulses, 256);
                    else
                        nStims = 256;
                    end

                    % set the number of stimulations for this channel only
                    % if it is required
                    if obj.currentStimN ~= nStims
                        obj.setStimNumber(nStims);
                        obj.currentStimN = nStims;
                    end

                    % send stimulation
                    obj.client.inOnlyCommand(sprintf("execute ManualStimTriggerPulse %s", obj.keyTrigger));

                    % wait
                    pause((obj.singlePulseLengthUs / 1e6) * nStims);
                end

                err = obj.client.flushOutput(WaitTimeMS=1000);
            else
                error("A pulse train with an inter-pulse pause of >1s is not supported yet! Consider setting a timer and configuring a single-pulse stimulation to be triggered repeatedly.");
            end
        end

        function ip = isImpuseTrain(obj)
            ip = obj.totalPulses > 1;
        end

        function ic = isConfigured(obj)
            ic = ~isempty(obj.totalPulses) && ~isempty(obj.configureCommand);
        end

        function obj = setGlobalRecordingState(obj, state)
            arguments
                obj StimulationManager
                state string % allowed values are run, record or stop
            end

            obj.client.toggleGlobalRecordingState(state);
        end

        function obj = toggleRecordingEnabled(obj, state)
            arguments
                obj StimulationManager
                state logical
            end

            obj.client.toggleChannelRecordingEnabled(obj.stimChannel, state);
        end

        function err = executeCustomCommand(obj, command, waitMS)
            arguments
                obj StimulationManager
                command string
                waitMS single = 2000
            end
            obj.client.inOnlyCommand(command);

            err = obj.client.flushOutput(WaitTimeMS=waitMS);
        end
    end

    methods (Hidden)
        function setStimNumber(obj, nStims)
            obj.client.inOnlyCommand(sprintf("set %s.NumberOfStimPulses %s", obj.stimChannel, num2str(nStims)));
        end
    end
end