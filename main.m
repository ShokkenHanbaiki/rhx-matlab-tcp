function main()
    client = RHXClient(ServerPort=5000);

    % comment out the following 2 lines in case you don't want to use the
    % console, but instead want to configure your own stimulation
    % console = Console(client);
    % console.run();

    % this is an example of how to set up a timer with the stimulation
    % manager object

    t = timer;

    t.Period = 5;
    t.TasksToExecute = 5;
    t.ExecutionMode = "fixedSpacing";

    % first, we must set up the stimulation manager. We can't use
    % t.StartFcn for this, because we need to work with a shared instance
    % of StimulationManager
    sm = StimulationManager().configurePulseTrain(client, "Shape=Biphasic Source=KeyPressF1 IsPulseTrain=True DurationUS=500 AmplitudeUA=50", "A-001", 500, 100);
    sm = sm.setGlobalRecordingState("record").toggleRecordingEnabled(true);

    sm = sm.synchronizeConfiguration();

    % configure the tick and end function with the stim manager
    t.TimerFcn = {@timerTick, sm};
    t.StopFcn = {@timerStop, sm};

    % then, we can start the timer
    start(t);

    % matlab timers are pretty weird since they continue running even after
    % the app officially closed. This pause command is thus included here
    % to prevent the command line from being shown before the timer
    % actually ends.
    pause;
end

function timerTick(timer, eventData, sm)
    % this code would be run on every tick of the timer.
    fprintf("hello!");
    sm.stimulate();
end

function timerStop(timer, eventData, sm)
    % you can include some cleanup code here if you want to (like turning off recording to save space)
    sm.setGlobalRecordingState("stop");

    fprintf("Timer finished!\n");
end