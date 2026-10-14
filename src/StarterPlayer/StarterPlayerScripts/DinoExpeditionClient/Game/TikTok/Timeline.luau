--[[
	Timeline — the beat clock every TikTok sequence runs on. Deterministic: a sequence is a list of shots,
	each a whole number of beats long, and everything inside a shot is a function of its local time.

	  Timeline.Music          { BPM = 123, MusicOffset = 0 }   edit here (or per sequence) to re-sync
	  Timeline.BeatToSeconds(beat, bpm?)                          1 beat at 123 BPM = 0.4878 s
	  Timeline.SecondsToBeat(seconds, bpm?)
	  Timeline.Layout(seq)   -> { Shots = { {Index, Name, StartBeat, Beats, Start, Dur, Offset} }, Beats, Dur }
	                          seq.Shots entries are { shotName, beats, startBeat? } (startBeat: begin part-way into the shot)

	Inside a shot (Shots.luau) cues are scheduled on the shot's own clock:
	  ctx:AtBeat(beat, fn)    fires once when the shot's clock crosses `beat` (beats from the cut)
	  ctx:AtTime(seconds, fn)
	A cue scheduled before the playhead (a PLAY FROM BEAT seek) is skipped, never fired late.
]]

local Timeline = {}

Timeline.Music = {
	BPM = 123,
	-- seconds of silence before beat 0 in your music track (set so the first cut lands on the first kick)
	MusicOffset = 0,
}

function Timeline.BeatToSeconds(beat: number, bpm: number?): number
	return beat * 60 / (bpm or Timeline.Music.BPM)
end

function Timeline.SecondsToBeat(seconds: number, bpm: number?): number
	return seconds * (bpm or Timeline.Music.BPM) / 60
end

-- seq = { BPM?, Shots = { { "ShotName", beats, args? }, ... } }
function Timeline.Layout(seq)
	local bpm = seq.BPM or Timeline.Music.BPM
	local list = {}
	local beat = 0
	for i, s in ipairs(seq.Shots) do
		local beats = s[2]
		table.insert(list, {
			Index = i,
			Name = s[1],
			Beats = beats,
			StartBeat = beat,
			Start = Timeline.BeatToSeconds(beat, bpm),
			Dur = Timeline.BeatToSeconds(beats, bpm),
			-- optional third entry: start this many beats into the shot (use the end of a longer shot)
			Offset = Timeline.BeatToSeconds(s[3] or 0, bpm),
		})
		beat += beats
	end
	return { Shots = list, Beats = beat, Dur = Timeline.BeatToSeconds(beat, bpm), BPM = bpm }
end

-- which shot holds a global beat
function Timeline.ShotAtBeat(layout, beat: number): number
	for i, s in ipairs(layout.Shots) do
		if beat < s.StartBeat + s.Beats then return i end
	end
	return #layout.Shots
end

--------------------------------------------------------------------------------
-- per-shot cue list (owned by the shot's ctx)
--------------------------------------------------------------------------------
local Cues = {}
Cues.__index = Cues

function Timeline.NewCues(bpm: number)
	return setmetatable({ List = {}, BPM = bpm, Last = -math.huge }, Cues)
end

function Cues:AtTime(t: number, fn: () -> ())
	table.insert(self.List, { T = t, Fn = fn, Done = false })
end

function Cues:AtBeat(beat: number, fn: () -> ())
	self:AtTime(Timeline.BeatToSeconds(beat, self.BPM), fn)
end

-- fire every cue in (Last, t]; `silent` marks them done without firing (seeking past them)
function Cues:Advance(t: number, silent: boolean?)
	for _, c in ipairs(self.List) do
		if not c.Done and c.T <= t + 1e-6 and c.T > self.Last - 1e-6 then
			c.Done = true
			if not silent then
				local ok, err = pcall(c.Fn)
				if not ok then warn("[TikTok] cue:", err) end
			end
		end
	end
	self.Last = t
end

return Timeline
