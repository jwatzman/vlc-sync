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

--[[
 - TODO should we be be checking for a nil vlc.object.input or not is_playing?
]]--

-- set to false to tell the serve function to go away
enabled = true

function dlog(msg)
	vlc.msg.dbg(string.format("[sync-server] %s", msg))
end

function descriptor()
	return
	{
		title = "Sync Server";
		version = "2011-01-24";
		author = "jwatzman";
		shortdesc = "Sync Server";
		description = "Syncronizes two viewings of the same video over the "
		           .. "internet. This is the server component -- the client "
		           .. "connects to us and we tell the client how far into the "
		           .. "video we should be.";
		capabilities = { "input-listener", "playing-listener" };
	}
end

-- repeatedly send the time every second to fd until we are no longer enabled
function serve(fd)
	while enabled do
		local input = vlc.object.input()
		if not input then
			enabled = false
			vlc.deactivate()
		else
			local t = math.floor(vlc.var.get(input, "time"))
			vlc.net.send(fd, string.format("%i\n", t))
			os.execute("sleep 1") -- XXX won't work on Windows
		end
	end
	vlc.net.close(fd)
end

function activate()
	dlog("activated")
	enabled = true

	if not vlc.input.is_playing() then
		dlog("not playing")
		local dialog = vlc.dialog("Sync Server")
		dialog:add_label("Nothing is playing!", 1, 1, 1, 1)
		dialog:add_button("Close", vlc.deactivate, 2, 1, 1, 1)
		dialog:show()
	else
		local l = vlc.net.listen_tcp("0.0.0.0", 1234)
		local fd = l:accept()
		if fd < 0 then
			dlog("accept failed")
			local dialog = vlc.dialog("Sync Server")
			dialog:add_label("Failed to serve.", 1, 1, 1, 1)
			dialog:add_button("Close", vlc.deactivate, 2, 1, 1, 1)
			dialog:show()
		else
			serve(fd)
		end
	end
end

function deactivate()
	dlog("deactivated")
	enabled = false
end

function input_changed()
	dlog("input changed")
	vlc.deactivate()
end

function status_changed()
	dlog("status changed")
	vlc.deactivate()
end
