//Download dbgview to see the comments.
state("Sunblaze") {}

//
startup {
print("__STARTUP START__");
	vars.timer = new TimerModel { CurrentState = timer };
	//Look for a specific part of the game code, in this case a variable in a struct we are interested in. Easier to deal with than pointers for Unity games
	vars.signatureScan = (Func<Process, string, int, string, IntPtr>)((process, name, offset, target) => {
		print("____________\n" + name + " attempt\n____________");
		IntPtr ptr = IntPtr.Zero;
		foreach (var page in process.MemoryPages())
		{
			var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);
			if (ptr == IntPtr.Zero)
			{
				ptr= scanner.Scan(new SigScanTarget(offset,target));
			}
			if (ptr != IntPtr.Zero) {
				print("---------------------------------\n" + name + " address found at : 0x" + ptr.ToString("X8") + "\n---------------------------------");
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
	vars.createSetting("_subChapter", "Split At Each New Subchapter", "Arbitrary - Dialogues or new mechanics | Compatible with 'Individual Chapter Timer'", false);
	vars.createSetting("_IC", "Individual Chapter Timer", "'Full Game Timer' by default | Be sure that 'Single Level Timer' is off", false);
	vars.createSetting("_IL", "Single Level Timer", "Useful for developing new strategies and determining exactly what is faster", false);
	settings.CurrentDefaultParent = "_subChapter";
		vars.createSetting("_zenMode", "Zen Mode", "", false);
	settings.CurrentDefaultParent = "_IC";
		vars.createSetting("_levelSplit", "Split At Each New Level", "", true);
		vars.createSetting("_autoReset", "Reset Automatically", "Do not reset finished runs", false);
	settings.CurrentDefaultParent = "_IL";
		vars.createSetting("_doubleLevel", "Double Level Timer", "Complete 2 levels instead of 1 to stop the timer | Useful for testing starts that include transition shenanigans", false);

	vars.numberSplits = 22;
	//Used to split when you reach a certain level in a certain chapter - {chapter, level, verif} - verif is used as a boolean to know if we already reached a level this run and prevent multiple splits from happening
	vars.splits = new int[,] {
		{0, 12, 1},
		{1, 18, 1}, {1, 39, 1},
		{2, 9, 1}, {2, 41, 1}, {2, 58, 1},
		{3, 19, 1}, {3, 41, 1}, {3, 63, 1},
		{4, 22, 1}, {4, 39, 1},
		{5, 13, 1}, {5, 42, 1}, {5, 60, 1},
		{6, 7, 1}, {6, 15, 1}, {6, 38, 1}, {6, 52, 1}, {6, 63, 1}, {6, 91, 1}, {6, 104, 1}, {6, 120, 1}
	};
	vars.numberSplitsZen = 14;
	vars.splitsZen = new int[,] {
		{0, 10, 1},
		{1, 17, 1},
		{2, 10, 1}, {2, 20, 1},
		{3, 9, 1}, {3, 16, 1}, {3, 26, 1},
		{4, 7, 1}, {4, 17, 1}, {4, 23, 1},
		{5, 11, 1}, {5, 23, 1}, {5, 29, 1}, {5, 34, 1},
	};
	vars.timeTmp = -1;
	vars.levelTmp = -1;
print("__STARTUP END__");
}

//
init {
print("__INIT START__");
	
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

print("__INIT END__");
}

//
update {
	vars.watchers.UpdateAll(game);
	if(settings["_IL"]) {
		if(vars.fileTime.Current - vars.fileTime.Old > 1000000 || vars.fileTime.Current < vars.fileTime.Old) {
			vars.timeTmp = vars.fileTime.Current/10000;
			vars.levelTmp = vars.level.Current;
		}
		if ((settings["_doubleLevel"] && vars.levelTmp + 1 >= vars.level.Current) || (!settings["_doubleLevel"] && vars.levelTmp == vars.level.Current))
			timer.SetGameTime(TimeSpan.FromMilliseconds(vars.fileTime.Current/10000 - vars.timeTmp));
	}
	else
		timer.SetGameTime(TimeSpan.FromMilliseconds(settings["_IC"] ? vars.chapterTime.Current/10000 : vars.fileTime.Current/10000));
//	if(vars.mode.Current != vars.mode.Old)
//		print("Chapter = " + vars.chapter.Current + "\nLevel = " + vars.level.Current + "\nMode = " + vars.mode.Current);
}

//
start {
	if (settings["_IL"] && vars.mode.Old <= 4 && vars.mode.Current == 1) {
		vars.timeTmp = vars.fileTime.Current/10000;
		vars.levelTmp = vars.level.Current;
		return true;
	}
	else if (vars.mode.Old <= 4 && vars.mode.Current == 1 && vars.level.Current == 0) {
		if (settings["_zenMode"]) {
			for (int i = 0; i < vars.numberSplitsZen; i++)
				vars.splitsZen[i, 2] = 1;
		}
		else {
			for (int i = 0; i < vars.numberSplits; i++)
				vars.splits[i, 2] = 1;
		}
		return true;
	}
}

//
isLoading {
	return true;
}

//
reset {
	if (settings["_IC"] && settings["_autoReset"])
		return (vars.mode.Old == 2 && vars.mode.Current == 4);
	else if (settings["_IL"])
		return (vars.mode.Current == 4);
	return (vars.saveSlot.Current < vars.saveSlot.Old || vars.fileTime.Current < vars.fileTime.Old);
}

//
split {
	if(settings["_subChapter"]) {
		if (settings["_zenMode"]) {
			for (int i = 0; i < vars.numberSplitsZen; i++) 
				if(vars.chapter.Current == vars.splitsZen[i, 0] && vars.level.Current == vars.splitsZen[i, 1] && vars.splitsZen[i, 2] == 1) {
					vars.splitsZen[i, 2] = 0;
					return true;
				}
		}
		else {
			for (int i = 0; i < vars.numberSplits; i++) 
				if(vars.chapter.Current == vars.splits[i, 0] && vars.level.Current == vars.splits[i, 1] && vars.splits[i, 2] == 1) {
					vars.splits[i, 2] = 0;
					return true;
				}
		}
	}
	if(settings["_IC"])
		return((settings["_levelSplit"] && vars.level.Old < vars.level.Current) || vars.mode.Current == 3 && vars.mode.Old != 3);
	else
		return (vars.mode.Current != 3 && vars.mode.Old == 3);
}
