--[[

Syncronization extension for VLC -- server component
Copyright (c) 2011 Joshua Watzman (sinclair44@gmail.com)

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.

--]]

function get_time()
	return math.floor(vlc.var.get(vlc.object.input(), "time"))
end

function is_playing()
	return vlc.input.is_playing()
end

function dlog(msg)
	vlc.msg.dbg(string.format("[sync-server] %s", msg))
end

function sleep(secs)
	for i = 1,100000000 do
	end
end

function descriptor()
	return
	{
		title = "Sync Server";
		version = "1.0";
		author = "jwatzman";
		shortdesc = "Sync Server";
		description = "Syncronizes two viewings of the same video over the "
		           .. "internet. This is the server component -- the client "
		           .. "connects to us and we tell the client how far into the "
		           .. "video we should be.";
		capabilities = {};
	}
end

function serve()
	local l = vlc.net.listen_tcp("localhost", 1234)
	local fd = l:accept()
	if fd < 0 then
		dlog("accept failed")
	else
		for i = 1,10 do
			vlc.net.send(fd, string.format("%i\n", get_time()))
			sleep(1)
		end
		vlc.net.close(fd)
	end
	vlc.deactivate()
end

function activate()
	dlog("activated")
	if not is_playing() then
		dlog("not playing")
		vlc.deactivate()
	else
		serve()
	end
end

function deactivate()
	dlog("deactivated")
end
