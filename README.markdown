About
=====

VLC does not have a good way for two people to watch the same video at the
same time and automatically keep the two viewings in sync over the internet.
It does have the "netsync" module, but that seems designed for a LAN where
one person streams a video and the rest recieve and sync on the stream. All
that really needs to happen is for the two people to open the same video
file and for VLC to periodically transmit timecodes between the two in order
to keep in sync. That's exactly what this VLC extension does -- it simply
transmits timecodes from a server to a client; if the client is more than
two seconds out of sync, the client seeks to that timecode.

Installation
============

The client should work on any OS that VLC supports. Please report any bugs!

The only actually tested configuration is with a Windows 7 server and Mac
OS X client.

To install, drop sync-server.lua and/or sync-client.lua as appropriate into
the VLC extensions directory.

The extensions directory is located at:

 - OS X systemwide: /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
 - OS X current user: ~/Library/Application Support/org.videolan.vlc/lua/extensions/
 - Linux systemwide: depends upon distro
 - Linux current user: ~/.local/share/vlc/lua/extensions/
 - Windows systemwide: C:\Program Files\VideoLan\VLC\lua\extensions\
 - Windows current user: I have no idea

Usage
=====

The client and the server both begin playing the same video. While the video
is playing (possibly paused if needed), the server activates the server
extension from the View menu. A dialog will pop up if there is an error. 
Then the client activates the client extension the same way; and enters
the server IP and port. A dialog will pop up if there is an
error. Both videos should now be approximately in sync.

Note that the server might need to have the sync port forwarded on the
router if there is a NAT between the two machines. Since the sync is
maintained via seeking, if the video has issues seeking the client might
get very sad.

Known Issues
============

WFM, YMMV, etc. Patches welcomed.

 - if previous connection attempts have failed and vlc did not exit cleanly listen_tcp/accept may not succeed (kill all vlc instances and retry)
 - get a keep alive warning when sync-server is waiting for client to connect (ignore it)
 - server can only accept one connection
 - no way to kick server out of accept()
 - client and server do not always properly detect remote disconnects
 - client and server should run in a separate thread, if possible?
 - no security whatsoever
 - does not ensure you are playing the same vieo on each side
 - conflates master/slave with server/client
 - client connects to a hard-coded location
 - pausing on either end can create weird results until unpaused
 - does not deal at all with latency jitter
 - code is pretty crappy
