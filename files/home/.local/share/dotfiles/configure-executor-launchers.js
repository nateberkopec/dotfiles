ObjC.import("AppKit");
ObjC.import("Foundation");

const defaults = $.NSUserDefaults.alloc.initWithSuiteName("com.tinycast.app");
const stored = defaults.dataForKey("customCommands");
const commands = stored.isNil()
	? []
	: JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(stored, $.NSUTF8StringEncoding)));
const launchers = [
	{
		id: "B08441BF-6EBE-4224-AEC4-18A6B3615C7A",
		name: "Open Personal Executor",
		command: 'exec "$HOME/.local/share/dotfiles/open-executor" personal',
	},
	{
		id: "4D436EF3-5202-485C-A203-48BBA62D9A6B",
		name: "Open Speedshop Executor",
		command: 'exec "$HOME/.local/share/dotfiles/open-executor" speedshop',
	},
];

for (const launcher of launchers) {
	const command = {
		...launcher,
		isEnabled: true,
		showsInRootSearch: true,
		loadsShellEnvironment: false,
		requiresConfirmation: false,
		showsConfirmation: true,
		arguments: [],
		showsOutput: false,
		iconSymbol: "network",
	};
	const index = commands.findIndex((entry) => entry.id === command.id);
	if (index < 0) commands.push(command);
	else commands[index] = command;
}

const encoded = JSON.stringify(commands);
const previous = stored.isNil()
	? null
	: ObjC.unwrap($.NSString.alloc.initWithDataEncoding(stored, $.NSUTF8StringEncoding));

if (
	previous !== encoded ||
	!defaults.boolForKey("customCommandsEnabled") ||
	!defaults.boolForKey("customCommandsShowInLauncher")
) {
	const apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.tinycast.app");
	for (let index = 0; index < apps.count; index++) {
		const app = apps.objectAtIndex(index);
		if (!app.terminate) throw new Error("Could not quit Tinycast to update its launchers.");
		let attempts = 0;
		while (!app.terminated && attempts++ < 50) {
			$.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1));
		}
		if (!app.terminated) throw new Error("Tinycast did not quit; launcher settings were not changed.");
	}
	defaults.setObjectForKey($(encoded).dataUsingEncoding($.NSUTF8StringEncoding), "customCommands");
	defaults.setBoolForKey(true, "customCommandsEnabled");
	defaults.setBoolForKey(true, "customCommandsShowInLauncher");
	if (!defaults.synchronize) throw new Error("Could not save Tinycast launchers.");
	if (apps.count > 0 && !$.NSWorkspace.sharedWorkspace.launchApplication("Tinycast")) {
		throw new Error("Launchers saved, but Tinycast could not be reopened.");
	}
}
