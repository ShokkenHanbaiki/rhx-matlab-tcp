classdef StimulationTimer
    properties
        manager
    end

    methods
        function obj = StimulationTimer(manager)
            arguments
                manager StimulationManager
            end

            obj.manager = manager;
        end

        function timerSetup(timer, eventData)
            
        end
        
        function timerTick(timer, eventData)
            % this code would be run on every tick of the time
            sm.stimulate();
        end
        
        function timerStop(timer, eventData)
            % you can include some cleanup code here if you want to (like turning off recording to save space)
            sm = sm.setGlobalRecordingState("stop");
        end
    end
end