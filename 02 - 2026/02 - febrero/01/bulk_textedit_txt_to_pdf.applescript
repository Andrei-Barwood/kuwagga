use AppleScript version "2.4"
use framework "Foundation"

property skipExistingPDF : true
property perFileDelaySeconds : 0.03
property textEditRestartInterval : 500
property outputSubfolderName : "_pdf"

on run
	set sourcePath to my chooseFolderPath()
	if sourcePath is missing value then return
	
	set fm to current application's NSFileManager's defaultManager()
	set rootURL to current application's NSURL's fileURLWithPath:sourcePath isDirectory:true
	set options to 0
	set fileEnum to fm's enumeratorAtURL:rootURL includingPropertiesForKeys:{} options:options errorHandler:(missing value)
	
	set processedCount to 0
	set convertedCount to 0
	set skippedCount to 0
	set errorCount to 0
	
	tell application "TextEdit" to launch
	
	repeat
		set fileURL to fileEnum's nextObject()
		if fileURL is missing value then exit repeat
		
		set isDirectoryEntry to (fileURL's hasDirectoryPath()) as boolean
		if isDirectoryEntry is false then
			set inputPath to (fileURL's |path|()) as text
			
			if my shouldSkipInputPath(inputPath) then
				set skippedCount to skippedCount + 1
			else
				set outputInfo to my outputPDFPathFor(inputPath)
				set outputDir to outputDir of outputInfo
				set outputPath to outputPath of outputInfo
				
				if my ensureDirectoryExists(outputDir, fm) then
					if skipExistingPDF and (fm's fileExistsAtPath:outputPath) as boolean then
						set skippedCount to skippedCount + 1
					else
						if my convertOneFile(inputPath, outputPath) then
							set convertedCount to convertedCount + 1
						else
							set errorCount to errorCount + 1
						end if
					end if
				else
					set errorCount to errorCount + 1
				end if
			end if
			
			set processedCount to processedCount + 1
			
			if (processedCount mod textEditRestartInterval) is 0 then
				tell application "TextEdit" to quit saving no
				current application's NSThread's sleepForTimeInterval:0.4
				tell application "TextEdit" to launch
			end if
			
			if perFileDelaySeconds > 0 then
				current application's NSThread's sleepForTimeInterval:perFileDelaySeconds
			end if
		end if
	end repeat
	
	try
		tell application "TextEdit" to quit saving no
	end try
	
	set reportText to "Processed: " & processedCount & return & "Converted: " & convertedCount & return & "Skipped existing PDF: " & skippedCount & return & "Errors: " & errorCount
	log reportText
end run

on chooseFolderPath()
	set scriptLine to "POSIX path of (choose folder with prompt \"Select the root folder with subfolders and text files:\")"
	set pickedPath to my runCommand("/usr/bin/osascript", {"-e", scriptLine})
	if pickedPath is missing value then return missing value
	if pickedPath is "" then return missing value
	return pickedPath
end chooseFolderPath

on outputPDFPathFor(inputPath)
	set nsPath to current application's NSString's stringWithString:inputPath
	set parentPath to nsPath's stringByDeletingLastPathComponent()
	set fileName to nsPath's lastPathComponent()
	set baseName to (current application's NSString's stringWithString:fileName)'s stringByDeletingPathExtension()
	set outputDir to (parentPath's stringByAppendingPathComponent:outputSubfolderName)
	set outputFile to (baseName's stringByAppendingPathExtension:"pdf")
	set outputPath to (outputDir's stringByAppendingPathComponent:outputFile)
	return {outputDir:outputDir as text, outputPath:outputPath as text}
end outputPDFPathFor

on shouldSkipInputPath(inputPath)
	set nsPath to current application's NSString's stringWithString:inputPath
	set ext to ((nsPath's pathExtension())'s lowercaseString()) as text
	if ext is "pdf" then return true
	
	set parentPath to (nsPath's stringByDeletingLastPathComponent()) as text
	if parentPath ends with ("/" & outputSubfolderName) then return true
	
	return false
end shouldSkipInputPath

on ensureDirectoryExists(dirPath, fm)
	if (fm's fileExistsAtPath:dirPath) as boolean then return true
	set mkResult to my runCommand("/bin/mkdir", {"-p", dirPath})
	if mkResult is missing value then return false
	return true
end ensureDirectoryExists

on runCommand(launchPath, argList)
	try
		set task to current application's NSTask's alloc()'s init()
		task's setLaunchPath:launchPath
		task's setArguments:argList
		
		set outPipe to current application's NSPipe's pipe()
		task's setStandardOutput:outPipe
		task's setStandardError:outPipe
		
		task's |launch|()
		task's waitUntilExit()
		
		if (task's terminationStatus() as integer) is not 0 then return missing value
		
		set dataOut to (outPipe's fileHandleForReading()'s readDataToEndOfFile())
		set rawText to (current application's NSString's alloc()'s initWithData:dataOut encoding:(current application's NSUTF8StringEncoding))
		if rawText is missing value then return missing value
		
		set trimmedText to (rawText's stringByTrimmingCharactersInSet:(current application's NSCharacterSet's whitespaceAndNewlineCharacterSet()))
		return trimmedText as text
	on error
		return missing value
	end try
end runCommand

on convertOneFile(inputPath, outputPath)
	set theDoc to missing value
	try
		tell application "TextEdit"
			set openedItem to open (POSIX file inputPath)
			if class of openedItem is list then
				set theDoc to item 1 of openedItem
			else
				set theDoc to openedItem
			end if
			
			with timeout of 300 seconds
				save theDoc in (POSIX file outputPath) as "PDF"
			end timeout
			
			close theDoc saving no
		end tell
		return true
	on error
		try
			if theDoc is not missing value then tell application "TextEdit" to close theDoc saving no
		end try
		return false
	end try
end convertOneFile

