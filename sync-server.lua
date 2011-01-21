function get_time()
	return math.floor(vlc.var.get(vlc.object.input(), "time"))
end

function descriptor()
	return
	{
		title = "Sync - Server";
		version = "1.0";
		author = "jwatzman";
		capabilities = {};
	}
end

function activate()
	vlc.msg.dbg("[sync-server] hello world!")
	for i = 1,10
		do
			for j = 1,100000000
				do
				end
			vlc.msg.dbg(string.format("[sync-server] secs %i", get_time()))
		end
	vlc.deactivate()
end

function deactivate()
	vlc.msg.dbg("[sync-server] goodbye world!")
end
