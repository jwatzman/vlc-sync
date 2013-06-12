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

fd = nil
input = nil

last_tick = nil

-- settings
syncSettings = {
	update_delay = 1, -- (sec) delay between sending sync packets
	update_accuracy = 2, -- (sec) maximum tolerable difference between client and server 
}

-- default server host:port
host = "0.0.0.0"
port = 1234

function descriptor()
	return
	{
		title = "Sync Server";
		version = "2013-01-29";
		author = "jwatzman, sj";
		url = 'https://github.com/jwatzman/vlc-sync/';
		shortdesc = "Sync Server";
		description = "Syncronizes two viewings of the same video over the "
				.. "internet. This is the server component -- the client "
				.. "connects to us and we tell the client how far into the "
				.. "video we should be.";
		capabilities = { "input-listener", "playing-listener" };
	}
end

function activate()
	debug_log("enabled")
	input = vlc.object.input()
	if not vlc.input.is_playing() then
		debug_log("not playing")
		dialog_not_playing()
	else
		real_pause()
		syncOSD.channel = vlc.osd.channel_register()
		syncOSD.waiting_for_client()
		local l = vlc.net.listen_tcp(host, port)
		-- to do: write non-blocking accept
		fd = l:accept()
		if fd < 0 then
			debug_log("accept failed")
			dialog_accept_failed()
		else
			debug_log("client connected")
			syncOSD.client_connected()
			last_tick = os.date('*t')
			-- note: intf-event occurs several times per second
			vlc.var.add_callback(input, "intf-event", tick, "none")
		end
	end
end

function tick()
	local t = os.date('*t')
	if math.floor(os.difftime(os.time(t), os.time(last_tick))) > syncSettings.update_delay then
		debug_log("tick! "..math.floor(os.difftime(os.time(t), os.time(last_tick))))
		last_tick = t
		send_playback_time()
	end
end

function send_playback_time()
	local t = math.floor(vlc.var.get(input, "time"))
	vlc.net.send(fd, string.format("%i\n", t))
	debug_log("playback time: "..t)
end

function close()
	-- function triggered on dialog box close event
	vlc.deactivate()
end

function input_changed()
	-- related to capabilities={"input-listener"} in descriptor()
	-- triggered by Start/Stop media input event
	debug_log("input changed")
	vlc.deactivate()
end

function playing_changed()
	-- related to capabilities={"playing-listener"} in descriptor()
	-- triggered by Pause/Play madia input event
	debug_log("playing changed, current status: "..vlc.playlist.status())
	if fd ~= nil then
		if( vlc.playlist.status() == "paused" or vlc.playlist.status() == "stopped" ) then
			vlc.net.send(fd,"pause\n")
		elseif vlc.playlist.status() == "playing" then
			vlc.net.send(fd,"play\n")
		end
	end
end

function deactivate()
	debug_log("deactivated")
	if input ~= nil then
		vlc.var.del_callback(input, "intf-event", tick, "none")
	end
	if fd ~= nil then
		vlc.net.send(fd,"\004") -- note: \004 = (End of transmission)
		vlc.net.close(fd)
	end
	if syncOSD.channel ~= nil then
		vlc.osd.channel_clear(syncOSD.channel)
	end
	vlc.deactivate()
end

-- dialogs
function dialog_not_playing()
	local dialog = vlc.dialog("Sync Server")
	dialog:add_label("Nothing is playing!", 2, 1, 1, 1)
	dialog:add_label("Please select a file to play before launching the sync-server.", 1, 2, 3 ,1)
	dialog:add_button("Close", deactivate, 2, 3, 1, 1)
	dialog:show()
end

function dialog_accept_failed()
	local dialog = vlc.dialog("Sync Server")
	dialog:add_label("Accept connection failed!", 2, 1, 1, 1)
	dialog:add_label("Port: "..port, 1, 3, 1, 1)
	dialog:add_label("Please check the port is correct and ensure your NAT is configured correctly.", 1, 4, 3, 1)
	dialog:add_button("Close", deactivate, 2, 5, 1, 1)
	dialog:show()
end

-- osd
syncOSD = {
	channel = nil,
	waiting_for_client = function()
		vlc.osd.message("[sync-server] waiting for client", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	client_connected = function()
		vlc.osd.message("[sync-server] client connected", syncOSD.channel, "top-right", 2*1000*1000)
	end
}

-- general
function real_pause()
	-- bug: vlc.playlist.pause() toggles play/pause rather than always pausing
	if vlc.playlist.status() ~= "paused" then
		vlc.playlist.pause()
	end
end

function real_play()
	-- bug: vlc.playlist.pause() toggles play/pause rather than always pausing
	if vlc.playlist.status() ~= "playing" then
		vlc.playlist.pause()
	end
end

function debug_log(msg)
	-- output debug message (-vv)
	vlc.msg.info(string.format("[sync-server] %s", msg))
end