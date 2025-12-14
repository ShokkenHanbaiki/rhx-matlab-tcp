# Intan RHX TCP applet
This console app written in Matlab aims to be a simple interface
for the Intan RHX software by using its TCP server.

# Quick start guide
First, set up the TCP server within Intan RHX. Refer to the [Intan RHX documentation](https://intantech.com/files/Intan_RHX_user_guide.pdf), 
page 30, for more details on this. Once you have clicked **Connect** in the 
TCP server setup window and have noted the IP and port on which the server is running,
you can open `main.m` within this applet.

Here, you need to specify the IP address and port of the Intan RHX TCP server
to the instance of `RHXClient` initialized within `main()`. This can be done as follows:
```
client = RHXClient(ServerAddress="127.0.0.1", ServerPort=5000);
``` 

Do note that the IP `127.0.0.1` with port 5000 are default values, and thus do 
not have to be specified explicitly. Hence, the following is sufficient in case these values apply to your case:
```
client = RHXClient();
```

Once you have configured access to the TCP server within `main.m`, you are ready
to go to make use of the applet. Go ahead and press F5 while having `main.m`
open to start the applet. Type commands in the command window to communicate with
the TCP server.

Refer to the documentation for this applet below (coming soon!) in case you 
need to modify or extend some of its functionalities.