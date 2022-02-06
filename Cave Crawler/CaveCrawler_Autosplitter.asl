
state("CaveCrawler")
{
	int  level		: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xE0;
	int  resetLevel		: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0x50;//pointer
	int  score		: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xB0;
	bool inLevel		: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0x48;
	bool levelCompleted	: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xC8;
}


startup
{
	vars.name = "Cave Crawler Autosplitter 1.2";

	vars.timer = new TimerModel { CurrentState = timer };
	refreshRate = 60;

	if(timer.CurrentTimingMethod == TimingMethod.RealTime) {
		timer.CurrentTimingMethod = TimingMethod.GameTime;
		print("Timing Method Changed!");
	} 

	vars.createSetting = (Func<string, string, string, bool, bool>)((name, description, tooltip, enabled) => {
		settings.Add(name, enabled, description);
		settings.SetToolTip(name, tooltip);
		return true;
	});

	vars.levels = new string[] { "Tutorial", "Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Bonus Level"};

	vars.createSetting("Split", "Split", "", true);
	vars.createSetting("Start", "Start", "", true);
	vars.createSetting("Reset", "Reset", "", true);
	settings.CurrentDefaultParent = "Split";
		for (int i = 0; i <= 6; i++)
			vars.createSetting("splitLevel" + i, "At the end of the " + vars.levels[i], "", true);
		vars.createSetting("splitBoss", "When killing the Boss", "", false);
		vars.createSetting("splitSkip", "When Glitch-Skipping a Level", "", false);
	settings.CurrentDefaultParent = "Start";
		for (int i = 0; i <= 6; i++)
			vars.createSetting("startLevel" + i, "When entering the " + vars.levels[i], "", true);
	settings.CurrentDefaultParent = "Reset";
		vars.createSetting("resetMenu", "When quitting back to the menu", "", true);
		vars.createSetting("resetLevel", "When dying or restarting a level", "", false);

	vars.i = 0;
	vars.reset = false;
	vars.skip = false;
	print("\n~Running " + vars.name + "~\n");
}

start
{
	if (!old.inLevel && current.inLevel && settings["startLevel" + current.level])
		return true;
	return false;
}

isLoading
{
    return (!current.inLevel);
}

reset
{
	if (settings["resetMenu"] && vars.reset) {
		vars.i = 0;
		vars.reset = false;
		return true;
	}
	if (settings["resetLevel"] && current.resetLevel != old.resetLevel && current.level == old.level) {
		vars.timer.Reset();
		vars.timer.Start();
	}
	if (!old.inLevel && !current.inLevel && settings["resetMenu"])
		vars.i++;
	return false;
}

split
{
	if (!old.levelCompleted && current.levelCompleted && settings["splitLevel" + current.level])
		return true;
	else if (settings["splitBoss"] && current.score == old.score + 2000)
		return true;
	else if (settings["splitSkip"] && !current.levelCompleted && old.levelCompleted && vars.skip) {
		vars.skip = false;
		return true;
	}
	return false;
}


update
{
	if (!old.inLevel && !current.inLevel) {
		if (vars.i >= 5)
			vars.reset = true;
		else if (vars.i <= -5) {
			vars.i = 0;
			vars.skip = true;
		}
		else if (settings["splitSkip"] && current.levelCompleted && !vars.skip)
			vars.i--;
   }
}
