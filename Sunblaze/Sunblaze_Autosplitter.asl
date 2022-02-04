//Download dbgview to see the comments.
state("Sunblaze") {}

startup {
vars.print = (Action<dynamic>) ((output) => print("[Sunblaze ASL] " + output));
vars.print("__STARTUP START__");
	//
	vars.timer = new TimerModel { CurrentState = timer };
	//Look for a specific part of the game code, in this case a variable in a struct we are interested in. Easier to deal with than pointers for Unity games
	vars.signatureScan = (Func<Process, string, int, string, IntPtr>)((process, name, offset, target) => {
		vars.print("____________\n" + name + " attempt\n____________");
		IntPtr ptr = IntPtr.Zero;
		foreach (var page in process.MemoryPages())
		{
			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);
			if (ptr == IntPtr.Zero)
			{
				ptr= scanner.Scan(new SigScanTarget(offset,target));
			}
			if (ptr != IntPtr.Zero) {
				vars.print("---------------------------------\n" + name + " address found at : 0x" + ptr.ToString("X8") + "\n---------------------------------");
				break;
			}
		}
		return(ptr);
	});
	//
	vars.createSetting = (Func<string, string, string, bool, bool>)((name, description, tooltip, enabled) => {
		settings.Add(name, enabled, description);
		settings.SetToolTip(name, tooltip);
		return true;
	});
	//
	vars.levelOn = (Func<string[], string, bool>)((sTest, str) => {
		for (int i = 0; i < sTest.Length; ++i)
			if (sTest[i] == str)
				return true;
		return false;
	});
	//
	vars.buildOptions = (Func<int[], string, bool>)((numberLevel, optionName) => {
		for (int chap = 0; chap < numberLevel.Length; ++chap)
		{
			string id, desc;
			settings.CurrentDefaultParent = optionName;
			id = "_ch" + (chap) + "" + optionName[1];
			desc = chap == 6 ? "The Lost Levels" : "Chapter " + (chap + 1);
			settings.Add(id, true, desc);
			settings.CurrentDefaultParent = id;
			for (int lvl = 0; lvl < numberLevel[chap]; ++lvl)
			{
				id = "_lvl" + (chap) + "-" + (lvl) + optionName[1];
				desc = "Level " + (lvl + 1);
				//vars.print("ID = " + id + "  " + vars.levelOn(vars.defaultSplits, id));
				settings.Add(id, vars.levelOn(vars.defaultSplits, id), desc);
				//settings.SetToolTip(id, "" + id);
			}
		}
		return true;
	});
	//
	vars.defaultSplits = new string[] {
	"_lvl0-11n",
	"_lvl1-17n","_lvl1-38n",
	"_lvl2-8n","_lvl2-40n","_lvl2-57n",
	"_lvl3-18n","_lvl3-40n","_lvl3-62n",
	"_lvl4-21n","_lvl4-38n",
	"_lvl5-12n","_lvl5-41n","_lvl5-59n",
	"_lvl6-6n","_lvl6-14n","_lvl6-37n","_lvl6-51n","_lvl6-62n","_lvl6-90n","_lvl6-103n","_lvl6-119n",
	"_lvl0-9z",
	"_lvl1-16z",
	"_lvl2-9z","_lvl2-19z",
	"_lvl3-8z","_lvl3-15z","_lvl3-25z",
	"_lvl4-6z","_lvl4-16z","_lvl4-22z",
	"_lvl5-10z","_lvl5-22z","_lvl5-28z","_lvl5-33z"
	};

	vars.createSetting("_IC", "Individual Chapter Timer", "The Full Game Timer is active by default", false);
	vars.createSetting("_IL", "Individual Level Timer", "Useful for developing new strategies and determining exactly what is faster", false);
	vars.createSetting("_splits", "Custom Splits", "Choose at the end of which level you want to split", false);
	settings.CurrentDefaultParent = "_IC";
		vars.createSetting("_levelSplit", "Split at each new level", "", true);
		vars.createSetting("_autoReset", "Reset Automatically", "Reset when restarting the chapter, coming back to the menu or selecting a level through the menu\nDo not reset finished runs", true);
	settings.CurrentDefaultParent = "_IL";
		vars.createSetting("_doubleLevel", "Pause the timer after completing 2 levels", "Useful for testing transition strats", false);
		vars.createSetting("_splitIL", "Split", "Split on top of pausing the timer\nUseful if you want to keep a trace of your best time", false);
	settings.CurrentDefaultParent = "_splits";
		vars.createSetting("_normalModeSplits", "Normal Mode Splits", "", true);
		vars.createSetting("_hardModeSplits", "Hard Mode Splits", "", true);
		vars.createSetting("_zenModeSplits", "Zen Mode Splits", "", true);

	vars.numberLevelNormal = new int[] {39, 54, 67, 66, 68, 64, 126};
	vars.numberLevelHard = new int[] {11, 11, 11, 11, 11, 11};
	vars.numberLevelZen = new int[] {22, 28, 27, 29, 31, 38};
	vars.buildOptions(vars.numberLevelNormal, "_normalModeSplits");
	vars.buildOptions(vars.numberLevelHard, "_hardModeSplits");
	vars.buildOptions(vars.numberLevelZen, "_zenModeSplits");
	vars.timeTmp = -1;
	vars.levelTmp = -1;
vars.print("__STARTUP END__");
}


init {
vars.print("__INIT START__");
	
	IntPtr splitInfo = IntPtr.Zero;
	while(splitInfo == IntPtr.Zero){
		splitInfo = vars.signatureScan(game, "SplitInfo", 0, "7A9C9704D5080000??000000");
		if (splitInfo == IntPtr.Zero)
			System.Threading.Thread.Sleep(1000);
	}

	vars.mode = new MemoryWatcher<int>(new DeepPointer(splitInfo + 0x8));
	vars.saveSlot = new MemoryWatcher<int>(new DeepPointer(splitInfo + 0xC));
	vars.chapter = new MemoryWatcher<int>(new DeepPointer(splitInfo + 0x10));
	vars.level = new MemoryWatcher<int>(new DeepPointer(splitInfo + 0x14));
	vars.timerIsRunning = new MemoryWatcher<bool>(new DeepPointer(splitInfo + 0x18));
	vars.fileTime = new MemoryWatcher<long>(new DeepPointer(splitInfo + 0x20));
	vars.chapterTime = new MemoryWatcher<long>(new DeepPointer(splitInfo + 0x28));

	vars.watchers = new MemoryWatcherList() {
		vars.mode,
		vars.saveSlot, vars.chapter, vars.level,
		vars.timerIsRunning,
		vars.fileTime, vars.chapterTime
	};

vars.print("__INIT END__");
}

update {
	vars.watchers.UpdateAll(game);
	//vars.print(vars.mode.Current + " " + vars.saveSlot.Current + " " + vars.chapter.Current+ " " + vars.level.Current+ " " + vars.timerIsRunning.Current+ " " + vars.fileTime.Current + " " + vars.chapterTime.Current);
	//if(vars.mode.Current != vars.mode.Old || vars.timerIsRunning.Current != vars.timerIsRunning.Old) vars.print("Chapter = " + vars.chapter.Current + "\nLevel = " + vars.level.Current + "\nMode = " + vars.mode.Current + "\nTimerIsRunning = " + vars.timerIsRunning.Current + "\nFileTime = " + vars.fileTime.Current);
}


start {
	if (settings["_IL"] && vars.mode.Old <= 4 && vars.mode.Current == 1) {
		if (vars.timeTmp == vars.fileTime.Current/10000)
			return false;
		vars.timeTmp = vars.fileTime.Current/10000;
		vars.levelTmp = vars.level.Current;
		return true;
	}
	return (vars.mode.Old <= 4 && vars.mode.Current == 1 && vars.level.Current == 0 && (settings["_IC"] || vars.chapter.Current % 7 == 0));
}


isLoading {
	return true;
}


gameTime {
	if(settings["_IL"]) {
	 	if (vars.levelTmp + (settings["_doubleLevel"] ? 1 : 0) >= vars.level.Current)
			timer.SetGameTime(TimeSpan.FromMilliseconds(vars.fileTime.Current/10000 - vars.timeTmp));
	}
	else
		timer.SetGameTime(TimeSpan.FromMilliseconds(settings["_IC"] ? vars.chapterTime.Current/10000 : vars.fileTime.Current/10000));
}


reset {
	if (settings["_IL"] && vars.mode.Current == 4) {
		vars.timeTmp = vars.fileTime.Current/10000;
		return true;
	}
	else if (settings["_IC"] && settings["_autoReset"])
		return (vars.mode.Old == 2 && vars.mode.Current == 4);
	return (vars.saveSlot.Current < vars.saveSlot.Old || vars.fileTime.Current < vars.fileTime.Old);
}


split {
	//if(vars.level.Old + 1 == vars.level.Current) vars.print("_lvl" + (vars.chapter.Current % 7) + "-" + vars.level.Old+(vars.saveSlot.Current == 4 ? "z" : vars.chapter.Current > 6 ? "h" : "n"));
	if (settings["_IL"]) {
		if (settings["_splitIL"])
			return (vars.levelTmp + (settings["_doubleLevel"] ? 2 : 1) == vars.level.Current && vars.level.Current > vars.level.Old);
		return false;
	}
	else if(settings["_IC"]){
		if (settings["_levelSplit"]) {
			if (vars.level.Old < vars.level.Current)
				return true;
			return (vars.mode.Current == 3 && vars.mode.Old != 3);
		}
		if (vars.mode.Current == 3 && vars.mode.Old != 3)
			return true;
	}
	if(settings["_splits"] && vars.level.Old + 1 == vars.level.Current)
		return (settings["_lvl" + (vars.chapter.Current % 7) + "-" + vars.level.Old + (vars.saveSlot.Current == 4 ? "z" : vars.chapter.Current > 6 ? "h" : "n")]);
	return (vars.mode.Current == 3 && vars.timerIsRunning.Current != vars.timerIsRunning.Old);
}
//Bug :
//If alt+tab and afk on end of chapter screen it can split again when coming back 
