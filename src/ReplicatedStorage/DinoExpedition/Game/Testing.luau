--[[
	Testing — the game knows it's in a TEST PHASE. While Testing.Enabled is on, live servers:
	  - only let in the approved testers below (plus the owner / group admins), and only once they're in the group
	  - show the tester main menu (access check over Base Camp shots, PLAY, TESTER WALL, REPORT A BUG)
	  - save to a separate PRE-BETA store, so launch starts everyone fresh
	  - show a small PRE-BETA build tag on screen
	Studio is never affected (no gate, no menu, normal saves) unless PreviewInStudio is switched on.

	Testers keep their PRE-BETA TESTER tag forever, even after Enabled goes off at launch.
	To add a tester: append { Name, UserId } (look the id up on their Roblox profile URL).
]]

local RunService = game:GetService("RunService")

local Testing = {}

Testing.Enabled = true -- flip to false at launch: no gate, no menu, normal saves (tester tags stay)
-- open test (2026-10-12): anyone may play - they only have to join the group. The list below is now the TESTER
-- WALL and the PRE-BETA TESTER tag, not the door. Set false to go back to approved testers only.
Testing.Open = true
Testing.Phase = "PRE-BETA"
Testing.Version = "0.3"
Testing.Build = "PRE-BETA " .. Testing.Version
-- the WHAT'S NEW card on the main menu (testers see it every time they come in): { Icon, Title, Line }.
-- Keep each line short; edit this list for every new build.
Testing.WhatsNew = {
	{ Icon = "Map", Title = "FREE ROAM", Line = "DRIVE ANYWHERE, HOP OUT, FIND SECRETS" },
	{ Icon = "Launcher", Title = "POWER TRAINER", Line = "STAND ON YOUR PAD TO GET STRONGER" },
	{ Icon = "Jeep", Title = "LOST THEM!", Line = "SHAKE THE PACK, KEEP HUNTING WITH EGGS" },
	{ Icon = "Crown", Title = "EPIC BOSSES", Line = "NEW REVEALS, NEW MOVES, KNOCKDOWNS" },
	{ Icon = "Egg", Title = "NEW HATCHES", Line = "5 HATCH STYLES + RARE HATCH NEWS" },
	{ Icon = "Coin", Title = "WHILE YOU WERE AWAY", Line = "YOUR YARD EARNS WHILE YOU'RE GONE" },
	{ Icon = "Buddy", Title = "TRADING", Line = "TRADE DINOS + EGGS FROM ANY PROFILE" },
	{ Icon = "Star", Title = "SPIN, LUCK + EVENTS", Line = "DAILY SPIN, LUCK RUSHES, METEOR SHOWERS" },
}
Testing.NextUp = "NEXT: MUTATIONS + HYBRIDS" -- a teaser line under the list (nil hides it)
Testing.GroupId = 902411651 -- testers must be members (the access check offers a JOIN button)
Testing.Discord = ".gg/dinos"
Testing.SaveStore = "DinoExpedition_PreBeta_v1" -- live test servers save here; launch uses the normal store
-- Studio: set true to see the menu + access check while playtesting (saves still use the normal store)
Testing.PreviewInStudio = false
Testing.PreviewResult = nil :: string? -- with the preview on: "Denied" or "NeedGroup" to see those screens (Studio never kicks)

-- approved PRE-BETA testers (applications accepted 2026-10-12). Matched by UserId, so name changes don't lock anyone out.
Testing.Testers = {
	{ Name = "SickleEdge", UserId = 2036303552 },
	{ Name = "Compete1aiden", UserId = 5373955286 },
	{ Name = "buggyblox1201", UserId = 1685857359 },
	{ Name = "Kingjax067", UserId = 4736881162 },
	{ Name = "lukerson_h", UserId = 708863952 },
	{ Name = "Ilovegod78558", UserId = 6208601882 },
	{ Name = "Jaylynngodrizz", UserId = 5156512811 },
	{ Name = "RyanMitar100", UserId = 572317491 },
	{ Name = "noahy917", UserId = 8403068895 },
	{ Name = "NotTufferson", UserId = 11747542860 },
	{ Name = "Get_clap2unitz", UserId = 9063807477 },
	{ Name = "DracoOfGaia", UserId = 1055598263 },
	{ Name = "crowezzz", UserId = 7929662822 },
	{ Name = "Fortnitepro987789", UserId = 1471993597 },
	{ Name = "IREALLYLIKECHEZ12", UserId = 7861330060 },
	{ Name = "ElBautizador0", UserId = 7354408751 },
	{ Name = "samil123456789", UserId = 44771916 },
}

local byId = {} :: { [number]: boolean }
for _, t in ipairs(Testing.Testers) do byId[t.UserId] = true end

function Testing.IsTester(userId: number): boolean
	return byId[userId] == true
end

-- is the test phase running on THIS server (live game, or Studio with the preview switched on)
function Testing.Active(): boolean
	if not Testing.Enabled then return false end
	if RunService:IsStudio() then return Testing.PreviewInStudio end
	return true
end

return Testing
