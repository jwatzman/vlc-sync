--[[

Syncronization extension for VLC -- client component
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
	update_delay = 1, -- (sec) delay between attempting to receive sync packets
	update_accuracy = 2, -- (sec) maximum tolerable difference between client and server playback times
}

callback_active = false
open_dialog = nil
host_input = nil
port_input = nil

-- default server host:port
host = "127.0.0.1"
port = 1234

function descriptor()
	return
	{
		title = "Sync Client";
		version = "2013-01-29";
		author = "jwatzman, sj";
		url = 'https://github.com/jwatzman/vlc-sync/';
		shortdesc = "Sync Client";
		description = "Synchronizes two viewings of the same video over the "
				.. "internet. This is the client component -- we connect "
				.. "to the server and it tells us how far into the video "
				.. "we should be.";
		capabilities = { "input-listener" };
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
		dialog_options()
	end
end

function connect()
	host = host_input:get_text()
	port = port_input:get_text()
	-- bug: does not function correctly on Mac OS X
	-- open_dialog:delete()
	-- note: can not show any further dialogs after this point!
	open_dialog:hide() 
	open_dialog:update()
	syncOSD.channel = vlc.osd.channel_register()
	syncOSD.connecting_to_server()
	fd = vlc.net.connect_tcp(host, port)
	if fd < 0 then
		debug_log("connect failed")
		syncOSD.connect_failed()
		vlc.deactivate()
	else
		debug_log("connected to server")
		syncOSD.connected_to_server()
		last_tick = os.date('*t')
		callback_active = true
		-- note: intf-event occurs several times per second
		vlc.var.add_callback(input, "intf-event", tick, "none")
	end
end

function tick()
	local t = os.date('*t')
	if math.floor(os.difftime(os.time(t), os.time(last_tick))) > syncSettings.update_delay then
		debug_log("tick! "..math.floor(os.difftime(os.time(t), os.time(last_tick))))
		last_tick = t
		recv_state()
	end
end

function recv_state()
	-- read next command
	local pollfds = {}
	pollfds[fd] = vlc.net.POLLIN
	debug_log("polling fd: "..fd)
	if vlc.net.poll(pollfds, 1) > 0 then
		local str = vlc.net.recv(fd, 1000)
		debug_log("recv: "..str)
		if str:find("\004") ~= nil then
			debug_log("got killbit, deactivating")
			syncOSD.server_disconnected()
			vlc.deactivate()
		elseif str:find("pause") ~= nil then
			real_pause()
			debug_log("server paused")
			syncOSD.server_paused()
		elseif str:find("play") ~= nil then
			real_play()
			debug_log("server played")
			syncOSD.server_played()
		else
			-- receive playback time
			local i, j = string.find(str, "%d+\n")
			local remote_playback_time = tonumber(string.sub(str, i, j))
			debug_log("client playback time: "..remote_playback_time)
			set_playback_time(remote_playback_time)
		end
	end
end

function set_playback_time(remote_playback_time)
	local local_playback_time = math.floor(vlc.var.get(input, "time"))
	if math.abs(local_playback_time - remote_playback_time) > syncSettings.update_accuracy then
		debug_log(string.format("updating time from %i to %i", local_playback_time, remote_playback_time))	
					
		-- this is broken in VLC 2 see: http://trac.videolan.org/vlc/ticket/6527
		-- vlc.var.set(input, "time", remote_playback_time) 
		local duration = vlc.input.item():duration()
		vlc.var.set(input,"position", remote_playback_time / duration)
					
		debug_log("update time set")
	end
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

function deactivate()
	debug_log("deactivated")
	if input ~= nil and callback_active then
		vlc.var.del_callback(input, "intf-event", tick, "none")
	end
		if fd ~= nil then
		vlc.net.close(fd)
	end
	-- delay to let messages finish displaying
	delay(3)
	if open_dialog ~= nil then
		-- bug: dialog:delete() does not work on Mac OS X
		--open_dialog:delete()
		open_dialog:hide()
	end
	if syncOSD.channel ~= nil then
		vlc.osd.channel_clear(syncOSD.channel)
	end
	vlc.deactivate()
end

-- horrible delay hack
function delay(sec)
	local t = os.date('*t')
	local last_delay_tick = t
	debug_log("delaying: "..sec.." seconds")
	while(os.difftime(os.time(last_delay_tick),os.time(t))) < sec do
		last_delay_tick = os.date('*t')
	end
	debug_log("delay finished")
end

-- dialogs
function dialog_options()
	open_dialog = vlc.dialog("Sync Client")
	open_dialog:add_label("Sync-server IP:", 1, 1, 1, 1)
	host_input = open_dialog:add_text_input(host, 2, 1, 1, 1)
	open_dialog:add_label("Port:", 1, 2, 1, 1)
	port_input = open_dialog:add_text_input(port, 2, 2, 1, 1)
	open_dialog:add_button("Connect", connect, 2, 3, 1, 1)
	open_dialog:show()
end

function dialog_not_playing()
	open_dialog = vlc.dialog("Sync Client")
	open_dialog:add_label("Nothing is playing!", 1, 1, 1, 1)
	open_dialog:add_label("Please select a file to play before launching the sync-client.", 1, 2, 5 ,1)
	open_dialog:add_button("Close", vlc.deactivate, 2, 3, 1, 1)
	open_dialog:show()
end

-- osd
syncOSD = {
	channel = nil,
	connecting_to_server = function()
		vlc.osd.message("[sync-client] connecting to server", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	connect_failed = function()
		vlc.osd.message("[sync-client] failed to connect to server", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	connected_to_server = function()
		vlc.osd.message("[sync-client] connected to server", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	server_paused = function()
		vlc.osd.message("[sync-client] server paused", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	server_played = function()
		vlc.osd.message("[sync-client] server played", syncOSD.channel, "top-right", 2*1000*1000)
	end,
	server_disconnected = function()
		vlc.osd.message("[sync-client] server disconnected", syncOSD.channel, "top-right", 2*1000*1000)
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
	vlc.msg.info(string.format("[sync-client] %s", msg))
end