classdef RHXClient
    properties
        tcpClient 
    end

    methods
        %% constructors
        function obj = RHXClient(args)
            arguments
                args.ServerAddress string = "127.0.0.1"
                args.ServerPort single = 8000
            end

            try
                obj.tcpClient = tcpclient(args.ServerAddress, args.ServerPort);
            catch err
                disp(err);
                error("Matlab TCP client could not connect. Is the server at %s:%d running?", ...
                    args.ServerAddress, args.ServerPort);
            end

            connTest = obj.testConnectivity();
            if ~connTest
                error("Matlab TCP client connected, but issuing a test command failed. Application will exit.")
            end
        end

        %% miscellaneous methods

        function result = testConnectivity(obj)
            try
                sampleRate = obj.inOutCommand("get Version", OutFormat="string");
                fprintf("Connection to server successful; %s\n", sampleRate);

                result = true;
            catch err
                disp(err);

                fprintf("Connection to server was unsuccessful\n");
                result = false;
            end
        end

        %% basic methods
        function result = inOutCommand(obj, payload, args)
            arguments
                obj RHXClient
                payload
                args.InFormat string = "uint8"
                args.OutFormat string = "string"
                args.WaitTimeMS single = 2000
            end

            write(obj.tcpClient, payload, args.InFormat);
            timerStart = datetime("now");

            while milliseconds(datetime("now") - timerStart) < args.WaitTimeMS && obj.tcpClient.NumBytesAvailable == 0
                pause(0.1);
            end

            if obj.tcpClient.NumBytesAvailable > 0
                result = read(obj.tcpClient, obj.tcpClient.NumBytesAvailable, args.OutFormat);
            else
                error("Request timeout for command %s\n", payload)
            end
        end

        function inOnlyCommand(obj, payload, args)
            arguments
                obj RHXClient
                payload
                args.InFormat string = "uint8"
            end

            write(obj.tcpClient, payload, args.InFormat);
            pause(0.05);
        end

        function output = flushOutput(obj, args)
            arguments
                obj RHXClient
                args.OutFormat string = "string"
                args.WaitTimeMS single = 500
            end

            timerStart = datetime("now");

            while milliseconds(datetime("now") - timerStart) < args.WaitTimeMS && obj.tcpClient.NumBytesAvailable == 0
                pause(0.1);
            end

            if obj.tcpClient.NumBytesAvailable > 0
                output = read(obj.tcpClient, obj.tcpClient.NumBytesAvailable, args.OutFormat);
            else
                output = "";
            end
        end

        %% higher-level methods
        function err = configureAmplifierStimulation(obj, channel, args)
            arguments
                obj RHXClient
                channel string
                args dictionary
            end

            if isKey(args, "Shape"); obj.inOnlyCommand(sprintf("set %s.Shape %s", channel, lookup(args, "Shape"))); end
            if isKey(args, "Polarity"); obj.inOnlyCommand(sprintf("set %s.Polarity %s", channel, lookup(args, "Polarity"))); end
            if isKey(args, "Source"); obj.inOnlyCommand(sprintf("set %s.Source %s", channel, lookup(args, "Source"))); end

            if isKey(args, "IsPulseTrain")
                if lookup(args, "IsPulseTrain") == "True"
                    obj.inOnlyCommand(sprintf("set %s.PulseOrTrain PulseTrain", channel));

                    if ~isKey(args, "NumPulses")
                        error("IsPulseTrain must be supplied with NumPulses");
                    else
                        obj.inOnlyCommand(sprintf("set %s.NumberOfStimPulses %s", channel, lookup(args, "NumPulses")));
                    end
                else
                    obj.inOnlyCommand(sprintf("set %s.PulseOrTrain SinglePulse", channel));
                end
            end

            if isKey(args, "PulseTrainDurationUS")
                obj.inOnlyCommand(sprintf("set %s.PulseTrainPeriodMicroseconds %s", channel, lookup(args, "PulseTrainDurationUS")));
            end

            if isKey(args, "DurationUS")
                halfDurationUS = round(lookup(args, "DurationUS") / 2);
                obj.inOnlyCommand(sprintf("set %s.FirstPhaseDurationMicroseconds %s", channel, halfDurationUS));
                obj.inOnlyCommand(sprintf("set %s.SecondPhaseDurationMicroseconds %s", channel, halfDurationUS));
            end

            if isKey(args, "AmplitudeUA")
                obj.inOnlyCommand(sprintf("set %s.FirstPhaseAmplitudeMicroAmps %s", channel, lookup(args, "AmplitudeUA")));
                obj.inOnlyCommand(sprintf("set %s.SecondPhaseAmplitudeMicroAmps %s", channel, lookup(args, "AmplitudeUA")));
            end

            obj.inOnlyCommand(sprintf("set %s.StimEnabled True", channel));
            % obj.inOnlyCommand("execute UploadStimParameters");

            output = obj.flushOutput();
            if output ~= ""
                fprintf("Command completed with potential errors: %s\n", output);
                err = output;
            else
                fprintf("Command completed successfully\n");
                err = "";
            end
        end

        function err = configureAnalogOutStimulation(obj, channel, args)
            arguments
                obj RHXClient
                channel string
                args dictionary
            end

            % manual stimulator likely accepts positive-only wave
            obj.inOnlyCommand(sprintf("set %s.Shape Monophasic", channel));
            obj.inOnlyCommand(sprintf("set %s.Polarity PositiveFirst", channel));

            % set baseline voltage to 0
            obj.inOnlyCommand(sprintf("set %s.BaselineVoltageVolts 0", channel));

            if isKey(args, "Source"); obj.inOnlyCommand(sprintf("set %s.Source %s", channel, lookup(args, "Source"))); end

            if isKey(args, "DurationUS")
                halfDurationUS = round(lookup(args, "DurationUS") / 2);
                obj.inOnlyCommand(sprintf("set %s.FirstPhaseDurationMicroseconds %s", channel, halfDurationUS));
                obj.inOnlyCommand(sprintf("set %s.SecondPhaseDurationMicroseconds %s", channel, halfDurationUS));
            end

            if isKey(args, "AmplitudeV")
                obj.inOnlyCommand(sprintf("set %s.FirstPhaseAmplitudeVolts %s", channel, lookup(args, "AmplitudeV")));
                obj.inOnlyCommand(sprintf("set %s.SecondPhaseAmplitudeVolts %s", channel, lookup(args, "AmplitudeV")));
            end
            
            obj.inOnlyCommand(sprintf("set %s.StimEnabled True", channel));
            % obj.inOnlyCommand("execute UploadStimParameters");

            output = obj.flushOutput();
            if output ~= ""
                fprintf("Command completed with potential errors: %s\n", output);
                err = output;
            else
                fprintf("Command completed successfully\n");
                err = "";
            end
        end

        function err = toggleStimEnable(obj, channel, enableState)
            arguments
                obj RHXClient
                channel string
                enableState logical
            end

            if enableState
                enableString = "True";
                fprintf("Enabling stimulation for channel %s\n", channel);
            else
                enableString = "False";
                fprintf("Disabling stimulation for channel %s\n", channel);
            end
            obj.inOnlyCommand(sprintf("set %s.StimEnabled %s", channel, enableString));

            err = obj.flushOutput();
            if err ~= ""
                fprintf("Command completed with potential errors: %s\n", err);
            else
                fprintf("Command completed successfully\n");
            end
        end
    end
end