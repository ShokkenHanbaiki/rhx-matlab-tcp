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
                args.ErrorWaitMS single = 200
            end

            write(obj.tcpClient, payload, args.InFormat);
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
    end
end