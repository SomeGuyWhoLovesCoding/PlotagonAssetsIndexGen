import sys.FileSystem;
import sys.io.File;
import haxe.Json;

using StringTools;

typedef AssetEntry = {
	path: String,
	isDirectory: Bool,
	entries: Array<AssetEntry>
}

class Main {
	static function main() {
		var args = Sys.args();
		if (args.length == 0) {
			Sys.println("Plotagon AssetsIndex.json Gen Usage:\n- haxe --interp Main.hx [path/to/StreamingAssets]");
			return;
		}

		var streamingAssetsPath = args[0];

		if (!FileSystem.exists(streamingAssetsPath) || !FileSystem.isDirectory(streamingAssetsPath)) {
			Sys.println("Error: Specified folder not found!");
			Sys.println('Check if path "${streamingAssetsPath}" exists and is a directory.');
			return;
		}

		// Root entry represents the base of the JSON tree
		var rootEntry = createDirEntry(" ");
		
		// Scan all items in StreamingAssets
		scanDirectory(streamingAssetsPath, "", rootEntry);

		// Sort the top-level entries (files first, then folders)
		sortEntries(rootEntry.entries);

		// Generate and save the beautified JSON using \t for indentation
		var jsonStr = Json.stringify(rootEntry, null, "\t");
		File.saveContent("assetsIndex.json", jsonStr);
		Sys.println("Successfully generated assetsIndex.json");
	}

	// Scans directories recursively
	static function scanDirectory(basePath: String, relativePath: String, parentEntry: AssetEntry) {
		var items = FileSystem.readDirectory(basePath);
		items.sort(Reflect.compare);

		for (item in items) {
			// Skip hidden files, system files, and explicitly excluded folders
			if (item.startsWith(".") || item == "Thumbs.db" || item == "desktop.ini" || item == "CoherentUI_Host") {
				continue;
			}

			var itemPath = basePath + "/" + item;
			var itemRelativePath = relativePath == "" ? item : relativePath + "/" + item;
			
			if (FileSystem.isDirectory(itemPath)) {
				var dirEntry = createDirEntry(itemRelativePath);
				
				// Check if this is a folder that needs depth-2 scanning
				if (shouldScanDepthTwo(item)) {
					scanDepthTwo(itemPath, itemRelativePath, dirEntry);
				} else {
					// Recursively scan subdirectory
					scanDirectory(itemPath, itemRelativePath, dirEntry);
				}
				
				parentEntry.entries.push(dirEntry);
			} else {
				// It's a file
				parentEntry.entries.push(createFileEntry(itemRelativePath));
			}
		}
		
		// Sort entries: files first, then folders, alphabetically within each group
		sortEntries(parentEntry.entries);
	}

	// Scans subdirectories, and then the files inside those subdirectories (Depth of 2)
	static function scanDepthTwo(basePath: String, relativePath: String, parentEntry: AssetEntry) {
		var items = FileSystem.readDirectory(basePath);
		items.sort(Reflect.compare);

		for (item in items) {
			if (item.startsWith(".") || item == "Thumbs.db" || item == "desktop.ini") {
				continue;
			}

			var itemPath = basePath + "/" + item;
			if (FileSystem.isDirectory(itemPath)) {
				var subDirEntry = createDirEntry(relativePath + "/" + item);
				var subItems = FileSystem.readDirectory(itemPath);
				subItems.sort(Reflect.compare);

				for (subItem in subItems) {
					if (subItem.startsWith(".") || subItem == "Thumbs.db" || subItem == "desktop.ini") {
						continue;
					}
					var subItemPath = itemPath + "/" + subItem;
					if (!FileSystem.isDirectory(subItemPath)) {
						subDirEntry.entries.push(createFileEntry(relativePath + "/" + item + "/" + subItem));
					}
				}
				
				// Sort files inside the depth-two folder
				sortEntries(subDirEntry.entries);
				parentEntry.entries.push(subDirEntry);
			} else {
				// Fallback: loose files directly in the depth-two root folder
				parentEntry.entries.push(createFileEntry(relativePath + "/" + item));
			}
		}
		
		// Sort entries: files first, then folders, alphabetically within each group
		sortEntries(parentEntry.entries);
	}

	// Helper function to enforce "files first, folders last" + alphabetical order
	static function sortEntries(entries: Array<AssetEntry>) {
		entries.sort(function(a, b) {
			if (a.isDirectory != b.isDirectory) {
				// false (file) should come before true (directory)
				return a.isDirectory ? 1 : -1;
			}
			// If both are files or both are directories, sort alphabetically by path
			return Reflect.compare(a.path, b.path);
		});
	}

	static function shouldScanDepthTwo(folderName: String): Bool {
		// Check if the folder name matches the depth-two targets
		var depthTwoTargets = ["items", "voices", "Languages", "Animation", "Animations", "AnimatorBundle"];
		return depthTwoTargets.indexOf(folderName) != -1;
	}

	static function createDirEntry(path: String): AssetEntry {
		return {path: path, isDirectory: true, entries: []};
	}

	static function createFileEntry(path: String): AssetEntry {
		return {path: path, isDirectory: false, entries: []};
	}
}