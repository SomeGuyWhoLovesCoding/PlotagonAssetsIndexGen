import sys.FileSystem;
import sys.io.File;

typedef AssetEntry = {
	path:String,
	isDirectory:Bool,
	entries:Array<AssetEntry>
}

// generated via qwen 3.7 plus
class Main {
	static function main() {
		// Root entry represents the base of the JSON tree
		var rootEntry = createDirEntry(" ");
		var contentEntry = createDirEntry("Content");
		rootEntry.entries.push(contentEntry);

		var args = Sys.args();
		if (args.length == 0) {
			Sys.println("Plotagon AssetsIndex.json Gen Usage:\n- Main [path/to/your/folder]");
			return;
		}

		var contentPath = args[0];

		// Folders to scan inside Content
		var targetFolders = [
			"characters",
			"extracharacters",
			"items",
			"Languages",
			"music",
			"scenes",
			"sounds",
			"voices"
		];

		// Folders that require a depth of 2 (Subdirectories -> Files)
		var depthTwoFolders = ["items", "Languages", "voices"];

		if (!FileSystem.exists(contentPath) || !FileSystem.isDirectory(contentPath)) {
			Sys.println("Error: 'Content' folder not found in the current directory!");
			Sys.println('Check if path ${contentPath} exists.');
			return;
		}

		for (folder in targetFolders) {
			var folderPath = contentPath + "/" + folder;
			if (FileSystem.exists(folderPath) && FileSystem.isDirectory(folderPath)) {
				var folderEntry = createDirEntry("Content/" + folder);
				var isDepthTwo = depthTwoFolders.indexOf(folder) != -1;

				if (isDepthTwo) {
					scanDepthTwo(folderPath, "Content/" + folder, folderEntry);
				} else {
					scanFlat(folderPath, "Content/" + folder, folderEntry);
				}

				contentEntry.entries.push(folderEntry);
			} else {
				Sys.println("Warning: Target folder not found - " + folderPath);
			}
		}

		// Generate and save the JSON
		var jsonStr = buildJson(rootEntry);
		File.saveContent("assetsIndex.json", jsonStr);
		Sys.println("Successfully generated assetsIndex.json");
	}

	// Scans files directly inside the folder (Flat Depth)
	static function scanFlat(basePath:String, relativePath:String, parentEntry:AssetEntry) {
		var items = FileSystem.readDirectory(basePath);
		for (item in items) {
			var itemPath = basePath + "/" + item;
			if (!FileSystem.isDirectory(itemPath)) {
				parentEntry.entries.push(createFileEntry(relativePath + "/" + item));
			}
		}
	}

	// Scans subdirectories, and then the files inside those subdirectories (Depth of 2)
	static function scanDepthTwo(basePath:String, relativePath:String, parentEntry:AssetEntry) {
		var items = FileSystem.readDirectory(basePath);
		for (item in items) {
			var itemPath = basePath + "/" + item;
			if (FileSystem.isDirectory(itemPath)) {
				var subDirEntry = createDirEntry(relativePath + "/" + item);
				var subItems = FileSystem.readDirectory(itemPath);

				for (subItem in subItems) {
					var subItemPath = itemPath + "/" + subItem;
					if (!FileSystem.isDirectory(subItemPath)) {
						subDirEntry.entries.push(createFileEntry(relativePath + "/" + item + "/" + subItem));
					}
				}
				parentEntry.entries.push(subDirEntry);
			} else {
				// Fallback: In case there are loose files directly in the depth-two root folder
				parentEntry.entries.push(createFileEntry(relativePath + "/" + item));
			}
		}
	}

	static function createDirEntry(path:String):AssetEntry {
		return {path: path, isDirectory: true, entries: []};
	}

	static function createFileEntry(path:String):AssetEntry {
		return {path: path, isDirectory: false, entries: []};
	}

	static function escapeJson(s:String):String {
		return s.split("\\")
			.join("\\\\")
			.split('"')
			.join('\\"')
			.split("\n")
			.join("\\n")
			.split("\r")
			.join("\\r")
			.split("\t")
			.join("\\t");
	}

	// Custom serializer to perfectly match the engine's quirky JSON spacing/indentation requirements
	static function buildJson(entry:AssetEntry):String {
		var sb = new StringBuf();
		sb.add('{\n');

		// The root path is just a single space, others get a trailing space appended
		var pathStr = entry.path == "" ? "" : entry.path;

		sb.add(' "path ":  "' + escapeJson(pathStr) + '",\n');
		sb.add(' "isDirectory ": ' + entry.isDirectory + ',\n');
		sb.add(' "entries ": [\n');

		for (i in 0...entry.entries.length) {
			sb.add(buildJson(entry.entries[i]));
			if (i < entry.entries.length - 1)
				sb.add(',');
			sb.add('\n');
		}

		sb.add(' ]\n');
		sb.add('}');
		return sb.toString();
	}
}
