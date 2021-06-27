state("Sunblaze") {}

startup
{
	vars.Dbg = (Action<dynamic>) ((output) => print("[Sunblaze ASL] " + output));

	settings.Add("IL", false, "Individual level timer behavior");
		settings.SetToolTip("IL", "Includes resetting when entering any transition\nas well as syncing to the game's time for a level.");
		settings.Add("2IL", false, "Split only after every second level completion", "IL");
			settings.SetToolTip("2IL", "For testing strategies which involve transitions between levels.");
	settings.Add("IC", false, "Individual chapter timer behavior");
		settings.SetToolTip("IC", "Includes resetting when pressing \"Restart Chapter\"\nas well as syncing to the game's chapter timer.");

	int[][] Subchapters =
	{
		new[] { 13, 6, 21 },
		new[] { 10, 32, 17 },
		new[] { 20, 22, 22 },
		new[] { 23, 17 },
		new[] { 14, 29, 28 },
		new[] { 8, 8, 23, 14, 11, 28, 13, 16 }
	};

	string id, desc, parent;

	for (int ch = 0; ch < Subchapters.Length; ++ch)
	{
		id = "ch_" + ch;
		desc = "Chapter " + (ch + 1);
		settings.Add(id, true, desc);

		int total = 0;
		for (int sub = 0; sub < Subchapters[ch].Length; ++sub)
		{
			id = "sub_" + ch + "-" + sub;
			desc = "Subchapter " + (ch + 1) + "." + (sub + 1);
			parent = "ch_" + ch;
			settings.Add(id, true, desc, parent);

			for (int lvl = 0; lvl < Subchapters[ch][sub]; ++lvl)
			{
				id = "lvl_" + ch + "-" + total;
				desc = "Level " + (total + 1) + " (" + (lvl + 1) + " in subchapter)";
				parent = "sub_" + ch + "-" + sub;
				settings.Add(id, lvl == Subchapters[ch][sub] - 1, desc, parent);

				++total;
			}
		}
	}
}

init
{
	vars.TokenSource = new CancellationTokenSource();
	vars.ScanThread = new Thread(() =>
	{
		vars.Dbg("Starting scan thread.");

		Func<string, SigScanTarget, IntPtr> scanAllPages = (name, trg) =>
		{
			var ptr = IntPtr.Zero;
			foreach (var page in game.MemoryPages(true).Reverse())
			{
				var scnr = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
				if ((ptr = scnr.Scan(trg)) != IntPtr.Zero)
				{
					vars.Dbg("Found " + name + " at 0x" + ptr.ToString("X"));
					return ptr;
				}
			}

			return IntPtr.Zero;
		};

		vars.SplitInfo = IntPtr.Zero;
		var SplitInfoTrg = new SigScanTarget("7A 9C 97 04 D5 08 00 00 ?? 00 00 00");

		while (!vars.TokenSource.Token.IsCancellationRequested)
		{
			if ((vars.SplitInfo = scanAllPages("SplitInfo", SplitInfoTrg)) == IntPtr.Zero)
			{
				vars.Dbg("Resolving magic number was unsuccessful. Retrying.");
				Thread.Sleep(2000);
				continue;
			}

			break;
		}

		vars.Dbg("Exiting scan thread.");
	});

	vars.ScanThread.Start();

	vars.ILStartTime = (long)0;
	vars.ILStartLevel = 0;
}

update
{
	if (vars.ScanThread.IsAlive) return false;

	current.Mode         = game.ReadValue<int>((IntPtr)vars.SplitInfo  + 0x08);
	current.SaveSlot     = game.ReadValue<int>((IntPtr)vars.SplitInfo  + 0x0C);
	current.Chapter      = game.ReadValue<int>((IntPtr)vars.SplitInfo  + 0x10);
	current.Level        = game.ReadValue<int>((IntPtr)vars.SplitInfo  + 0x14);
	// current.TimerRunning = game.ReadValue<bool>((IntPtr)vars.SplitInfo + 0x18);
	current.FileTime     = game.ReadValue<long>((IntPtr)vars.SplitInfo + 0x20);
	current.ChapterTime  = game.ReadValue<long>((IntPtr)vars.SplitInfo + 0x28);
}

start
{
	if (old.Mode <= 4 && current.Mode == 1)
	{
		vars.ILStartTime = current.FileTime;
		vars.ILStartLevel = current.Level;
		return true;
	}
}

split
{
	if (settings["IL"]) return old.Level != current.Level && current.Level == vars.ILStartLevel + (settings["2IL"] ? 2 : 1);
	return old.Level != current.Level && settings["lvl_" + current.Chapter + "-" + current.Level];
}

reset
{
	return settings["IC"] && old.Mode == 2 && current.Mode == 4 ||
	       settings["IL"] && old.Mode != 4 && current.Mode == 4 ||
	       old.SaveSlot > -1 && current.SaveSlot == -1;
}

gameTime
{
	if (settings["IL"]) return TimeSpan.FromMilliseconds(current.FileTime / 10000f - vars.ILStartTime / 10000f);
	return TimeSpan.FromMilliseconds(settings["IC"] ? current.ChapterTime / 10000f : current.FileTime / 10000f);
}

isLoading
{
	return true;
}

exit
{
	vars.TokenSource.Cancel();
}

shutdown
{
	vars.TokenSource.Cancel();
}
