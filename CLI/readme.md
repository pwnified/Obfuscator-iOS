## obsfuckate

This project builds a binary that can be called from a build rule in Xcode. The binary must be on the path, or pointed to in the build rule.
It's purpose is to read a json strings file containing all your projects strings, and convert them to a header file as a build process in Xcode.

Associate a rule to match "*.obsfucate.json" and pass it 3 arguments, (input json, output header, class list). 
The custom script entry should look something like this:
   "${SRCROOT}/obsfuckate" "${INPUT_FILE_PATH}" "${DERIVED_FILES_DIR}/${INPUT_FILE_BASE}.h" "NSCoder+NSData+NSArray+NSError"
and make sure to add an output file:
   $(DERIVED_FILES_DIR)/$(INPUT_FILE_BASE).h
and it will automatically run when the input json changes.

Then drag the json strings file into the 'compile sources' build phase and MAKE SURE it's not in any 'copy resources' build phases.

To debug the obsfuckate command line project in Xcode, use the arguments passed on launch in Xcode:
${SRCROOT}/mystrings.obsfucate.json ${SRCROOT}/mystrings.obsfucate.h "NSArray+NSData+NSCoder"
or similar

The conditional macro DEFINE_FUNCTIONS is to control if the strings are declared or defined. Additionally, when defined, kClassSalts will be the list of salts ready to be passed to storeKey, ie.:
[Obfuscator storeKey:@"wtf" forSalt:kClassSalts, nil];

