
state("CaveCrawler")
{
	int	 level			: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xE0;
	int  score			: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xB0;
	bool inLevel		: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0x48;
	bool levelCompleted	: 0x21C9C50, 0x138, 0x108, 0x0, 0x58, 0x20, 0xC8;
}

startup
{
	refreshRate = 60;

	if(timer.CurrentTimingMethod == TimingMethod.RealTime) {
		timer.CurrentTimingMethod = TimingMethod.GameTime;
		print("Timing Method Changed!");
	} 

	settings.Add("Level0", false, "Split at the end of the Tutorial");
	settings.Add("Level1", false, "Split at the end of the Level 1");
	settings.Add("Level2", false, "Split at the end of the Level 2");
	settings.Add("Level3", false, "Split at the end of the Level 3");
	settings.Add("Level4", false, "Split at the end of the Level 4");
	settings.Add("Boss", false, "Split when killing the Boss");
	settings.Add("Level5", true, "Split at the end of the Level 5");
	settings.Add("Level6", true, "Split at the end of the Bonus Level");
	settings.Add("Start1", false, "Start only when you enter the Level 1");

	vars.reset = 0;
}

start
{
	//start when you enter a level
	if (vars.reset != 0)
		vars.reset = 0;
	if (old.inLevel == false && current.inLevel == true && (!settings["Start1"] || current.level == 1))
		return true;
	return false;
}

isLoading
{
	//Pause the timer when not in a level (so either in the menu or during the transition between levels)
    return (!current.inLevel);
}

reset
{
	//reset when quitting back to the menu
	if (old.inLevel == false && current.inLevel == false)
		vars.reset++;
	if (vars.reset >= 10) {
		vars.reset = 0;
		return true;
	}
	return false;
}

split
{
	//split when you complete a level
	if (old.levelCompleted == false && current.levelCompleted == true && settings["Level" + current.level])
		return true;
	else if (settings["Boss"] && current.score == old.score + 2000)
		return true;
	return false;
}

update
{
}